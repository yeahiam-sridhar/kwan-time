package notifications

import (
	"context"
	"fmt"
	"log"
	"time"

	"firebase.google.com/go/v4/messaging"
	"kwan-time/internal/models"
	"kwan-time/internal/repository"
)

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION TYPES
// ═══════════════════════════════════════════════════════════════════════════

const (
	NotificationTypeReminder       = "reminder"
	NotificationTypeBookingConfirmed = "booking_confirmed"
	NotificationTypeEventStart     = "event_start"
	NotificationTypeDailySummary   = "daily_summary"
	NotificationTypeWeeklyReport   = "weekly_report"
)

// ═══════════════════════════════════════════════════════════════════════════
// PUSH NOTIFICATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════

// Service handles sending push notifications via FCM and APNs
type Service struct {
	repo   *repository.Repository
	fcm    *messaging.Client
	maxRetries int
	pollInterval time.Duration
}

// NewService creates a new notification service
func NewService(repo *repository.Repository, fcmClient *messaging.Client) *Service {
	return &Service{
		repo:         repo,
		fcm:          fcmClient,
		maxRetries:   3,
		pollInterval: 30 * time.Second,
	}
}

// ═══════════════════════════════════════════════════════════════════════════
// WORKER LOOP
// ═══════════════════════════════════════════════════════════════════════════

// Start starts the notification worker loop
func (s *Service) Start(ctx context.Context) {
	ticker := time.NewTicker(s.pollInterval)
	defer ticker.Stop()

	fmt.Println("Notification worker started (polling every 30 seconds)")

	for {
		select {
		case <-ctx.Done():
			fmt.Println("Notification worker stopped")
			return

		case <-ticker.C:
			s.pollAndSendNotifications(ctx)
		}
	}
}

// pollAndSendNotifications polls the notification queue and sends pending notifications
func (s *Service) pollAndSendNotifications(ctx context.Context) {
	// Get pending notifications (limit 100 per batch)
	notifications, err := s.repo.GetPendingNotifications(ctx, 100)
	if err != nil {
		log.Printf("Failed to fetch pending notifications: %v", err)
		return
	}

	if len(notifications) == 0 {
		return // No pending notifications
	}

	log.Printf("Processing %d pending notifications", len(notifications))

	for _, notif := range notifications {
		if err := s.sendNotification(ctx, notif); err != nil {
			log.Printf("Failed to send notification %s: %v", notif.ID, err)
		}
	}
}

// sendNotification sends a single notification
func (s *Service) sendNotification(ctx context.Context, notif *models.Notification) error {
	// Get user details (including FCM/APNs tokens)
	user, err := s.repo.GetUserByID(ctx, notif.UserID)
	if err != nil {
		return fmt.Errorf("failed to fetch user: %w", err)
	}

	// Determine which platform(s) to send to
	var sendErrors []error

	if user.FCMToken != nil && *user.FCMToken != "" {
		if err := s.sendFCMNotification(ctx, *user.FCMToken, notif); err != nil {
			sendErrors = append(sendErrors, fmt.Errorf("FCM error: %w", err))
		}
	}

	if user.APNsToken != nil && *user.APNsToken != "" {
		if err := s.sendAPNsNotification(ctx, *user.APNsToken, notif); err != nil {
			sendErrors = append(sendErrors, fmt.Errorf("APNs error: %w", err))
		}
	}

	// If notification was sent to at least one platform, mark as sent
	if len(sendErrors) < 2 { // At least one platform succeeded
		if err := s.repo.MarkNotificationSent(ctx, notif.ID); err != nil {
			log.Printf("Failed to mark notification as sent: %v", err)
		}
		return nil
	}

	// All platforms failed
	if len(sendErrors) > 0 {
		return fmt.Errorf("all platforms failed: %v", sendErrors)
	}

	// No tokens available
	if err := s.repo.MarkNotificationSent(ctx, notif.ID); err != nil {
		log.Printf("Failed to mark notification as sent: %v", err)
	}

	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// FCM (Android/Web)
// ═══════════════════════════════════════════════════════════════════════════

// sendFCMNotification sends a notification via Firebase Cloud Messaging
func (s *Service) sendFCMNotification(ctx context.Context, token string, notif *models.Notification) error {
	// Build FCM message
	message := &messaging.Message{
		Token: token,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				Title: notif.Title,
				Body:  notif.Body,
				Sound: getSoundKey(notif.SoundKey),
				Color: "#1AFFFFFF", // Glassmorphism color
			},
		},
		Data: map[string]string{
			"notification_id": notif.ID,
			"type":            notif.Type,
			"timestamp":       time.Now().Format(time.RFC3339),
		},
	}

	// Send message
	response, err := s.fcm.Send(ctx, message)
	if err != nil {
		return fmt.Errorf("failed to send FCM message: %w", err)
	}

	log.Printf("FCM message sent: %s (notification: %s)", response, notif.ID)
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// APNs (iOS)
// ═══════════════════════════════════════════════════════════════════════════

