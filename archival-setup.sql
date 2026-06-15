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

-- Enable Realtime so listeners get instant updates
ALTER PUBLICATION supabase_realtime ADD TABLE now_playing;

-- ── Storage buckets ───────────────────────────────────────────────────────
-- Create via Supabase Dashboard → Storage → New Bucket:
--   Name: fur-fm-tracks   Public: YES
--   Name: fur-fm-images   Public: YES
--
-- Or run these (requires pg_storage extension):
-- SELECT storage.create_bucket('fur-fm-tracks', '{"public": true}');
-- SELECT storage.create_bucket('fur-fm-images', '{"public": true}');
