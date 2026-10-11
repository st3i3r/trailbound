// WebAudio procedural SFX — zero asset budget. Fire crackle = filtered noise;
// UI blips = short oscillators. Real packs can replace per-sound later.
let ctx: AudioContext | null = null;

const ac = () => (ctx ??= new AudioContext());

export function blip(freq = 440, dur = 0.08) {
  const c = ac();
  const o = c.createOscillator();
  const g = c.createGain();
  o.frequency.value = freq;
  o.type = "square";
  g.gain.setValueAtTime(0.05, c.currentTime);
  g.gain.exponentialRampToValueAtTime(0.001, c.currentTime + dur);
  o.connect(g).connect(c.destination);
  o.start();
  o.stop(c.currentTime + dur);
}

export function catchFish() { blip(660); setTimeout(() => blip(880), 90); }
export function coin() { blip(1320, 0.05); }
