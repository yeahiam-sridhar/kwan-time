# KWAN-TIME v2.0 — WebSocket Real-Time Sync (Agent 3)

## Overview

Agent 3 implements WebSocket real-time synchronization for KWAN-TIME. Connected clients receive live updates when events are created, updated, deleted, or notifications arrive. All events are optimistically updated on the client side with server confirmation/rollback.

---

## Architecture

### Components

1. **WebSocket Handler** (`websocket.go`)
   - HTTP upgrade (HTTP → WebSocket)
   - Client connection lifecycle
   - Redis subscription management
   - Message routing

2. **Connection Manager** (`connection.go`)
   - Manages all connected clients
   - Per-user client groups
   - Message broadcasting
   - Sequence tracking

3. **Message Types** (`messages.go`)
   - Frozen message contract (10 message types)
   - Factory functions for message creation
   - Enum for type safety

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client App                              │
│  (User presses "Create Event")                                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ├─► Generate optimistic_id
                       ├─► Update local state (optimistic)
                       ├─► POST /api/v1/events (Agent 2)
                       │
┌──────────────────────┴──────────────────────────────────────────┐
│                    Agent 2 (REST API)                           │
│  POST /api/v1/events → 202 Accepted + optimistic_id            │
│  ├─ Queue async save to DB                                     │
│  └─ Publish to Redis: user:{userID}:events                     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────────┐
│                  Redis Channel                                  │
│    user:{userID}:events                                        │
│  Contains: {action: "create", event: {...}}                   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────────┐
│              Agent 3 (WebSocket Handler)                        │
│  ├─ Subscribes to Redis channel pattern                        │
│  ├─ Receives mutation from Redis                               │
│  ├─ Broadcasts to all clients for user:                        │
│  │  - EVENT_CREATED message                                   │
│  │  - DASHBOARD_REFRESHED message                             │
│  │  - SYNC_CONFIRM (if has optimistic_id)                    │
│  └─ Sends messages via WebSocket to all connected clients     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────────┐
│                      WebSocket                                  │
│   Client receives: {type: "EVENT_CREATED", data: {...}}       │
│                or: {type: "SYNC_CONFIRM", data: {...}}         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────────┐
│                    Client App                                   │
│  ├─ If SYNC_CONFIRM: confirm optimistic change (no flicker)   │
│  ├─ If EVENT_CREATED: merge with local state                  │
│  ├─ If DASHBOARD_REFRESHED: trigger dashboard refresh         │
│  └─ Play notification sound (Agent 11)                        │
└──────────────────────────────────────────────────────────────────┘
```

---

## Message Types

### Frozen Message Contract

All messages follow this structure:
```json
{
  "type": "MESSAGE_TYPE",
  "id": "msg_1234567890",
  "seq": 42,
  "timestamp": "2026-02-25T10:30:45.123Z",
  "data": { /* payload */ },
  "error": null
}
```

### Event Mutations (3)

#### `EVENT_CREATED`
```json
{
  "type": "EVENT_CREATED",
  "data": {
    "optimistic_id": "evt_1234567890",
    "event": {
      "id": "evt_actual_id",
      "title": "Team Meeting",
      "event_type": "online",
      ...
    }
  }
}
```

#### `EVENT_UPDATED`
```json
{
  "type": "EVENT_UPDATED",
  "data": {
    "optimistic_id": "evt_1234567890",
    "event": { /* full updated event */ }
  }
}
```

#### `EVENT_DELETED`
```json
{
  "type": "EVENT_DELETED",
  "data": {
    "optimistic_id": "evt_1234567890",
    "event": {
      "id": "evt_actual_id"
    }
  }
}
```

### Sync Control (2)

#### `SYNC_CONFIRM` (Success)
```json
{
  "type": "SYNC_CONFIRM",
  "data": {
    "optimistic_id": "evt_client_generated",
    "id": "evt_server_id",
    "timestamp": "2026-02-25T10:30:45.123Z",
    "data": { /* full resource */ }
  }
}
```

#### `SYNC_REVERT` (Rollback)
```json
{
  "type": "SYNC_REVERT",
  "data": {
    "optimistic_id": "evt_client_generated",
    "reason": "Conflict with existing event",
    "old_data": { /* previous state */ }
  }
}
```

### Dashboard (1)

#### `DASHBOARD_REFRESHED`
Signals that dashboard summaries are stale and need refresh

```json
{
  "type": "DASHBOARD_REFRESHED",
  "data": {
    "reason": "event_created",
    "timestamp": "2026-02-25T10:30:45.123Z"
  }
}
```

### Notifications (1)

#### `NOTIFICATION_RECEIVED`
```json
{
  "type": "NOTIFICATION_RECEIVED",
  "data": {
    "id": "notif_123",
    "type": "reminder",
    "title": "Meeting starts in 15 minutes",
    "body": "Team Standup - 10:30 AM",
    "sound_key": "chime_soft",
    "created_at": "2026-02-25T10:15:45.123Z"
  }
}
```

### Connection (2)

#### `HEARTBEAT` (Server → Client)
Sent every 30 seconds to keep connection alive

```json
{
  "type": "HEARTBEAT",
  "data": {
    "client_time": 1709019045000
  }
}
```

#### `PONG` (Client → Server)
Client response to `HEARTBEAT`

```json
{
  "type": "PONG",
  "seq": 100
}
```

---

## Client Integration

### Connect via WebSocket

```dart
// In Flutter client (Agent 4)
final wsClient = WebSocketClient(
  url: 'ws://localhost:8080/ws',
  token: jwtToken,
);

