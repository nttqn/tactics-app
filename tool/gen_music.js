// Synthesises the menu theme: a short medieval dance in D Dorian, 6/8,
// for flute, lute, drone and hand drum. It loops seamlessly: every note
// tail and the reverb wrap around the end of the buffer.
//
// Usage: node tool/gen_music.js <out.wav>
// Convert to assets/audio/m_title.mp3 with ffmpeg (libmp3lame, ~128 kbit/s).
const fs = require('fs');

const SR = 44100;
const EIGHTH = 0.2; // seconds; a dotted quarter is 100 bpm
const BAR = 6 * EIGHTH;
const BARS = 32;
const LEN = Math.round(BARS * BAR * SR);
const L = new Float32Array(LEN);
const R = new Float32Array(LEN);

// Deterministic noise so every run produces the same file.
let seed = 20261011;
const rand = () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

const NOTE = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
const hz = (name) => {
  const semis = NOTE[name[0]] + 12 * (Number(name.slice(1)) + 1);
  return 440 * 2 ** ((semis - 69) / 12);
};

/** Mixes one sample into the loop, wrapping past the end. */
const put = (i, v, pan) => {
  const j = ((i % LEN) + LEN) % LEN;
  L[j] += v * Math.cos((pan + 1) * Math.PI / 4);
  R[j] += v * Math.sin((pan + 1) * Math.PI / 4);
};

/** Plucked string (Karplus-Strong): the lute. */
function pluck(freq, start, dur, amp, pan) {
  const n = Math.round(SR / freq);
  const line = new Float32Array(n);
  let prev = 0;
  for (let i = 0; i < n; i++) {
    // Soften the excitation so the pluck is warm rather than harsh.
    prev = 0.6 * prev + 0.4 * (rand() * 2 - 1);
    line[i] = prev;
  }
  const total = Math.round(dur * SR);
  const fade = Math.round(0.04 * SR);
  const begin = Math.round(start * SR);
  let k = 0;
  for (let i = 0; i < total; i++) {
    const next = (k + 1) % n;
    const out = line[k];
    line[k] = 0.4985 * (line[k] + line[next]);
    k = next;
    const env = i > total - fade ? (total - i) / fade : 1;
    put(begin + i, out * amp * env, pan);
  }
}

/** Soft wind tone with vibrato and a little breath: the flute. */
function flute(freq, start, dur, amp, pan) {
  const total = Math.round((dur + 0.08) * SR);
  const begin = Math.round(start * SR);
  let phase = 0;
  let breath = 0;
  for (let i = 0; i < total; i++) {
    const t = i / SR;
    const vib = t > 0.18 ? 0.004 * Math.sin(2 * Math.PI * 5.2 * t) : 0;
    phase += (2 * Math.PI * freq * (1 + vib)) / SR;
    const attack = Math.min(1, t / 0.045);
    const release = t > dur ? Math.max(0, 1 - (t - dur) / 0.08) : 1;
    breath = 0.85 * breath + 0.15 * (rand() * 2 - 1);
    const tone =
      Math.sin(phase) +
      0.28 * Math.sin(2 * phase) +
      0.09 * Math.sin(3 * phase) +
      0.25 * breath * attack;
    put(begin + i, tone * amp * attack * release, pan);
  }
}

/** Hand drum: a low thump or a higher tap. */
function drum(start, amp, low) {
  const total = Math.round((low ? 0.4 : 0.16) * SR);
  const begin = Math.round(start * SR);
  let phase = 0;
  for (let i = 0; i < total; i++) {
    const t = i / SR;
    const f = low ? 58 + 70 * Math.exp(-t * 30) : 170 + 60 * Math.exp(-t * 40);
    phase += (2 * Math.PI * f) / SR;
    const env = Math.exp(-t * (low ? 9 : 26));
    put(begin + i, Math.sin(phase) * amp * env, low ? 0 : 0.15);
  }
}

