-- ═══════════════════════════════════════════════════════════════════════════════
-- KWAN-TIME v2.0: Seed Data
-- Sample data for testing (Jan/Feb/Mar 2026)
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- Insert test user
INSERT INTO users (id, name, username, email, timezone, sound_profile)
VALUES (
  '550e8400-e29b-41d4-a716-446655440000'::UUID,
  'Demo User',
  'demo',
  'demo@kwan.time',
  'Asia/Kolkata',
  'calm'
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- JANUARY 2026 (from spreadsheet)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Jan 1 (Thu): 2 in_person events
INSERT INTO events (user_id, title, event_type, status, start_time, end_time)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Morning Standup', 'in_person', 'completed', 
   '2026-01-01 09:00:00+05:30', '2026-01-01 10:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Team Sync', 'in_person', 'completed',
   '2026-01-01 14:00:00+05:30', '2026-01-01 15:00:00+05:30');

-- Jan 2 (Fri): 6 in_person events
INSERT INTO events (user_id, title, event_type, status, start_time, end_time)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Client Meeting 1', 'in_person', 'completed',
   '2026-01-02 08:00:00+05:30', '2026-01-02 09:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Client Meeting 2', 'in_person', 'completed',
   '2026-01-02 10:00:00+05:30', '2026-01-02 11:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Workshop', 'in_person', 'completed',
   '2026-01-02 13:00:00+05:30', '2026-01-02 15:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Coaching Session', 'in_person', 'completed',
   '2026-01-02 15:30:00+05:30', '2026-01-02 16:30:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Planning Session', 'in_person', 'completed',
   '2026-01-02 17:00:00+05:30', '2026-01-02 18:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Review Meeting', 'in_person', 'completed',
   '2026-01-02 19:00:00+05:30', '2026-01-02 20:00:00+05:30');

-- Jan 16 (Fri): AVAILABLE - no events
-- (This is a free slot highlighted in the dashboard)

-- Insert some booked events in January
INSERT INTO events (user_id, title, event_type, status, start_time, end_time)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Booked Session 1', 'booked', 'not_started',
   '2026-01-10 10:00:00+05:30', '2026-01-10 11:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Booked Session 2', 'booked', 'not_started',
   '2026-01-12 14:00:00+05:30', '2026-01-12 15:30:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Online Meeting', 'online', 'not_started',
   '2026-01-15 09:00:00+05:30', '2026-01-15 10:00:00+05:30');

-- Cancelled events in January
INSERT INTO events (user_id, title, event_type, status, start_time, end_time)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Cancelled Session 1', 'cancelled', 'cancelled',
   '2026-01-05 10:00:00+05:30', '2026-01-05 11:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Cancelled Session 2', 'cancelled', 'cancelled',
   '2026-01-07 15:00:00+05:30', '2026-01-07 16:00:00+05:30');

-- ═══════════════════════════════════════════════════════════════════════════════
-- FEBRUARY 2026
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT INTO events (user_id, title, event_type, status, start_time, end_time)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Feb Workshop', 'in_person', 'not_started',
   '2026-02-03 10:00:00+05:30', '2026-02-03 12:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Feb Coaching', 'online', 'not_started',
   '2026-02-06 11:00:00+05:30', '2026-02-06 12:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Feb Consultation', 'in_person', 'not_started',
   '2026-02-09 14:00:00+05:30', '2026-02-09 15:30:00+05:30');

-- ═══════════════════════════════════════════════════════════════════════════════
-- MARCH 2026
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT INTO events (user_id, title, event_type, status, start_time, end_time)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'March Conference', 'in_person', 'not_started',
   '2026-03-02 09:00:00+05:30', '2026-03-02 17:00:00+05:30'),
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'March Training', 'online', 'not_started',
   '2026-03-10 13:00:00+05:30', '2026-03-10 14:00:00+05:30');

-- ═══════════════════════════════════════════════════════════════════════════════
-- BOOKING LINKS (Agent 12)
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT INTO booking_links (user_id, slug, title, duration_minutes, buffer_minutes, is_active)
VALUES (
  '550e8400-e29b-41d4-a716-446655440000'::UUID,
  'demo-booking',
  'Book a Session with Demo User',
  60,
  15,
  TRUE
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTIFICATION QUEUE (Agent 10)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Sample event reminders
INSERT INTO notification_queue (user_id, event_id, notify_at, type, title, body, sound_key, sent)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::UUID, NULL, NOW() - INTERVAL '1 hour', 'reminder',
   '⏰ Upcoming Event', 'You have an event in 60 minutes', 'reminder_chime', FALSE);

COMMIT;