// sendAPNsNotification sends a notification via Apple Push Notification service
// NOTE: Full APNs implementation requires github.com/sideshow/apns2 package
// This is a skeleton showing the flow
func (s *Service) sendAPNsNotification(ctx context.Context, token string, notif *models.Notification) error {
	// Full implementation would use:
	// import "github.com/sideshow/apns2"
	// import "github.com/sideshow/apns2/certificate"
	//
	// client := apns2.NewClient(certificate).Production()
	// notification := &apns2.Notification{
	//     DeviceToken: token,
	//     Topic:       "com.kwantime.app",
	//     Payload:     payload,
	// }
	// res, err := client.Push(notification)

	log.Printf("APNs notification queued: %s (note: requires certificate setup)", notif.ID)
	// For now, just log that it would be sent
	return nil
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

// getSoundKey returns the sound identifier for FCM
func getSoundKey(key *string) string {
	if key == nil || *key == "" {
		return "default"
	}

	// Map internal sound keys to FCM sound names
	soundMap := map[string]string{
		"chime_soft":     "chime_soft",
		"chime_bright":   "chime_bright",
		"bell_notification": "notification",
		"ding_soft":      "ding_soft",
	}

	if sound, ok := soundMap[*key]; ok {
		return sound
	}

	return "default"
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION CREATION (Called by event triggers)
// ═══════════════════════════════════════════════════════════════════════════

// CreateEventReminder creates reminder notifications for an event
func (s *Service) CreateEventReminder(ctx context.Context, userID, eventID, title string, reminderMinutes []int) error {
	for _, minutes := range reminderMinutes {
		notif := &models.Notification{
			ID:       fmt.Sprintf("notif_%d", time.Now().UnixNano()),
			UserID:   userID,
			EventID:  &eventID,
			Type:     NotificationTypeReminder,
			Title:    fmt.Sprintf("Reminder: %s", title),
			Body:     fmt.Sprintf("Starting in %d minutes", minutes),
			SoundKey: ptrString("chime_soft"),
			NotifyAt: time.Now().Add(time.Duration(-minutes) * time.Minute),
		}

		if err := s.repo.CreateNotification(ctx, notif); err != nil {
			return fmt.Errorf("failed to create reminder: %w", err)
		}
	}

	return nil
}

// CreateBookingConfirmation creates a booking confirmation notification
func (s *Service) CreateBookingConfirmation(ctx context.Context, userID, clientName string) error {
	notif := &models.Notification{
		ID:       fmt.Sprintf("notif_%d", time.Now().UnixNano()),
		UserID:   userID,
		Type:     NotificationTypeBookingConfirmed,
		Title:    "Booking Confirmed",
		Body:     fmt.Sprintf("New booking from %s", clientName),
		SoundKey: ptrString("bell_notification"),
		NotifyAt: time.Now(),
	}

	return s.repo.CreateNotification(ctx, notif)
}

// CreateDailySummary creates a daily summary notification
func (s *Service) CreateDailySummary(ctx context.Context, userID string, eventCount int) error {
	notif := &models.Notification{
		ID:       fmt.Sprintf("notif_%d", time.Now().UnixNano()),
		UserID:   userID,
		Type:     NotificationTypeDailySummary,
		Title:    "Daily Summary",
		Body:     fmt.Sprintf("You have %d events today", eventCount),
		SoundKey: ptrString("chime_bright"),
		NotifyAt: time.Now().Add(9 * time.Hour), // 9:00 AM
	}

	return s.repo.CreateNotification(ctx, notif)
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

func ptrString(s string) *string {
	return &s
}
