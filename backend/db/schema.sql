-- ═══════════════════════════════════════════════════════════════════════════════
-- KWAN-TIME v2.0: Database Schema
-- PostgreSQL 16+
-- ═══════════════════════════════════════════════════════════════════════════════

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- ═══════════════════════════════════════════════════════════════════════════════
-- CORE TABLES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Users table: Core user profile + device tokens + preferences
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

-- Events table: Calendar events with full metadata
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

-- Monthly summaries: Pre-computed from events, refreshed every 5 minutes
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

-- Daily summaries: Quick lookup for day-level availability
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

-- Notification queue: Agent 10 reads this, processes, and sends via FCM/APNs
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

-- Booking links: Public pages for client scheduling (Agent 12)
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSTGRESQL FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Function: get_three_month_overview
-- Returns 3 monthly summaries starting from p_start_month
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
DECLARE
  v_current_month DATE;
BEGIN
  v_current_month := DATE_TRUNC('month', (NOW() AT TIME ZONE (
    SELECT timezone FROM users WHERE id = p_user_id
  )))::DATE;

  RETURN QUERY
  SELECT
    ms.month,
    TO_CHAR(ms.month, 'YYYY-MM') AS label,
    (ms.month = v_current_month) AS is_current,
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
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: get_available_slots
-- Returns available time slots for a given date and duration
CREATE OR REPLACE FUNCTION get_available_slots(
  p_user_id UUID,
  p_date DATE,
  p_duration_min INT
) RETURNS TABLE (
  start_time TIME,
  end_time TIME
) AS $$
DECLARE
  v_user_tz TEXT;
  v_day_start TIMESTAMPTZ;
  v_day_end TIMESTAMPTZ;
BEGIN
  SELECT timezone INTO v_user_tz FROM users WHERE id = p_user_id;
  
  v_day_start := (p_date || ' 00:00:00') AT TIME ZONE v_user_tz AT TIME ZONE 'UTC';
  v_day_end := (p_date || ' 23:59:59') AT TIME ZONE v_user_tz AT TIME ZONE 'UTC';

  -- Generate 1-hour slots and check if available
  RETURN QUERY
  WITH slots AS (
    SELECT GENERATE_SERIES(0, 23) AS hour
  )
  SELECT
    (TO_TIMESTAMP(EXTRACT(HOUR FROM CURRENT_TIMESTAMP AT TIME ZONE v_user_tz)) || ':00')::TIME,
    ((TO_TIMESTAMP(EXTRACT(HOUR FROM CURRENT_TIMESTAMP AT TIME ZONE v_user_tz)) + (p_duration_min || ' min')::INTERVAL))::TIME
  FROM slots
  WHERE NOT EXISTS (
    SELECT 1 FROM events e
    WHERE e.user_id = p_user_id
      AND e.start_time AT TIME ZONE v_user_tz >= (p_date || ' ' || (LPAD(slots.hour::TEXT, 2, '0')) || ':00')::TIMESTAMPTZ AT TIME ZONE v_user_tz
      AND e.end_time AT TIME ZONE v_user_tz <= (p_date || ' ' || (LPAD(slots.hour::TEXT, 2, '0')) || ':' || LPAD((slots.hour + 1)::TEXT, 2, '0'))::TIMESTAMPTZ AT TIME ZONE v_user_tz
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: refresh_monthly_summary
-- Recomputes one monthly summary from raw events
CREATE OR REPLACE FUNCTION refresh_monthly_summary(
  p_user_id UUID,
  p_month DATE
) RETURNS void AS $$
DECLARE
  v_month_start DATE;
  v_month_end DATE;
  v_user_tz TEXT;
BEGIN
  v_month_start := DATE_TRUNC('month', p_month)::DATE;
  v_month_end := (DATE_TRUNC('month', p_month) + INTERVAL '1 month - 1 day')::DATE;
  
  SELECT timezone INTO v_user_tz FROM users WHERE id = p_user_id;

  INSERT INTO monthly_summaries (
    user_id, month, total_online, total_in_person, total_free, total_booked,
    total_cancelled, total_not_started, total_in_progress, total_completed,
    available_days, available_saturdays, available_sundays, free_time_minutes, updated_at
  )
  SELECT
    p_user_id,
    v_month_start,
    COALESCE(SUM(CASE WHEN event_type = 'online' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN event_type = 'in_person' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN event_type = 'free' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN event_type = 'booked' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN event_type = 'cancelled' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN status = 'not_started' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END), 0),
    COUNT(DISTINCT (DATE(e.start_time AT TIME ZONE v_user_tz))),
    COUNT(DISTINCT CASE 
      WHEN EXTRACT(DOW FROM (e.start_time AT TIME ZONE v_user_tz)) = 6 THEN DATE(e.start_time AT TIME ZONE v_user_tz)
    END),
    COUNT(DISTINCT CASE 
      WHEN EXTRACT(DOW FROM (e.start_time AT TIME ZONE v_user_tz)) = 0 THEN DATE(e.start_time AT TIME ZONE v_user_tz)
    END),
    COALESCE(SUM(EXTRACT(EPOCH FROM (e.end_time - e.start_time))::INT / 60), 0),
    NOW()
  FROM events e
  WHERE e.user_id = p_user_id
    AND DATE(e.start_time AT TIME ZONE v_user_tz) >= v_month_start
    AND DATE(e.start_time AT TIME ZONE v_user_tz) <= v_month_end
  ON CONFLICT (user_id, month) DO UPDATE SET
    total_online = EXCLUDED.total_online,
    total_in_person = EXCLUDED.total_in_person,
    total_free = EXCLUDED.total_free,
    total_booked = EXCLUDED.total_booked,
    total_cancelled = EXCLUDED.total_cancelled,
    total_not_started = EXCLUDED.total_not_started,
    total_in_progress = EXCLUDED.total_in_progress,
    total_completed = EXCLUDED.total_completed,
    available_days = EXCLUDED.available_days,
    available_saturdays = EXCLUDED.available_saturdays,
    available_sundays = EXCLUDED.available_sundays,
    free_time_minutes = EXCLUDED.free_time_minutes,
    updated_at = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql;

-- Function: get_pending_notifications
-- Returns all notifications ready to send
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
BEGIN
  RETURN QUERY
  SELECT
    nq.id,
    nq.user_id,
    nq.event_id,
    nq.notify_at,
    nq.type,
    nq.title,
    nq.body,
    nq.sound_key
  FROM notification_queue nq
  WHERE nq.notify_at <= NOW()
    AND nq.sent = FALSE
  ORDER BY nq.notify_at ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER: Auto-update updated_at timestamp
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- CRON JOB: Refresh monthly summaries every 5 minutes
-- ═══════════════════════════════════════════════════════════════════════════════

-- Note: Run this after creating the extension above
-- SELECT cron.schedule('refresh-monthly-summaries', '*/5 * * * *', 
--   'SELECT refresh_monthly_summary(id, NOW()::DATE) FROM users');
