package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"firebase.google.com/go/v4/app"
	"firebase.google.com/go/v4/messaging"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"
	"kwan-time/internal/handlers"
	"kwan-time/internal/middleware"
	"kwan-time/internal/notifications"
	"kwan-time/internal/repository"
	"kwan-time/internal/websocket"
)

// ═══════════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════

func main() {
	// Load configuration from environment variables
	dbURL := getEnv("DATABASE_URL", "postgres://kwan:kwan@localhost:5432/kwan_calendar")
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379/0")
	port := getEnv("PORT", "8080")
	jwtPublicKey := getEnv("JWT_PUBLIC_KEY", "")

	// Initialize database connection
	log.Println("Connecting to database...")
	db, err := initDatabase(dbURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	// Initialize Redis connection
	log.Println("Connecting to Redis...")
	rdb, err := initRedis(redisURL)
	if err != nil {
		log.Fatalf("Failed to initialize Redis: %v", err)
	}

	// Initialize repository
	repo := repository.NewRepository(db)

	// Initialize middleware
	jwtVerifier := middleware.NewJWTVerifier(jwtPublicKey)
	rateLimiter := middleware.NewRateLimiter(10, 5) // 10 req/s, burst of 5

	// Initialize handlers
	eventHandlers := handlers.NewEventHandlers(repo, rdb)
	dashboardHandlers := handlers.NewDashboardHandlers(repo)
	userHandlers := handlers.NewUserHandlers(repo)
	notificationHandlers := handlers.NewNotificationHandlers(repo, rdb)
	bookingHandlers := handlers.NewBookingHandlers(repo)
	publicHandlers := handlers.NewPublicHandlers(repo)

	// Initialize WebSocket handler (Agent 3)
	wsHandler := websocket.NewHandler(rdb)
	wsHandler.Start()
	defer wsHandler.Stop()

	// Initialize FCM client (for Agent 10)
	var fcmClient *messaging.Client
	var notifService *notifications.Service
	
	firebaseConfigPath := getEnv("FIREBASE_CONFIG", "")
	if firebaseConfigPath != "" {
		log.Println("Initializing Firebase Admin SDK...")
		fbApp, err := app.NewApp(context.Background(), nil,
			app.WithCredentialsFile(firebaseConfigPath),
		)
		if err == nil {
			fcmClient, err = fbApp.Messaging(context.Background())
			if err == nil {
				notifService = notifications.NewService(repo, fcmClient)
				// Start notification worker in background
				go notifService.Start(context.Background())
				log.Println("Notification worker started")
			} else {
				log.Printf("Failed to create FCM client: %v (notifications disabled)", err)
			}
		} else {
			log.Printf("Failed to initialize Firebase: %v (notifications disabled)", err)
		}
	} else {
		log.Println("FIREBASE_CONFIG not set - notifications disabled")
	}

	// Setup router
	router := createRouter(
		jwtVerifier,
		rateLimiter,
		eventHandlers,
		dashboardHandlers,
		userHandlers,
		notificationHandlers,
		bookingHandlers,
		publicHandlers,
		wsHandler,
	)

	// Start server
	address := fmt.Sprintf(":%s", port)
	log.Printf("Starting server on %s", address)

	server := &http.Server{
		Addr:         address,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
}

// ═══════════════════════════════════════════════════════════════════════════
// ROUTER SETUP
// ═══════════════════════════════════════════════════════════════════════════

func createRouter(
	jwtVerifier *middleware.JWTVerifier,
	rateLimiter *middleware.RateLimiter,
	eventHandlers *handlers.EventHandlers,
	dashboardHandlers *handlers.DashboardHandlers,
	userHandlers *handlers.UserHandlers,
	notificationHandlers *handlers.NotificationHandlers,
	bookingHandlers *handlers.BookingHandlers,
	publicHandlers *handlers.PublicHandlers,
	wsHandler *websocket.Handler,
) chi.Router {
	router := chi.NewRouter()

	// Global middleware
	router.Use(middleware.RecoveryMiddleware)
	router.Use(middleware.CORSMiddleware)
	router.Use(middleware.JSONContentTypeMiddleware)
	router.Use(middleware.LoggingMiddleware)

	// Health check (public endpoint)
	router.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"ok"}`)
	})

	// WebSocket endpoint (requires authentication)
	router.Route("/ws", func(r chi.Router) {
		r.Use(jwtVerifier.AuthMiddleware)
		r.Get("/", wsHandler.ServeWS)
	})

	// Public API routes (no auth required)
	router.Route("/api/v1/public", func(r chi.Router) {
		r.Use(rateLimiter.RateLimitMiddleware)

		// Booking link public endpoints
		r.Get("/booking/{slug}", publicHandlers.GetBookingInfo)
		r.Get("/booking/{slug}/available-slots", publicHandlers.GetAvailableSlots)
		r.Post("/booking/{slug}/confirm", publicHandlers.ConfirmBooking)
	})

	// Protected API routes (auth required)
	router.Route("/api/v1", func(r chi.Router) {
		r.Use(jwtVerifier.AuthMiddleware)
		r.Use(rateLimiter.RateLimitMiddleware)

		// Event endpoints
		r.Route("/events", func(r chi.Router) {
			r.Get("/", eventHandlers.GetEvents)
			r.Post("/", eventHandlers.CreateEvent)
			r.Route("/{eventID}", func(r chi.Router) {
				r.Get("/", eventHandlers.GetEvent)
				r.Patch("/", eventHandlers.UpdateEvent)
				r.Delete("/", eventHandlers.DeleteEvent)
			})
		})

		// Dashboard endpoints
		r.Route("/dashboard", func(r chi.Router) {
			r.Get("/three-month-overview", dashboardHandlers.GetThreeMonthOverview)
			r.Post("/refresh-summary", dashboardHandlers.RefreshMonthlySummary)
		})

		// User endpoints
		r.Route("/user", func(r chi.Router) {
			r.Get("/profile", userHandlers.GetProfile)
			r.Patch("/sound-profile", userHandlers.UpdateSoundProfile)
		})

		// Notification endpoints
		r.Route("/notifications", func(r chi.Router) {
			r.Post("/register-device", notificationHandlers.RegisterDevice)
			r.Get("/preferences", notificationHandlers.GetNotificationPreferences)
			r.Patch("/preferences", notificationHandlers.UpdateNotificationPreferences)
		})

		// Booking link endpoints
		r.Route("/booking-links", func(r chi.Router) {
			r.Get("/", bookingHandlers.GetMyBookingLinks)
			r.Post("/", bookingHandlers.CreateBookingLink)
		})
	})

	return router
}

// ═══════════════════════════════════════════════════════════════════════════
// INITIALIZATION FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

// initDatabase initializes the PostgreSQL database connection
func initDatabase(dbURL string) (*sqlx.DB, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Create pgxpool first
	pgxCfg, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse database URL: %w", err)
	}

	pgxCfg.MaxConns = 25
	pgxCfg.MinConns = 5

	pool, err := pgxpool.NewWithConfig(ctx, pgxCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create pgx pool: %w", err)
	}

	// Test connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// Wrap pgxpool with sqlx
	db := sqlx.NewDb(pool, "pgx")

	return db, nil
}

// initRedis initializes the Redis connection
func initRedis(redisURL string) (*redis.Client, error) {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse Redis URL: %w", err)
	}

	client := redis.NewClient(opt)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to ping Redis: %w", err)
	}

	return client, nil
}

// getEnv gets environment variable with default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
