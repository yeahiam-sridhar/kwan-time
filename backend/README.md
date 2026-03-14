# KWAN-TIME v2.0 Backend API

Go 1.22+ REST API for KWAN-TIME calendar application with real-time WebSocket support.

## Quick Start

### Prerequisites
- Go 1.22+
- PostgreSQL 16+
- Redis 7+
- Make (optional, for Makefile commands)

### Setup in 5 Minutes

```bash
# 1. Clone and navigate to backend
cd backend

# 2. Initialize database
make db-reset  # Creates DB, runs migrations, loads seed data

# 3. Generate JWT keys (for local development)
make generate-jwt-keys

# 4. Set environment variables
export DATABASE_URL="postgres://kwan:kwan@localhost:5432/kwan_calendar"
export JWT_PUBLIC_KEY=$(cat public-key.pem)

# 5. Run server
make run
# OR: go run cmd/server/main.go
```

Server will start on **http://localhost:8080**

### Test Health Endpoint
```bash
curl http://localhost:8080/health
# Response: {"status":"ok"}
```

---

## Project Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go                 # Entry point, router, connection setup
├── internal/
│   ├── models/
│   │   └── models.go               # All API request/response models
│   ├── repository/
│   │   └── repository.go           # Database query layer (sqlx + pgxpool)
│   ├── handlers/
│   │   └── handlers.go             # HTTP handlers for all 11 endpoints
│   ├── middleware/
│   │   └── middleware.go           # Auth, CORS, rate limiting, logging
│   └── config/
│       └── config.go               # (TODO: Environment configuration)
├── db/
│   ├── schema.sql                  # PostgreSQL schema (6 tables)
│   ├── migrations/
│   │   └── 001_init.sql            # Initial migration
│   ├── seed.sql                    # Sample data (1 user, 15 events, etc)
│   └── README_DB.md                # Database architecture docs
├── docs/
│   └── API.md                      # API endpoint documentation
├── Makefile                        # Common development commands
├── .env.example                    # Environment variables template
├── go.mod                          # Go module definition
└── README.md                       # This file
```

---

## API Endpoints

### Public (No Authentication)
```
GET    /api/v1/public/booking/{slug}
GET    /api/v1/public/booking/{slug}/available-slots
POST   /api/v1/public/booking/{slug}/confirm
```

### Protected (Require JWT)

**Events**
```
GET    /api/v1/events              List user's events
GET    /api/v1/events/{eventID}    Get single event
POST   /api/v1/events              Create event (202 Accepted)
PATCH  /api/v1/events/{eventID}    Update event (202 Accepted)
DELETE /api/v1/events/{eventID}    Delete event
```

**Dashboard**
```
GET    /api/v1/dashboard/three-month-overview
POST   /api/v1/dashboard/refresh-summary
```

**User**
```
GET    /api/v1/user/profile
PATCH  /api/v1/user/sound-profile
```

**Notifications**
```
POST   /api/v1/notifications/register-device
GET    /api/v1/notifications/preferences
PATCH  /api/v1/notifications/preferences
```

**Booking Links**
```
GET    /api/v1/booking-links       List booking links
POST   /api/v1/booking-links       Create booking link
```

See [docs/API.md](docs/API.md) for complete endpoint documentation.

---

## Authentication

### JWT RS256
Protect endpoints with JWT Bearer tokens:

```bash
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...
```

**Token Requirements:**
- Signed with private key (on server)
- Verified with public key (from `JWT_PUBLIC_KEY` env var)
- Must include:
  - `sub` (subject): user ID
  - `aud` (audience): user email
  - `exp` (expiration): token expiry time

### Generate Keys for Development
```bash
make generate-jwt-keys
# Creates: private-key.pem, public-key.pem
```

### Verify JWT Locally
```bash
# Online tool: https://jwt.io
# Paste token and public key
```

---

## Database

### Initialize
```bash
make db-reset  # Complete reset with seed data
# OR manually:
make db-init
make db-migrate
make db-seed
```

### Verify Setup
```bash
psql -U postgres -d kwan_calendar
# SQL> SELECT COUNT(*) FROM users;  -- Should show 1
# SQL> SELECT COUNT(*) FROM events; -- Should show ~15
# SQL> \dt                          -- List all tables
```

See [db/README_DB.md](db/README_DB.md) for detailed schema documentation.

---

## Development

### Dependencies
```bash
# Download all dependencies
make deps

# View dependency graph
go mod graph

# Check for updates
go list -u -m all
```

### Code Quality
```bash
# Format code
make fmt

