package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	"kwan-time/internal/models"
)

// Repository holds database connection and query methods
type Repository struct {
	db *sqlx.DB
}

// NewRepository creates a new repository instance
func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// ═══════════════════════════════════════════════════════════════════════════
// USER OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════

// GetUserByID retrieves a user by ID
func (r *Repository) GetUserByID(ctx context.Context, userID string) (*models.User, error) {
	var user models.User
	query := `
		SELECT id, name, username, email, timezone, fcm_token, apns_token, sound_profile, created_at, updated_at
		FROM users
		WHERE id = $1
	`
	err := r.db.GetContext(ctx, &user, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	return &user, nil
}

// GetUserByEmail retrieves a user by email
func (r *Repository) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User
	query := `
		SELECT id, name, username, email, timezone, fcm_token, apns_token, sound_profile, created_at, updated_at
		FROM users
		WHERE email = $1
	`
	err := r.db.GetContext(ctx, &user, query, email)
	if err != nil {
		return nil, fmt.Errorf("failed to get user by email: %w", err)
	}
	return &user, nil
}

// CreateUser creates a new user
func (r *Repository) CreateUser(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (id, name, username, email, timezone, sound_profile, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	now := time.Now().UTC()
	_, err := r.db.ExecContext(ctx, query, user.ID, user.Name, user.Username, user.Email, user.Timezone, user.SoundProfile, now, now)
	if err != nil {
		return fmt.Errorf("failed to create user: %w", err)
	}
	return nil
}

// UpdateUserSoundProfile updates the user's sound profile
func (r *Repository) UpdateUserSoundProfile(ctx context.Context, userID, profile string) error {
	query := `
		UPDATE users
		SET sound_profile = $1, updated_at = $2
		WHERE id = $3
	`
	_, err := r.db.ExecContext(ctx, query, profile, time.Now().UTC(), userID)
	if err != nil {
		return fmt.Errorf("failed to update sound profile: %w", err)
	}
	return nil
}

// RegisterFCMToken registers a device FCM token
func (r *Repository) RegisterFCMToken(ctx context.Context, userID, fcmToken string) error {
	query := `
		UPDATE users
		SET fcm_token = $1, updated_at = $2
		WHERE id = $3
	`
	_, err := r.db.ExecContext(ctx, query, fcmToken, time.Now().UTC(), userID)
	if err != nil {
		return fmt.Errorf("failed to register FCM token: %w", err)
	}
	return nil
}

// RegisterAPNsToken registers a device APNs token
func (r *Repository) RegisterAPNsToken(ctx context.Context, userID, apnsToken string) error {
	query := `
		UPDATE users
		SET apns_token = $1, updated_at = $2
		WHERE id = $3
	`
	_, err := r.db.ExecContext(ctx, query, apnsToken, time.Now().UTC(), userID)
	if err != nil {
		return fmt.Errorf("failed to register APNs token: %w", err)
	}
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// EVENT OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════

// GetEvent retrieves an event by ID
func (r *Repository) GetEvent(ctx context.Context, eventID string) (*models.Event, error) {
	var event models.Event
	query := `
		SELECT id, user_id, title, event_type, status, location, start_time, end_time,
		       is_recurring, recurrence_rule, color_override, reminder_minutes, sound_trigger,
		       notification_sent, created_at, updated_at
		FROM events
		WHERE id = $1
	`
	err := r.db.GetContext(ctx, &event, query, eventID)
	if err != nil {
		return nil, fmt.Errorf("failed to get event: %w", err)
	}
	return &event, nil
}

// GetUserEvents retrieves all events for a user in a given date range
func (r *Repository) GetUserEvents(ctx context.Context, userID string, startDate, endDate time.Time) ([]*models.Event, error) {
	var events []*models.Event
	query := `
		SELECT id, user_id, title, event_type, status, location, start_time, end_time,
		       is_recurring, recurrence_rule, color_override, reminder_minutes, sound_trigger,
		       notification_sent, created_at, updated_at
		FROM events
		WHERE user_id = $1 AND start_time >= $2 AND start_time < $3
		ORDER BY start_time ASC
	`
	err := r.db.SelectContext(ctx, &events, query, userID, startDate, endDate)
	if err != nil {
		return nil, fmt.Errorf("failed to get user events: %w", err)
	}
	return events, nil
}

// CreateEvent creates a new event
func (r *Repository) CreateEvent(ctx context.Context, event *models.Event) error {
	query := `
		INSERT INTO events (id, user_id, title, event_type, status, location, start_time, end_time,
			is_recurring, recurrence_rule, color_override, reminder_minutes, sound_trigger,
			notification_sent, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
	`
	now := time.Now().UTC()
	_, err := r.db.ExecContext(ctx, query,
		event.ID, event.UserID, event.Title, event.EventType, event.Status, event.Location,
		event.StartTime, event.EndTime, event.IsRecurring, event.RecurrenceRule,
		event.ColorOverride, event.ReminderMinutes, event.SoundTrigger,
		false, now, now,
	)
	if err != nil {
		return fmt.Errorf("failed to create event: %w", err)
	}
	return nil
}

// UpdateEvent updates an existing event
func (r *Repository) UpdateEvent(ctx context.Context, event *models.Event) error {
	query := `
		UPDATE events
		SET title = $1, event_type = $2, status = $3, location = $4, start_time = $5,
		    end_time = $6, color_override = $7, reminder_minutes = $8, sound_trigger = $9,
		    updated_at = $10
		WHERE id = $11 AND user_id = $12
	`
	result, err := r.db.ExecContext(ctx, query,
		event.Title, event.EventType, event.Status, event.Location,
		event.StartTime, event.EndTime, event.ColorOverride, event.ReminderMinutes,
		event.SoundTrigger, time.Now().UTC(), event.ID, event.UserID,
	)
	if err != nil {
		return fmt.Errorf("failed to update event: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rowsAffected == 0 {
		return errors.New("event not found or unauthorized")
	}
	return nil
}

// DeleteEvent deletes an event
func (r *Repository) DeleteEvent(ctx context.Context, eventID, userID string) error {
	query := `
		DELETE FROM events
		WHERE id = $1 AND user_id = $2
	`
	result, err := r.db.ExecContext(ctx, query, eventID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete event: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rowsAffected == 0 {
		return errors.New("event not found or unauthorized")
	}
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD/ANALYTICS OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════

// GetThreeMonthOverview retrieves three-month analytics summary (from pre-computed table)
func (r *Repository) GetThreeMonthOverview(ctx context.Context, userID string) ([]*models.MonthSummary, error) {
	var months []*models.MonthSummary
	query := `
		SELECT month, label, is_current, total_online, total_in_person, total_free, total_booked,
		       total_cancelled, total_not_started, total_in_progress, total_completed,
		       free_time_minutes, available_days, available_saturdays, available_sundays,
		       available_dates
		FROM monthly_summaries
		WHERE user_id = $1
		ORDER BY month ASC
		LIMIT 3
	`
	err := r.db.SelectContext(ctx, &months, query, userID)
	if err != nil {
		return []*models.MonthSummary{}, nil
	}
	return months, nil
}

// RefreshMonthlyKSummaries triggers a refresh of the monthly summaries (called by cron, but exposed for manual refresh)
func (r *Repository) RefreshMonthlySummaries(ctx context.Context, userID string) error {
	query := `
		SELECT refresh_monthly_summary($1)
	`
	_, err := r.db.ExecContext(ctx, query, userID)
	if err != nil {
		return fmt.Errorf("failed to refresh monthly summaries: %w", err)
	}
	return nil
}

// GetAvailableSlots retrieves available time slots for a date
func (r *Repository) GetAvailableSlots(ctx context.Context, userID string, targetDate time.Time, durationMinutes int) ([]*models.AvailableSlot, error) {
	var slots []*models.AvailableSlot

	// Call PostgreSQL function
	query := `
		SELECT (result).start_time, (result).end_time
		FROM get_available_slots($1, $2::date, $3)
	`

	rows, err := r.db.QueryContext(ctx, query, userID, targetDate, durationMinutes)
	if err != nil {
		return nil, fmt.Errorf("failed to get available slots: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var start, end time.Time
		if err := rows.Scan(&start, &end); err != nil {
			return nil, fmt.Errorf("failed to scan slot: %w", err)
		}
		slot := &models.AvailableSlot{
			StartTime:   start,
			EndTime:     end,
			DisplayText: fmt.Sprintf("%s - %s", start.Format("15:04"), end.Format("15:04")),
		}
		slots = append(slots, slot)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating slots: %w", err)
	}

	return slots, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════

// GetPendingNotifications retrieves notifications ready to send
func (r *Repository) GetPendingNotifications(ctx context.Context, limit int) ([]*models.Notification, error) {
	var notifications []*models.Notification
	query := `
		SELECT id, user_id, event_id, type, title, body, sound_key, notify_at, sent, sent_at, created_at
		FROM notification_queue
		WHERE sent = false AND notify_at <= $1
		ORDER BY notify_at ASC
		LIMIT $2
	`
	err := r.db.SelectContext(ctx, &notifications, query, time.Now().UTC(), limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending notifications: %w", err)
	}
	return notifications, nil
}

// MarkNotificationSent marks a notification as sent
func (r *Repository) MarkNotificationSent(ctx context.Context, notificationID string) error {
	query := `
		UPDATE notification_queue
		SET sent = true, sent_at = $1
		WHERE id = $2
	`
	_, err := r.db.ExecContext(ctx, query, time.Now().UTC(), notificationID)
	if err != nil {
		return fmt.Errorf("failed to mark notification sent: %w", err)
	}
	return nil
}

// CreateNotification creates a new notification
func (r *Repository) CreateNotification(ctx context.Context, notification *models.Notification) error {
	query := `
		INSERT INTO notification_queue (id, user_id, event_id, type, title, body, sound_key, notify_at, sent, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	_, err := r.db.ExecContext(ctx, query,
		notification.ID, notification.UserID, notification.EventID, notification.Type, notification.Title,
		notification.Body, notification.SoundKey, notification.NotifyAt, false, time.Now().UTC(),
	)
	if err != nil {
		return fmt.Errorf("failed to create notification: %w", err)
	}
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// PUBLIC BOOKING OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════

// GetBookingLinkBySlug retrieves a booking link by its slug
func (r *Repository) GetBookingLinkBySlug(ctx context.Context, slug string) (*models.BookingLink, error) {
	var link models.BookingLink
	query := `
		SELECT id, user_id, slug, title, duration_minutes, buffer_minutes, is_active, max_advance_days, created_at, updated_at
		FROM booking_links
		WHERE slug = $1 AND is_active = true
	`
	err := r.db.GetContext(ctx, &link, query, slug)
	if err != nil {
		return nil, fmt.Errorf("failed to get booking link: %w", err)
	}
	return &link, nil
}

// GetUserBookingLinks retrieves all booking links for a user
func (r *Repository) GetUserBookingLinks(ctx context.Context, userID string) ([]*models.BookingLink, error) {
	var links []*models.BookingLink
	query := `
		SELECT id, user_id, slug, title, duration_minutes, buffer_minutes, is_active, max_advance_days, created_at, updated_at
		FROM booking_links
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	err := r.db.SelectContext(ctx, &links, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user booking links: %w", err)
	}
	return links, nil
}

// CreateBookingLink creates a new booking link
func (r *Repository) CreateBookingLink(ctx context.Context, link *models.BookingLink) error {
	query := `
		INSERT INTO booking_links (id, user_id, slug, title, duration_minutes, buffer_minutes, is_active, max_advance_days, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	now := time.Now().UTC()
	_, err := r.db.ExecContext(ctx, query,
		link.ID, link.UserID, link.Slug, link.Title, link.DurationMinutes, link.BufferMinutes,
		link.IsActive, link.MaxAdvanceDays, now, now,
	)
	if err != nil {
		return fmt.Errorf("failed to create booking link: %w", err)
	}
	return nil
}

// CreateBookingEvent creates an event from a public booking
func (r *Repository) CreateBookingEvent(ctx context.Context, userID, bookingLinkID, clientName, clientEmail string, startTime, endTime time.Time) (string, error) {
	eventID := fmt.Sprintf("evt_%d", time.Now().UnixNano())
	query := `
		INSERT INTO events (id, user_id, title, event_type, status, location, start_time, end_time,
			is_recurring, color_override, notification_sent, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
	`
	now := time.Now().UTC()
	title := fmt.Sprintf("Booking: %s (%s)", clientName, clientEmail)

	_, err := r.db.ExecContext(ctx, query,
		eventID, userID, title, "booked", "not_started", "", startTime, endTime,
		false, nil, false, now, now,
	)
	if err != nil {
		return "", fmt.Errorf("failed to create booking event: %w", err)
	}
	return eventID, nil
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER METHODS
// ═══════════════════════════════════════════════════════════════════════════

// Close closes the database connection
func (r *Repository) Close() error {
	return r.db.Close()
}
