# KWAN-TIME v2.0 — Development Guide

Complete end-to-end setup for Phase 2 (Backend API ready for Phase 3).

---

## 🚀 Start Here (5 minutes)

### What You'll Have After This Guide
✅ PostgreSQL with 6 tables and sample data  
✅ Go REST API running on localhost:8080  
✅ Redis connected for real-time features  
✅ Authentication ready (JWT RS256)  
✅ All 11 endpoints functional  

### Prerequisites
- **macOS/Linux**: `bash`, `psql`, `go`, `redis-cli`
- **Windows**: Use WSL2 or install PostgreSQL + Go natively
- Ports 5432 (PostgreSQL), 6379 (Redis), 8080 (API) available

---

## Step 1: Database Setup (2 min)

### PostgreSQL

**macOS** (with Homebrew):
```bash
brew install postgresql@16
brew services start postgresql@16
```

**Linux** (Ubuntu/Debian):
```bash
sudo apt update
sudo apt install postgresql-16
sudo systemctl start postgresql
```

**Windows**: [Download PostgreSQL 16 installer](https://www.postgresql.org/download/windows/)

### Verify PostgreSQL
```bash
psql --version  # Should show: psql (PostgreSQL) 16.x
```

### Create Database
```bash
cd backend

# Option 1: Using Make (simplest)
make db-reset

# Option 2: Manual
psql -U postgres << EOF
CREATE DATABASE kwan_calendar;
\c kwan_calendar
EOF

# Then load schema
psql -U postgres -d kwan_calendar < db/migrations/001_init.sql
psql -U postgres -d kwan_calendar < db/seed.sql
```

### Verify Data Loaded
```bash
psql -U postgres -d kwan_calendar

-- In the SQL shell:
SELECT COUNT(*) FROM users;        -- Should show: 1
SELECT COUNT(*) FROM events;       -- Should show: ~15
SELECT COUNT(*) FROM booking_links; -- Should show: 1
\q
```

---

## Step 2: Redis Setup (1 min)

### Start Redis

**macOS**:
```bash
brew install redis
brew services start redis
redis-cli ping  # Should respond: PONG
```

**Linux**:
```bash
sudo apt install redis-server
sudo systemctl start redis-server
redis-cli ping
```

**Windows**: Use [Windows Subsystem for Redis](https://github.com/microsoftarchive/redis/releases) or Docker

### Verify Redis
```bash
redis-cli
> PING
# Response: PONG
> quit
```

---

## Step 3: Go API Setup (2 min)

### Install Go 1.22+
```bash
go version  # Should show: go version go1.22.x or later
```

### Download Dependencies
```bash
cd backend
go mod download
go mod tidy
```

### Generate JWT Keys (for local development)
```bash
make generate-jwt-keys
# Creates: private-key.pem, public-key.pem
```

### Set Environment Variables
```bash
export DATABASE_URL="postgres://postgres:@localhost/kwan_calendar"
export REDIS_URL="redis://localhost:6379/0"
export JWT_PUBLIC_KEY=$(cat public-key.pem)
export PORT=8080
```

**Or use .env file:**
```bash
cp .env.example .env
# Edit .env with your values
source .env
```

### Start API Server
```bash
make run
# OR: go run cmd/server/main.go

# Output should show:
# 2026/02/25 10:30:45 Connecting to database...
# 2026/02/25 10:30:45 Connecting to Redis...
# 2026/02/25 10:30:45 Starting server on :8080
```

### Verify API Running
```bash
curl http://localhost:8080/health
# Response: {"status":"ok"}
```

---

## Step 4: Test with Sample Requests

### 1. Get Demo User
```bash
# First generate a JWT token (this is a dev example)
TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9..." 

curl http://localhost:8080/api/v1/user/profile \
  -H "Authorization: Bearer $TOKEN"
```

### 2. List Events for a Date Range
```bash
curl "http://localhost:8080/api/v1/events?start_date=2026-01-01&end_date=2026-03-31" \
  -H "Authorization: Bearer $TOKEN"
```

### 3. Get Dashboard Overview (3-month summary)
```bash
curl http://localhost:8080/api/v1/dashboard/three-month-overview \
  -H "Authorization: Bearer $TOKEN"
```

### 4. Create an Event (Returns 202 Accepted)
```bash
curl -X POST http://localhost:8080/api/v1/events \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Team Meeting",
    "event_type": "online",
    "status": "not_started",
    "start_time": "2026-02-26T10:00:00Z",
    "end_time": "2026-02-26T11:00:00Z"
  }'

# Response: {"accepted":true,"optimistic_id":"evt_..."}
```

### 5. Public Booking Link
```bash
curl http://localhost:8080/api/v1/public/booking/link_1234567890
# Response: {"data":{...booking link info...}}
```

---

## Step 5: Frontend Integration (Optional)

### Setup Flutter App
```bash
cd frontend/kwan_time

# Install dependencies
flutter pub get

# Update API endpoint in constants
# File: lib/core/constants/api_routes.dart
# Set: const String baseURL = 'http://localhost:8080';

# Run app
flutter run -d <device_id>
# Get device list: flutter devices
```

### What Happens on App Start
1. App connects to API on localhost:8080
2. WebSocket connection (when Agent 3 is ready)
3. Loads user profile from `/api/v1/user/profile`
4. Fetches 3-month calendar overview
5. Renders calendar view with events

---

## 📊 Verify Complete Setup

### Database
```bash
psql -U postgres -d kwan_calendar -c "\dt"
# Should list: booking_links, daily_summaries, events, monthly_summaries, notification_queue, users
```

### Redis
```bash
redis-cli INFO server | grep "redis_version"
# Should show: redis_version:7.x.x or later
```

### API
```bash
curl -s http://localhost:8080/health | jq
# Should show: {"status":"ok"}
```

### All Components Running
```bash
# PostgreSQL check
pg_isready -h localhost -p 5432
# Response: accepting connections

# Redis check  
redis-cli ping
# Response: PONG

# API check
curl http://localhost:8080/health
# Response: {"status":"ok"}
```

---

## 🔧 Common Development Tasks

### Reset Everything
```bash
make db-reset        # Drop, recreate, migrate, seed database
make generate-jwt-keys # Create new JWT key pair
```

### View Database Schema
```bash
psql -U postgres -d kwan_calendar -c "\d users"
# Shows table structure
```

### Query Sample Data
```bash
psql -U postgres -d kwan_calendar << EOF
SELECT * FROM users LIMIT 1;
SELECT * FROM events LIMIT 5;
SELECT * FROM booking_links LIMIT 1;
EOF
```

### Stop Services
```bash
# PostgreSQL
brew services stop postgresql@16

# Redis
brew services stop redis

# API
# Just Ctrl+C in terminal
```

### View Logs
```bash
# API logs (already printed to terminal when running)
# See: [GET] /api/v1/events 200 24ms (user: ...)

# PostgreSQL logs
tail -f /var/log/postgresql/postgresql.log

# Redis logs
redis-cli INFO replication
```

---

## 🚀 Ready for Next Phase

Once all components are working:

### Phase 3: View Implementations
- **Agent 5**: Rive animations (floating)
- **Agent 6**: Classic calendar view (drag & drop)
- **Agent 7**: Business dashboard (3-month summary)
- **Agent 8**: Physics engine (gooey interactions)
- **Agent 11**: Sound service (playback + ambient)
- **Agent 12**: Public booking interface

### Phase 2 Remaining:
- **Agent 3**: WebSocket real-time sync (depends on this API ✓)
- **Agent 10**: Push notifications worker (depends on this API ✓)

---

## 📚 Documentation

- **API Reference**: [backend/docs/API.md](../backend/docs/API.md)
- **Database Architecture**: [backend/db/README_DB.md](../backend/db/README_DB.md)
- **Frozen Contracts**: [FROZEN_CONTRACTS.md](../FROZEN_CONTRACTS.md)
- **Project Overview**: [README.md](../README.md)

---

## ⚠️ Troubleshooting

### Port Already in Use
```bash
# Find what's using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

### Database Connection Error
```
error: failed to connect to postgres host=localhost user=postgres
```
**Solution:**
```bash
# Check PostgreSQL is running
brew services list | grep postgres

# Ensure database exists
psql -U postgres -l | grep kwan_calendar

# Reset: make db-reset
```

### Package Version Conflicts
```bash
# Clean and rebuild
go clean -cache
go mod tidy
go mod download
make build
```

### JWT Token Issues
```bash
# Generate new keys if tokens don't work
make generate-jwt-keys

# Verify public key is set
echo $JWT_PUBLIC_KEY
```

---

## 🎯 Next Steps

1. ✅ **Now**: All services running locally
2. **Next**: Run integration tests (Agent 9)
3. **Then**: Deploy to staging (Docker Compose)
4. **Finally**: Real-time sync (Agent 3) and notifications (Agent 10)

---

**KWAN-TIME v2.0 — Backend Foundation Ready**  
*Phase 2 (REST API) ✅ Complete*  
*Date: 2026-02-25*
