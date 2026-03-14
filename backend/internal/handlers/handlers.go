package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/redis/go-redis/v9"
	"kwan-time/internal/middleware"
	"kwan-time/internal/models"
	"kwan-time/internal/repository"
)

// ═══════════════════════════════════════════════════════════════════════════
// BASE RESPONSE HELPERS
// ═══════════════════════════════════════════════════════════════════════════

// respondJSON sends a JSON response
func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		http.Error(w, `{"error":{"code":"JSON_ENCODE_ERROR","message":"Failed to encode response"}}`, http.StatusInternalServerError)
	}
}

// respondError sends an error response
func respondError(w http.ResponseWriter, status int, code, message string) {
	w.WriteHeader(status)
	response := map[string]interface{}{
		"error": map[string]interface{}{
			"code":      code,
			"message":   message,
			"timestamp": time.Now().UTC(),
		},
	}
	json.NewEncoder(w).Encode(response)
}

// respondAccepted sends a 202 Accepted response with optimistic ID
func respondAccepted(w http.ResponseWriter, optimisticID string) {
	w.WriteHeader(http.StatusAccepted)
	response := map[string]interface{}{
		"accepted":      true,
		"optimistic_id": optimisticID,
	}
	json.NewEncoder(w).Encode(response)
}

// ═══════════════════════════════════════════════════════════════════════════
// EVENT HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

type EventHandlers struct {
	repo *repository.Repository
	rdb  *redis.Client
}

func NewEventHandlers(repo *repository.Repository, rdb *redis.Client) *EventHandlers {
	return &EventHandlers{repo: repo, rdb: rdb}
}

// GetEvents retrieves all events for the authenticated user in a date range
func (h *EventHandlers) GetEvents(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	// Parse query parameters for date range
	startDateStr := r.URL.Query().Get("start_date")
	endDateStr := r.URL.Query().Get("end_date")

	if startDateStr == "" || endDateStr == "" {
		respondError(w, http.StatusBadRequest, "MISSING_PARAMS", "start_date and end_date required")
		return
	}

	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_DATE", "start_date must be YYYY-MM-DD")
		return
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_DATE", "end_date must be YYYY-MM-DD")
		return
	}

	events, err := h.repo.GetUserEvents(r.Context(), userID, startDate, endDate)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch events")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"data": events})
}

// GetEvent retrieves a single event
func (h *EventHandlers) GetEvent(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	eventID := chi.URLParam(r, "eventID")
	event, err := h.repo.GetEvent(r.Context(), eventID)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Event not found")
		return
	}

	if event.UserID != userID {
		respondError(w, http.StatusForbidden, "FORBIDDEN", "Cannot access this event")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"data": event})
}

// CreateEvent creates a new event (returns 202 Accepted)
func (h *EventHandlers) CreateEvent(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	var req models.CreateEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_JSON", "Failed to parse request body")
		return
	}

	// Generate event ID and optimistic ID
	eventID := fmt.Sprintf("evt_%d", time.Now().UnixNano())
	optimisticID := eventID

	// Create event model
	event := &models.Event{
		ID:              eventID,
		UserID:          userID,
		Title:           req.Title,
		EventType:       req.EventType,
		Status:          req.Status,
		Location:        req.Location,
		StartTime:       req.StartTime,
		EndTime:         req.EndTime,
		IsRecurring:     false,
		ReminderMinutes: req.ReminderMinutes,
		SoundTrigger:    req.SoundTrigger,
	}

	// Queue for async save (don't wait for DB operation)
	go func() {
		if err := h.repo.CreateEvent(r.Context(), event); err != nil {
			// Log error but don't fail response since we already sent 202
			fmt.Printf("Failed to create event %s: %v\n", eventID, err)
		}
		// Publish to Redis for WebSocket distribution (Agent 3)
		h.publishEventMutation("create", event)
	}()

	respondAccepted(w, optimisticID)
}