/** Tambourine jingle: a short burst of bright noise. */
function jingle(start, amp) {
  const total = Math.round(0.09 * SR);
  const begin = Math.round(start * SR);
  let last = 0;
  for (let i = 0; i < total; i++) {
    const x = rand() * 2 - 1;
    const bright = x - last; // crude high-pass
    last = x;
    put(begin + i, bright * amp * Math.exp((-i / SR) * 45), -0.3);
  }
}

// ---- The tune --------------------------------------------------------------
// Each bar is a list of [note, length in eighths]; every bar adds up to 6.
const A = [
  [['D5', 2], ['E5', 1], ['F5', 2], ['G5', 1]],
  [['A5', 3], ['G5', 1], ['F5', 1], ['E5', 1]],
  [['F5', 2], ['E5', 1], ['D5', 2], ['C5', 1]],
  [['D5', 3], ['A4', 3]],
  [['D5', 2], ['E5', 1], ['F5', 2], ['G5', 1]],
  [['A5', 2], ['C6', 1], ['B5', 2], ['A5', 1]],
  [['G5', 1], ['F5', 1], ['E5', 1], ['F5', 2], ['E5', 1]],
  [['D5', 6]],
];
const B = [
  [['A5', 2], ['A5', 1], ['C6', 2], ['A5', 1]],
  [['G5', 2], ['F5', 1], ['G5', 3]],
  [['F5', 2], ['F5', 1], ['A5', 2], ['F5', 1]],
  [['E5', 2], ['D5', 1], ['E5', 3]],
  [['A5', 2], ['B5', 1], ['C6', 2], ['D6', 1]],
  [['C6', 1], ['B5', 1], ['A5', 1], ['G5', 2], ['E5', 1]],
  [['F5', 1], ['E5', 1], ['D5', 1], ['E5', 2], ['C5', 1]],
  [['D5', 6]],
];
// Open fifths under each bar: [root, fifth, octave].
const FIFTHS = {
  D: ['D3', 'A3', 'D4'],
  C: ['C3', 'G3', 'C4'],
  F: ['F3', 'C4', 'F4'],
  A: ['A2', 'E3', 'A3'],
};
const HARMONY_A = ['D', 'D', 'C', 'D', 'D', 'A', 'C', 'D'];
const HARMONY_B = ['A', 'C', 'F', 'A', 'F', 'C', 'A', 'D'];

const down = (name) => name[0] + (Number(name.slice(1)) - 1);

// Four eight-bar strains: lute alone, flute joins, then the second strain
// twice, the last time with the lute doubling the tune an octave below.
const strains = [
  { tune: A, harmony: HARMONY_A, flute: false, lute: true },
  { tune: A, harmony: HARMONY_A, flute: true, lute: false },
  { tune: B, harmony: HARMONY_B, flute: true, lute: false },
  { tune: B, harmony: HARMONY_B, flute: true, lute: true },
];

strains.forEach((strain, s) => {
  strain.tune.forEach((bar, b) => {
    const barStart = (s * 8 + b) * BAR;
    let at = barStart;
    for (const [note, eighths] of bar) {
      const dur = eighths * EIGHTH;
      if (strain.flute) flute(hz(note), at, dur * 0.92, 0.2, 0.3);
      if (strain.lute) {
        const voice = strain.flute ? down(note) : note;
        pluck(hz(voice), at, Math.max(dur, 0.5) + 0.5, strain.flute ? 0.3 : 0.5, -0.35);
      }
      at += dur;
    }
    // Lute accompaniment: root on the beat, then fifth and octave.
    const [root, fifth, octave] = FIFTHS[strain.harmony[b]];
    const pattern = [root, fifth, octave, root, octave, fifth];
    pattern.forEach((note, i) => {
      const strong = i === 0 || i === 3;
      pluck(hz(note), barStart + i * EIGHTH, 0.9, strong ? 0.42 : 0.26, -0.15);
    });
    // Drum: thump on one, tap on four, jingles on the off-beats.
    drum(barStart, 0.55, true);
    drum(barStart + 3 * EIGHTH, 0.3, false);
    if (s > 0) {
      jingle(barStart + 2 * EIGHTH, 0.1);
      jingle(barStart + 5 * EIGHTH, 0.1);
    }
  });
});

