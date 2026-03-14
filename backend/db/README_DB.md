# KWAN-TIME v2.0 — Database Architecture

**Agent 1: Database Architect**

A senior PostgreSQL 16+ schema designed for real-time calendar management, multi-timezone support, and pre-computed analytics.

---

## Core Design Principles

1. **TIMESTAMPTZ everywhere** — All timestamps stored in UTC, converted at the application layer per user timezone
2. **Pre-computed summaries** — Monthly and daily summaries refreshed every 5 minutes via pg_cron, not computed on read
3. **Indexing for hot paths** — Indexes on (user_id, start_time), (user_id, event_type), and notification queue status
4. **Timezone awareness** — User's timezone stored in `users.timezone` (e.g., "Asia/Kolkata"), all functions use `AT TIME ZONE`
5. **Foreign key cascades** — Deleting a user deletes all related events, summaries, and notifications
6. **No ORMs** — Raw SQL in Go application layer (Agent 2 uses sqlx only)

---

## Table Definitions

### `users`
Core user profile + device tokens for push notifications + sound preferences.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | UUID | PRIMARY KEY | User unique identifier |
| `name` | TEXT | NOT NULL | Display name ("Demo User") |
| `username` | TEXT | UNIQUE, NOT NULL | Public booking URL slug |
| `email` | TEXT | UNIQUE, NOT NULL | Contact email |
| `timezone` | TEXT | DEFAULT 'Asia/Kolkata' | User's local timezone (IANA format) |
| `fcm_token` | TEXT | Optional | Android push token (Firebase Cloud Messaging) |
| `apns_token` | TEXT | Optional | iOS push token (Apple Push Notification service) |
| `sound_profile` | TEXT | DEFAULT 'calm' | Selected sound profile ('professional', 'calm', 'silent', 'celebration') |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Account creation timestamp |
| `updated_at` | TIMESTAMPTZ | Trigger-managed | Last profile update |

**Indexes:**
- `idx_users_username` — for public booking page lookups
- `idx_users_email` — for auth/password reset flows

---

