// AudioWorklet processor for granular drone synthesis.
// Reads from a ring buffer fed by the oscillators, scatters overlapping
// grains with Hanning envelopes, subtle pitch scatter, and stereo panning.
// Runs in a dedicated audio thread — no main-thread JS involved.

class GranularDroneProcessor extends AudioWorkletProcessor {
  constructor() {
    super();

    // Ring buffer — 2.5 seconds of audio at whatever sample rate the context uses
    this._bSz = Math.ceil(sampleRate * 2.5);
    this._buf = new Float32Array(this._bSz);
    this._wp  = 0; // write pointer

    this._grains = [];

    // LCG seed — wall-clock bucket (~1s resolution) keeps statistical
    // character broadly consistent across listeners in the same slot
    this._seed = (Date.now() >>> 10) >>> 0;

    // Spawn first grain after ~60ms (let ring buffer warm up a little)
    this._spawnCtr  = 0;
    this._nextSpawn = (sampleRate * 0.06) | 0;
  }

  // Marsaglia LCG — fast, good enough for grain scheduling
  _rng() {
    this._seed = (Math.imul(this._seed | 0, 1664525) + 1013904223) >>> 0;
    return this._seed / 0x100000000; // 0–1
  }
  _rf(lo, hi) { return lo + this._rng() * (hi - lo); }
  _ri(lo, hi) { return (lo + this._rng() * (hi - lo)) | 0; }

  process(inputs, outputs) {
    const inCh = inputs[0]?.[0];
    const outL = outputs[0]?.[0];
    const outR = outputs[0]?.[1];
    if (!outL) return true;

    outL.fill(0);
    if (outR) outR.fill(0);

    // ── 1. Write input into ring buffer ─────────────────────────────────
    if (inCh) {
      for (let i = 0, bSz = this._bSz; i < 128; i++) {
        this._buf[this._wp] = inCh[i];
        if (++this._wp >= bSz) this._wp = 0;
      }
    }

    // ── 2. Maybe spawn a grain ───────────────────────────────────────────
    this._spawnCtr += 128;
    if (this._spawnCtr >= this._nextSpawn && this._grains.length < 20) {
      this._spawnCtr = 0;
      // Inter-onset interval: 50–110 ms → gives 9–20 grains/sec, 2–4 overlapping
      this._nextSpawn = this._ri(
        (sampleRate * 0.050) | 0,
        (sampleRate * 0.110) | 0
      );

      const durSamp = (this._rf(0.070, 0.200) * sampleRate) | 0; // 70–200 ms
      // Look back 40–320 ms into the buffer for the grain start position
      const lkb     = (this._rf(0.040, 0.320) * sampleRate) | 0;
      const startRp = ((this._wp - lkb) + this._bSz) % this._bSz;
      const pan     = this._rf(-0.24, 0.24); // constant-power pan

      this._grains.push({
        rp:  startRp,                         // read pointer (float)
        len: durSamp,                          // grain length in samples
        pos: 0,                                // sample within grain
        rt:  this._rf(0.9986, 1.0014),         // playback rate — ±0.07% pitch scatter
        amp: this._rf(0.55, 1.0),
        pL:  Math.sqrt(0.5 - pan * 0.5),      // constant-power left
        pR:  Math.sqrt(0.5 + pan * 0.5),      // constant-power right
      });
    }

    // ── 3. Process grains into output ────────────────────────────────────
    const buf = this._buf;
    const bSz = this._bSz;
    let gi = 0;

    while (gi < this._grains.length) {
      const g  = this._grains[gi];
      const pL = g.pL, pR = g.pR, amp = g.amp, len = g.len;
      let   done = false;

      for (let i = 0; i < 128; i++) {
        if (g.pos >= len) { done = true; break; }

        // Hanning window — smooth fade-in and fade-out, no clicks
        const env = 0.5 * (1.0 - Math.cos(6.283185307 * g.pos / len));

        // Linear interpolation for sub-sample read position
        const rp = g.rp;
        const i0 = (rp | 0) % bSz;
        const i1 = (i0 + 1) % bSz;
        const fr = rp - (rp | 0);
        const s  = (buf[i0] + fr * (buf[i1] - buf[i0])) * env * amp;

        outL[i] += s * pL;
        if (outR) outR[i] += s * pR;

        g.rp += g.rt;
        if (g.rp >= bSz) g.rp -= bSz;
        g.pos++;
      }

      if (done) this._grains.splice(gi, 1);
      else gi++;
    }

    return true; // keep processor alive
  }
}

registerProcessor('granular-drone', GranularDroneProcessor);
