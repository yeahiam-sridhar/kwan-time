# KWAN-TIME v2.0

**The Ultimate Calendar + BI Dashboard for Professionals**

*Sunlight animations. Glassmorphism. Zero-latency booking. Real-time sync.*

---

## 🎯 Vision

A business owner opens Kwan-Time at 8 AM. The sunlight animation sweeps from the top-left. A gentle morning chime plays. They swipe to the BI Dashboard. In under 1 second they see: *"5 free Fridays in January. I'm packed in March."* They tap a free date → a share link appears → they send it to a client → the client books → a notification arrives with a satisfying sound → the dashboard count drops with a spring animation.

**That moment must feel like magic. Your code makes the magic possible.**

---

## 🏗️ Full Stack

```
Frontend:  Flutter 3.19+ (Dart 3) + Rive (animations)
Backend:   Go 1.22+ + PostgreSQL 16 + Redis 7
Real-time: WebSockets (gorilla/websocket) + Redis Streams
Notify:    Firebase Cloud Messaging (FCM) + APNs
Audio:     just_audio + audio_service (Flutter)
State:     Riverpod + Hive (local-first)
Router:    go_router
CI/CD:     GitHub Actions + Docker Compose
```

---

## 🤖 12-Agent System

Each agent owns a vertical slice. Frozen contracts prevent conflicts. Parallel development.

| Agent | Role | Status |
|-------|------|--------|
| 1 | Database Architect (PostgreSQL) | ✅ COMPLETE |
| 2 | Go REST API Engineer | 🚀 NEXT |
| 3 | WebSocket & Real-time | ⏳ Depends on 2 |
| 4 | Flutter UI Shell | ✅ COMPLETE |
| 5 | Rive Animator | ⏳ Week 3 |
| 6 | Classic Calendar View | ⏳ Week 3 |
| 7 | BI Dashboard View | ⏳ Week 3 |
| 8 | Physics & Interactions | ⏳ Week 3 |
| 9 | QA & Integration Testing | ⏳ Week 4 |
| 10 | Push Notifications | 🚀 NEXT |
| 11 | Sound & Music Engine | ✅ SCAFFOLD |
| 12 | Public Booking Page | ⏳ Week 3 |

---

## 📂 Repository Structure

```
kwan-time/
├── backend/
│   ├── db/                      ← Agent 1 (Database)
│   │   ├── schema.sql           ✅ Complete schema
│   │   ├── migrations/
│   │   │   └── 001_init.sql     ✅ Initial migration
│   │   ├── seed.sql             ✅ Sample data
│   │   └── README_DB.md         ✅ Schema documentation
│   ├── cmd/
│   │   └── server/              ← Agent 2 (API)
│   │       └── main.go          🚀 TODO
│   ├── internal/
│   │   ├── handlers/            ← Agent 2
│   │   ├── repository/          ← Agent 2
│   │   ├── models/              ← Agent 2
│   │   ├── middleware/          ← Agent 2
│   │   ├── websocket/           ← Agent 3
│   │   └── notifications/       ← Agent 10
│   └── docs/
│       └── openapi.yaml         ← Agent 2
│
├── frontend/
│   └── kwan_time/               ← Flutter app
│       ├── pubspec.yaml         ✅ Dependencies configured
│       ├── lib/
│       │   ├── main.dart        ✅ App shell
│       │   ├── core/
│       │   │   ├── theme/       ✅ Glassmorphism theme
│       │   │   ├── constants/   ✅ event_colors, sound_keys, api_routes
│       │   │   ├── providers/   ✅ Riverpod architecture + interfaces
│       │   │   ├── router/      ✅ GoRouter setup
│       │   │   └── services/    🚀 TODO (Agent 2 API client)
│       │   ├── shared/
│       │   │   └── widgets/     🚀 TODO (GlassCard, etc.)
│       │   └── features/
│       │       ├── classic_calendar/  ← Agent 6
│       │       ├── bi_dashboard/      ← Agent 7
│       │       ├── public_booking/    ← Agent 12
│       │       ├── notifications/     ← Agent 10
│       │       └── sound/             ← Agent 11
│       └── assets/
│           ├── rive/            ← 7 animations (Agent 5)
│           └── sounds/          ← 13 audio files (Agent 11)
│
├── .github/
│   └── workflows/               ← Agent 9 (CI/CD)
│       └── ci.yml              🚀 TODO
│
├── docker-compose.yml           ← PostgreSQL + Redis + Go (Agent 2)
├── SETUP_PROGRESS.md            ✅ Detailed build status
└── README.md                    ← This file
```

