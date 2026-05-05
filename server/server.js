require('dotenv').config();
const express   = require('express');
const Mux       = require('@mux/mux-node');
const { createClient } = require('@supabase/supabase-js');
const fs        = require('fs');
const path      = require('path');

const {
  MUX_TOKEN_ID,
  MUX_TOKEN_SECRET,
  MUX_WEBHOOK_SECRET,
  MUX_LIVE_STREAM_ID,
  SUPABASE_URL,
  SUPABASE_SERVICE_KEY,
  PORT = 3000,
} = process.env;

const muxClient = new Mux({ tokenId: MUX_TOKEN_ID, tokenSecret: MUX_TOKEN_SECRET });
const supabase  = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
const app       = express();

// ── Serve the website files from the parent directory ────────────────────────
app.use(express.static(path.join(__dirname, '..')));

// ── CORS — allow the frontend (file:// or any origin) ────────────────────────
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin',  '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// Raw body needed for Mux webhook signature verification
app.use('/webhooks/mux', express.raw({ type: '*/*' }));
app.use(express.json());

// ── State ─────────────────────────────────────────────────────────────────────
const streamState = {
  streamId:   null,
  playbackId: null,
  streamKey:  null,
  rtmpUrl:    'rtmps://global-live.mux.com:443/app',
  status:     'idle',   // 'idle' | 'active'
};

// SSE clients waiting for live/idle events
const sseClients = new Set();

function broadcast(data) {
  sseClients.forEach(send => send(data));
}

// ── Mux init ──────────────────────────────────────────────────────────────────
async function initStream() {
  if (MUX_LIVE_STREAM_ID) {
    // Reuse existing stream — stream key stays constant so OBS config never changes
    const stream = await muxClient.video.liveStreams.retrieve(MUX_LIVE_STREAM_ID);
    streamState.streamId   = stream.id;
    streamState.playbackId = stream.playback_ids?.[0]?.id;
    streamState.streamKey  = stream.stream_key;
    streamState.status     = stream.status === 'active' ? 'active' : 'idle';
    console.log(`[mux] Using live stream: ${stream.id}`);
  } else {
    // First run — create stream and save the ID to .env
    const stream = await muxClient.video.liveStreams.create({
      playback_policy:    ['public'],
      new_asset_settings: { playback_policy: ['public'] }, // auto-archive as VOD
      reduced_latency:    true,
    });
    streamState.streamId   = stream.id;
    streamState.playbackId = stream.playback_ids?.[0]?.id;
    streamState.streamKey  = stream.stream_key;
    streamState.status     = 'idle';

    // Persist stream ID so it survives restarts
    const envPath    = path.join(__dirname, '.env');
    const envContent = fs.readFileSync(envPath, 'utf8');
    if (!envContent.includes('MUX_LIVE_STREAM_ID=')) {
      fs.appendFileSync(envPath, `\nMUX_LIVE_STREAM_ID=${stream.id}\n`);
    } else {
      fs.writeFileSync(envPath, envContent.replace(/MUX_LIVE_STREAM_ID=.*/, `MUX_LIVE_STREAM_ID=${stream.id}`));
    }
    console.log('[mux] Created new live stream — stream ID saved to .env');
  }

  // Keep Supabase live_sessions in sync
  await supabase.from('live_sessions').upsert(
    { mux_stream_id: streamState.streamId, mux_playback_id: streamState.playbackId, status: streamState.status },
    { onConflict: 'mux_stream_id' }
  );
}

// ── API: stream info ──────────────────────────────────────────────────────────
// Frontend calls this once on page load to get the playback ID and current status.
app.get('/api/stream-info', (_req, res) => {
  res.json({
    playbackId: streamState.playbackId,
    streamKey:  streamState.streamKey,
    rtmpUrl:    streamState.rtmpUrl,
    status:     streamState.status,
  });
});

// ── SSE: real-time stream status ──────────────────────────────────────────────
// Frontend connects here to receive live/idle events without polling.
app.get('/api/stream-events', (req, res) => {
  res.writeHead(200, {
    'Content-Type':  'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection':    'keep-alive',
  });

  const send = (data) => res.write(`data: ${JSON.stringify(data)}\n\n`);

  // Push current state immediately on connect
  send({ type: 'status', status: streamState.status, playbackId: streamState.playbackId });

  sseClients.add(send);
  req.on('close', () => sseClients.delete(send));
});

// ── Webhooks: Mux events ──────────────────────────────────────────────────────
app.post('/webhooks/mux', async (req, res) => {
  // Verify signature if secret is configured
  if (MUX_WEBHOOK_SECRET) {
    try {
      muxClient.webhooks.verifySignature(req.body, req.headers, MUX_WEBHOOK_SECRET);
    } catch {
      return res.status(401).send('Invalid webhook signature');
    }
  }

  const event = JSON.parse(req.body.toString());
  const { type, data } = event;
  console.log(`[webhook] ${type}`);

  if (type === 'video.live_stream.active') {
    streamState.status = 'active';
    broadcast({ type: 'status', status: 'active', playbackId: streamState.playbackId });
    await supabase.from('live_sessions')
      .update({ status: 'active', started_at: new Date().toISOString() })
      .eq('mux_stream_id', data.id);
  }

  if (type === 'video.live_stream.idle') {
    streamState.status = 'idle';
    broadcast({ type: 'status', status: 'idle' });
    await supabase.from('live_sessions')
      .update({ status: 'ended', ended_at: new Date().toISOString() })
      .eq('mux_stream_id', data.id);
  }

  // Mux auto-creates a VOD asset when the stream ends — save it for archives
  if (type === 'video.asset.ready' && data.live_stream_id === streamState.streamId) {
    const assetId    = data.id;
    const vodId      = data.playback_ids?.[0]?.id;
    await supabase.from('live_sessions')
      .update({ mux_asset_id: assetId, vod_playback_id: vodId })
      .eq('mux_stream_id', streamState.streamId);
    console.log(`[mux] VOD archived — playback: https://stream.mux.com/${vodId}.m3u8`);
  }

  res.sendStatus(200);
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, async () => {
  console.log('\n══════════════════════════════════════════');
  console.log('  Fur FM Server  →  http://localhost:' + PORT);
  console.log('══════════════════════════════════════════');

  try {
    await initStream();
    console.log('  OBS Server   →  ' + streamState.rtmpUrl);
    console.log('  Stream Key   →  ' + streamState.streamKey);
    console.log('  Playback     →  https://stream.mux.com/' + streamState.playbackId + '.m3u8');
  } catch (err) {
    console.warn('  [mux] Streaming unavailable:', err.message);
    console.warn('  [mux] Site and auth still work — upgrade Mux plan to enable video.');
  }

  console.log('══════════════════════════════════════════\n');
});
