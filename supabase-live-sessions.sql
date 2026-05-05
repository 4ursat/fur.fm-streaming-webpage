-- ═══════════════════════════════════════════════════════════════════════════
-- Fur FM — Live Sessions Table
-- Run this in: Supabase Dashboard > SQL Editor > New Query
-- (Separate from supabase-setup.sql which is already applied)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS live_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mux_stream_id   TEXT UNIQUE NOT NULL,
  mux_playback_id TEXT NOT NULL,
  mux_asset_id    TEXT,            -- VOD asset ID, set when stream ends
  vod_playback_id TEXT,            -- VOD playback ID for archived replays
  status          TEXT NOT NULL DEFAULT 'idle',  -- 'idle' | 'active' | 'ended'
  started_at      TIMESTAMPTZ,
  ended_at        TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE live_sessions ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read session history (for archive display)
CREATE POLICY "Authenticated users can read live sessions"
  ON live_sessions FOR SELECT
  TO authenticated
  USING (true);

-- Only the service role (server) can write — no client-side inserts
-- (The server uses SUPABASE_SERVICE_KEY which bypasses RLS)