---

## 🚀 Getting Started

### Prerequisites
- **macOS/Linux/Windows** (WSL2 recommended)
- **Flutter 3.19+** with Dart 3
- **Go 1.22+**
- **PostgreSQL 16+**
- **Redis 7+**
- **Node.js 18+** (for build tools)

### 1. Clone & Setup Database

```bash
# Clone repo
git clone https://github.com/yourorg/kwan-time.git
cd kwan-time

# Start PostgreSQL + Redis (via Docker)
docker-compose up -d

# Initialize database
psql -U postgres -d kwantime < backend/db/migrations/001_init.sql
psql -U postgres -d kwantime < backend/db/seed.sql

# Verify
psql -U postgres -d kwantime -c "SELECT COUNT(*) FROM users;"
# Expected output: 1 (demo user)
```

### 2. Run Backend (Agent 2 placeholder)

```bash
# Agent 2 to implement (Week 2)
# For now, database is ready and can be queried directly

# Future:
# cd backend
# go run cmd/server/main.go
# Server will listen on http://localhost:8080
```

### 3. Run Frontend (Agent 4 scaffold ready)

```bash
cd frontend/kwan_time
flutter pub get
flutter run -d <device_id>
```

**For iOS Simulator:**
```bash
flutter run -d "iPhone 15"
```

**For Android Emulator:**
```bash
flutter run -d emulator-5554
```

**For Web:**
```bash
flutter run -d chrome
```

---

## 📋 Development Phases

### Phase 1: Foundation ✅ (Week 1)
- [x] **Agent 1:** Database schema + migrations + seed
- [x] **Agent 4:** Flutter shell + theme + constants + interfaces
- [x] **Agent 11:** Sound infrastructure setup

### Phase 2: Backend 🚀 (Week 2)
- [ ] **Agent 2:** REST API + models + handlers
- [ ] **Agent 3:** WebSocket real-time + Redis Streams
- [ ] **Agent 10:** Push notifications (Go worker)

### Phase 3: Frontend Views ⏳ (Week 3)
- [ ] **Agent 5:** Rive animations (7 state machines)
- [ ] **Agent 6:** Classic calendar (month/week/day views)
- [ ] **Agent 7:** BI dashboard (3-month overview)
- [ ] **Agent 8:** Physics engine (springs, gooey drag, parallax)
- [ ] **Agent 10:** Push notifications (Flutter UI)
- [ ] **Agent 11:** Sound service (micro + ambient audio)
- [ ] **Agent 12:** Public booking page (client-facing)

### Phase 4: QA & Deploy ⏳ (Week 4)
- [ ] **Agent 9:** Integration tests + performance benchmarks + CI/CD

---

## 🎨 Design System

### Glassmorphism 2026

**Colors (Single Source of Truth):**
```dart
// lib/core/constants/event_colors.dart
online:      #4A90E2  (Blue)
in_person:   #E07B3C  (Orange)
free:        #4CAF50  (Green)
booked:      #2E7D32  (Dark Green)
cancelled:   #D32F2F  (Red)
```

**Glass Surfaces:**
- Background: 10% white (`Color(0x1AFFFFFF)`)
- Border: 20% white (`Color(0x33FFFFFF)`)
- Blur: 20px backdrop filter

**Sunlight Animation:**
- 6 AM: Warm orange-white from top-left
- 12 PM: Bright yellow from top-center
- 6 PM: Warm amber from top-right
- 10 PM: Deep blue-indigo (night)
- Interpolates hourly, updates every 15 minutes

---

## 🔐 Database Schema Highlights

### Core Tables
- **users** — Profile + device tokens + preferences
- **events** — Calendar events + status + recurrence
- **monthly_summaries** — Pre-computed analytics (refreshed 5min)
- **daily_summaries** — Quick day availability lookup
- **notification_queue** — Agent 10 polls this, sends push
- **booking_links** — Public scheduling pages (Agent 12)

### Key Functions
- `get_three_month_overview()` → BI dashboard data
- `get_available_slots()` → Public booking calendar
- `refresh_monthly_summary()` → Cron-triggered analytics
- `get_pending_notifications()` → Agent 10 worker query

### Timezone Handling
All times stored as `TIMESTAMPTZ` (UTC). Converted to user timezone at app layer via `AT TIME ZONE user.timezone`.

