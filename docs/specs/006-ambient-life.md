# Spec 006 — Ambient life audit: making the camp feel inhabited

Status: audited + rules adopted; two engineering items queued
(terrain-cost nav, program variants). Landed-in: this spec,
`seating.gd` (WISH_CAP_KINDS), `game.gd` (`_wish_kinds` capability
set), `PLAN_gameplay.md` (D0.6 note), `test_depth.gd` (grantability
invariant).
Source input: user question — random vs state machine, road
preference, animation cadence — followed by a SOTA audit request.

## The question

Does the sim generate NPC behavior "randomly," do characters prefer
roads, do they march in sync — and are these known problems?

## What the sim actually is

Not pure random, not a full FSM — **compiled deterministic
programs** (`sim_director.gd` `cast_night`/`cast_day`):

- At cast time each entity gets a baked step program
  (`anim/goto/wait/emote/jump` + `react`/`respond` branches) from
  the seeded world rng. Runtime only executes; replay is exact.
- Archetype-authored routines (angler banks, kids play, sitters
  claim sockets) — authored loops, not per-tick dice.
- A stimulus layer (`perceive` + `respond`/`react` scored bands) —
  utility-AI-lite for dog proximity, barks, the meteor beat.
- Context wraps (`_storm_wrap` tent-huddle, seeded rare beats) that
  reshape a whole cast without touching individual programs.

## SOTA map — what best-in-class does vs what we do

| Technique | Reference | Ours | Verdict |
|---|---|---|---|
| Uniform random steering | (anti-pattern; feels dead) | skipped at design time | OK |
| **Weighted terrain costs** ("desire paths") | RimWorld, Dwarf Fortress, every city builder | `nav` = blocked (∞) + `pad_cost` 3.0 only; road/grass/shore indistinguishable | **Gap — queued** |
| Per-archetype routines + schedule | Stardew day schedules, AC villager routines | compiled programs per archetype | OK |
| Personality → routine *sets* (variety within archetype) | ACNH: 8 personalities × activity sets make ~400 villagers feel distinct | one loop shape per archetype; `_jitter` varies timing only | **Gap — queued** |
| Stimulus scoring / utility AI | The Sims needs; Klei DST brains (priority-ordered behaviour lists ≈ our `respond` bands) | `respond` bands + `perceive` weights | OK (right-sized) |
| Phase desync | every crowd system | `_jitter`: 0–1.5 s start delay + ±40 % wait jitter, seeded | OK |
| Blocking movement ops | prevents step-stutter | `goto` blocks until arrival | OK |

## Anti-pattern checklist (the named failure modes)

1. **Synchronized marching** — all entities animate/idle together.
   *Prevented*: `_jitter` desynchronizes loops while replay stays
   deterministic. ✅
2. **Step-stutter** (walk 1 step, idle, walk 1 step) — *Prevented*:
   `goto` blocks until arrival; routes emit full waypoint chains. ✅
3. **Hyperactive walkers** — *Prevented*: programs are wait-heavy
   (fish 8 s, sit 6 s, idle 4 s); sitters pace pad↔socket, which
   reads as people re-sitting — lively, acceptable. ✅
4. **Terrain-blind routing** — actors ignore the road the art
   draws. *Open*: the weighted A* exists; `nav` just has no road
   cells yet. **Fix queued**: `nav.cost` cell classes
   (road < grass < pad < blocked), ~20 lines of engine + layout
   authoring. Only matters once the tileset paints paths.
5. **Cloned archetype behavior** — every hiker runs the identical
   loop shape. *Open*: timing jitter only. **Fix queued**:
   2–3 variant programs per archetype picked by seeded rng at cast
   (e.g., hiker whittles vs stargazes) — the ACNH "personality set"
   trick with our determinism intact.
6. **The broken promise** — a wish/request the camp cannot satisfy.
   *Fixed this pass*: capability gating, below.
7. **The mandatory chore** — a free, once-a-day, positive-only verb
   that optimal play makes obligatory (stoke, tuck, fetch, photo,
   margin). *Mitigated by convention, see Rule 3* — the SOTA answer
   (Cozy Grove dailies, AC tree-shaking) is that these are
   *rituals*, not optimizations: bounded reward, zero friction,
   fiction carries it. The risk lives in presentation, not math.

## Design rules adopted

**Rule 1 — No broken promises (enforced).** A request is only dealt
where tonight's camp can grant it. `Game._wish_kinds(st)` computes
the satisfiable set per morning — pad tags (incl. restoration
grants via `_world()`), fire-ring warmth, placed light, uncovered
sky, a free adjacent pair — and `Seating.WISH_CAP_KINDS` gates
trait, archetype, *and* generic picks against it. `test_depth`
asserts every dealt wish is grantable. Postcard's `kinds=[]` is
deliberately conservative (its fictional camp has no verified
geography → only always-true kinds).

**Rule 2 — The daily-ritual convention.** Once-per-day verbs share
one idiom: `can_*()` gate + verb + `*_day`/boolean flag reset in
`new_day` + undoable where reversible + bounded-positive reward.
Members: `spot`, `read_margin`, `take_photo`, `dog_fetch`,
`stoke_fire`, `tuck_in` (+ `dog_pet`, morning dig). New depth verbs
must use the same shape — the UI agent gets a uniform affordance
(check `can_*`, show the gesture, disable). Rewards stay small and
positive so skipping never reads as loss; the *presentation*
(emote, animation, sfx) is what makes it a ritual rather than a
checkbox — that half is the UI agent's, flagged in both D0.5/D0.6
handoff tables.

**Rule 3 — Determinism is the contract, jitter is the texture.**
All ambient variation draws from seeded world rng at cast time in
spawn order. Nothing rolls per-frame or per-tick. New beats must
draw at cast (like `_roll_rare_beat`) or score stimuli (like
`respond`), never sample wall-clock or unseeded rng.

**Rule 4 — The map dictates the path.** Routing costs live in
layout `nav`, not in actors. Adding terrain preference is a data
change (layout authoring), never a behavior change (actor code).

## Queued work (not yet engineered)

| Item | Shape | Why it's the right next thing |
|---|---|---|
| `nav.cost` terrain table | layout `nav.cost` cell→weight map merged into `_route`'s A* step cost; author road cells in layouts | the #1 believability lever once paths exist in art — RimWorld desire-path effect |
| Program variants | per-archetype loop sets in the casting table (data), seeded pick | kills "every hiker identical" — the remaining mechanical tell |
| Schedule arcs | optional: guests drift toward the fire/tents as the night deepens (program chapter 2) | bigger; only if night scenes feel static after the above |

Rejected: mid-resolution player verbs (spectator-night is the
design), persona-level memory (personas are small render pools;
arch-level "familiar face" is the honest granularity), full BT/GOAP
(the scored-band model covers our scope; DST-scale brains are
overkill for 8 tents).
