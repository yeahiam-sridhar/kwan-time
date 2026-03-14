package websocket

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
	"kwan-time/internal/middleware"
)

// ═══════════════════════════════════════════════════════════════════════════
// WEBSOCKET HANDLER
// ═══════════════════════════════════════════════════════════════════════════

// Handler manages WebSocket connections and Redis subscriptions
type Handler struct {
	connectionManager *ConnectionManager
	rdb               *redis.Client
	upgrader          websocket.Upgrader
}

// NewHandler creates a new WebSocket handler
func NewHandler(rdb *redis.Client) *Handler {
	return &Handler{
		connectionManager: NewConnectionManager(),
		rdb:               rdb,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			CheckOrigin: func(r *http.Request) bool {
				// In production, verify origin against whitelist
				return true
			},
		},
	}
}

// Start starts the WebSocket handler
func (h *Handler) Start() {
	h.connectionManager.Start()
	go h.subscribeToRedisEvents()
}

// Stop stops the WebSocket handler
func (h *Handler) Stop() {
	h.connectionManager.Stop()
}

// ServeWS handles WebSocket upgrade and connection lifecycle
func (h *Handler) ServeWS(w http.ResponseWriter, r *http.Request) {
	// Extract user ID from context (set by auth middleware)
	userID, err := middleware.GetUserID(r)
	if err != nil {
		http.Error(w, `{"error":{"code":"UNAUTHORIZED","message":"Authentication required"}}`, http.StatusUnauthorized)
		return
	}

	// Upgrade HTTP connection to WebSocket
	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Printf("WebSocket upgrade error: %v\n", err)
		return
	}

	// Create client
	client := NewClient(conn, userID)

	// Register with connection manager
	h.connectionManager.register <- client

	// Start read and write pumps in goroutines
	go client.ReadPump(h.connectionManager)
	go client.WritePump()

	fmt.Printf("WebSocket client connected: %s\n", userID)
}

// ═══════════════════════════════════════════════════════════════════════════
// REDIS SUBSCRIPTION
// ═══════════════════════════════════════════════════════════════════════════

// RedisEventPayload represents the structure of events published from Agent 2 (REST API)
type RedisEventPayload struct {
	Action string      `json:"action"` // create, update, delete
	Event  interface{} `json:"event"`
}

// subscribeToRedisEvents subscribes to all user event channels
func (h *Handler) subscribeToRedisEvents() {
	// This is a simplified implementation that subscribes to a pattern
	// In production, you might want to subscribe per-user on connection
	psubscriber := h.rdb.PSubscribe(context.Background(), "user:*:events", "user:*:notifications")
	defer psubscriber.Close()

	channel := psubscriber.Channel()

	fmt.Println("Redis subscription started for event distribution")

	for msg := range channel {
		// Parse the channel name to extract user ID
		// Format: user:{userID}:events or user:{userID}:notifications
		var userID string
		var messageType string

		// Example: "user:550e8400-e29b-41d4-a716-446655440000:events"
		if n, err := fmt.Sscanf(msg.Channel, "user:%s:events", &userID); err == nil && n == 1 {
			messageType = "events"
		} else if n, err := fmt.Sscanf(msg.Channel, "user:%s:notifications", &userID); err == nil && n == 1 {
			messageType = "notifications"
		} else {
			continue // Skip unparseable channels
		}

		// Process based on message type
		switch messageType {
		case "events":
			h.handleEventMutation(userID, msg.Payload)
		case "notifications":
			h.handleNotification(userID, msg.Payload)
		}
	}
}

// handleEventMutation handles event mutations from Agent 2
func (h *Handler) handleEventMutation(userID string, payload string) {
	var eventPayload RedisEventPayload
	if err := json.Unmarshal([]byte(payload), &eventPayload); err != nil {
		fmt.Printf("Failed to parse event payload: %v\n", err)
		return
	}

	// Determine message type based on action
	var msgType MessageType
	switch eventPayload.Action {
	case "create":
		msgType = MessageTypeEventCreated
	case "update":
		msgType = MessageTypeEventUpdated
	case "delete":
		msgType = MessageTypeEventDeleted
	default:
		return
	}

	// Extract optimistic ID from event if present (for SYNC_CONFIRM)
	// This is a simplified version - in production you'd parse the event object
	optimisticID := ""

	// Create message
	msg := NewEventMessage(msgType, optimisticID, eventPayload.Event, 0)

	// Broadcast to user's connected clients
	h.connectionManager.BroadcastToUser(userID, msg)

	// If there are connected clients, also send SYNC_CONFIRM
	if h.connectionManager.GetConnectedClients(userID) > 0 && optimisticID != "" {
		confirmMsg := NewSyncConfirmMessage(optimisticID, "", eventPayload.Event, 0)
		h.connectionManager.BroadcastToUser(userID, confirmMsg)
	}

	// Mark dashboard as stale
	refreshMsg := NewDashboardRefreshMessage(eventPayload.Action, 0)
	h.connectionManager.BroadcastToUser(userID, refreshMsg)

	fmt.Printf("Event mutation broadcast to user %s: %s\n", userID, eventPayload.Action)
}

// handleNotification handles notifications from Agent 10
func (h *Handler) handleNotification(userID string, payload string) {
	var notifData NotificationData
	if err := json.Unmarshal([]byte(payload), &notifData); err != nil {
		fmt.Printf("Failed to parse notification payload: %v\n", err)
		return
	}

	// Create message
	msg := NewNotificationMessage(notifData, 0)

	// Broadcast to user's connected clients
	h.connectionManager.BroadcastToUser(userID, msg)

	fmt.Printf("Notification broadcast to user %s: %s\n", userID, notifData.Type)
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUS AND MONITORING
// ═══════════════════════════════════════════════════════════════════════════

// GetStatus returns the current status of the WebSocket handler
func (h *Handler) GetStatus() map[string]interface{} {
	return map[string]interface{}{
		"connected_clients": h.connectionManager.GetAllConnectedCount(),
		"timestamp":         time.Now().UTC(),
	}
}

// HealthCheck performs a health check on Redis connection
func (h *Handler) HealthCheck(ctx context.Context) error {
	return h.rdb.Ping(ctx).Err()
}