**Example:**
```sql
SELECT DATE(e.start_time AT TIME ZONE u.timezone) AS event_date
FROM events e
JOIN users u ON e.user_id = u.id
WHERE u.id = '550e8400-e29b-41d4-a716-446655440000'::uuid;
```

---

## 📡 API Contract (Frozen)

### Error Response
```json
{
  "error": {
    "code": "EVENT_NOT_FOUND",
    "message": "The event you requested does not exist",
    "timestamp": "2026-01-23T14:00:00Z"
  }
}
```

### Optimistic Update Protocol
1. Flutter generates `optimistic_id = UUID.v4()`
2. Local state changes immediately
3. API call sends `X-Optimistic-ID: {uuid}` header
4. Go returns `202 Accepted` with ID echo
5. WebSocket broadcasts `SYNC_CONFIRM{optimistic_id}` or `SYNC_REVERT{reason}`
6. Flutter reconciles locally

### WebSocket Messages (7 types)
```
EVENT_CREATED      → {event_id, full_object}
EVENT_UPDATED      → {event_id, field, value, optimistic_id}
EVENT_DELETED      → {event_id}
DASHBOARD_STALE    → {user_id, affected_month}
SYNC_CONFIRM       → {optimistic_id, server_id}
SYNC_REVERT        → {optimistic_id, reason}
NOTIFICATION_SENT  → {notification_id, event_id}
PING/PONG          → (heartbeat)
```

---

## 🎵 Audio System

### Micro-Sounds (UI Feedback)
- `event_drop` — Soft bloop on drag drop
- `event_create` — Pop + shimmer on new event
- `view_toggle` — Whoosh on tab switch
- `booking_confirmed` — Crystal bell ding
- `error_shake` — Low thud on sync failure
- `share_success` — 3-note chime
- `reminder_chime` — Gentle reminder
- `event_start_ding` — Clear tone when event starts
- `weekly_chime` — Weekly summary notification

### Ambient Music (Time-of-Day)
- **6 AM–10 AM:** Tibetan bowl ambience (morning_bells)
- **10 AM–5 PM:** 40Hz binaural + brown noise (focus_hum)
- **5 PM–10 PM:** Soft piano / lo-fi (evening_calm)
- **10 PM–6 AM:** Minimal rain + silence (deep_night)
- Crossfade 3 seconds at transitions

### Sound Profiles
User selects one:
- **Professional** — Micro-sounds only
- **Calm** — Micro + ambient (default)
- **Silent** — Haptics only
- **Celebration** — Full sounds + richer effects

---

## 🧪 Testing & Quality

### Performance Targets (Agent 9)
- Dashboard GET → p99 < 50ms (Redis cache TTL 300s)
- Event PATCH → p99 < 20ms (202 Accepted async)
- Time to first meaningful paint → < 800ms
- 60fps during drag animations
- 100 concurrent users × 5 min load test → < 0.1% error

### Contract Tests
- API response ↔ Dart model serialization
- WebSocket messages ↔ Riverpod providers
- Rive input names ↔ Flutter integration
- Sound keys ↔ asset files
- Notification payloads ↔ FCM/APNs schema

### Timezone Regression Suite
- UTC, Asia/Kolkata, America/New_York, Pacific/Auckland
- DST transitions tested explicitly

---

## 📚 Documentation

- [**SETUP_PROGRESS.md**](./SETUP_PROGRESS.md) — Detailed build status + next steps
- [**backend/db/README_DB.md**](./backend/db/README_DB.md) — Database architecture deep dive
- [**Prompt System**](./PROMPT_SYSTEM.md) — Full 12-agent master prompt (read first!)

---

## 🤝 Contributing

Each agent owns their vertical:

1. **Read the master prompt** (before starting)
2. **Check frozen contracts** in `lib/core/providers/interfaces.dart`
3. **Follow design patterns** (Riverpod, no ORMs, TIMESTAMPTZ, etc.)
4. **Write tests** for your domain
5. **Update this README** if adding new structure

**Golden rule:** Downstream agents depend on upstream contracts. Don't break them.

---

## 📞 Support

- WhatsApp: [Link to group]
- GitHub Issues: [Link to issues]
- Docs: [Link to docs]

---

## 📄 License

MIT License — [See LICENSE file](./LICENSE)

---

*Built with ❤️ by 12 AI agents in a orchestrated system — Top 0.1% Prompt Engineering*

**Current Status:** Phase 1 ✅ | Phase 2 → STARTING | Phase 3 ⏳ | Phase 4 ⏳

**Next:** Agent 2 (Go REST API) — Estimated 2 days with full test coverage
