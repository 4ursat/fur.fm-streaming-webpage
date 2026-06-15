-- ═══════════════════════════════════════════════════════════════════════════
-- Fur FM — Admin Dashboard Schema
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- Safe to run multiple times (uses IF NOT EXISTS / IF NOT EXISTS guards)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Sessions table ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title            TEXT,
  date             DATE,
  time             TEXT,
  description      TEXT,
  stream_started_at TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Allow public (anon) reads so index.html can show upcoming session info
-- without requiring auth.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'sessions' AND policyname = 'Public can read sessions'
  ) THEN
    CREATE POLICY "Public can read sessions"
      ON sessions FOR SELECT TO anon, authenticated USING (true);
  END IF;
END $$;

-- Allow service role (admin panel) full write access — service role bypasses
-- RLS by default, so no explicit policy needed for that.

-- Enable Realtime on sessions so timer syncs across all viewers
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;

-- ── Past sessions table ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS past_sessions (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT        NOT NULL,
  session_date DATE,
  music_links  JSONB       NOT NULL DEFAULT '[]'::jsonb,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE past_sessions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'past_sessions' AND policyname = 'Public can read past sessions'
  ) THEN
    CREATE POLICY "Public can read past sessions"
      ON past_sessions FOR SELECT TO anon, authenticated USING (true);
  END IF;
END $$;
