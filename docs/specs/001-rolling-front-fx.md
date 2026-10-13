# Spec 001 — Rolling-front world FX

Status: **Landed** → `game/scripts/world_fx.gd`, UI-046, D-ARCH-1, D-ARCH-3.
Source: design matrix received 2026-10-13 (`matrix.txt`).

## Problem

A storm should arrive as a staggered rolling front (darkening → wind
→ downpour → ground saturation), not an instant state swap — and a
storm cancelled mid-roll must never snap back to hardcoded
endpoints. The original draft solved this with a fixed phase
timeline: parallel tweens on magic ratios (`duration*0.7`,
`interval 0.3`) between constants.

Its three structural flaws: interrupting a tween restarted between
constants (mid-roll snap), only binary storm/clear states existed
(no drizzle/overcast), and every new channel meant more interleaved
tween lines.

## Decision

Animate normalized scalars, not timelines. Each channel is a pure
response curve evaluated from the current scalar — interrupts
retarget from wherever the scalar is, partial weather is a target
value, a new channel is a new curve row not new plumbing.

- `front` 0→1 weather severity; `dusk` 0→1 nightfall; `flash` impulse
- Channels: grade, rain/leaf density (hysteresis), wind global,
  ambience mix, overlay `resp` rows (`front`/`front_lift`/`dusk`),
  emit registry (grade or node-property sinks)
- Discrete where physics is discrete: shader *selection* stays a
  profile row with double-buffered crossfade slots
- Lightning: settled + `front>0.8` + `UIFeel.can_pulse()`

## Light model (second spec layer, same file)

`grade = time(dusk) × absorb + Σ emit×w` — the "no sunny at night"
problem. Transmittance ≤1 always applies; a >1 profile channel is
in-scatter and daylight-weighted, so brightening weather can never
lift the night. `flash` and the campfire `PointLight2D` (`ember`
curve) are emit rows, not special cases.

## Generalization

The scalar+curves pattern is the reusable shape anywhere one state
fans out over staggered sensory layers: phase→dusk (shipped),
cinematic letterbox, fire warmth, site-blend, music intensity.
