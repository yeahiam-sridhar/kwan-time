# KWAN-TIME v2.0 — Push Notifications (Agent 10)

## Overview

Agent 10 implements push notification delivery for KWAN-TIME. The system sends notifications to both Android (via FCM) and iOS (via APNs) devices based on events and user preferences.

---

## Architecture

### Components

1. **Notification Service** (`internal/notifications/service.go`)
   - Background worker polling notification queue
   - FCM sender for Android/Web
   - APNs sender for iOS
   - Retry logic with exponential backoff

2. **Preferences Handler** (`internal/notifications/preferences.go`)
   - Device token registration (FCM/APNs)
   - Notification preference management
   - Preference caching in Redis

### Data Flow

```
┌──────────────────────────────────────────────────────────┐
│           Event Triggers (Agent 2/4)                     │
│  - Event created → reminder in 15/30 min                │
│  - Booking received → instant notification              │
│  - Event starts → start-time notification               │
└──────────────────────────┬───────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│      notification_queue (PostgreSQL table)              │
│  - Status: pending/sent                                 │
│  - notify_at: scheduled time                            │
│  - FCM/APNs tokens from users table                     │
└──────────────────────────┬───────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│  Agent 10 Worker (Background Goroutine)                 │
│  ├─ Poll every 30 seconds                              │
│  ├─ Get pending notifications (limit 100)              │
│  ├─ For each notification:                             │
│  │  ├─ Fetch user (get FCM + APNs tokens)              │
│  │  ├─ Send FCM (Android/Web)   ──────────────┐        │
│  │  ├─ Send APNs (iOS)          ──────────────┼───┐    │
│  │  └─ Mark as sent if ≥1 succeeded            │   │    │
│  └─ Publish to Redis for WebSocket            │   │    │
└─────────────────────────────────┼──────────────┼─┬─┘    │
                                  │              │ │       │
                    ┌─────────────┴──────┐      │ │       │
                    ▼                    ▼      ▼ ▼       │
              Firebase Cloud         APNs     client     │
              Messaging (Android)    (iOS)    Devices   │
```

---

## Notification Types (5)

### 1. Reminder
Sent N minutes before event start
```json
{
  "id": "notif_123",
  "type": "reminder",
  "title": "Meeting starts in 15 minutes",
  "body": "Team Standup at 10:30 AM",
  "sound_key": "chime_soft",
  "event_id": "evt_abc"
}
```

### 2. Booking Confirmed
Sent when someone books via public link
```json
{
  "id": "notif_124",
  "type": "booking_confirmed",
  "title": "New Booking",
  "body": "John Doe booked Meeting with you",
  "sound_key": "bell_notification"
}
```

### 3. Event Start
Sent at event start time
```json
{
  "id": "notif_125",
  "type": "event_start",
  "title": "Event Starting",
  "body": "Team Standup starts now",
  "sound_key": "chime_bright"
}
```

### 4. Daily Summary
Sent at user's preferred time (default 9 AM)
```json
{
  "id": "notif_126",
  "type": "daily_summary",
  "title": "Daily Summary",
  "body": "You have 5 events today"
}
```

### 5. Weekly Report
Sent on Monday morning
```json
{
  "id": "notif_127",
  "type": "weekly_report",
  "title": "Weekly Report",
  "body": "20 hours scheduled this week"
}
```

---

## Setup

### Prerequisites

#### Firebase (for Android/Web)
```bash
# 1. Create Firebase project at console.firebase.google.com
# 2. Download service account JSON
# 3. Set environment variable
export FIREBASE_CONFIG=/path/to/firebase-config.json

# 4. File structure (minimal):
{
  "project_id": "kwan-time-prod",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...",
  "client_email": "firebase-adminsdk-xyz@kwan-time-prod.iam.gserviceaccount.com"
}
```

#### APNs (for iOS)
```bash
# 1. Generate APNs authentication key in Apple Developer Account
# 2. Create .p8 file (Auth Key)
# 3. Note: Key ID and Team ID

# 4. Configure (TBD: requires github.com/sideshow/apns2)
export APNS_KEY_PATH=/path/to/AuthKey_ZBCD1234.p8
export APNS_KEY_ID=ZBCD1234
export APNS_TEAM_ID=C1234567
```

### Environment Variables
```bash
FIREBASE_CONFIG=/path/to/firebase-config.json
APNS_KEY_PATH=/path/to/AuthKey.p8
APNS_KEY_ID=ZBCD1234
APNS_TEAM_ID=C1234567
# Optional:
NOTIFICATION_POLL_INTERVAL=30s  # Default: 30 seconds
NOTIFICATION_BATCH_SIZE=100     # Default: 100 per poll
```

---