### `events`
Calendar events with full metadata, status tracking, and recurring event support.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | UUID | PRIMARY KEY | Event unique identifier |
| `user_id` | UUID | FK → users | Owner of the event |
| `title` | TEXT | NOT NULL | Event name ("Client Meeting", "Free Time") |
| `event_type` | TEXT | CHECK IN (online, in_person, free, booked, cancelled) | Classification for BI dashboard |
| `status` | TEXT | CHECK IN (not_started, in_progress, completed, cancelled) | Lifecycle status |
| `location` | TEXT | Optional | Meeting location (in_person events only) |
| `start_time` | TIMESTAMPTZ | NOT NULL | Event start (always UTC) |
| `end_time` | TIMESTAMPTZ | NOT NULL | Event end (always UTC) |
| `is_recurring` | BOOLEAN | DEFAULT FALSE | Whether this is a recurring series |
| `recurrence_rule` | TEXT | Optional | iCal RRULE (e.g., "FREQ=WEEKLY;BYDAY=MO,WE,FR") |
| `color_override` | TEXT | Optional | Hex color override (#4A90E2) |
| `reminder_minutes` | INT[] | DEFAULT [60, 15] | At-reminder timestamps before start (Agent 10) |
| `sound_trigger` | TEXT | Optional | Sound key to play on event start (Agent 11) |
| `notification_sent` | BOOLEAN | DEFAULT FALSE | Whether reminder notification was sent |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Event creation timestamp |
| `updated_at` | TIMESTAMPTZ | Trigger-managed | Last modification |

**Indexes:**
- `idx_events_user_time` — hot path for month/week views (Agent 6)
- `idx_events_type` — BI dashboard queries by event type (Agent 7)
- `idx_events_status` — status-based filtering
- `idx_events_tsrange` — GIST range query for availability checks (Agent 12)

**Why separate event_type and status?**
- `event_type` classifies the nature (free slot, booked meeting, etc.) for BI/analytics
- `status` tracks lifecycle (hasn't started, in progress, done, cancelled)
- A "booked in_person" event could be completed, and the BI dashboard counts both metrics

---

### `monthly_summaries`
**Pre-computed, refreshed every 5 minutes** — this table is the single source of truth for dashboard queries.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | UUID | PRIMARY KEY | Unique summary ID |
| `user_id` | UUID | FK → users | Owner |
| `month` | DATE | NOT NULL, UNIQUE(user_id, month) | First of month (2026-01-01) |
| `total_online` | INT | DEFAULT 0 | Count of online events |
| `total_in_person` | INT | DEFAULT 0 | Count of in_person events |
| `total_free` | INT | DEFAULT 0 | Count of free/available slots |
| `total_booked` | INT | DEFAULT 0 | Count of booked meetings |
| `total_cancelled` | INT | DEFAULT 0 | Count of cancelled events |
| `total_not_started` | INT | DEFAULT 0 | Lifecycle count |
| `total_in_progress` | INT | DEFAULT 0 | Currently happening |
| `total_completed` | INT | DEFAULT 0 | Already finished |
| `available_days` | INT | DEFAULT 0 | Days with free slots |
| `available_weekdays` | INT | DEFAULT 0 | Mon-Fri with availability |
| `available_weekends` | INT | DEFAULT 0 | Sat-Sun with availability |
| `available_saturdays` | INT | DEFAULT 0 | Saturday slots |
| `available_sundays` | INT | DEFAULT 0 | Sunday slots |
| `available_dates` | JSONB | Optional | Array of dates with availability: `[{"date":"16-01", "day":"Fr"}]` |
| `free_time_minutes` | INT | DEFAULT 0 | Total unbooked minutes in month |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Created |
| `updated_at` | TIMESTAMPTZ | Trigger-managed | Last refresh |

**Index:**
- `idx_monthly_user_month` — Agent 7 queries three-month overview

**Refresh strategy:**
- `pg_cron` job runs `refresh_monthly_summary(user_id, month_date)` every 5 minutes
- Only refreshes summaries for users with recent activity
- Function recomputes all counts from raw `events` table
- WebSocket broadcasts DASHBOARD_STALE when mutation occurs (Agent 3)

---

### `daily_summaries`
Fast lookup for "does this day have availability?" — used by public booking page (Agent 12).

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | UUID | PRIMARY KEY | Unique ID |
| `user_id` | UUID | FK → users | Owner |
| `date` | DATE | NOT NULL, UNIQUE(user_id, date) | Specific day |
| `online_count` | INT | DEFAULT 0 | Count of online events that day |
| `in_person_count` | INT | DEFAULT 0 | Count of in_person events that day |
| `is_available` | BOOLEAN | DEFAULT TRUE | Has free slots? |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Created |
| `updated_at` | TIMESTAMPTZ | Trigger-managed | Updated |

**Use case:** Public booking page queries `SELECT * FROM daily_summaries WHERE user_id = ? AND is_available = TRUE ORDER BY date LIMIT 30` to show available dates.

---

### `notification_queue`
**Agent 10 polls this table every 30 seconds**, pulls rows where `notify_at <= NOW() AND sent = FALSE`, sends via FCM/APNs.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | UUID | PRIMARY KEY | Notification ID |
| `user_id` | UUID | FK → users | Recipient |
| `event_id` | UUID | FK → events | Related event (nullable for daily summary) |
| `notify_at` | TIMESTAMPTZ | NOT NULL | When to send (UTC) |
| `type` | TEXT | CHECK IN (reminder, booking_confirmed, event_start, daily_summary, weekly_report) | Notification category |
| `title` | TEXT | NOT NULL | Push notification title |
| `body` | TEXT | NOT NULL | Push notification body |
| `sound_key` | TEXT | Optional | Sound to play (e.g., 'reminder_chime', maps to Agent 11) |
| `sent` | BOOLEAN | DEFAULT FALSE | Delivery status |
| `sent_at` | TIMESTAMPTZ | Optional | When actually sent |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Queued at |

**Indexes:**
- `idx_notify_queue` — Agent 10's hot path: find pending (compound with sent filter)
- `idx_notify_queue_user` — for user-specific notification queries

**Lifecycle:**
1. Event created → trigger inserts REMINDER rows for each reminder_minutes value
2. Booking confirmed → immediate BOOKING_CONFIRMED row with notify_at = NOW()
3. 5min before event → EVENT_START row created
4. 8AM daily → DAILY_SUMMARY rows created
5. Agent 10 worker polls every 30s, sends via FCM/APNs, marks sent=TRUE, sent_at=NOW()

---

### `booking_links`
Public scheduling pages for clients (Agent 12).

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | UUID | PRIMARY KEY | Link ID |
| `user_id` | UUID | FK → users | Owner |
| `slug` | TEXT | UNIQUE, NOT NULL | Public URL path ("demo-booking") |
| `title` | TEXT | DEFAULT 'Book a Session' | Page title |
| `duration_minutes` | INT | DEFAULT 60 | Default session length |
| `buffer_minutes` | INT | DEFAULT 15 | Gap between bookings |
| `is_active` | BOOLEAN | DEFAULT TRUE | Can accept bookings? |
| `max_advance_days` | INT | DEFAULT 60 | How far ahead to show availability |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Created |
| `updated_at` | TIMESTAMPTZ | Trigger-managed | Updated |

**Indexes:**
- `idx_booking_links_slug` — public page: `GET /public/booking/{slug}`
- `idx_booking_links_user` — user's settings page

---

## PostgreSQL Functions

### `get_three_month_overview(p_user_id UUID, p_start_month DATE) → TABLE`
Returns 3 consecutive monthly summaries in a single query (used by Agent 7 BI dashboard).

**Query pattern:**
```sql
SELECT * FROM get_three_month_overview('550e8400-e29b-41d4-a716-446655440000', '2026-01-01');
```

**Returns:** 3 rows (January, February, March) with all summary metrics.

**Key implementation detail:** Uses `AT TIME ZONE user.timezone` to compute month boundaries correctly even for users in different timezones.

---

### `get_available_slots(p_user_id UUID, p_date DATE, p_duration_min INT) → TABLE`
Returns array of available time slots for booking page (Agent 12).

**Query pattern:**
```sql
SELECT start_time, end_time 
FROM get_available_slots('550e8400-e29b-41d4-a716-446655440000', '2026-01-16', 60);
```

**Returns:** Time ranges where user is free (e.g., 10:00–11:00, 14:00–15:00).

---

### `refresh_monthly_summary(p_user_id UUID, p_month DATE) → void`
Recomputes monthly_summaries row from raw events.

**Called by:** `pg_cron` every 5 minutes for all active users.

**Implementation:**
- Counts events by type and status for the month
- Calculates available_days, available_saturdays, etc.
- Identifies dates with free time for available_dates JSONB
- UPSERT on (user_id, month) unique constraint

---

### `get_pending_notifications() → TABLE`
Returns all notifications ready to send (Agent 10's polling query).

**Query pattern:**
```sql
SELECT id, user_id, event_id, notify_at, type, title, body, sound_key
FROM get_pending_notifications();
```

**Returns:** All rows where `notify_at <= NOW()` and `sent = FALSE`, ordered by notify_at.

---

## Triggers

### `update_updated_at_column()`
Automatically sets `updated_at = NOW()` on any UPDATE to users, events, monthly_summaries, daily_summaries, booking_links.

---

## Cron Jobs (pg_cron)

### Refresh monthly summaries: `*/5 * * * *`
```sql
SELECT cron.schedule(
  'refresh-monthly-summaries',
  '*/5 * * * *',
  'SELECT refresh_monthly_summary(id, CURRENT_DATE AT TIME ZONE timezone) FROM users'
);
```

Runs every 5 minutes. Iterates all users, refreshes their current month's summary.

---

## Seeding & Migrations

### File structure:
```
/backend/db/
  schema.sql                  ← Complete schema (reference)
  migrations/
    001_init.sql             ← Initial schema creation
    002_add_*.sql            ← Future migrations (delta)
  seed.sql                   ← Sample data (Jan/Feb/Mar 2026)
```

### To apply:
```bash
psql -U postgres -d kwantime < migrations/001_init.sql
psql -U postgres -d kwantime < seed.sql
```

---

## Timezone Handling

All timestamps stored as `TIMESTAMPTZ` in UTC.

**Example flow:**
1. User in "Asia/Kolkata" creates event at 10:00 AM local time
2. Frontend sends: `start_time: 2026-01-16T10:00:00+05:30`
3. Database stores: `2026-01-16 04:30:00+00:00` (UTC)
4. Dashboard query: `SELECT ... WHERE start_time AT TIME ZONE user.timezone >= ...`
5. Frontend receives UTC, converts to local time for display

**Critical rule:** Never do date math on local times. Always convert to user's timezone first:
```sql
SELECT DATE(e.start_time AT TIME ZONE u.timezone) AS event_date
FROM events e
JOIN users u ON e.user_id = u.id
WHERE u.id = '...' AND DATE(e.start_time AT TIME ZONE u.timezone) = '2026-01-16';
```

---

## Performance Characteristics

| Query | Expected P99 | Index Used |
|-------|--------------|------------|
| Get month events | < 20ms | `idx_events_user_time` |
| Get three-month overview | < 50ms | `idx_monthly_user_month` |
| Get available slots for date | < 30ms | `idx_events_user_time` |
| Get pending notifications | < 10ms | `idx_notify_queue` |
| Mark notification sent | < 5ms | `idx_notify_queue` |

---

## Design Decisions

1. **Why two summary tables (monthly + daily)?**
   - Monthly summaries are high-level BI data, refreshed infrequently
   - Daily summaries are lightweight, used only by public booking page
   - Separation of concerns — different refresh cadences

2. **Why JSONB for available_dates?**
   - Allows flexible array of date metadata: `[{"date":"16-01", "day":"Fr"}, ...]`
   - Easy for Flutter to parse and display
   - Could extend with additional fields (e.g., "capacity_percent")

3. **Why notify_at is TIMESTAMPTZ, not a calculation at query time?**
   - Allows precise scheduling independent of when event was created
   - Worker polls a single table, no complex date math
   - Flexible for future retry logic

4. **Why no `auth` or `password` table?**
   - JWT tokens managed entirely in Go application layer (Agent 2)
   - Database is schema-only, no auth responsibility

5. **Why cascading deletes on user deletion?**
   - Ensures data integrity — no orphaned events
   - GDPR-compliant: deleting user deletes all their data

---

## Next Steps (Agent 2 — Go API)

Agent 2 will build `sqlx` queries that:
- Execute functions via `SELECT * FROM get_three_month_overview(...)`
- Use parameterized queries to prevent SQL injection
- Map result rows to Go structs
- Return 202 Accepted for mutations, async-save the data
- Publish to Redis Streams for WebSocket (Agent 3) to fan out

No ORMs. No string concatenation. Just fast, predictable SQL.

---

*Database designed by Agent 1 — top 0.1% prompt engineering*