// UpdateEvent updates an existing event (returns 202 Accepted)
func (h *EventHandlers) UpdateEvent(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	eventID := chi.URLParam(r, "eventID")

	// Verify event exists and belongs to user
	existing, err := h.repo.GetEvent(r.Context(), eventID)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Event not found")
		return
	}

	if existing.UserID != userID {
		respondError(w, http.StatusForbidden, "FORBIDDEN", "Cannot update this event")
		return
	}

	var req models.UpdateEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_JSON", "Failed to parse request body")
		return
	}

	// Apply updates
	if req.Title != nil {
		existing.Title = *req.Title
	}
	if req.EventType != nil {
		existing.EventType = *req.EventType
	}
	if req.Status != nil {
		existing.Status = *req.Status
	}
	if req.Location != nil {
		existing.Location = req.Location
	}
	if req.StartTime != nil {
		existing.StartTime = *req.StartTime
	}
	if req.EndTime != nil {
		existing.EndTime = *req.EndTime
	}
	if len(req.ReminderMinutes) > 0 {
		existing.ReminderMinutes = req.ReminderMinutes
	}

	optimisticID := eventID

	// Queue for async save
	go func() {
		if err := h.repo.UpdateEvent(r.Context(), existing); err != nil {
			fmt.Printf("Failed to update event %s: %v\n", eventID, err)
		}
		h.publishEventMutation("update", existing)
	}()

	respondAccepted(w, optimisticID)
}

// DeleteEvent deletes an event
func (h *EventHandlers) DeleteEvent(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	eventID := chi.URLParam(r, "eventID")

	if err := h.repo.DeleteEvent(r.Context(), eventID, userID); err != nil {
		if err.Error() == "event not found or unauthorized" {
			respondError(w, http.StatusNotFound, "NOT_FOUND", "Event not found")
		} else {
			respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to delete event")
		}
		return
	}

	go func() {
		h.publishEventMutation("delete", &models.Event{ID: eventID, UserID: userID})
	}()

	w.WriteHeader(http.StatusNoContent)
}

// publishEventMutation publishes event changes to Redis for WebSocket distribution
func (h *EventHandlers) publishEventMutation(action string, event *models.Event) {
	// This will be consumed by Agent 3 (WebSocket handler)
	payload := map[string]interface{}{
		"action": action,
		"event":  event,
	}
	data, _ := json.Marshal(payload)
	h.rdb.Publish(context.Background(), fmt.Sprintf("user:%s:events", event.UserID), string(data))
}

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

type DashboardHandlers struct {
	repo *repository.Repository
}

func NewDashboardHandlers(repo *repository.Repository) *DashboardHandlers {
	return &DashboardHandlers{repo: repo}
}

// GetThreeMonthOverview retrieves three-month analytics summary
func (h *DashboardHandlers) GetThreeMonthOverview(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	months, err := h.repo.GetThreeMonthOverview(r.Context(), userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch overview")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"months": months})
}

// RefreshMonthlySummary manually triggers refresh of monthly summaries
func (h *DashboardHandlers) RefreshMonthlySummary(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	if err := h.repo.RefreshMonthlySummaries(r.Context(), userID); err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to refresh summary")
		return
	}

	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"status":"refreshed"}`)
}

// ═══════════════════════════════════════════════════════════════════════════
// USER HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

type UserHandlers struct {
	repo *repository.Repository
}

func NewUserHandlers(repo *repository.Repository) *UserHandlers {
	return &UserHandlers{repo: repo}
}

// GetProfile retrieves the user's profile
func (h *UserHandlers) GetProfile(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	user, err := h.repo.GetUserByID(r.Context(), userID)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "User not found")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"data": user})
}

// UpdateSoundProfile updates the user's sound profile
func (h *UserHandlers) UpdateSoundProfile(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	var req models.UpdateSoundProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_JSON", "Failed to parse request body")
		return
	}

	if err := h.repo.UpdateUserSoundProfile(r.Context(), userID, req.Profile); err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to update sound profile")
		return
	}

	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"profile":"updated"}`)
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

type NotificationHandlers struct {
	repo *repository.Repository
	rdb  *redis.Client
}

func NewNotificationHandlers(repo *repository.Repository, rdb *redis.Client) *NotificationHandlers {
	return &NotificationHandlers{repo: repo, rdb: rdb}
}

// RegisterDevice registers device push notification tokens
func (h *NotificationHandlers) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	var req models.RegisterDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_JSON", "Failed to parse request body")
		return
	}

	if req.Platform == "ios" {
		if err := h.repo.RegisterAPNsToken(r.Context(), userID, req.FCMToken); err != nil {
			respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to register device")
			return
		}
	} else {
		if err := h.repo.RegisterFCMToken(r.Context(), userID, req.FCMToken); err != nil {
			respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to register device")
			return
		}
	}

	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"registered":true}`)
}

// GetNotificationPreferences retrieves user notification preferences
func (h *NotificationHandlers) GetNotificationPreferences(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement preferences table query
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"reminded_minutes": []int{15, 30},
		"daily_summary":    true,
	})
}

// UpdateNotificationPreferences updates user notification preferences
func (h *NotificationHandlers) UpdateNotificationPreferences(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	var req models.UpdateNotificationPrefsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_JSON", "Failed to parse request body")
		return
	}

	// TODO: Store preferences in database
	_ = userID
	_ = req

	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"updated":true}`)
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOKING LINK HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