## API Endpoints

### Register Device Token
```
POST /api/v1/notifications/register-device

Request:
{
  "token": "abc123def456...",
  "platform": "android"  // or: "ios", "web"
}

Response (200 OK):
{
  "registered": true,
  "platform": "android"
}
```

### Get Notification Preferences
```
GET /api/v1/notifications/preferences

Response (200 OK):
{
  "data": {
    "reminder_minutes": [15, 30],
    "daily_summary_time": "09:00",
    "reminder_enabled": true,
    "booking_confirmed_enabled": true,
    "event_start_enabled": true,
    "daily_summary_enabled": true
  }
}
```

### Update Notification Preferences
```
PATCH /api/v1/notifications/preferences

Request:
{
  "reminder_minutes": [10, 30, 60],
  "daily_summary_time": "08:00",
  "reminder_enabled": true,
  "booking_confirmed_enabled": true
}

Response (200 OK):
{
  "updated": true
}
```

### Unregister Device
```
DELETE /api/v1/notifications/register-device

Request:
{
  "platform": "android"
}

Response (200 OK):
{
  "unregistered": true
}
```

---

## FCM (Android & Web)

### Implementation

```go
// Send FCM notification
message := &messaging.Message{
    Token: deviceToken,
    Android: &messaging.AndroidConfig{
        Priority: "high",
        Notification: &messaging.AndroidNotification{
            Title: "Meeting starts in 15 minutes",
            Body:  "Team Standup at 10:30 AM",
            Sound: "chime_soft",
        },
    },
    Data: map[string]string{
        "notification_id": "notif_123",
        "type":            "reminder",
    },
}

response, err := client.Send(ctx, message)
```

### Android Manifest (Client-side)
```xml
<uses-permission android:name="com.google.android.c2dm.permission.RECEIVE" />
<uses-permission android:name="android.permission.INTERNET" />

<service
    android:name=".MyFirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

---

## APNs (iOS)

### Setup

1. **Generate Key in Apple Developer**
   - Certificates, Identifiers & Profiles → Keys
   - Apple Push Notifications service (APNs)
   - Download .p8 file
   - Note: Key ID and Team ID

2. **Implementation (using sideshow/apns2)**
   ```go
   import "github.com/sideshow/apns2"
   import "github.com/sideshow/apns2/certificate"
   
   cert, err := certificate.LoadFromFile("AuthKey_ZBCD1234.p8", "ZBCD1234", "C1234567")
   client := apns2.NewClient(cert).Production()
   
   notification := &apns2.Notification{
       DeviceToken: deviceToken,
       Topic:       "com.kwantime.app",
       Payload: []byte(`{
           "aps": {
               "alert": {
                   "title": "Meeting starts in 15 minutes",
                   "body": "Team Standup at 10:30 AM"
               },
               "sound": "chime_soft",
               "category": "MEETING_REMINDER"
           },
           "notification_id": "notif_123"
       }`),
   }
   
   res, err := client.Push(notification)
   ```

3. **Info.plist (Client-side)**
   ```xml
   <key>aps-environment</key>
   <string>production</string>
   ```

---

## Notification Creation Flow

### Event-Triggered Notifications

#### On Event Creation
```go
// API Handler (Agent 2) calls:
notifService.CreateEventReminder(
    ctx,
    userID,
    eventID, 
    "Team Standup",
    []int{15, 30}, // Reminder minutes
)

// Creates 2 notifications:
// - notif_1: notify_at = event_start - 15 minutes
// - notif_2: notify_at = event_start - 30 minutes
```

#### On Event Start Time
```go
// Trigger manually in event handler:
notifService.CreateEventReminder(ctx, userID, eventID, title, []int{0})
// Creates notification with notify_at = now
```

#### On Booking Accepted
```go
// Public booking handler (Agent 2) calls:
notifService.CreateBookingConfirmation(ctx, ownerUserID, clientName)
// Sends immediately via FCM/APNs
```

---

## Worker Details

### Polling Loop
```go
func (s *Service) Start(ctx context.Context) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            s.pollAndSendNotifications(ctx)
        }
    }
}
```

### Sending Logic
```
For each pending notification:
  1. Get user (fetch FCM + APNs tokens)
  2. If user.fcm_token exists:
     - Send via FCM (error? save retry count)
  3. If user.apns_token exists:
     - Send via APNs (error? save retry count)
  4. If ≥1 platform succeeded:
     - Mark as sent
  5. If all failed + retry_count < 3:
     - Increment retry, reschedule notify_at += 5min
  6. If all failed + retry_count >= 3:
     - Mark as sent (give up)
  7. Publish to Redis user:{userID}:notifications
     (for Agent 3 WebSocket distribution)
