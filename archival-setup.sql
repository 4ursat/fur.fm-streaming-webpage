-- ═══════════════════════════════════════════════════════════════════════════
-- Fur FM — Archival Room Schema
-- Run in: Supabase Dashboard → SQL Editor → New Query
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Tracks library ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tracks (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT        NOT NULL,
  filename     TEXT        NOT NULL,
  storage_path TEXT        NOT NULL,
  url          TEXT        NOT NULL,
  duration     FLOAT,
  uploaded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Embedded ID3/metadata tags read from uploaded files (title, artist, album, cover art)
ALTER TABLE tracks ADD COLUMN IF NOT EXISTS tag_artist       TEXT;
ALTER TABLE tracks ADD COLUMN IF NOT EXISTS tag_album        TEXT;
ALTER TABLE tracks ADD COLUMN IF NOT EXISTS tag_picture_url  TEXT;

-- Link tracks to a specific session so the archive can be prepped per-session
ALTER TABLE tracks ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES sessions(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_tracks_session_id ON tracks(session_id);

-- Persist the archive collection title per-session (e.g. "Alan Lomax Field Recordings, 1967")
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS archive_header TEXT;

-- Session Type: 'archival' sessions get an attached archive (tracks/image/notes);
-- 'live' sessions are a placeholder for future live-artist-performance support.
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'archival'
  CHECK (type IN ('archival', 'live'));
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS archive_image_url TEXT;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS archive_notes     TEXT;

ALTER TABLE tracks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='tracks' AND policyname='Public can read tracks'
  ) THEN
    CREATE POLICY "Public can read tracks"
      ON tracks FOR SELECT TO anon, authenticated USING (true);
  END IF;
END $$;

-- ── Now Playing (single row, always upserted) ─────────────────────────────
CREATE TABLE IF NOT EXISTS now_playing (
  id             UUID        PRIMARY KEY,
  track_title    TEXT,
  artist         TEXT,
  archive_source TEXT,
  context_notes  TEXT,
  image_url      TEXT,
  translation    TEXT,
  audio_url      TEXT,
  playhead_pos   FLOAT       NOT NULL DEFAULT 0,
  duration       FLOAT       NOT NULL DEFAULT 0,
  is_playing     BOOLEAN     NOT NULL DEFAULT FALSE,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed the single control row
INSERT INTO now_playing (id)
VALUES ('00000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE now_playing ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='now_playing' AND policyname='Public can read now_playing'
  ) THEN
    CREATE POLICY "Public can read now_playing"
      ON now_playing FOR SELECT TO anon, authenticated USING (true);
  END IF;
END $$;

-- Add archive_header column (safe to run if column already exists)
ALTER TABLE now_playing ADD COLUMN IF NOT EXISTS archive_header TEXT;

-- Enable Realtime so listeners get instant updates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'now_playing'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE now_playing;
  END IF;
END $$;

-- ── RLS policies for admin (anon key) write access ───────────────────────────
-- The admin panel uses the anon key. RLS must explicitly permit writes.
-- (admin is password-gated at the JS level, so open anon write is acceptable)

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sessions' AND policyname='Anon full access on sessions') THEN
    CREATE POLICY "Anon full access on sessions" ON sessions FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='tracks' AND policyname='Anon can write tracks') THEN
    CREATE POLICY "Anon can write tracks" ON tracks FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='now_playing' AND policyname='Anon can update now_playing') THEN
    CREATE POLICY "Anon can update now_playing" ON now_playing FOR ALL TO anon USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ── Storage buckets ───────────────────────────────────────────────────────
-- Create via Supabase Dashboard → Storage → New Bucket:
--   Name: fur-fm-tracks   Public: YES
--   Name: fur-fm-images   Public: YES
--
-- Or run these (requires pg_storage extension):
-- SELECT storage.create_bucket('fur-fm-tracks', '{"public": true}');
-- SELECT storage.create_bucket('fur-fm-images', '{"public": true}');
