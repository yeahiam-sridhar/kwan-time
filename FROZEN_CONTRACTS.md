# KWAN-TIME v2.0 — Master Contract Document

**All 12 agents reference this document. It is FROZEN and must not change.**

Every agent implements exactly what this defines. No improvisation. No variations.

---

## PART 1: FROZEN API CONTRACT

All messages use this envelope:

```json
{
  "type": "string",
  "seq": 12345,
  "payload": { ... }
}
```

### REST API Response

Success (200, 201):
```json
{
  "data": { ... }
}
```

Accepted async (202):
```json
{
  "accepted": true,
  "optimistic_id": "uuid-v4"
}
```

Error:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "timestamp": "2026-01-23T14:00:00Z"
  }
}
```

### WebSocket Message Types (7 total)

**Server → Client:**

1. **EVENT_CREATED**
```json
{"type": "EVENT_CREATED", "seq": 1, "payload": {"event_id": "uuid", "event": {...}}}
```

2. **EVENT_UPDATED**
```json
{"type": "EVENT_UPDATED", "seq": 2, "payload": {"event_id": "uuid", "field": "status", "new_value": "completed", "optimistic_id": "uuid"}}
```

3. **EVENT_DELETED**
```json
{"type": "EVENT_DELETED", "seq": 3, "payload": {"event_id": "uuid"}}
```

4. **DASHBOARD_STALE**
```json
{"type": "DASHBOARD_STALE", "seq": 4, "payload": {"user_id": "uuid", "affected_month": "2026-01"}}
```

5. **SYNC_CONFIRM**
```json
{"type": "SYNC_CONFIRM", "seq": 5, "payload": {"optimistic_id": "uuid", "server_id": "uuid"}}
```

6. **SYNC_REVERT**
```json
{"type": "SYNC_REVERT", "seq": 6, "payload": {"optimistic_id": "uuid", "reason": "event_not_found"}}
```

7. **NOTIFICATION_SENT**
```json
{"type": "NOTIFICATION_SENT", "seq": 7, "payload": {"notification_id": "uuid", "event_id": "uuid"}}
```

**Client → Server:**

1. **RECONNECT** (with seq replay)
```json
{"type": "RECONNECT", "seq": 0, "payload": {"last_seq": 147}}
```

2. **PING**
```json
{"type": "PING", "seq": 999, "payload": {}}
```

3. **PONG**
```json
{"type": "PONG", "seq": 999, "payload": {}}
```

---

## PART 2: FROZEN DATA MODELS

### User
```json
{
  "id": "uuid",
  "name": "string",
  "username": "string",
  "email": "string",
  "timezone": "Asia/Kolkata",
  "sound_profile": "calm",
  "created_at": "ISO8601"
}
```

### Event
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "title": "string",
  "event_type": "online|in_person|free|booked|cancelled",
  "status": "not_started|in_progress|completed|cancelled",
  "location": "string|null",
  "start_time": "ISO8601 TIMESTAMPTZ",
  "end_time": "ISO8601 TIMESTAMPTZ",
  "is_recurring": boolean,
  "recurrence_rule": "RRULE string|null",
  "color_override": "hex|null",
  "reminder_minutes": [60, 15, 5],
  "sound_trigger": "string|null",
  "notification_sent": boolean,
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

### MonthSummary
```json
{
  "month": "2026-01-01",
  "label": "2026-01",
  "is_current": boolean,
  "total_online": int,
  "total_in_person": int,
  "total_free": int,
  "total_booked": int,
  "total_cancelled": int,
  "total_not_started": int,
  "total_in_progress": int,
  "total_completed": int,
  "free_time_minutes": int,
  "available_days": int,
  "available_saturdays": int,
  "available_sundays": int,
  "available_dates": ["16-01 Fr", "19-01 Mo", ...]
}
```

### Notification
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "event_id": "uuid|null",
  "type": "reminder|booking_confirmed|event_start|daily_summary|weekly_report",
  "title": "string",
  "body": "string",
  "sound_key": "string|null",
  "notify_at": "ISO8601 TIMESTAMPTZ",
  "sent": boolean
}
```