// Drone on D and A, like a hurdy-gurdy. Frequencies are nudged so each
// completes a whole number of cycles in the loop and joins up cleanly.
const loopSeconds = LEN / SR;
for (const [name, level] of [['D2', 1], ['A2', 0.7], ['D3', 0.45]]) {
  for (const detune of [1, 1.003]) {
    const f = Math.round(hz(name) * detune * loopSeconds) / loopSeconds;
    for (let i = 0; i < LEN; i++) {
      const t = i / SR;
      let v = 0;
      for (let k = 1; k <= 7; k++) {
        v += Math.sin(2 * Math.PI * f * k * t) / k ** 1.5;
      }
      // Swells gently once per bar, like a turning wheel.
      const swell = 1 + 0.18 * Math.sin((2 * Math.PI * t) / BAR - Math.PI / 2);
      put(i, v * 0.028 * level * swell, detune === 1 ? -0.2 : 0.2);
    }
  }
}

// ---- Reverb (four combs and two all-passes per channel) -------------------
function reverb(dry, offsetMs) {
  const combs = [29.7, 37.1, 41.1, 43.7].map((ms) => ({
    buf: new Float32Array(Math.round(((ms + offsetMs) / 1000) * SR)),
    i: 0,
  }));
  const allpasses = [5.0, 1.7].map((ms) => ({
    buf: new Float32Array(Math.round(((ms + offsetMs / 3) / 1000) * SR)),
    i: 0,
  }));
  const wet = new Float32Array(LEN);
  // Two passes over the loop: the second starts with the first one's tail
  // already ringing, so the reverb also wraps around the loop point.
  for (let pass = 0; pass < 2; pass++) {
    for (let n = 0; n < LEN; n++) {
      let sum = 0;
      for (const c of combs) {
        const out = c.buf[c.i];
        c.buf[c.i] = dry[n] + out * 0.8;
        c.i = (c.i + 1) % c.buf.length;
        sum += out;
      }
      let x = sum / combs.length;
      for (const a of allpasses) {
        const delayed = a.buf[a.i];
        const y = -0.7 * x + delayed;
        a.buf[a.i] = x + 0.7 * y;
        a.i = (a.i + 1) % a.buf.length;
        x = y;
      }
      wet[n] = x;
    }
  }
  return wet;
}

const wetL = reverb(L, 0);
const wetR = reverb(R, 0.6);
let peak = 0;
let sumSquares = 0;
for (let i = 0; i < LEN; i++) {
  L[i] += 0.24 * wetL[i];
  R[i] += 0.24 * wetR[i];
  peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
  sumSquares += L[i] * L[i] + R[i] * R[i];
}
// Peak well below full scale so the theme sits at the same loudness as the
// in-battle tracks (about -23 dB mean) instead of jumping out.
const gain = 0.45 / peak;

// ---- 16-bit stereo WAV -----------------------------------------------------
const data = Buffer.alloc(LEN * 4);
for (let i = 0; i < LEN; i++) {
  data.writeInt16LE(Math.round(L[i] * gain * 32767), i * 4);
  data.writeInt16LE(Math.round(R[i] * gain * 32767), i * 4 + 2);
}
const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + data.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20); // PCM
header.writeUInt16LE(2, 22); // stereo
header.writeUInt32LE(SR, 24);
header.writeUInt32LE(SR * 4, 28);
header.writeUInt16LE(4, 32);
header.writeUInt16LE(16, 34);
header.write('data', 36);
header.writeUInt32LE(data.length, 40);

const out = process.argv[2] || 'm_title.wav';
fs.writeFileSync(out, Buffer.concat([header, data]));
const rms = Math.sqrt(sumSquares / (2 * LEN)) * gain;
console.log(
  `${out}: ${loopSeconds.toFixed(1)}s, peak before gain ${peak.toFixed(2)}, ` +
    `RMS ${(20 * Math.log10(rms)).toFixed(1)} dBFS`,
);