type BookingHandlers struct {
	repo *repository.Repository
}

func NewBookingHandlers(repo *repository.Repository) *BookingHandlers {
	return &BookingHandlers{repo: repo}
}

// GetMyBookingLinks retrieves all booking links for the authenticated user
func (h *BookingHandlers) GetMyBookingLinks(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	links, err := h.repo.GetUserBookingLinks(r.Context(), userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch booking links")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"data": links})
}

// CreateBookingLink creates a new public booking link
func (h *BookingHandlers) CreateBookingLink(w http.ResponseWriter, r *http.Request) {
	userID, err := middleware.GetUserID(r)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "UNAUTHORIZED", "User not authenticated")
		return
	}

	var req struct {
		Title           string `json:"title"`
		DurationMinutes int    `json:"duration_minutes"`
		BufferMinutes   int    `json:"buffer_minutes"`
		MaxAdvanceDays  int    `json:"max_advance_days"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_JSON", "Failed to parse request body")
		return
	}

	// Generate slug
	linkID := fmt.Sprintf("link_%d", time.Now().UnixNano())
	slug := fmt.Sprintf("link_%d", time.Now().Unix())

	link := &models.BookingLink{
		ID:              linkID,
		UserID:          userID,
		Slug:            slug,
		Title:           req.Title,
		DurationMinutes: req.DurationMinutes,
		BufferMinutes:   req.BufferMinutes,
		IsActive:        true,
		MaxAdvanceDays:  req.MaxAdvanceDays,
	}

	if err := h.repo.CreateBookingLink(r.Context(), link); err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to create booking link")
		return
	}

	respondJSON(w, http.StatusCreated, map[string]interface{}{"data": link})
}

// ═══════════════════════════════════════════════════════════════════════════
// PUBLIC BOOKING HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

type PublicHandlers struct {
	repo *repository.Repository
}

func NewPublicHandlers(repo *repository.Repository) *PublicHandlers {
	return &PublicHandlers{repo: repo}
}

// GetBookingInfo retrieves public booking page information
func (h *PublicHandlers) GetBookingInfo(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	link, err := h.repo.GetBookingLinkBySlug(r.Context(), slug)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Booking link not found")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"data": link})
}

// GetAvailableSlots retrieves available time slots for public booking
func (h *PublicHandlers) GetAvailableSlots(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	link, err := h.repo.GetBookingLinkBySlug(r.Context(), slug)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Booking link not found")
		return
	}

	dateStr := r.URL.Query().Get("date")
	if dateStr == "" {
		respondError(w, http.StatusBadRequest, "MISSING_PARAM", "date parameter required (YYYY-MM-DD)")
		return
	}

	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_DATE", "date must be YYYY-MM-DD")
		return
	}

	slots, err := h.repo.GetAvailableSlots(r.Context(), link.UserID, date, link.DurationMinutes)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch available slots")
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{"slots": slots})
}

// ConfirmBooking confirms a public booking
func (h *PublicHandlers) ConfirmBooking(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	link, err := h.repo.GetBookingLinkBySlug(r.Context(), slug)
	if err != nil {
		respondError(w, http.StatusNotFound, "NOT_FOUND", "Booking link not found")
		return
	}

	var req models.BookingConfirmRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_JSON", "Failed to parse request body")
		return
	}

	// Parse booking time
	dateTime := fmt.Sprintf("%sT%s:00Z", req.Date, req.Time)
	startTime, err := time.Parse("2006-01-02T15:04:05Z", dateTime)
	if err != nil {
		respondError(w, http.StatusBadRequest, "INVALID_DATETIME", "Invalid date/time format")
		return
	}

	endTime := startTime.Add(time.Duration(link.DurationMinutes) * time.Minute)

	// Create event
	eventID, err := h.repo.CreateBookingEvent(r.Context(), link.UserID, link.ID, req.ClientName, req.ClientEmail, startTime, endTime)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "DB_ERROR", "Failed to create booking")
		return
	}

	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"event_id": eventID,
		"status":   "confirmed",
	})
}