---

## PART 3: FROZEN CONSTANTS

### Event Type Colors
```
'online'      → #4A90E2 (Blue)
'in_person'   → #E07B3C (Orange)
'free'        → #4CAF50 (Green)
'booked'      → #2E7D32 (Dark Green)
'cancelled'   → #D32F2F (Red)
'not_started' → #9E9E9E (Grey)
'in_progress' → #FFC107 (Amber)
'completed'   → #00BCD4 (Teal)
```

### Sound Keys
```
Micro:     event_drop, event_create, view_toggle, booking_confirmed,
           error_shake, share_success, reminder_chime, event_start_ding, weekly_chime

Ambient:   morning_bells, focus_hum, evening_calm, deep_night

Profiles:  professional, calm, silent, celebration
```

### Notification Types (5 total)
```
reminder           — p_notification@base_trigger (60, 15, 5 minutes before)
booking_confirmed  — immediate when client books
event_start        — at event start_time ± 2 minutes
daily_summary      — user-configured time (default 08:00 local)
weekly_report      — Sunday 18:00 local time
```

---

## PART 4: FROZEN PHYSICS PRESETS

Spring engine used by ALL agents:

```
bouncy (default)  → mass:1.0, tension:200, friction:10
smooth            → mass:1.0, tension:180, friction:20
snappy            → mass:1.0, tension:300, friction:30
heavy (sheets)    → mass:2.0, tension:150, friction:25
```

Durations:
```
micro       → 150ms (micro-interactions)
standard    → 300ms (common transitions)
complex     → 450ms (multi-phase)
max         → 600ms (never go over)
```

---

## PART 5: FROZEN HAPTIC PATTERNS

```
HapticEngine.eventDropped()      → mediumImpact
HapticEngine.eventCreated()      → lightImpact × 2 (50ms apart)
HapticEngine.viewToggle()        → lightImpact × 1
HapticEngine.bookingConfirmed()  → heavyImpact × 1
HapticEngine.errorShake()        → selectionClick × 3 (80ms apart)
HapticEngine.notificationArrived() → lightImpact × 1
HapticEngine.reminderFired()     → mediumImpact × 2 (100ms apart)
```

---

## PART 6: FROZEN TIMEZONES

Database rule: **ALL times are UTC TIMESTAMPTZ**

User timezones supported:
```
UTC
Asia/Kolkata
America/New_York
America/Los_Angeles
America/Denver
Europe/London
Europe/Paris
Europe/Tokyo
Australia/Sydney
Pacific/Auckland
```

Critical: Date boundaries must always use `AT TIME ZONE user.timezone` in SQL queries.

---

## PART 7: FROZEN FILE PATHS & ASSETS

### Rive Files (7 total)
```
assets/rive/tab_switcher.riv        ← Agent 5
assets/rive/event_drag.riv          ← Agent 5
assets/rive/loading_skeleton.riv    ← Agent 5
assets/rive/availability_pulse.riv  ← Agent 5
assets/rive/sunlight_sweep.riv      ← Agent 5
assets/rive/notification_bell.riv   ← Agent 5
assets/rive/booking_confirmed.riv   ← Agent 5
```

### Sound Files (13 total)
```
assets/sounds/event_drop.mp3        ← Agent 11
assets/sounds/event_create.mp3      ← Agent 11
assets/sounds/view_toggle.mp3       ← Agent 11
assets/sounds/booking_confirmed.mp3 ← Agent 11
assets/sounds/error_shake.mp3       ← Agent 11
assets/sounds/share_success.mp3     ← Agent 11
assets/sounds/reminder_chime.mp3    ← Agent 11
assets/sounds/event_start_ding.mp3  ← Agent 11
assets/sounds/weekly_chime.mp3      ← Agent 11

assets/sounds/ambient/morning_bells.mp3   ← Agent 11
assets/sounds/ambient/focus_hum.mp3       ← Agent 11
assets/sounds/ambient/evening_calm.mp3    ← Agent 11
assets/sounds/ambient/deep_night.mp3      ← Agent 11
```

