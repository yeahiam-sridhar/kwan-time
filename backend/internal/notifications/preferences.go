package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/redis/go-redis/v9"
	"kwan-time/internal/middleware"
	"kwan-time/internal/repository"
)

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION PREFERENCES HANDLER
// ═══════════════════════════════════════════════════════════════════════════

// PreferencesHandler handles notification preference endpoints
type PreferencesHandler struct {
	repo *repository.Repository
	rdb  *redis.Client
}

// NewPreferencesHandler creates a new preferences handler
func NewPreferencesHandler(repo *repository.Repository, rdb *redis.Client) *PreferencesHandler {
	return &PreferencesHandler{
		repo: repo,
		rdb:  rdb,
	}
}

// ─────────────────────────────────────────────────────────────────────────
// PREFERENCE STORAGE
// ─────────────────────────────────────────────────────────────────────────

// NotificationPreferences represents user notification settings
type NotificationPreferences struct {
	ReminderMinutes     []int  `json:"reminder_minutes"`
	DailySummaryTime    string `json:"daily_summary_time"`
	ReminderEnabled     bool   `json:"reminder_enabled"`
	BookingConfirmed    bool   `json:"booking_confirmed_enabled"`
	EventStartEnabled   bool   `json:"event_start_enabled"`
	DailySummaryEnabled bool   `json:"daily_summary_enabled"`
}

// DefaultPreferences returns default notification preferences
func DefaultPreferences() *NotificationPreferences {
	return &NotificationPreferences{
		ReminderMinutes:     []int{15, 30},
		DailySummaryTime:    "09:00",
		ReminderEnabled:     true,
		BookingConfirmed:    true,
		EventStartEnabled:   true,
		DailySummaryEnabled: true,
	}
}

// ─────────────────────────────────────────────────────────────────────────
// PREFERENCES ENDPOINTS
// ─────────────────────────────────────────────────────────────────────────

// GetNotificationPreferences retrieves user notification preferences
func (h *PreferencesHandler) GetNotificationPreferences(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"User not authenticated"}}`, http.StatusUnauthorized)
		return
	}

	// Try to get from cache first
	prefs, err := h.getPreferencesFromCache(r.Context(), userID)
	if err == nil && prefs != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{"data": prefs})
		return
	}

	// Return defaults (TODO: store in database)
	prefs = DefaultPreferences()
	_ = h.setPreferencesInCache(r.Context(), userID, prefs) // Best effort cache

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{"data": prefs})
}

// UpdateNotificationPreferences updates user notification preferences
func (h *PreferencesHandler) UpdateNotificationPreferences(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"User not authenticated"}}`, http.StatusUnauthorized)
		return
	}

	var req NotificationPreferences
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":{"code":"INVALID_JSON","message":"Invalid request body"}}`, http.StatusBadRequest)
		return
	}

	// Validate preferences
	if len(req.ReminderMinutes) == 0 {
		req.ReminderMinutes = []int{15, 30}
	}

	// Store in cache (TODO: also store in database)
	if err := h.setPreferencesInCache(r.Context(), userID, &req); err != nil {
		log.Printf("Failed to store preferences: %v", err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{"updated": true})

	fmt.Printf("Updated preferences for user %s\n", userID)
}

// ─────────────────────────────────────────────────────────────────────────
// CACHE OPERATIONS
// ─────────────────────────────────────────────────────────────────────────

// getPreferencesFromCache retrieves preferences from Redis
func (h *PreferencesHandler) getPreferencesFromCache(ctx context.Context, userID string) (*NotificationPreferences, error) {
	key := fmt.Sprintf("user:prefs:%s", userID)

	data, err := h.rdb.Get(ctx, key).Result()
	if err != nil {
		return nil, err
	}

	var prefs NotificationPreferences
	if err := json.Unmarshal([]byte(data), &prefs); err != nil {
		return nil, err
	}

	return &prefs, nil
}

