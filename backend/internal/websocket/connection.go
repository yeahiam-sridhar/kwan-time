package websocket

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT CONNECTION
// ═══════════════════════════════════════════════════════════════════════════

// Client represents a connected WebSocket client
type Client struct {
	conn           *websocket.Conn
	userID         string
	send           chan *Message
	sequence       int64 // For tracking message order
	mu             sync.RWMutex
	lastMessageSeq int64 // Client's last acknowledged sequence
	isAuthenticated bool
}

// NewClient creates a new client
func NewClient(conn *websocket.Conn, userID string) *Client {
	return &Client{
		conn:      conn,
		userID:    userID,
		send:      make(chan *Message, 256), // Buffered channel
		sequence:  0,
		isAuthenticated: true, // Authenticated via JWT middleware
	}
}

// SendMessage sends a message to the client
func (c *Client) SendMessage(msg *Message) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.isAuthenticated {
		select {
		case c.send <- msg:
			return true
		case <-time.After(5 * time.Second):
			// Client's send channel is full, disconnect
			return false
		}
	}
	return false
}

// ReadPump reads messages from the client
func (c *Client) ReadPump(cm *ConnectionManager) {
	defer func() {
		cm.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		var msg Message
		err := c.conn.ReadJSON(&msg)
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				fmt.Printf("WebSocket error: %v\n", err)
			}
			break
		}

		// Handle different message types
		switch msg.Type {
		case MessageTypePong:
			// Client acknowledged heartbeat
			c.mu.Lock()
			c.lastMessageSeq = msg.Sequence
			c.mu.Unlock()

		default:
			// Echo unknown messages (shouldn't happen if client follows protocol)
		}
	}
}

// WritePump writes messages to the client
func (c *Client) WritePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case msg := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteJSON(msg); err != nil {
				return
			}

		case <-ticker.C:
			// Send heartbeat every 30 seconds
			c.mu.Lock()
			seq := c.sequence
			c.sequence++
			c.mu.Unlock()

			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			heartbeat := NewHeartbeatMessage(time.Now().UnixMilli(), seq)
			if err := c.conn.WriteJSON(heartbeat); err != nil {
				return
			}
		}
	}
}

// GetUserID returns the authenticated user ID
func (c *Client) GetUserID() string {
	return c.userID
}

// ═══════════════════════════════════════════════════════════════════════════
// CONNECTION MANAGER
// ═══════════════════════════════════════════════════════════════════════════

// ConnectionManager manages all connected WebSocket clients
type ConnectionManager struct {
	clients       map[string]map[*Client]bool // map[userID]map[client]true
	clientsMu     sync.RWMutex
	register      chan *Client
	unregister    chan *Client
	broadcast     chan *BroadcastMessage
	done          chan bool
	sequence      int64
	sequenceMu    sync.Mutex
}

// BroadcastMessage is a message to be broadcast to specific clients
type BroadcastMessage struct {
	UserID  string
	Message *Message
}

// NewConnectionManager creates a new connection manager
func NewConnectionManager() *ConnectionManager {
	return &ConnectionManager{
		clients:    make(map[string]map[*Client]bool),
		register:   make(chan *Client, 256),
		unregister: make(chan *Client, 256),
		broadcast:  make(chan *BroadcastMessage, 256),
		done:       make(chan bool),
		sequence:   0,
	}
}

// Start starts the connection manager
func (cm *ConnectionManager) Start() {
	go func() {
		for {
			select {
			case client := <-cm.register:
				cm.clientsMu.Lock()
				if cm.clients[client.userID] == nil {
					cm.clients[client.userID] = make(map[*Client]bool)
				}
				cm.clients[client.userID][client] = true
				cm.clientsMu.Unlock()
				fmt.Printf("Client connected: %s (total for user: %d)\n", client.userID, len(cm.clients[client.userID]))

			case client := <-cm.unregister:
				cm.clientsMu.Lock()
				if clients, ok := cm.clients[client.userID]; ok {
					if _, ok := clients[client]; ok {
						delete(clients, client)
						close(client.send)

						if len(clients) == 0 {
							delete(cm.clients, client.userID)
						}
						fmt.Printf("Client disconnected: %s\n", client.userID)
					}
				}
				cm.clientsMu.Unlock()

			case broadcast := <-cm.broadcast:
				cm.clientsMu.RLock()
				if clients, ok := cm.clients[broadcast.UserID]; ok {
					// Assign sequence number
					cm.sequenceMu.Lock()
					cm.sequence++
					broadcast.Message.Sequence = cm.sequence
					cm.sequenceMu.Unlock()

					for client := range clients {
						if !client.SendMessage(broadcast.Message) {
							// Client's channel is full, disconnect it
							go func(c *Client) {
								cm.unregister <- c
							}(client)
						}
					}
				}
				cm.clientsMu.RUnlock()

			case <-cm.done:
				return
			}
		}
	}()
}

// Stop stops the connection manager
func (cm *ConnectionManager) Stop() {
	cm.done <- true
}

// BroadcastToUser sends a message to all connected clients for a user
func (cm *ConnectionManager) BroadcastToUser(userID string, msg *Message) {
	cm.broadcast <- &BroadcastMessage{
		UserID:  userID,
		Message: msg,
	}
}

// GetConnectedClients returns the number of connected clients for a user
func (cm *ConnectionManager) GetConnectedClients(userID string) int {
	cm.clientsMu.RLock()
	defer cm.clientsMu.RUnlock()

	if clients, ok := cm.clients[userID]; ok {
		return len(clients)
	}
	return 0
}

// GetAllConnectedCount returns total connected clients across all users
func (cm *ConnectionManager) GetAllConnectedCount() int {
	cm.clientsMu.RLock()
	defer cm.clientsMu.RUnlock()

	total := 0
	for _, clients := range cm.clients {
		total += len(clients)
	}
	return total
}

// ParseMessage parses a JSON message
func ParseMessage(data []byte) (*Message, error) {
	var msg Message
	err := json.Unmarshal(data, &msg)
	return &msg, err
}
