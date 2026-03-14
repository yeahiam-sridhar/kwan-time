# Backend Testing Guide

## Overview

Backend testing for KWAN-TIME v2.0 covers unit tests, integration tests, and end-to-end tests for the Go API server.

## Test Organization

```
backend/
├── cmd/server/
│   └── main_test.go              # Server initialization tests
├── internal/
│   ├── handlers/
│   │   └── handlers_test.go      # HTTP handler tests
│   ├── middleware/
│   │   └── middleware_test.go    # Auth, CORS tests
│   ├── models/
│   │   └── models_test.go        # Model validation tests
│   ├── notifications/
│   │   └── service_test.go       # FCM/APNs tests
│   ├── repository/
│   │   └── repository_test.go    # Database query tests
│   └── websocket/
│       └── websocket_test.go     # Real-time sync tests
├── db/
│   └── db_test.go                # Database setup tests
└── Makefile                      # Test targets
```

## Running Tests

### All tests
```bash
cd backend
make test
```

### Specific test file
```bash
go test ./internal/handlers/ -v
```

### With coverage
```bash
make test-coverage
open coverage.html
```

### Test specific function
```bash
go test ./internal/repository/ -run TestGetEvents -v
```

### Race condition detection
```bash
go test ./... -race
```

### Parallel execution
```bash
go test ./... -parallel 8
```

## Test Categories

### Unit Tests
- Individual function logic
- Database query building
- JSON marshaling/unmarshaling
- Validation rules
- Error handling

### Integration Tests
- API endpoint workflows
- Database + handler interaction
- WebSocket message flow
- Notification queueing
- Auth token validation

### E2E Tests
- Complete booking flow (API + DB + WebSocket)
- Multi-user concurrent bookings
- Network failure recovery
- Event sync between users

## Mocking Strategy

### Database Mocking
```go
type MockDB struct {
    GetEventsFunc func(...) ([]Event, error)
}

func (m *MockDB) GetEvents(...) ([]Event, error) {
    return m.GetEventsFunc(...)
}
```

### HTTP Testing
```go
func TestCreateEvent(t *testing.T) {
    req := httptest.NewRequest("POST", "/api/v1/events", body)
    w := httptest.NewRecorder()
    
    handler.ServeHTTP(w, req)
    
    assert.Equal(t, 201, w.Code)
}
```

### WebSocket Testing
Use `github.com/gorilla/websocket/examples` patterns for testing connections.

## Test Fixtures

Create test data consistently:

```go
func createMockEvent() Event {
    return Event{
        ID:        "test-123",
        Title:     "Test Event",
        Type:      "meeting",
        StartTime: time.Now().Add(1 * time.Hour),
        EndTime:   time.Now().Add(2 * time.Hour),
    }
}

func createMockBookingRequest() BookingRequest {
    return BookingRequest{
        Date:        "2026-02-25",
        Time:        "10:00",
        ClientName:  "John Doe",
        ClientEmail: "john@example.com",
    }
}
```

## Performance Benchmarks

### Endpoint benchmarks
```bash
go test -bench=BenchmarkGetEvents ./internal/handlers/ -benchmem
```

### Expected performance
- GET /api/v1/events: <100ms
- POST /api/v1/events: <200ms
- Database query: <50ms
- WebSocket message: <10ms

### Memory profiling
```bash
go test -memprofile=mem.prof ./...
go tool pprof mem.prof
```

### CPU profiling
```bash
go test -cpuprofile=cpu.prof ./...
go tool pprof cpu.prof
```

## CI/CD

### Local pre-commit checks
```bash
# Format
gofmt -w ./...

# Lint
golangci-lint run

# Test
make test

# Build
make build
```

### GitHub Actions
Runs on every push/PR to backend/:
1. Download dependencies
2. Run tests with PostgreSQL + Redis
3. Run linter (golangci-lint)
4. Build binary
5. Build Docker image

## Test Coverage

### View coverage
```bash
make test-coverage
# Opens coverage.html in browser
```

### Target coverage: 80%+
- Handlers: 85%+
- Repository: 90%+
- Middleware: 75%+
- WebSocket: 70%

### Excluded from coverage
- `main.go` (setup code)
- Vendor dependencies
- Generated code

## Database Testing

### Setup test database
```bash
# Uses .env.example for test DB credentials
make db-init
make db-migrate
make db-seed
```

### Seed test data
```sql
INSERT INTO events (...) VALUES (...);
INSERT INTO bookings (...) VALUES (...);
```

### Cleanup after tests
```go
func cleanup(t *testing.T, db *sql.DB) {
    t.Cleanup(func() {
        db.Exec("TRUNCATE TABLE events CASCADE;")
        db.Exec("TRUNCATE TABLE bookings CASCADE;")
    })
}
```

## Common Test Patterns

### Table-driven tests
```go
testCases := []struct {
    name     string
    input    string
    expected string
    wantErr  bool
}{
    {"valid", "test@example.com", "test@example.com", false},
    {"invalid", "invalid", "", true},
}

for _, tc := range testCases {
    t.Run(tc.name, func(t *testing.T) {
        // test logic
    })
}
```

### Cleanup with defer
```go
func TestWithDatabaseSetup(t *testing.T) {
    db := setupTestDB(t)
    defer cleanupTestDB(t, db)
    
    // test code
}
```

### Error assertions
```go
if err != nil {
    t.Fatalf("unexpected error: %v", err)
}

if !strings.Contains(err.Error(), "expected message") {
    t.Errorf("got wrong error: %v", err)
}
```

## Debugging Tests

### Verbose output
```bash
go test -v ./internal/handlers/
```

### Run single test
```bash
go test -run TestCreateEvent ./internal/handlers/
```

### Debugging with Delve
```bash
dlv test ./internal/handlers/ -- -test.run TestCreateEvent
```

### Print statements during test
```go
t.Logf("DEBUG: got response: %+v", response)
```

## Best Practices

1. **Test names are documentation**
   ✓ `TestGetEvents_ReturnsEmptySlice_WhenNoneExist`
   ✗ `TestGetEvents`

2. **One assertion (or logical group) per test**
   ✓ Small, focused tests
   ✗ Testing 5 different things in one test

3. **Use table-driven tests for multiple scenarios**
   ✓ Easy to add new cases
   ✗ Using separate test functions

4. **Mock external dependencies**
   ✓ Fast, reliable tests
   ✗ Real network calls, database hits

5. **Use t.Helper() for utility functions**
   ```go
   func createMockEvent(t *testing.T) Event {
       t.Helper()
       // ...
   }
   ```

6. **Clean up after tests**
   ✓ `defer cleanup()`
   ✗ Leaving test data in database

## Troubleshooting

### "database is locked"
Multiple tests accessing same database - use transactions per test.

### Tests pass locally but fail in CI
Check for:
- Hardcoded paths
- Time-dependent tests
- Unordered results

### Slow tests
- Profile with `go test -cpuprofile=`
- Look for `time.Sleep()` calls
- Check database query performance

### Flaky tests
- Avoid race conditions with proper sync.Mutex
- Don't depend on test execution order
- Mock time-based functions

## Resources

- Go Testing: https://golang.org/pkg/testing/
- Testify: https://github.com/stretchr/testify (assertions)
- Mockito patterns: https://github.com/golang/mock
- Table-driven tests: https://github.com/golang/go/wiki/TableDrivenTests

---

**Testing Status**: ✅ COMPLETE  
**Agent**: Agent 9 (Backend QA)  
**Coverage**: 80%+ target on critical paths
