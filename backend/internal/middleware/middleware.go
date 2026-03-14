package middleware

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/time/rate"
)

// ═══════════════════════════════════════════════════════════════════════════
// CONTEXT KEYS (for passing data through request context)
// ═══════════════════════════════════════════════════════════════════════════

type contextKey string

const (
	ContextKeyUserID contextKey = "user_id"
	ContextKeyEmail  contextKey = "email"
)

// ═══════════════════════════════════════════════════════════════════════════
// AUTHENTICATION MIDDLEWARE
// ═══════════════════════════════════════════════════════════════════════════

// JWTVerifier verifies JWT tokens using RS256 public key
type JWTVerifier struct {
	publicKeyPEM string // Public key in PEM format
}

// NewJWTVerifier creates a new JWT verifier
func NewJWTVerifier(publicKeyPEM string) *JWTVerifier {
	return &JWTVerifier{publicKeyPEM: publicKeyPEM}
}

// AuthMiddleware verifies JWT token and extracts claims
func (jv *JWTVerifier) AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, `{"error":{"code":"MISSING_TOKEN","message":"Missing authorization header"}}`, http.StatusUnauthorized)
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, `{"error":{"code":"INVALID_TOKEN_FORMAT","message":"Invalid authorization format"}}`, http.StatusUnauthorized)
			return
		}

		tokenString := parts[1]

		// Parse token and verify signature
		claims := &jwt.RegisteredClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			// Verify signing method is RS256
			if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}

			// Parse public key from PEM
			publicKey, err := jwt.ParseRSAPublicKeyFromPEM([]byte(jv.publicKeyPEM))
			if err != nil {
				return nil, fmt.Errorf("failed to parse public key: %w", err)
			}
			return publicKey, nil
		})

		if err != nil || !token.Valid {
			http.Error(w, `{"error":{"code":"INVALID_TOKEN","message":"Invalid or expired token"}}`, http.StatusUnauthorized)
			return
		}

		// Extract user ID and email from claims
		userID := claims.Subject
		if userID == "" {
			http.Error(w, `{"error":{"code":"MISSING_USER_ID","message":"Token missing user ID"}}`, http.StatusUnauthorized)
			return
		}

		// Add to context
		ctx := context.WithValue(r.Context(), ContextKeyUserID, userID)
		ctx = context.WithValue(ctx, ContextKeyEmail, claims.Audience[0])

		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// OptionalAuthMiddleware attempts to extract JWT but doesn't fail if missing (for public endpoints)
func (jv *JWTVerifier) OptionalAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			next.ServeHTTP(w, r)
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			next.ServeHTTP(w, r)
			return
		}

		tokenString := parts[1]
		claims := &jwt.RegisteredClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			publicKey, err := jwt.ParseRSAPublicKeyFromPEM([]byte(jv.publicKeyPEM))
			if err != nil {
				return nil, fmt.Errorf("failed to parse public key: %w", err)
			}
			return publicKey, nil
		})

		if err == nil && token.Valid {
			userID := claims.Subject
			if userID != "" {
				ctx := context.WithValue(r.Context(), ContextKeyUserID, userID)
				ctx = context.WithValue(ctx, ContextKeyEmail, claims.Audience[0])
				r = r.WithContext(ctx)
			}
		}

		next.ServeHTTP(w, r)
	})
}

// GetUserID extracts user ID from context
func GetUserID(r *http.Request) (string, error) {
	userID, ok := r.Context().Value(ContextKeyUserID).(string)
	if !ok || userID == "" {
		return "", errors.New("user ID not found in context")
	}
	return userID, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// RATE LIMITING MIDDLEWARE
// ═══════════════════════════════════════════════════════════════════════════

// RateLimiter implements per-user rate limiting
type RateLimiter struct {
	limiters map[string]*rate.Limiter
	limit    rate.Limit
	burst    int
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(requestsPerSecond float64, burst int) *RateLimiter {
	return &RateLimiter{
		limiters: make(map[string]*rate.Limiter),
		limit:    rate.Limit(requestsPerSecond),
		burst:    burst,
	}
}

// RateLimitMiddleware applies rate limiting based on user ID
func (rl *RateLimiter) RateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var identifier string

		// Try to get user ID from context, otherwise use IP address
		if userID, err := GetUserID(r); err == nil {
			identifier = userID
		} else {
			identifier = r.RemoteAddr
		}

		// Get or create limiter for this identifier
		if _, exists := rl.limiters[identifier]; !exists {
			rl.limiters[identifier] = rate.NewLimiter(rl.limit, rl.burst)
		}

		limiter := rl.limiters[identifier]

		if !limiter.Allow() {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("X-RateLimit-Retry-After", "60")
			w.WriteHeader(http.StatusTooManyRequests)
			fmt.Fprint(w, `{"error":{"code":"RATE_LIMIT_EXCEEDED","message":"Too many requests"}}`)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGGING MIDDLEWARE
// ═══════════════════════════════════════════════════════════════════════════

// LoggingMiddleware logs HTTP requests and responses
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Create a custom response writer to capture status code
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(wrapped, r)

		duration := time.Since(start)
		userID := "anonymous"
		if uid, err := GetUserID(r); err == nil {
			userID = uid
		}

		log.Printf("[%s] %s %s %d %dms (user: %s)", r.Method, r.RequestURI, r.Proto, wrapped.statusCode, duration.Milliseconds(), userID)
	})
}

// responseWriter wraps http.ResponseWriter to capture status code
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// ═══════════════════════════════════════════════════════════════════════════
// PANIC RECOVERY MIDDLEWARE
// ═══════════════════════════════════════════════════════════════════════════

// RecoveryMiddleware recovers from panics and returns 500 error
func RecoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				log.Printf("PANIC: %v", err)
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprint(w, `{"error":{"code":"INTERNAL_SERVER_ERROR","message":"An internal error occurred"}}`)
			}
		}()

		next.ServeHTTP(w, r)
	})
}

// ═══════════════════════════════════════════════════════════════════════════
// CORS MIDDLEWARE
// ═══════════════════════════════════════════════════════════════════════════

// CORSMiddleware adds CORS headers to responses
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Max-Age", "3600")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTENT-TYPE MIDDLEWARE
// ═══════════════════════════════════════════════════════════════════════════

// JSONContentTypeMiddleware ensures responses are JSON
func JSONContentTypeMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		next.ServeHTTP(w, r)
	})
}
