# Spec 005 — Eastward texture audit: authored beats on a systemic spine

Status: A+B+C built, D blocked (2026-10-14 — A/B/C landed same
session: vignette card + cues, ceremony cues, letter cue, `when`
barks, five new trigger keys; D waits on the actor presenter)
Landed-in: `PLAN_gameplay.md` (vignette cues + reactive barks),
`ARCHITECTURE.md` §6 (moment-bound emit terms), this spec,
`game.gd` (`light_cue_changed`/`set_light_cue`/`clear_light_cue`,
`dialogue_when_ok`, `days_log` +`fav_served`/`regulars`),
`vignettes.json` (+`label`/`line`/`cue` + new trigger rows),
`dialogue.json` (+`when` rows), `night_summary.gd` (VignetteCard),
`journal.gd` (letter cue), `pinewatch_test.gd` (cue wiring,
`CEREMONY_CUE`, smoke coverage), `test_seating.gd` (`when` eval)
Source input: Eastward design audit (user question → analysis)

## Problem

Eastward is the presentation north star, but it is a **linear
narrative RPG** — no clock, no calendar, no simulation; time moves
only when the script says so, and every lighting beat is painted
per-scene. Trailbound is a **systemic cozy sim**: the day loop
(board → seat → resolve → decorate → repeat) is the game itself.
Wholesale adoption of Eastward's model would delete the genre.
The auditable question is narrower: *which authored-texture lessons
transfer onto the systemic spine without breaking determinism,
replayability, or the cozy contract.*

## Audit verdict

**Keep the systemic spine exactly as is; borrow Eastward's authored
texture on top of it.** The real lesson of Eastward is not "no
systems" — it is "systems serve authored moments." Trailbound
already has the serving infrastructure (emit registry, dialogue
rows, vignette picker, `emote` comp); the gap is that none of it
is aimed at *emotional beats*.

### What Eastward does that we already do — no adoption needed

| Eastward | Ours |
|---|---|
| Painted authored mood per scene | scalar `front`/`dusk` + emit registry (D-ARCH-1/3) — same outcome, systemic |
| Autosave at story beats | commit-on-beat (D-ARCH-6) — same philosophy, finer grain |
| Cooking as cozy texture | exact + fusion + mash tiers, book, sellable meals, guest favourites |
| Sam as constant companion | the dog (rounds, tricks, bond, scraps) |
| NPCs that make the world feel authored | regulars' 3-visit story arcs + once-ever vignettes |
| Fridge whimsy-narration | grandpa's journal voice, letter portraits |

## Adopted

### A. Vignette beats get a surface + an authored light cue

**Gap found in audit:** `goodnight()` returns `rep["vignette"]`
(picked by `_vignette_weight`, journaled in `vignettes_seen`) but
**nothing presents it** — the payoff exists only as bookkeeping.

1. **Interim surface (now):** the night summary gains a vignette
   card — the `label` + a one-line scene description — so the
   picked beat lands on screen before the actor layer exists.
2. **Authored cue (now):** `vignettes.json` rows gain an optional
   `cue` block: `{col, w}` riding the existing emit curves
   (`ember` for hearth-warm beats, `dusk` for night-sky beats,
   `flat` for a held moment tint). The presenter calls
   `world_fx.track_emit("vig_"+id, col, w)` when the beat plays and
   `untrack_emit` on dismiss — moment-bound registered terms are
   already legal consumers (D-ARCH-3); **no new curve kind needed**.
3. **Ceremony kinds** get the same map at `Ceremony.play`
   (`fivestar` → gold bloom, `page` → warm lift, `crew` → hearth
   glow): a small `kind → {col, w}` table beside the call site.
4. **Letter reads** may carry an optional `cue` — a warm lamp lift
   while the letter overlay is open.

### B. Morning-after reactive barks (context-conditioned dialogue)

Eastward's world feels authored because NPCs react to state. Our
reviews live only inside the night-summary text. Extend
`dialogue.json` with an optional `when` block evaluated at the
morning delivery pass against `days_log.back()` + delivered state:

```json
{"id": "mai_praise5", "site": "pinewatch", "anchor": "mai",
 "when": {"last_stars_min": 5},
 "lines": ["Five stars, cháu. Grandpa would have framed the log."]}
```

Condition keys (v1): `last_stars_min`, `last_weather`,
`served_favourite`, `regular_visit`, `first_night`. The delivery
pass prefers a `when`-matching row over a plain `day` row; every
row stays once-ever via `dialogue_seen`. Data-only extension —
the bubble presenter is unchanged.

### C. Denser vignette triggers (data-only)

`_vignette_weight` already iterates a trigger dict; new keys are
one comparison each: `shelter` (first cabin/platform night),
`dog` (met / bond ≥ n), `stars_min` (a perfect night earns its
own scene), `letter` (read today), `first_night` (site day 1).
Priority: **shelter + stars_min first** — they react to what the
player did tonight, which is the Eastward feel at lowest cost.

### D. Dog presence beats

`emote` comp on the dog entity in cast programs: wag on an all-5★
night, whimper under a `flash`/`front` scalar, curl at the fire
during `quiet_night`. Pure cast-time schedule rows — blocked on
the actor presenter (spec 003 dependency).

## Rejected — with reasons

| Eastward pattern | Why it fails here |
|---|---|
| No day structure at all | deletes the management-loop genre — the day IS the unit of play |
| Fridge-style physical save stations | friction on mobile; commit-on-beat already gives the same guarantee with zero taps |
| Static set-dressing NPCs | trait-resolving guests are strictly better sim citizens |
| Linear one-shot content | replayable sandbox — authored-per-scene doesn't scale |
| Autosave-only | superseded by touch/commit cadence |

## Naming note — two "emit"s, keep them distinct

- `schedule` op `emit {cue, t}` — **percept cues**: broadcast a
  stimulus into `sys_listen` for `react`/`respond` programs.
- `world_fx.track_emit` — **light terms**: additive entries in the
  grade `Σ emit×w` sum.

Specs and code comments must say *percept cue* vs *light cue* —
a vignette's `cue` block means the light term.

## Dependencies & order

1. A-1 (summary vignette card) + A-2/A-3 (cue maps) — no deps;
   ships independently of the actor layer.
2. B (barks) — needs the `when` evaluation in the morning pass;
   bubble presenter already exists (UI-038).
3. C — extends `_vignette_weight`/`_pick_vignette` only.
4. D — blocked on the actor view presenter (spec 003 gate).

## Verification

- `--smoke`: a night with a vignette asserts the summary card
  shows the label; a `cue`d vignette asserts `track_emit` received
  a `vig_*` id (mockable via the registry dict).
- `test_seating`/new test: `when` rows beat `day` rows on
  condition match; unmatched `when` rows stay silent; once-ever
  persists across reload.
- Vignette trigger additions are pure data → covered by the
  weighted-pick tests in `test_seating`.