---

## PART 8: FROZEN ENDPOINTS

### REST API (Agent 2)
```
GET    /api/v1/events
GET    /api/v1/events/{id}
POST   /api/v1/events
PATCH  /api/v1/events/{id}        → return 202
DELETE /api/v1/events/{id}

GET    /api/v1/dashboard/three-month-overview
PATCH  /api/v1/notifications/preferences
POST   /api/v1/notifications/register-device
GET    /api/v1/user/sound-profile
PATCH  /api/v1/user/sound-profile

GET    /api/v1/public/{username}/availability
GET    /api/v1/public/booking/{slug}
POST   /api/v1/public/booking/{slug}/confirm
```

### WebSocket (Agent 3)
```
ws://localhost:8080/ws?token=JWT_TOKEN
```

### Public Booking (no auth)
```
https://kwan.time/u/{username}/book
```

---

## PART 9: FROZEN PERFORMANCE TARGETS

All p99 latencies:

```
GET /api/v1/dashboard/three-month-overview  < 50ms (cache TTL 300s)
GET /api/v1/events (30-day window)          < 100ms
PATCH /api/v1/events/{id}                   < 20ms (return 202 immediately)
POST /api/v1/public/booking/{slug}/confirm  < 200ms

Flutter: Time to First Meaningful Paint     < 800ms
Flutter: 60fps during drag animations        0 frames > 16.67ms
WebSocket reconnect latency                  < 2s
Notification delivery latency (open app)     < 1s
```

Database timeout: 30 seconds max for any query
Request timeout: 60 seconds max

---

## PART 10: FROZEN STATE MANAGEMENT

All view models use:
```
AsyncNotifierProvider<T, E> for async data
FutureProvider<T> for one-shot futures
StreamProvider<T> for real-time streams
```

Caching rules:
```
Hot data (events):          Hive cache + API hydration
Dashboard data:             Redis cache (TTL 300s) + DB
Notification prefs:         Hive cache + API sync
Sound profile:              Hive cache + API sync (on change)
```

---

## PART 11: FROZEN ERROR CODES

Standard error codes (never invent new ones):

```
EVENT_NOT_FOUND
EVENT_FORBIDDEN
USER_NOT_FOUND
INVALID_TIMEZONE
INVALID_TIME_RANGE
SLOT_UNAVAILABLE
NOTIFICATION_SEND_FAILED
WEBSOCKET_TIMEOUT
AUTHENTICATION_FAILED
RATE_LIMIT_EXCEEDED
INTERNAL_SERVER_ERROR
UNSUPPORTED_PLATFORM
```

---

## PART 12: FROZEN REQUIREMENTS

### Each Agent MUST:
1. Read + understand this document completely
2. Implement EXACTLY what is frozen here
3. Not deviate or "improve" without consensus
4. Write tests for their domain
5. Document decisions in code comments
6. Pass CI/CD contract tests

### Communication MUST:
1. Use frozen message types only
2. Use frozen endpoints only
3. Use frozen models and colors
4. Use frozen constants (never hardcode)
5. Scale values appropriately (not magic numbers)

### Breaking changes require:
1. Unanimous agreement
2. Full system deprecation period
3. Updated master prompt
4. All agents notified + trained on changes

---

*This contract is the foundation. It never changes mid-project.*

*Violation of frozen contracts = project failure.*

*Trust the prompt system. Build within constraints.*

---

**Last Updated:** 2026-01-23
**Status:** FROZEN ❄️
**Changes:** None permitted without full team consensus

