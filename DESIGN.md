# FUR·FM Stream Page Design Specification

## Current Working Design (base: b401e7a)

### Layout Overview
Fullscreen stage with fixed corner overlays + center elements.

---

## Color Palette
- **Background**: `#0d1c15` (dark forest)
- **Primary Text**: `#f0e0a8` (cream/tan)
- **Secondary Text**: `#c89020` (gold)
- **Accent**: `#e07828` (orange - logo dot, progress)
- **Error**: `#e05030` (red)
- **Overlay BG**: `rgba(13,28,21,0.52)` - `rgba(13,28,21,0.95)` (varying opacity)
- **Border**: `rgba(200,144,32,0.1)` to `rgba(200,144,32,0.3)` (subtle gold)

---

## Typography
- **Font Family**: `'Courier New', Courier, monospace` (body)
- **Serif Font**: `'Cormorant Garamond', Georgia, serif` (headers, titles)
- **Session Title**: 1.1rem, Garamond, italic, weight 300
- **Logo Name**: 1.15rem, bold, letter-spacing 0.09em
- **Chat Sender**: 0.7rem, gold, letter-spacing 0.06em
- **Chat Text**: 0.84rem, cream, line-height 1.45
- **Now Playing**: 0.95rem bold (track), 0.72rem (meta)

---

## Layout Sections

### 1. Stage (Container)
- `position: fixed; inset: 0; overflow: hidden`
- Contains VDO.ninja iframe (fullscreen video)
- Z-index foundation for all overlays

### 2. Top-Left Overlay (Logo)
- **Position**: `top: 2rem; left: 1.8rem`
- **Content**:
  - SVG rings (3 circles, animated when live)
  - Text: "FUR·FM" with orange dot separator
- **Animation**: Ring pulse on live (ring-broadcast keyframe)
- **Z-index**: 10

### 3. Top-Right Overlay (Session Info)
- **Position**: `top: 2rem; right: 1.8rem; text-align: right; max-width: 46%`
- **Content**:
  - Session title (e.g., "Coffee at Oops")
  - Timer (HH:MM:SS upcount)
- **Typography**: Garamond italic for title, monospace for timer
- **Z-index**: 10

### 4. Now Playing Bar (Top Center)
- **Position**: `position: absolute; top: 2rem; left: 50%; transform: translateX(-50%)`
- **Width**: `min(380px, 42vw)`
- **Visibility**: Hidden by default, shows when `.visible` class added
- **Content**:
  - Track line: "Track Title — Artist"
  - Meta line: "Archive Source"
  - Translation (if available)
  - Progress row (when playing):
    - Progress bar with fill
    - Time display "0:00 / 0:00"
- **Z-index**: 9
- **Background**: None (transparent, overlays video)

### 5. Bottom-Left Overlay (Listener Count + Leave)
- **Position**: `bottom: 1.8rem; left: 1.8rem`
- **Display**: flex, column, gap 0.45rem
- **Content**:
  - Listener count text (italic, gold)
  - "leave quietly" button (uppercase, small)
- **Button Behavior**: Pointer-events: all, hover color change
- **Z-index**: 10

### 6. Bottom-Right Overlay (Chat)
- **Position**: `bottom: 1.8rem; right: 1.8rem`
- **Width**: `min(250px, calc(44% - 1.8rem))`
- **Pointer-events**: all
- **Display**: flex, column
- **Content**:
  - Fullscreen button (top, right-aligned, 0.6rem)
  - Messages container (scrollable, max-height 180px)
  - Chat input area (sticky bottom)
- **Z-index**: 10

#### Chat Messages
- **Scrollbar**: Hidden
- **Padding**: 0.65rem 0.75rem 0.55rem
- **Gap**: 0.55rem between messages
- **Background**: `rgba(13,28,21,0.52)` with blur
- **Each Message**:
  - Sender name (0.7rem, gold)
  - Message text (0.84rem, cream, word-break: break-word)
  - System messages: italic, dimmed

#### Chat Input Area
- **Background**: `rgba(13,28,21,0.62)` with blur
- **Padding**: 0.42rem 0.75rem 0.48rem
- **Border-top**: 1px solid `rgba(200,144,32,0.1)`
- **Layout**: flex, align-center, gap 0.5rem
- **Input**:
  - Flex: 1
  - Border-bottom only
  - Placeholder: "whisper..."
  - Font: italic 0.8rem
- **Send Button**:
  - Icon: "→"
  - Color: gold, hover cream
  - Cursor: pointer

---

## Responsive Breakpoints

### Mobile (max-width: 600px)
- All overlays repositioned closer together
- Reduced font sizes
- Chat max-height: 80px
- Adjusted spacing and padding

### Landscape Short Screen (max-height: 480px and landscape)
- Bottom overlays moved slightly up

---

## Interactive Elements

### Chat Send
- Click send button or Enter to submit
- Message shows in local chat immediately
- Sent to Supabase `chat_messages` table
- Realtime listener gets notification via postgres_changes

### Leave Button
- Signs out user
- Redirects to index.html

### Fullscreen Button
- Toggles fullscreen mode
- Text changes between "⤢ fullscreen" / "↙ exit fullscreen"

### Logo Animation
- When stream is live: rings pulse in sequence (0.5s, 1s delays)
- Ring opacity animates 0.04 → 0.85 → 0.04

---

## Data Flow

### Now Playing (np-bar)
- Loaded from `now_playing` table (fixed ID)
- Shows when `track_title` OR `artist` is present
- Updates via Supabase realtime

### Chat
- Loads last 60 messages on mount
- New messages via postgres_changes INSERT
- Local echo prevention (tracks sent message IDs)

### Listener Count
- Updated via Supabase Presence
- Shows count of active users in channel

### Session Timer
- Starts from `stream_started_at` timestamp
- Increments every 100ms
- Only broadcaster can see timer update button (hash-based)

---

## States

### Stream Idle
- Standby screen visible (full viewport overlay)
- Text: "FUR · FM" / "not currently live"

### Stream Active
- Video plays fullscreen via VDO.ninja iframe
- Overlays appear on top
- Chat is active and receiving messages
- Now playing bar visible if track data exists

### Audio Interaction Gate
- Audio won't autoplay until user clicks anywhere
- Once clicked, audio is unblocked for session

---

## Animations & Transitions

- **Ring pulse**: 2.4s ease-in-out, staggered (0s, 0.5s, 1s)
- **Chat message entry**: opacity 0→1, y 5→0, 0.3s power2.out
- **Hover colors**: 0.2s transition

---

## Notes for Redesign

This is the working baseline. When redesigning to Instagram style:
- Maintain color palette
- Keep chat realtime functionality
- Keep listener count & presence
- Integrate now-playing bar into new layout
- Preserve all interactive behaviors
- Test on mobile (max-width: 600px)