await wsClient.connect();

// Listen for messages
wsClient.messages.listen((msg) {
  switch (msg.type) {
    case 'EVENT_CREATED':
      handleEventCreated(msg.data);
    case 'SYNC_CONFIRM':
      handleSyncConfirm(msg.data);
    case 'DASHBOARD_REFRESHED':
      refreshDashboard();
    case 'NOTIFICATION_RECEIVED':
      showNotification(msg.data);
  }
});
```

### Send Optimistic Update

```dart
// Before sending to API
final optimisticId = 'evt_${DateTime.now().millisecondsSinceEpoch}';

// Update local state immediately
events.add(Event(
  id: optimisticId,
  title: 'New Event',
  status: 'not_started',
));

// Send to API (GET 202 Accepted)
final response = await api.createEvent(event);

// Wait for WebSocket confirmation
wsClient.onMessage('SYNC_CONFIRM', (msg) {
  if (msg.data.optimistic_id == optimisticId) {
    // Confirmed! Replace optimistic_id with server id
    events[optimisticId].id = msg.data.id;
    events[optimisticId].created_at = msg.data.timestamp;
  }
});

// If SYNC_REVERT arrives => rollback
wsClient.onMessage('SYNC_REVERT', (msg) {
  if (msg.data.optimistic_id == optimisticId) {
    // Remove or revert to previous state
    events.removeWhere((e) => e.id == optimisticId);
  }
});
```

---

## Server-Side Flow

### 1. Client Connects
```go
router.Get("/ws", jwtMiddleware, wsHandler.ServeWS)

// Handler:
func (h *Handler) ServeWS(w http.ResponseWriter, r *http.Request) {
    userID, _ := middleware.GetUserID(r) // From JWT
    conn, _ := h.upgrader.Upgrade(w, r, nil)
    client := NewClient(conn, userID)
    h.connectionManager.register <- client
    go client.ReadPump(connectionManager)
    go client.WritePump()
}
```

### 2. Event Mutation from Agent 2
Agent 2 REST API publishes:
```go
// In handlers.go (Agent 2)
h.rdb.Publish(ctx, fmt.Sprintf("user:%s:events", userID), eventPayload)
// Payload: {action: "create", event: {...}}
```

### 3. WebSocket Receives via Redis
```go
// In websocket.go (Agent 3)
func (h *Handler) subscribeToRedisEvents() {
    psubscriber := h.rdb.PSubscribe(ctx, "user:*:events")
    
    for msg := range psubscriber.Channel() {
        // Parse user ID from channel
        // Call handleEventMutation(userID, msg.Payload)
    }
}
```

### 4. Broadcast to Clients
```go
func (h *Handler) handleEventMutation(userID string, payload string) {
    msgType := getMsgType(action)  // EVENT_CREATED, etc
    msg := NewEventMessage(msgType, optimisticId, event, seq)
    
    h.connectionManager.BroadcastToUser(userID, msg)
    // Message sent to ALL connected clients for that user
}
```

---

## Sequence Tracking

Each message has a sequence number for replay on reconnection:

```go
type ConnectionManager struct {
    sequence  int64  // Global counter
    clients   map[string]map[*Client]bool  // Grouped by user
}

