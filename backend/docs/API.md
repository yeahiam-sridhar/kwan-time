# KWAN-TIME v2.0 Backend API Documentation

## Overview
Go 1.22+ REST API for KWAN-TIME calendar application. Implements 11 REST endpoints with JWT RS256 authentication, optimistic updates, and Redis-backed WebSocket real-time sync.

## Architecture

### Technology Stack
- **Router**: chi/v5 (lightweight, composable middleware)
- **Database**: PostgreSQL 16 with pgxpool connection pooling
- **Query Layer**: sqlx (prepared statements, no ORM)
- **Authentication**: JWT RS256 (public key verification)
- **Real-Time**: Redis Streams for WebSocket message distribution
- **Rate Limiting**: token bucket per user (10 req/s, burst 5)

### Project Structure
```
backend/
├── cmd/server/main.go           # Entry point, router setup, connection pools
├── internal/
│   ├── models/models.go          # All API request/response models
│   ├── repository/repository.go  # Database query layer (sqlx)
│   ├── handlers/handlers.go      # 11 HTTP endpoint handlers
│   ├── middleware/middleware.go  # Auth, CORS, rate limiting, logging
│   └── config/                   # (TBD: environment configuration)
├── db/                           # (See backend/db/README_DB.md)
│   ├── schema.sql
│   ├── migrations/001_init.sql
│   └── seed.sql
├── docs/                         # API documentation
├── go.mod                        # Dependencies
└── go.sum                        # Lock file
```

## API Endpoints

### Public Endpoints (No Authentication)
```
GET    /api/v1/public/booking/{slug}                 Get booking page info
GET    /api/v1/public/booking/{slug}/available-slots Get available time slots
POST   /api/v1/public/booking/{slug}/confirm         Confirm a booking
```

### Protected Endpoints (Require JWT)

#### Events
```
GET    /api/v1/events                  List events (query: start_date, end_date)
GET    /api/v1/events/{eventID}        Get single event
POST   /api/v1/events                  Create event (202 Accepted)
PATCH  /api/v1/events/{eventID}        Update event (202 Accepted)
DELETE /api/v1/events/{eventID}        Delete event
```

#### Dashboard
```
GET    /api/v1/dashboard/three-month-overview       Get 3-month analytics
POST   /api/v1/dashboard/refresh-summary            Manually refresh monthly summary
```

#### User
```
GET    /api/v1/user/profile            Get user profile
PATCH  /api/v1/user/sound-profile      Update sound profile
```

#### Notifications
```
POST   /api/v1/notifications/register-device        Register FCM/APNs token
GET    /api/v1/notifications/preferences            Get notification preferences
PATCH  /api/v1/notifications/preferences            Update notification preferences
```

#### Booking Links
```
GET    /api/v1/booking-links           List user's booking links
POST   /api/v1/booking-links           Create new booking link
```

## Response Format

### Success Response (200 OK)
```json
{
  "data": { /* resource or array of resources */ }
}
```

### Accepted Response (202 Accepted)
```json
{
  "accepted": true,
  "optimistic_id": "evt_1234567890"
}
```

### Error Response
```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Invalid or expired token",
    "timestamp": "2026-02-25T10:30:45.123Z"
  }
}
```

## Authentication

### JWT RS256
- All protected endpoints require `Authorization: Bearer <token>` header
- Token must be signed with private key, verified with public key
- Public key loaded from `JWT_PUBLIC_KEY` environment variable (PEM format)
- Claims required: `sub` (user ID), `aud` (email)

### Rate Limiting
- **Public endpoints**: 100 requests per minute (per IP)
- **Protected endpoints**: 1000 requests per minute (per user)
- Returns `429 Too Many Requests` when limit exceeded

## Middleware Stack

### Order
1. Recovery (panic recovery)
2. CORS (cross-origin headers)
3. JSON Content-Type (application/json)
4. Logging (request/response metrics)
5. Rate Limiting (per-user or per-IP)
6. Authentication (for protected routes only)

### CORS
- `Access-Control-Allow-Origin`: * (adjust in production)
- `Access-Control-Allow-Methods`: GET, POST, PATCH, DELETE, OPTIONS
- `Access-Control-Allow-Headers`: Content-Type, Authorization
- Preflight requests return 200 OK

## Database Connection

### Connection String Format
```
postgres://user:password@host:port/database
```

### Environment Variables
```bash
DATABASE_URL=postgres://kwan:kwan@localhost:5432/kwan_calendar
REDIS_URL=redis://localhost:6379/0
JWT_PUBLIC_KEY=$(cat public-key.pem)
PORT=8080
```

### Connection Pooling
- **PostgreSQL**: pgxpool with min 5, max 25 connections
- **Redis**: Default single connection with auto-reconnect

## Development Setup

### Prerequisites
- Go 1.22+
- PostgreSQL 16+
- Redis 7+

### Installation