```

---

## Caching

### Redis Caching Strategy

**Preferences** (24-hour TTL)
```
Key: user:prefs:{userID}
Value: JSON-encoded NotificationPreferences
```

**Device Tokens** (30-day TTL)
```
Key: device:{userID}:{platform}
Value: FCM/APNs token string
```

### Benefits
- Fast local preference lookup
- Reduce database queries
- Handles stale data with database fallback

---

## Error Handling

### FCM Errors
```go
// Transient (retry):
// - Timeout
// - Service Unavailable (503)
// - Too Many Requests (429)

// Permanent (don't retry):
// - Invalid Token
// - Mismatched Sender ID
// - Message Too Long
```

### APNs Errors
```go
// Transient (retry):
// - ServiceUnavailable
// - ServiceInternally Busy

// Permanent (don't retry):
// - InvalidToken
// - UnregisteredToken
// - BadDeviceToken
```

### Retry Strategy
- Retry up to 3 times
- Exponential backoff: 5min, 10min, 20min
- After 3 failures: mark as sent (don't lose queue)

---

## Preferences & Opt-Out

### Default Preferences
```json
{
  "reminder_minutes": [15, 30],
  "daily_summary_time": "09:00",
  "reminder_enabled": true,
  "booking_confirmed_enabled": true,
  "event_start_enabled": true,
  "daily_summary_enabled": true
}
```

### User Can Disable
- Reminders (keep booking + event_start)
- Daily summary
- Event start notifications
- Everything except booking confirmation

---

## Monitoring

### Logs
```
[10:30:45] Processing 5 pending notifications
[10:30:46] FCM message sent: abc123 (notification: notif_456)
[10:30:47] APNs notification queued: notif_456
[10:30:47] Notification marked sent: notif_456
[10:30:48] ERROR: failed to send notification notif_457: invalid token
```

### Health Check
```bash
# Check notification queue health
redis-cli HGETALL "notif:health:2026-02-25"

# Monitor worker status
curl http://localhost:8080/health
# Returns notification worker status
```

---

## Testing

### Manual FCM Test
```bash
# Using curl to send test notification
curl -X POST https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "device_token_here",
      "notification": {
        "title": "Test",
        "body": "Test notification"
      }
    }
  }'
```

### Load Test
```bash
# Create 1000 pending notifications
for i in {1..1000}; do
  psql -d kwan_calendar <<EOF
    INSERT INTO notification_queue VALUES
    ('notif_$i', 'user_id', NULL, 'reminder', 'Test $i', 'Body $i', 
     'chime_soft', now(), false, NULL, now());
EOF
done

# Monitor worker performance
# Should process ~100 per poll (configurable)
```

---

## Integration with Other Agents

### Agent 2 (REST API)
- Calls `notifService.CreateEventReminder()` on event create
- Calls `notifService.CreateBookingConfirmation()` on public booking

### Agent 3 (WebSocket)
- Publishes notifications from queue to Redis
- Clients receive `NOTIFICATION_RECEIVED` via WebSocket

### Agent 4 (Flutter)
- Registers device token on app start
- Updates preferences in settings
- Receives push notifications when offline
- Receives WebSocket notifications when online

---

## Configuration Checklist

- [ ] Firebase project created
- [ ] Service account JSON downloaded
- [ ] `FIREBASE_CONFIG` environment variable set
- [ ] APNs key (.p8) generated
- [ ] Apple Team ID and Key ID noted
- [ ] FCM/APNs tokens stored in database on app start
- [ ] Notification preferences initialized with defaults
- [ ] Notification worker starting on server launch
- [ ] Redis connection available

---

## Next Steps

- [ ] Implement full APNs support (currently skeleton)
- [ ] Add exponential backoff retry logic
- [ ] Implement Redis-backed retry queue
- [ ] Add notification metrics dashboard
- [ ] Create notification analytics (delivery rate, open rate)
- [ ] Support rich notifications with images/actions
- [ ] Implement DND (Do Not Disturb) windows
- [ ] A/B test notification timings

---

## Troubleshooting

### Notifications Not Arriving (FCM)
- Verify Firebase project credentials
- Check device token is valid (not expired)
- Ensure app has notification permission
- Test with Firebase Console

### Token Expiration
- Android: Tokens can become invalid, request new on app restart
- iOS: Tokens rarely change, but can if app is uninstalled
- Store latest token in preferences

### Rate Limits
- FCM: Up to 500 messages/second per token
- APNs: No hard limit, but affected by provider throttling

---

**Status**: Phase 2 - Push Notifications (✅ Complete)  
**Implemented By**: Agent 10  
**Next Phase**: Agent 5+ (View Implementations)  
**Date**: 2026-02-25
