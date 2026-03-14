-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration 001: Initial Schema
-- Created: 2026-01-23
-- Description: Create all core tables, indexes, and functions
-- ═══════════════════════════════════════════════════════════════════════════════

-- This migration is identical to schema.sql and serves as the baseline
-- Subsequent migrations will be delta changes

BEGIN;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- Users table
CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  username         TEXT UNIQUE NOT NULL,
  email            TEXT UNIQUE NOT NULL,
  timezone         TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  fcm_token        TEXT,
  apns_token       TEXT,
  sound_profile    TEXT DEFAULT 'calm',
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- Events table
CREATE TABLE events (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title            TEXT NOT NULL,
  event_type       TEXT NOT NULL DEFAULT 'online' 
    CHECK (event_type IN ('online', 'in_person', 'free', 'booked', 'cancelled')),
  status           TEXT NOT NULL DEFAULT 'not_started'
    CHECK (status IN ('not_started', 'in_progress', 'completed', 'cancelled')),
  location         TEXT,
  start_time       TIMESTAMPTZ NOT NULL,
  end_time         TIMESTAMPTZ NOT NULL,
  is_recurring     BOOLEAN DEFAULT FALSE,
  recurrence_rule  TEXT,
  color_override   TEXT,
  reminder_minutes INT[] DEFAULT ARRAY[60, 15],
  sound_trigger    TEXT,
  notification_sent BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_user_time ON events(user_id, start_time);
CREATE INDEX idx_events_type ON events(user_id, event_type);
CREATE INDEX idx_events_status ON events(user_id, status);
CREATE INDEX idx_events_tsrange ON events USING GIST (tstzrange(start_time, end_time));

-- Monthly summaries
CREATE TABLE monthly_summaries (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  month               DATE NOT NULL,
  total_online        INT DEFAULT 0,
  total_in_person     INT DEFAULT 0,
  total_free          INT DEFAULT 0,
  total_booked        INT DEFAULT 0,
  total_cancelled     INT DEFAULT 0,
  total_not_started   INT DEFAULT 0,
  total_in_progress   INT DEFAULT 0,
  total_completed     INT DEFAULT 0,
  available_days      INT DEFAULT 0,
  available_weekdays  INT DEFAULT 0,
  available_weekends  INT DEFAULT 0,
  available_saturdays INT DEFAULT 0,
  available_sundays   INT DEFAULT 0,
  available_dates     JSONB,
  free_time_minutes   INT DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, month)
);

CREATE INDEX idx_monthly_user_month ON monthly_summaries(user_id, month);

-- Daily summaries
CREATE TABLE daily_summaries (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date             DATE NOT NULL,
  online_count     INT DEFAULT 0,
  in_person_count  INT DEFAULT 0,
  is_available     BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, date)
);

CREATE INDEX idx_daily_user_date ON daily_summaries(user_id, date);

-- Notification queue
CREATE TABLE notification_queue (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id         UUID REFERENCES events(id) ON DELETE CASCADE,
  notify_at        TIMESTAMPTZ NOT NULL,
  type             TEXT NOT NULL 
    CHECK (type IN ('reminder', 'booking_confirmed', 'event_start', 'daily_summary', 'weekly_report')),
  title            TEXT NOT NULL,
  body             TEXT NOT NULL,
  sound_key        TEXT,
  sent             BOOLEAN DEFAULT FALSE,
  sent_at          TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notify_queue ON notification_queue(notify_at, sent) WHERE sent = FALSE;
CREATE INDEX idx_notify_queue_user ON notification_queue(user_id, sent);

-- Booking links
CREATE TABLE booking_links (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  slug             TEXT UNIQUE NOT NULL,
  title            TEXT DEFAULT 'Book a Session',
  duration_minutes INT DEFAULT 60,
  buffer_minutes   INT DEFAULT 15,
  is_active        BOOLEAN DEFAULT TRUE,
  max_advance_days INT DEFAULT 60,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_booking_links_slug ON booking_links(slug);
CREATE INDEX idx_booking_links_user ON booking_links(user_id);

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create all triggers
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER events_updated_at BEFORE UPDATE ON events
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER monthly_summaries_updated_at BEFORE UPDATE ON monthly_summaries
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER daily_summaries_updated_at BEFORE UPDATE ON daily_summaries
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER booking_links_updated_at BEFORE UPDATE ON booking_links
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Functions (simplified versions - see schema.sql for full functions)
CREATE OR REPLACE FUNCTION get_three_month_overview(
  p_user_id UUID,
  p_start_month DATE
) RETURNS TABLE (
  month DATE,
  label TEXT,
  is_current BOOLEAN,
  total_online INT,
  total_in_person INT,
  total_free INT,
  total_booked INT,
  total_cancelled INT,
  total_not_started INT,
  total_in_progress INT,
  total_completed INT,
  free_time_minutes INT,
  available_days INT,
  available_saturdays INT,
  available_sundays INT,
  available_dates JSONB
) AS $$
SELECT
  ms.month,
  TO_CHAR(ms.month, 'YYYY-MM') AS label,
  FALSE AS is_current,
  ms.total_online,
  ms.total_in_person,
  ms.total_free,
  ms.total_booked,
  ms.total_cancelled,
  ms.total_not_started,
  ms.total_in_progress,
  ms.total_completed,
  ms.free_time_minutes,
  ms.available_days,
  ms.available_saturdays,
  ms.available_sundays,
  ms.available_dates
FROM monthly_summaries ms
WHERE ms.user_id = p_user_id
  AND ms.month >= p_start_month
  AND ms.month < (p_start_month + INTERVAL '3 months')
ORDER BY ms.month ASC;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_available_slots(
  p_user_id UUID,
  p_date DATE,
  p_duration_min INT
) RETURNS TABLE (
  start_time TIME,
  end_time TIME
) AS $$
SELECT
  '10:00:00'::TIME,
  '11:00:00'::TIME
UNION ALL
SELECT
  '14:00:00'::TIME,
  '15:00:00'::TIME
LIMIT 0;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION refresh_monthly_summary(
  p_user_id UUID,
  p_month DATE
) RETURNS void AS $$
BEGIN
  -- Implementation deferred to migration 002
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_pending_notifications()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  event_id UUID,
  notify_at TIMESTAMPTZ,
  type TEXT,
  title TEXT,
  body TEXT,
  sound_key TEXT
) AS $$
SELECT
  id, user_id, event_id, notify_at, type, title, body, sound_key
FROM notification_queue
WHERE sent = FALSE AND notify_at <= NOW()
ORDER BY notify_at ASC;
$$ LANGUAGE SQL STABLE;

COMMIT;
