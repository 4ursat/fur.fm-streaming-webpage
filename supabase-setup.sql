-- ═══════════════════════════════════════════════════════════════════════════
-- Fur FM — Supabase Database Setup
-- Run this in: Supabase Dashboard > SQL Editor > New Query
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Users ─────────────────────────────────────────────────────────────────
-- Mirrors auth.users with extra profile fields.
-- auth_id is the Supabase auth UUID; email OTP creates the auth record first.

CREATE TABLE IF NOT EXISTS users (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id    UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT UNIQUE NOT NULL,
  username   TEXT,
  verified   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Chat messages ──────────────────────────────────────────────────────────
-- Stores all chat per session. session_id is an ISO date string (YYYY-MM-DD).
-- username is denormalized so real-time payloads carry the display name.

CREATE TABLE IF NOT EXISTS chat_messages (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  username   TEXT NOT NULL DEFAULT 'Listener',
  content    TEXT NOT NULL,
  session_id TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_session
  ON chat_messages (session_id, created_at);

-- ══════════════════════════════════════════════════════════════════════════
-- Row Level Security
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- ── users policies ────────────────────────────────────────────────────────
-- Any verified (authenticated) user can read all profiles (needed for chat display names).
CREATE POLICY "Authenticated users can read profiles"
  ON users FOR SELECT
  TO authenticated
  USING (true);

-- A user can only insert their own profile row.
CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (auth_id = auth.uid());

-- A user can only update their own profile row.
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth_id = auth.uid());

-- ── chat_messages policies ────────────────────────────────────────────────
-- Any authenticated user can read all chat messages.
CREATE POLICY "Authenticated users can read chat"
  ON chat_messages FOR SELECT
  TO authenticated
  USING (true);

-- Any authenticated user can send a message.
CREATE POLICY "Authenticated users can insert chat"
  ON chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ══════════════════════════════════════════════════════════════════════════
-- Enable Realtime for chat (run once in SQL editor)
-- ══════════════════════════════════════════════════════════════════════════
-- Supabase Dashboard > Database > Replication > Tables
-- Add: chat_messages
--
-- Or run this directly:
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
