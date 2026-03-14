.PHONY: help build run test clean db-init db-migrate db-seed db-drop lint deps fmt

help:
	@echo "KWAN-TIME v2.0 Backend — Make Commands"
	@echo ""
	@echo "Database Setup:"
	@echo "  make db-init       Initialize PostgreSQL database"
	@echo "  make db-migrate    Run migrations"
	@echo "  make db-seed       Load seed data"
	@echo "  make db-drop       Drop all tables"
	@echo ""
	@echo "Development:"
	@echo "  make deps          Download dependencies"
	@echo "  make fmt           Format code"
	@echo "  make lint          Run linter"
	@echo "  make build         Build binary"
	@echo "  make run           Run development server"
	@echo "  make test          Run tests"
	@echo ""
	@echo "Operations:"
	@echo "  make clean         Remove build artifacts"
	@echo "  make logs          Show server logs"
	@echo ""

# ═══════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════

deps:
	@echo "Downloading Go dependencies..."
	go mod download
	go mod tidy
	@echo "✓ Dependencies updated"

# ═══════════════════════════════════════════════════════════════════════════
# CODE QUALITY
# ═══════════════════════════════════════════════════════════════════════════

fmt:
	@echo "Formatting code..."
	go fmt ./...
	@echo "✓ Code formatted"

lint:
	@echo "Linting code..."
	@command -v golangci-lint > /dev/null || (echo "golangci-lint not found. Install: https://golangci-lint.run/usage/install/"; exit 1)
	golangci-lint run ./...
	@echo "✓ Lint passed"

# ═══════════════════════════════════════════════════════════════════════════
# BUILDING
# ═══════════════════════════════════════════════════════════════════════════

build: fmt
	@echo "Building KWAN-TIME API..."
	mkdir -p bin
	go build -v -o bin/kwan-api cmd/server/main.go
	@echo "✓ Build complete: bin/kwan-api"

# ═══════════════════════════════════════════════════════════════════════════
# RUNNING
# ═══════════════════════════════════════════════════════════════════════════

run: build
	@echo "Starting KWAN-TIME API..."
	./bin/kwan-api

dev:
	@echo "Starting KWAN-TIME API (development mode with auto-reload)..."
	@command -v air > /dev/null || (echo "air not found. Install: go install github.com/cosmtrek/air@latest"; exit 1)
	air

# ═══════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════

test:
	@echo "Running tests..."
	go test ./... -v -race -coverprofile=coverage.out

test-coverage: test
	@echo "Generating coverage report..."
	go tool cover -html=coverage.out -o coverage.html
	@echo "✓ Coverage report: coverage.html"

# ═══════════════════════════════════════════════════════════════════════════
# DATABASE
# ═══════════════════════════════════════════════════════════════════════════

db-init:
	@echo "Creating PostgreSQL database..."
	psql -U postgres -c "DROP DATABASE IF EXISTS kwan_calendar;" || true
	psql -U postgres -c "CREATE DATABASE kwan_calendar;"
	@echo "✓ Database created"

db-migrate:
	@echo "Running migrations..."
	psql -U postgres -d kwan_calendar < db/migrations/001_init.sql
	@echo "✓ Migrations complete"

db-seed:
	@echo "Loading seed data..."
	psql -U postgres -d kwan_calendar < db/seed.sql
	@echo "✓ Seed data loaded"

db-drop:
	@echo "Dropping database (WARNING: this will delete all data)..."
	psql -U postgres -c "DROP DATABASE IF EXISTS kwan_calendar;"
	@echo "✓ Database dropped"

db-reset: db-drop db-init db-migrate db-seed
	@echo "✓ Database reset complete"

db-shell:
	@echo "Connecting to kwan_calendar database..."
	psql -U postgres -d kwan_calendar

# ═══════════════════════════════════════════════════════════════════════════
# MAINTENANCE
# ═══════════════════════════════════════════════════════════════════════════

clean:
	@echo "Cleaning build artifacts..."
	rm -rf bin/
	rm -f coverage.out coverage.html
	@echo "✓ Clean complete"

# ═══════════════════════════════════════════════════════════════════════════
# JWT KEY GENERATION (for local testing)
# ═══════════════════════════════════════════════════════════════════════════

generate-jwt-keys:
	@echo "Generating JWT RSA key pair..."
	openssl genrsa -out private-key.pem 2048
	openssl rsa -in private-key.pem -pubout -out public-key.pem
	@echo "✓ Keys generated:"
	@echo "  - private-key.pem (keep secret)"
	@echo "  - public-key.pem (use JWT_PUBLIC_KEY env var)"
	@cat public-key.pem

# ═══════════════════════════════════════════════════════════════════════════
# DOCKER SUPPORT
# ═══════════════════════════════════════════════════════════════════════════

docker-build:
	@echo "Building Docker image..."
	docker build -t kwan-time-api:latest .
	@echo "✓ Docker image built"

docker-up:
	@echo "Starting Docker containers..."
	docker-compose up -d
	@echo "✓ Containers running"

docker-down:
	@echo "Stopping Docker containers..."
	docker-compose down
	@echo "✓ Containers stopped"

docker-logs:
	docker-compose logs -f api