// setPreferencesInCache stores preferences in Redis
func (h *PreferencesHandler) setPreferencesInCache(ctx context.Context, userID string, prefs *NotificationPreferences) error {
	key := fmt.Sprintf("user:prefs:%s", userID)

	data, err := json.Marshal(prefs)
	if err != nil {
		return err
	}

	// Cache for 24 hours
	return h.rdb.Set(ctx, key, data, 24*time.Hour).Err()
}

// ─────────────────────────────────────────────────────────────────────────
// DEVICE TOKEN REGISTRATION
// ─────────────────────────────────────────────────────────────────────────

// RegisterDeviceToken registers a device FCM or APNs token
func (h *PreferencesHandler) RegisterDeviceToken(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"User not authenticated"}}`, http.StatusUnauthorized)
		return
	}

	var req struct {
		Token    string `json:"token"`
		Platform string `json:"platform"` // "android", "ios", "web"
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":{"code":"INVALID_JSON","message":"Invalid request body"}}`, http.StatusBadRequest)
		return
	}

	if req.Token == "" || req.Platform == "" {
		http.Error(w, `{"error":{"code":"MISSING_FIELD","message":"token and platform required"}}`, http.StatusBadRequest)
		return
	}

	// Store token based on platform
	var storeErr error
	switch req.Platform {
	case "android", "web":
		storeErr = h.repo.RegisterFCMToken(r.Context(), userID, req.Token)
	case "ios":
		storeErr = h.repo.RegisterAPNsToken(r.Context(), userID, req.Token)
	default:
		http.Error(w, `{"error":{"code":"INVALID_PLATFORM","message":"Supported: android, ios, web"}}`, http.StatusBadRequest)
		return
	}

	if storeErr != nil {
		http.Error(w, `{"error":{"code":"DB_ERROR","message":"Failed to register device"}}`, http.StatusInternalServerError)
		return
	}

	// Also store in cache for quick checks
	cacheKey := fmt.Sprintf("device:%s:%s", userID, req.Platform)
	_ = h.rdb.Set(r.Context(), cacheKey, req.Token, 30*24*time.Hour).Err()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"registered":true,"platform":"%s"}`, req.Platform)

	log.Printf("Device registered for user %s: %s", userID, req.Platform)
}

// UnregisterDeviceToken removes a device token
func (h *PreferencesHandler) UnregisterDeviceToken(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"User not authenticated"}}`, http.StatusUnauthorized)
		return
	}

	var req struct {
		Platform string `json:"platform"` // "android", "ios", "web"
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":{"code":"INVALID_JSON","message":"Invalid request body"}}`, http.StatusBadRequest)
		return
	}

	// For now, just clear the cache
	cacheKey := fmt.Sprintf("device:%s:%s", userID, req.Platform)
	_ = h.rdb.Del(r.Context(), cacheKey).Err()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"unregistered":true}`)

	log.Printf("Device unregistered for user %s: %s", userID, req.Platform)
}

// ─────────────────────────────────────────────────────────────────────────
// NOTIFICATION QUEUE STATUS
// ─────────────────────────────────────────────────────────────────────────

// GetNotificationQueue retrieves pending notifications for a user (Admin only)
func (h *PreferencesHandler) GetNotificationQueue(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"User not authenticated"}}`, http.StatusUnauthorized)
		return
	}

	// TODO: Add permission check (admin only)

	// Get pending notifications for user
	allNotifs, err := h.repo.GetPendingNotifications(r.Context(), 1000)
	if err != nil {
		http.Error(w, `{"error":{"code":"DB_ERROR","message":"Failed to fetch notifications"}}`, http.StatusInternalServerError)
		return
	}

	// Filter to user's notifications
	var userNotifs []interface{}
	for _, notif := range allNotifs {
		if notif.UserID == userID {
			userNotifs = append(userNotifs, notif)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{"notifications": userNotifs})
}