# Lint (requires golangci-lint)
make lint

# Run tests
make test

# Generate coverage report
make test-coverage
```

### Running

**Development (with auto-reload)**
```bash
make dev
# Requires: go install github.com/cosmtrek/air@latest
```

**Production build**
```bash
make build
./bin/kwan-api
```

---

## Configuration

### Environment Variables
```bash
# Required
DATABASE_URL=postgres://user:pass@host:5432/kwan_calendar
JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----\n..."

# Optional
PORT=8080                          # Default: 8080
REDIS_URL=redis://localhost:6379/0 # Default: localhost:6379
ENV=development                    # Default: production
LOG_LEVEL=info                     # Default: info
```

### Using .env File
```bash
# Copy template
cp .env.example .env

# Edit values
nano .env

# Load (in Bash/Zsh)
export $(cat .env | xargs)
```

---

## Features

### Optimistic Updates
API returns `202 Accepted` for create/update/delete operations:

```json
{
  "accepted": true,
  "optimistic_id": "evt_1709019600123456789"
}
```

Client immediately updates local UI with optimistic change, server saves asynchronously.

### Rate Limiting
- **Public API**: 100 requests/minute per IP
- **Protected API**: 1000 requests/minute per user
- Returns `429 Too Many Requests` when exceeded

### Real-time with Redis
Event mutations published to Redis channels for WebSocket distribution (Agent 3):
```
user:{userID}:events
user:{userID}:notifications
```

### Error Responses
All errors follow frozen contract:
```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Invalid or expired token",
    "timestamp": "2026-02-25T10:30:45.123Z"
  }
}
```

---

## Common Commands

```bash
# Start development server with auto-reload
make dev

# Build production binary
make build

# Run all tests with coverage
make test-coverage

# Reset database and reseed
make db-reset

# View database shell
make db-shell

# Generate JWT keys
make generate-jwt-keys

# View all available commands
make help
```

---

## Testing

### Unit Tests
```bash
go test ./internal/(...) -v
```

### Integration Tests
```bash
# Start PostgreSQL and Redis first
make test
```

### Load Testing (with k6)
```bash
# Install: https://k6.io/docs/getting-started/installation/
k6 run tests/load-test.js
```

---

## Troubleshooting

### Connection Refused
```
error: failed to connect to PostgreSQL
```
**Solution:**
- Verify PostgreSQL is running: `psql -U postgres`
- Check DATABASE_URL is correct
- Ensure database exists: `psql -U postgres -l | grep kwan_calendar`

### Invalid JWT Token
```
{"error": {"code": "INVALID_TOKEN", "message": "..."}}
```
**Solution:**
- Generate new keys: `make generate-jwt-keys`
- Set JWT_PUBLIC_KEY environment variable
- Verify token structure at https://jwt.io

### Database Migration Failed
```
error: migration error
```
**Solution:**
- Reset database: `make db-drop db-init db-migrate`
- Check migrations are applied: `\dt` in psql

---

## Architecture Decisions

1. **No ORM**: Uses `sqlx` directly for explicit SQL control
2. **Async Saves**: 202 Accepted responses allow client-side optimism
3. **Redis Pubsub**: For real-time event distribution (Agent 3)
4. **Per-User Rate Limiting**: Prevents abuse while enabling scale
5. **JWT RS256**: Stateless authentication, no session storage

---

## Next Phase: Agent 3 (WebSocket)

Agent 3 will implement:
- WebSocket server (gorilla/websocket)
- Redis Streams subscription
- Real-time message distribution
- Connection manager with heartbeat
- Optimistic ID reconciliation

See: [FROZEN_CONTRACTS.md](../FROZEN_CONTRACTS.md) for WebSocket message specs

---

## Performance Targets

- **P50 Latency**: < 50ms for all endpoints
- **P99 Latency**: < 200ms for complex queries
- **Throughput**: 1000 requests/second sustained

See [docs/API.md](docs/API.md#performance-targets) for optimization details.

---

## Contributing

### Before committing:
```bash
make fmt      # Format code
make lint     # Check for issues
make test     # Run tests
```

### Coding Standards
- Follow Go conventions from [Effective Go](https://golang.org/doc/effective_go)
- Add comments for exported functions
- Keep functions < 50 lines where possible
- Use interfaces for dependency injection

---

## License

KWAN-TIME © 2026

---

**Status**: Phase 2 - REST API (✅ Complete)  
**Implemented By**: Agent 2  
**Next Agent**: Agent 3 (WebSocket Real-Time)
