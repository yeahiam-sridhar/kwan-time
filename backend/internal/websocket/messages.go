package websocket

import (
	"encoding/json"
	"fmt"
	"time"
)

// ═══════════════════════════════════════════════════════════════════════════
// MESSAGE TYPES (FROZEN CONTRACTS from FROZEN_CONTRACTS.md)
// ═══════════════════════════════════════════════════════════════════════════

// MessageType defines the type of WebSocket message
type MessageType string

const (
	// Event mutations
	MessageTypeEventCreated   MessageType = "EVENT_CREATED"
	MessageTypeEventUpdated   MessageType = "EVENT_UPDATED"
	MessageTypeEventDeleted   MessageType = "EVENT_DELETED"

	// Dashboard
	MessageTypeDashboardRefreshed MessageType = "DASHBOARD_REFRESHED"

	// Sync control
	MessageTypeSyncConfirm  MessageType = "SYNC_CONFIRM"
	MessageTypeSyncRevert   MessageType = "SYNC_REVERT"

	// Notifications
	MessageTypeNotificationReceived MessageType = "NOTIFICATION_RECEIVED"

	// Connection
	MessageTypeHeartbeat MessageType = "HEARTBEAT"
	MessageTypePong      MessageType = "PONG"

	// Auth
	MessageTypeAuth MessageType = "AUTH"
)

// ─────────────────────────────────────────────────────────────────────────
// BASE MESSAGE STRUCTURE
// ─────────────────────────────────────────────────────────────────────────

// Message is the base structure for all WebSocket messages
type Message struct {
	Type      MessageType `json:"type"`
	ID        string      `json:"id,omitempty"`           // Message ID (for sequence tracking)
	Sequence  int64       `json:"seq,omitempty"`          // Sequence number (for replay)
	Data      interface{} `json:"data,omitempty"`         // Message payload
	Error     *ErrorData  `json:"error,omitempty"`        // Error details (if any)
	Timestamp time.Time   `json:"timestamp"`              // Server timestamp
}

// ErrorData represents an error in a message
type ErrorData struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// ─────────────────────────────────────────────────────────────────────────
// AUTHENTICATION MESSAGE
// ─────────────────────────────────────────────────────────────────────────

// AuthMessage authenticates the WebSocket connection
type AuthMessage struct {
	Type  MessageType `json:"type"`
	Token string      `json:"token"`
}

// ─────────────────────────────────────────────────────────────────────────
// EVENT MUTATION MESSAGES
// ─────────────────────────────────────────────────────────────────────────

// EventMutationData represents an event creation/update/deletion
type EventMutationData struct {
	OptimisticID string      `json:"optimistic_id,omitempty"` // Client-generated ID for optimistic updates
	Event        interface{} `json:"event"`                   // Full event object
}

// ─────────────────────────────────────────────────────────────────────────
// SYNC MESSAGES
// ─────────────────────────────────────────────────────────────────────────

// SyncConfirmData confirms a successful mutation
type SyncConfirmData struct {
	OptimisticID string      `json:"optimistic_id"`
	ID           string      `json:"id"`           // Actual server-generated ID
	Timestamp    time.Time   `json:"timestamp"`
	Data         interface{} `json:"data,omitempty"` // Updated resource (optional)
}

// SyncRevertData requests rollback of optimistic update
type SyncRevertData struct {
	OptimisticID string `json:"optimistic_id"`
	Reason       string `json:"reason"`
	OldData      interface{} `json:"old_data,omitempty"`
}

// ─────────────────────────────────────────────────────────────────────────
// DASHBOARD MESSAGE
// ─────────────────────────────────────────────────────────────────────────

// DashboardRefreshData indicates dashboard data is stale and needs refresh
type DashboardRefreshData struct {
	Reason   string `json:"reason"` // e.g., "event_created", "event_deleted"
	Timestamp time.Time `json:"timestamp"`
}

// ─────────────────────────────────────────────────────────────────────────
// NOTIFICATION MESSAGE
// ─────────────────────────────────────────────────────────────────────────

// NotificationData represents an in-app notification
type NotificationData struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"` // reminder, booking_confirmed, event_start, etc
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	SoundKey  *string   `json:"sound_key,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// ─────────────────────────────────────────────────────────────────────────
// HEARTBEAT / KEEPALIVE
// ─────────────────────────────────────────────────────────────────────────

// HeartbeatData is sent periodically to keep connection alive
type HeartbeatData struct {
	ClientTime int64 `json:"client_time,omitempty"` // Client timestamp (for latency measurement)
}

// ─────────────────────────────────────────────────────────────────────────
// MESSAGE FACTORY FUNCTIONS
// ─────────────────────────────────────────────────────────────────────────

// NewEventMessage creates an event mutation message
func NewEventMessage(msgType MessageType, optimisticID string, event interface{}, sequence int64) *Message {
	return &Message{
		Type:      msgType,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
		Data: EventMutationData{
			OptimisticID: optimisticID,
			Event:        event,
		},
	}
}

// NewSyncConfirmMessage creates a sync confirmation message
func NewSyncConfirmMessage(optimisticID, serverID string, data interface{}, sequence int64) *Message {
	return &Message{
		Type:      MessageTypeSyncConfirm,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
		Data: SyncConfirmData{
			OptimisticID: optimisticID,
			ID:           serverID,
			Timestamp:    time.Now().UTC(),
			Data:         data,
		},
	}
}

// NewSyncRevertMessage creates a sync revert (rollback) message
func NewSyncRevertMessage(optimisticID, reason string, oldData interface{}, sequence int64) *Message {
	return &Message{
		Type:      MessageTypeSyncRevert,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
		Data: SyncRevertData{
			OptimisticID: optimisticID,
			Reason:       reason,
			OldData:      oldData,
		},
	}
}

// NewDashboardRefreshMessage indicates dashboard needs refresh
func NewDashboardRefreshMessage(reason string, sequence int64) *Message {
	return &Message{
		Type:      MessageTypeDashboardRefreshed,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
		Data: DashboardRefreshData{
			Reason:    reason,
			Timestamp: time.Now().UTC(),
		},
	}
}

// NewNotificationMessage creates a notification message
func NewNotificationMessage(notif NotificationData, sequence int64) *Message {
	return &Message{
		Type:      MessageTypeNotificationReceived,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
		Data:      notif,
	}
}

// NewHeartbeatMessage creates a heartbeat message
func NewHeartbeatMessage(clientTime int64, sequence int64) *Message {
	return &Message{
		Type:      MessageTypeHeartbeat,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
		Data: HeartbeatData{
			ClientTime: clientTime,
		},
	}
}

// NewPongMessage responds to client ping
func NewPongMessage(sequence int64) *Message {
	return &Message{
		Type:      MessageTypePong,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
	}
}

// NewErrorMessage creates an error message
func NewErrorMessage(msgType MessageType, code, message string, sequence int64) *Message {
	return &Message{
		Type:      msgType,
		ID:        fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		Sequence:  sequence,
		Timestamp: time.Now().UTC(),
		Error: &ErrorData{
			Code:    code,
			Message: message,
		},
	}
}

// ─────────────────────────────────────────────────────────────────────────
// SERIALIZATION
// ─────────────────────────────────────────────────────────────────────────

// MarshalJSON converts message to JSON
func (m *Message) MarshalJSON() ([]byte, error) {
	return json.Marshal(m)
}

// UnmarshalJSON parses JSON into message
func (m *Message) UnmarshalJSON(data []byte) error {
	type alias Message
	return json.Unmarshal(data, (*alias)(m))
}