// On broadcast:
cm.sequenceMu.Lock()
cm.sequence++
msg.Sequence = cm.sequence
cm.sequenceMu.Unlock()
```

### Client-Side Replay

On reconnection, client can request missed messages:
```json
{
  "type": "REQUEST_REPLAY",
  "last_seq": 100  // Last message received
}
```

Server responds with messages from seq 101 onward (from cache/log).

---

## Performance & Reliability

### Heartbeat
- Server sends `HEARTBEAT` every 30 seconds
- Client responds with `PONG`
- If no `PONG` received within 60 seconds: disconnect

### Buffering
- Client send channel: 256 message buffer
- If buffer fills (client too slow): force disconnect + reconnect
- Redis Streams: persistent, survives server restart

### Concurrency
- One goroutine per client (ReadPump + WritePump)
- Connection manager goroutine handles registration/broadcast
- Thread-safe maps with RWMutex

### Memory
```go
// Per connected client
Channel buffer: 256 * ~1KB = 256KB
Total for 1000 clients: ~256MB
```

---

## Testing

### Manual WebSocket Test

```bash
# Install websocat: https://github.com/vi/websocat
cargo install websocat

# Connect (replace TOKEN)
websocat "ws://localhost:8080/ws" \
  -H "Authorization: Bearer $TOKEN"

# You should receive HEARTBEAT every 30 seconds
# Send PONG: {"type":"PONG","seq":1}
```

### Load Test (k6)
```javascript
import ws from 'k6/ws';

export default function() {
  let res = ws.connect('ws://localhost:8080/ws', {
    headers: { 'Authorization': `Bearer ${TOKEN}` }
  }, function(socket) {
    socket.on('message', (data) => {
      console.log('Message received:', data);
    });
  });
}
```

---

## Integration with Other Agents

### Agent 2 (REST API)
- Publishes mutations to Redis when events change
- Agent 3 subscribes and broadcasts

### Agent 4 (Flutter UI)
- Connects via `ws://host:8080/ws`
- Implements optimistic updates pattern
- Handles SYNC_CONFIRM and SYNC_REVERT

### Agent 10 (Notifications)
- Publishes to `user:{userID}:notifications`
- Agent 3 broadcasts as `NOTIFICATION_RECEIVED`
- Agent 4 displays in-app notification

### Agent 5 (Animations)
- Triggered by event state changes
- Watches for `EVENT_CREATED`, `EVENT_UPDATED` messages

---

## Configuration

### Environment Variables
```bash
REDIS_URL=redis://localhost:6379/0
# WebSocket config (auto-configured)
WS_HEARTBEAT_INTERVAL=30s
WS_READ_DEADLINE=60s
WS_WRITE_DEADLINE=10s
WS_BUFFER_SIZE=256
```

---

## Troubleshooting

### WebSocket Connection Fails
```
Error: connection refused
```
- Ensure `/ws` endpoint is registered in router
- Check JWT token is valid
- Verify auth middleware is applied

### Messages Not Arriving
```
No EVENT_CREATED message received
```
- Check Redis connection: `redis-cli PING`
- Verify Agent 2 is publishing: `redis-cli SUBSCRIBE "user:*:events"`
- Check client is subscribed to correct user channel

### High Memory Usage
- Too many connected clients with old messages
- Increase heartbeat frequency to disconnect idle clients
- Enable client-side message purging (keep last N messages)

---

## Next Steps

- [ ] Implement message persistence (replay on reconnect)
- [ ] Add compression for large payloads
- [ ] Support for broadcast messages (admin notifications)
- [ ] Metrics collection (connections, messages/sec, latency)
- [ ] Load testing with k6 (see tests/)

---

**Status**: Phase 2 - WebSocket Real-Time (✅ Complete)  
**Implemented By**: Agent 3  
**Next Agent**: Agent 10 (Push Notifications)  
**Date**: 2026-02-25