1. **Clone and setup database**
```bash
cd backend
psql -U postgres -c "CREATE DATABASE kwan_calendar;"
psql -U postgres -d kwan_calendar < db/schema.sql
psql -U postgres -d kwan_calendar < db/seed.sql
```

2. **Generate JWT Keys** (for testing)
```bash
openssl genrsa -out private-key.pem 2048
openssl rsa -in private-key.pem -pubout -out public-key.pem
```

3. **Run server**
```bash
export DATABASE_URL="postgres://kwan:kwan@localhost:5432/kwan_calendar"
export JWT_PUBLIC_KEY=$(cat public-key.pem)
go run cmd/server/main.go
```

Server starts on `http://localhost:8080`

### Running Tests (Agent 9 - QA)
```bash
go test ./... -v
go test ./... -cover
```

### Build for Production
```bash
go build -o bin/kwan-api cmd/server/main.go
./bin/kwan-api
```

## Optimistic Updates Pattern

### Flow
1. **Client**: Sends mutation (create/update/delete) to API
2. **Server**: Returns **202 Accepted** with `optimistic_id`
3. **Client**: Immediately updates local state with optimistic change
4. **Server**: Asynchronously saves to database
5. **Server**: Publishes mutation to Redis `user:{userID}:events` channel
6. **Agent 3 (WebSocket)**: Distributes event to all client connections
7. **Clients**: Receive `SYNC_CONFIRM` or `SYNC_REVERT` based on success

### Example: Create Event

**Request**
```json
POST /api/v1/events
Authorization: Bearer eyJ...

{
  "title": "Team Standup",
  "event_type": "online",
  "status": "not_started",
  "start_time": "2026-02-25T10:00:00Z",
  "end_time": "2026-02-25T10:30:00Z"
}
```

**Response (202 Accepted)**
```json
{
  "accepted": true,
  "optimistic_id": "evt_1709019600123456789"
}
```

**WebSocket Broadcast (Agent 3)**
```json
{
  "type": "SYNC_EVENT",
  "action": "create",
  "event": { /* full event */ }
}
```

## Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `MISSING_TOKEN` | 401 | Authorization header missing |
| `INVALID_TOKEN` | 401 | Token invalid, expired, or malformed |
| `UNAUTHORIZED` | 401 | User not authenticated |
| `FORBIDDEN` | 403 | User lacks permission for resource |
| `NOT_FOUND` | 404 | Resource not found |
| `INVALID_JSON` | 400 | Request body not valid JSON |
| `INVALID_DATE` | 400 | Date parameter format invalid |
| `MISSING_PARAM` | 400 | Required query parameter missing |
| `DB_ERROR` | 500 | Database operation failed |
| `INTERNAL_SERVER_ERROR` | 500 | Unhandled server error |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |

## Integration Points

### Agent 3 (WebSocket Real-Time)
- Listens to Redis channels: `user:{userID}:events`, `user:{userID}:notifications`
- Broadcasts mutations from HTTP API to connected WebSocket clients
- Ensures all clients see real-time updates

### Agent 10 (Push Notifications Worker)
- Polls `GET /api/v1/notifications/queue` for pending notifications (when implemented)
- Sends FCM (Android) and APNs (iOS) messages
- Marks notifications sent via internal repository function

### Agent 5 (Rive Animations)
- Client-side only, no API integration at this stage
- Triggers based on event state changes received via WebSocket

## Performance Targets

- **P50 Latency**: < 50ms for all endpoints
- **P99 Latency**: < 200ms for complex queries (3-month overview)
- **Throughput**: 1000 requests/second sustained
- **Database Queries**: All < 100ms with proper indexing

See `backend/db/README_DB.md` for database optimization details.

## Security Considerations

1. **JWT Public Key**: Store in environment, never commit to repo
2. **CORS**: Set `Access-Control-Allow-Origin` to frontend domain in production
3. **HTTPS**: Enforce TLS in production
4. **Database**: User passwords hashed with bcrypt (TBD: not yet implemented)
5. **Rate Limiting**: Adjust per-user limits based on usage patterns
6. **Logging**: Sensitive data (tokens, passwords) never logged

## Monitoring & Logging

### Logs Include
- Request method, URI, HTTP verb, response status
- Response time (milliseconds)
- User ID (if authenticated)
- Panic recovery events

### Format
```
[GET] /api/v1/events?start_date=2026-01-01&end_date=2026-01-31 HTTP/1.1 200 24ms (user: 550e8400-e29b-41d4-a716-446655440000)
```

## Next Steps

- [ ] Agent 3: WebSocket handler with Redis Streams subscription
- [ ] Agent 10: Background worker for push notifications
- [ ] Agent 2: Add password hashing and user registration endpoint
- [ ] Agent 9 (QA): Unit and integration tests for all handlers
- [ ] Performance testing and load testing
- [ ] Database query optimization based on profiling

---

**Status**: Phase 2 - API Implementation (In Progress)  
**Last Updated**: 2026-02-25  
**Implemented By**: Agent 2 (REST API)
