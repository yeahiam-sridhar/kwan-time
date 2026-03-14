package models

import (
	"time"
)

// ═══════════════════════════════════════════════════════════════════════════
// FROZEN MODELS (must match Agent 4 interfaces in lib/core/providers/interfaces.dart)
// All JSON tags MUST match the frozen contract in FROZEN_CONTRACTS.md
// ═══════════════════════════════════════════════════════════════════════════

// User represents a user in the system
type User struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Username     string    `json:"username"`
	Email        string    `json:"email"`
	Timezone     string    `json:"timezone"`
	FCMToken     *string   `json:"fcm_token,omitempty"`
	APNsToken    *string   `json:"apns_token,omitempty"`
	SoundProfile string    `json:"sound_profile"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// Event represents a calendar event
type Event struct {
	ID               string    `json:"id"`
	UserID           string    `json:"user_id"`
	Title            string    `json:"title"`
	EventType        string    `json:"event_type"` // online, in_person, free, booked, cancelled
	Status           string    `json:"status"`     // not_started, in_progress, completed, cancelled
	Location         *string   `json:"location,omitempty"`
	StartTime        time.Time `json:"start_time"`
	EndTime          time.Time `json:"end_time"`
	IsRecurring      bool      `json:"is_recurring"`
	RecurrenceRule   *string   `json:"recurrence_rule,omitempty"`
	ColorOverride    *string   `json:"color_override,omitempty"`
	ReminderMinutes  []int     `json:"reminder_minutes"`
	SoundTrigger     *string   `json:"sound_trigger,omitempty"`
	NotificationSent bool      `json:"notification_sent"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

// MonthSummary represents pre-computed monthly analytics
type MonthSummary struct {
	Month              time.Time `json:"month"`
	Label              string    `json:"label"`
	IsCurrent          bool      `json:"is_current"`
	TotalOnline        int       `json:"total_online"`
	TotalInPerson      int       `json:"total_in_person"`
	TotalFree          int       `json:"total_free"`
	TotalBooked        int       `json:"total_booked"`
	TotalCancelled     int       `json:"total_cancelled"`
	TotalNotStarted    int       `json:"total_not_started"`
	TotalInProgress    int       `json:"total_in_progress"`
	TotalCompleted     int       `json:"total_completed"`
	FreeTimeMinutes    int       `json:"free_time_minutes"`
	AvailableDays      int       `json:"available_days"`
	AvailableSaturdays int       `json:"available_saturdays"`
	AvailableSundays   int       `json:"available_sundays"`
	AvailableDates     []string  `json:"available_dates"`
}

// Notification represents a notification in the queue
type Notification struct {
	ID        string     `json:"id"`
	UserID    string     `json:"user_id"`
	EventID   *string    `json:"event_id,omitempty"`
	Type      string     `json:"type"` // reminder, booking_confirmed, event_start, daily_summary, weekly_report
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	SoundKey  *string    `json:"sound_key,omitempty"`
	NotifyAt  time.Time  `json:"notify_at"`
	Sent      bool       `json:"sent"`
	SentAt    *time.Time `json:"sent_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

// BookingLink represents a public booking page
type BookingLink struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	Slug            string    `json:"slug"`
	Title           string    `json:"title"`
	DurationMinutes int       `json:"duration_minutes"`
	BufferMinutes   int       `json:"buffer_minutes"`
	IsActive        bool      `json:"is_active"`
	MaxAdvanceDays  int       `json:"max_advance_days"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// ─────────────────────────────────────────────────────────────────────────
// REQUEST/RESPONSE MODELS
// ─────────────────────────────────────────────────────────────────────────

// ErrorResponse represents a standard error response
type ErrorResponse struct {
	Error struct {
		Code      string    `json:"code"`
		Message   string    `json:"message"`
		Timestamp time.Time `json:"timestamp"`
	} `json:"error"`
}

// DataResponse wraps successful response data
type DataResponse struct {
	Data interface{} `json:"data"`
}

// AcceptedResponse for 202 Accepted responses
type AcceptedResponse struct {
	Accepted      bool   `json:"accepted"`
	OptimisticID  string `json:"optimistic_id"`
}

// CreateEventRequest for POST /api/v1/events
type CreateEventRequest struct {
	Title           string   `json:"title"`
	EventType       string   `json:"event_type"`
	Status          string   `json:"status"`
	Location        *string  `json:"location"`
	StartTime       time.Time `json:"start_time"`
	EndTime         time.Time `json:"end_time"`
	ReminderMinutes []int    `json:"reminder_minutes"`
	SoundTrigger    *string  `json:"sound_trigger"`
}

// UpdateEventRequest for PATCH /api/v1/events/{id}
type UpdateEventRequest struct {
	Title           *string   `json:"title,omitempty"`
	EventType       *string   `json:"event_type,omitempty"`
	Status          *string   `json:"status,omitempty"`
	Location        *string   `json:"location,omitempty"`
	StartTime       *time.Time `json:"start_time,omitempty"`
	EndTime         *time.Time `json:"end_time,omitempty"`
	ReminderMinutes []int     `json:"reminder_minutes,omitempty"`
}

// UpdateSoundProfileRequest for PATCH /api/v1/user/sound-profile
type UpdateSoundProfileRequest struct {
	Profile string `json:"profile"`
}

// RegisterDeviceRequest for POST /api/v1/notifications/register-device
type RegisterDeviceRequest struct {
	FCMToken string `json:"fcm_token"`
	Platform string `json:"platform"` // android or ios
}

// UpdateNotificationPrefsRequest for PATCH /api/v1/notifications/preferences
type UpdateNotificationPrefsRequest struct {
	ReminderMinutes     []int  `json:"reminder_minutes"`
	DailySummaryTime    string `json:"daily_summary_time"`
	ReminderEnabled     bool   `json:"reminder_enabled"`
	BookingConfirmed    bool   `json:"booking_confirmed_enabled"`
	EventStartEnabled   bool   `json:"event_start_enabled"`
	DailySummaryEnabled bool   `json:"daily_summary_enabled"`
}

// BookingConfirmRequest for POST /api/v1/public/booking/{slug}/confirm
type BookingConfirmRequest struct {
	Date        string `json:"date"`        // "2026-01-16"
	Time        string `json:"time"`        // "10:00"
	ClientName  string `json:"name"`
	ClientEmail string `json:"email"`
	Notes       *string `json:"notes,omitempty"`
}

// AvailableSlot represents an available time slot
type AvailableSlot struct {
	StartTime   time.Time `json:"start_time"`
	EndTime     time.Time `json:"end_time"`
	DisplayText string    `json:"display_text"`
}

// ThreeMonthOverviewResponse for GET /api/v1/dashboard/three-month-overview
type ThreeMonthOverviewResponse struct {
	Months []MonthSummary `json:"months"`
}

// DailyBreakdown for detailed daily event counts
type DailyBreakdown struct {
	Date      string `json:"date"`
	Day       string `json:"day"`
	OnlineCount     int    `json:"online"`
	InPersonCount   int    `json:"in_person"`
}
