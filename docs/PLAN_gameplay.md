# Trailbound — Gameplay Depth Plan (2026-10-13)

Depth audit after the backend close-out pass. The honest state: the
**Evening half of the loop works end-to-end** (board → drag guest →
live star preview → seat → goodnight → night summary → next day).
Everything the player *manages* — items, meals, pads, errands — is
backend-complete but has no interaction surface yet.

## Audit: what exists vs what the player can reach

| System | Backend | In-scene | Gap |
|---|---|---|---|
| Seating puzzle (drag→pad→stars) | `seating.gd` | `pinewatch_test` tray+drag | none |
| Reviews/tips/rating/walk-ins | `econ.gd`,`goodnight()` | NightSummary sheet | none |
| Bookings board | `Seating.board` | BookingBoard sheet | none |
| Journal/letters/crew/restore | `game.gd`, systems/* | journal, markers | mostly wired |
| **Build mode** (place/move/store/return) | `buy_decor`,`move_decor`,`store_decor`,`return_decor`,`place_stored` + `decor_cells` | **nothing** | **the whole interaction** |
| **Outfitter** (buy gear/staples/decor) | `buy_*` verbs + catalog | **nothing** | shop sheet + flow |
| **Pad opening** (unlock→Clear) | `unlock_pad`,`clear_pad` | locked pads render, no tap | clear UI + transform anim |
| **Prep phase** (forage/fish/cook) | `gather`,`fish_catch`,`pantry_*`,`cook` | **skipped entirely** (MORNING→EVENING) | phase + errand spots + cook sheet |
| **Dinner** (meal→guest) | `allocate_meals` | **nothing** | evening tray extension |
| Errand spots | `errand_spots` in layouts | props only, not tappable | tap→roll wiring |
| Trail map / site travel | `travel_to`, `site_reachable` | **nothing** | map sheet |
| Dog | `dog.gd` | **nothing** | pet + adoption flow |
| Crew bubbles | `crew_*` | structure prop only | bubble→crew sheet |

The single structural fact: **`_advance_phase` jumps MORNING→EVENING** —
the Prep half of the day doesn't exist in the scene. Until it does, the
player can only seat guests; the camp never changes.

## Phase D1 — backend close-out (DONE 2026-10-13)

- `decor_cells` authored in all 3 layouts (14/23/26 cells — legal
  placement set inside the camp core, r1 reach ≤ ~2 pads, clear of
  pads/fire/water/scenery)
- `buy_decor` legality: cells ∈ decor_cells, footprint matches size
  (1x1 / 2x1 adjacent pair), no overlap with pads/fire/placed decor
- Build verbs: `move_decor` (free), `store_decor`/`place_stored`
  (free, seats accounted), `return_decor` (full refund, today's buys
  only — §6.1)
- Pad opening is two steps: `unlock_pad` (pays, `paid` flag, spot
  stays overgrown and still blocks bookings) → `clear_pad` (free,
  the ~2 s transform lives in the scene)
- `test_seating` green: 12 new checks + 4 stale-layout worked
  examples remapped to the v16 cells

## Phase D2 — the missing half of the day (spec below)

1. **Prep phase exists**: `_advance_phase` goes MORNING→PREP→EVENING.
   HUD phase button per §4 table (Head out → Goodnight).
2. **Errands interactive**: errand_spots tappable in Prep —
   forage nodes (gather→pantry), pond (fish), lookout (spot) —
   using existing `systems/errands.gd` surfaces.
3. **Outfitter sheet**: catalog tabs (decor/gear/staples) → buy
   verbs; items land in `stored` or place directly.
4. **Build mode**: catalog/stored item → drag ghost → legal
   decor_cells highlight → snap → radius ring → star deltas →
   place (`buy_decor`/`place_stored`/`move_decor`); long-press or
   context row for store/return.
5. **Pad clearing**: locked pad tap → price prompt → `unlock_pad`
   → hold ~2 s Clear transform (weeds/stones pull away) →
   `clear_pad`. The transform is the reward (§5.1).
6. **Dinner**: evening tray gains a meal column — drag a cooked
   meal onto a seated guest (favourite match → +1).

## Phase D3 — supporting casts

- Crew bubble on the hut structure → crew sheet (collect/speed-up)
- Trail map sheet (site travel after chapter 1)
- Dog adoption vignette + rounds
- Trail Daily entry

## Phase D4 — Actor layer: SOTA sim-first ECS (core first)

The camp must be watchable: kids playing, the dog on rounds, the
angler casting, the warden on chores (§13.4 vignettes, "alive in
ten seconds" pillar). Actors are **performers replaying the
resolved night, not agents** — deterministic cast, canned
performance. The SOTA shape for a deterministic Godot game is a
**sim/view split ECS**, not a node ECS and not restaurant-sim
agent AI:

```
SimWorld (pure data, fixed-dt tick, seeded)
   entities  = int ids
   stores    = comp_name -> {eid: Dictionary}
   systems   = static funcs run in order each tick
Director   = casting layer: Game state -> entity spawns
View       = presenter node: sim pos/persona -> sprite nodes
             (y-sorted world children; zero sim logic)
```

### Components (dict schema, v1)

| Component | Fields | Purpose |
|---|---|---|
| `pos` | x, y | sim position, world px |
| `mover` | speed, target, arrived | waypoint move |
| `schedule` | steps[], i, wait, started | behavior program |
| `anchor` | kind(pad/spot/item/pt), ref | home base |
| `persona` | sprite, tint, scale | view hint |
| `anim` | name, fps | current loop |
| `scene` | id, role, peers[] | pairwise vignette membership |
| `life` | ttl | despawn timer |

### Schedule ops — a real mini-BT, not a toy sequence

The DSL is a restricted **behavior tree**: sequences plus
select/condition/reaction nodes — the same paradigm ambient-NPC
systems in production games use, kept deterministic.

```
goto / anim / wait / emote / jump          (sequence ops)
select {branches:[{ctx:{k:v}|item|anchor -> goto}], else}
if    {cond -> goto}                       (condition nodes)
emit  {cue, t}                             (broadcast a cue at pos)
react {to, goto}                           (consume heard inbox)
```

### Senses are a system, not a step (learned the hard way)

`sys_listen` delivers cues inside `listen.r` into a per-entity
`heard` inbox — **event-latched, not polled**. First version had
react scan live cues at eval time; a 5s loop polling a 2s cue
misses ~60% of events. The inbox pattern is the SOTA-correct
shape (senses are systemic delivery, reactions are consumption)
and stays deterministic.

### Systems (ticked in order)

`sys_schedule` → `sys_move` → `sys_sense` → `sys_life`.
`sys_scene` (duets) joins when pairwise vignettes land — scripted
pairs, never emergent AI.

### Interactions: the general stimulus pipeline (production)

Everything that can be perceived is a **stimulus** — tagged
entities (continuous channel) and tagged cues (transient
channel) share one registry shape `{tags, pos, t?}`:

```
emit/tags -> stimulus set -> sys_sense -> per-entity percept
             (any tag)      (weights x falloff)   + heard inbox
```

- `perceive` comp = the persona: `{"sight_r","hear_r",
  "weights":{tag: weight}}`. Persona is DATA — weights and
  radii, no code. score = weights[tag] * (1 - dist/sight_r),
  best per tag lands in `percept.by_tag`.
- `respond` op consumes percepts: `{"op":"respond",
  "tags":["dog"], "bands":[{gte,goto},{else,goto}]}` — picks
  the best-scoring wanted stimulus, bands branch to programs.
- `react` op remains the reflex channel: cue name -> heard
  inbox -> binary flinch (transient events).
- `goto` targets resolve three ways: `"to":[x,y]`,
  `"tag":"dog"` (nearest tagged entity), `"percept":"oddity"`
  (a scored stimulus — covers cue positions).
- Adding an interaction pair = adding tags + weights.
  "Dog meets oddity" needed zero new code: oddity entity gets
  `tags:[oddity]`, dog gets `weights:{oddity:.9}` + a respond
  wrap; it investigates, sniffs, and barks an `alarm` cue —
  itself a stimulus other actors can respond to. Chained
  causal interactions emerge from the data.

Persona weights (kid .55 / dog_wary .9 / dog-oddity .9) pick
different outcomes from the same machinery — flee, wary, pet,
investigate — no pair-scripting. Semantic memory stays in
persistent game flags, not sim state.

### Item-bound anchors — the genre-SOTA property

`w.ctx = {items, weather}` at cast time; the Director binds
actors to *player-placed* decor (kids→the placed swing, dog→
dog_bed patrols occupied pads, angler→pond). Placement changes
the night — build mode feeding the sim is the Animal Crossing
property, and it is already live.

### Determinism contract

- World holds one seeded `rng`; systems draw only from it.
- Fixed-dt accumulation (`t += dt`); same seed + same cast ⇒ same
  final positions. Verified headless (test_sim).
- Actor state is **ephemeral**: rebuilt per phase from Game state,
  never serialized — saves keep only sim inputs.

### Director casting (scenario tables deferred)

`cast_night(st, vignette)` / `cast_morning(st)` map seated
archetypes + placed items → entity programs. v1 casts a minimal
in-code table (guest idle at pad, dog patrol, angler→bank); the
full archetype/weather/item scenario matrix is a data file later.

**Events are casts, not managers.** There is no `EventManager`
autoload mutating state mid-night — `st["event"]`/`st["weather"]`
are seeded at day roll, persisted, and the Director reads them at
cast time to pick scenario rows (storm cast: tent-huddle programs,
no bank visits; Tết cast: festive archetypes + lantern decor
state). A mid-night "storm arrival" is a *scheduled beat* in the
cast (thunder percept → campers retreat — deterministic). Rain,
dimming, lanterns are presenter layers reading the same key.
Incidents obey the cozy contract: a lừa-đảo guest is *denied
upside* (tips less, one guest's night sours, tap-to-shoo or the
warden handles him) — never owned-resource loss.

### Entropy (actor-scale verdicts, applied)

At ~10-15 actors the crowd-sim playbook mostly doesn't apply:

| Technique | Verdict | Where |
|---|---|---|
| Phase jitter | **Adopted** — Director bakes seed-drawn offsets into wait steps + a 0-1.5s start delay at cast time | `_jitter()`; sim stays pure, replay deterministic |
| Anchor slot claims | Adopt later — swing seats 2 kids, fire 4, bank 1: a capacity dict on anchors, not token pools | scenario tables |
| Per-eid anim frame offset | Adopt in presenter — `(t + eid*0.17) % dur`, the free DOTS/VAT analog | view presenter |
| Time-sliced brains, ORCA, VAT, GOAP | Rejected — scale is 10-15 sprites on an open field | — |
| Utility AI | Rejected at tick level (breaks determinism) — **already exists at cast level**: `_vignette_weight` is utility scoring over vignette candidates | `game.gd` |

### The three clocks (documented so they never cross)

1. **Day clock** — phase/batch: MORNING→PREP→EVENING→NIGHT (game.gd)
2. **Real clock** — crew stages only, UTC, offline-safe (§8.4)
3. **Sim clock** — actor ECS tick; presentation-time only, paused
   with panels, rewound identically on reload

## Phase D2 — the interaction layer (SOTA spec)

The missing half of the day is not more backend — it is the
interaction shell that exposes it. Four pieces, in build order.

### 1. Phase controller (Morning→Prep→Evening→Night)

SOTA pattern: a mode that owns legal verbs + visible panels,
not a monolith checking a string. Insert `PREP` between
`MORNING` and `EVENING`; `_advance_phase` gains enter/exit
hooks. Each phase declares:

| Phase | Legal verbs | Panels | Time |
|---|---|---|---|
| MORNING | read letter, travel | letter, journal | batch |
| PREP | buy/move/store/return, unlock/clear, cook, errands | outfitter, pantry, errand pick | batch (no pressure) |
| EVENING | seat/unseat guests, build verbs | booking board, tray | batch |
| NIGHT | goodnight only | summary | batch |

Verbs called out-of-phase return `{"ok":false,"err":"phase"}` —
the gate lives in `game.gd`, so UI can never create illegal state.

### 2. Commands + day action log (undo model)

SOTA: every mutation is a command record, which gives undo and
the "nothing is final until Goodnight" pillar for free. Replaces
`bought_today` (superset of it):

```gdscript
st["actions"]  # [{verb, params, inverse}, ...] — day-scoped log
{"verb":"buy_decor","params":{"item":"stump","cells":[[7,2]]},
 "inverse":{"verb":"return_decor","params":{"inst":3}}}
```

- `undo()` pops the log and applies `inverse` — always possible
  because every verb's inverse is total (buy↔return, move↔move,
  unlock↔refund-until-clear, place↔store).
- `Goodnight` **commits**: log cleared, placements become property.
- Same-day buys stay refundable; older items move/store free and
  are never sold (§6.1) — inverse generation knows the diff.

### 3. Build-mode interaction state machine

```
idle ──pick──▶ ghost(follows touch)
ghost ──drop legal──▶ apply command ──▶ idle
ghost ──drop illegal──▶ rejected feedback ──▶ ghost
ghost ──cancel──▶ idle
```

- Ghost is an **ephemeral preview entity**, never real state —
  evaluated by calling the same pure `Seating` functions the
  resolver uses (SOTA: preview and resolution share one truth,
  which is also what the §10 solver needs).
- Snap = nearest legal `decor_cell` to touch point; blocked cells
  flash the reason (occupied / pad / fire / water / scenery).
- Radius ring + live star delta render under the ghost — the
  "watch the stars move" moment is the core toy.
- Touch ergonomics: pickup radius ≥ 24px, 0.15s long-press to
  pick up placed items, two-finger or dedicated button to cancel.
- **Context-action rows** (the state-enum → verb pattern): every
  tappable object carries a state enum and the tap surfaces only
  the legal verbs — pad `overgrown` → [Unlock price] / `paid` →
  [Clear] / `open` → [Upgrade]; placed decor → [Move] [Store]
  [Return if today's]; errand node → [Forage] [Fish]; dog →
  [Pet]. The scene reads as passive-until-touched, which is the
  cozy contract's tactility rule made concrete.

### 4. EventLog — one ordered stream per day

```gdscript
st["log"]  # [{phase, kind, payload}] — append-only
{"phase":"evening","kind":"guest_seated","payload":{gid,pad,stars}}
```

Sinks: night summary reads it (what happened), journal pages
count from it (cumulative metrics), analytics mirrors it, the
Then/Now photo + share moments capture from it. Replaces
scattered counters — the audit trail IS the progression data.

## Actor view presenter + juice map (when actor art lands)

Thin node mirroring SimWorld — the only Node touching the sim:
`spawn sprite on new eid / lerp display position / anim comp →
frame / despawn`. Zero decisions in the presenter; all behavior
lives in sim comps. Presenter ticks from `_process`; the world
ticks at fixed dt accumulated from it.

### The juice map — sim signal -> presentation response

| Sim signal | Juice |
|---|---|
| `mover` velocity | secondary motion: lean/hop on accel; grass-squish decal underfoot; fading paw prints on dirt after rain |
| `emote` comp | icon bubble (","!"","♥") + squish-stretch on the sprite |
| `percept` new entry | head-turn emote toward stimulus pos |
| cue `bark`/`alarm` | soft sfx + bark bubble |
| `ctx.weather` | **Built (visual half):** `--storm`/`st["weather"]` drives `_set_storm` — grade → desaturated slate (4s SINE), GPU slanted rain (box strip, `ALIGN_Y_TO_VELOCITY`), screen-space ground ripples (shader below y-sorted world), periodic lightning grade-flash. Remaining: rain low-pass audio bed, umbrella/tarp idle variants, HUD exempt from grade (`light_mode=unshaded`), fire/window warm-cut (PointLight2D or painted glow) |
| `anim` name | frame set; `flee`/`wary`/`pet` are authored loops |
| coincidental sprite overlap | deterministic render offset from world rng + back-sprite alpha dip — residual fix only; real prevention is socket claiming below |
| actor behind tall prop | **walk-behind fade shipped** (pinewatch_test): `FADEABLE` props get a zone over their upper art; actor footing inside lerps alpha to 0.35. Verified — dog behind the van shows through |
| night summary payment | physical coin pickups: spawn → bounce → magnet to wallet |

### Adjacency visual variants (build-mode delight)

Placement context changes the item's *look*, not just its
effect — same signals as the puzzle: stool+table pair renders
merged, lantern beside a tent gets a lit variant, tarp over a
pad shows the shelter drape, swing with kids nearby gains a
gentle sway at rest. Pure presentation; driven by the same
decor/neighbour data the solver uses.

### Sockets = anchor slot capacity (the deferred item, named)

Items expose per-sub-position anchor slots — the campfire's
log seats, the swing's two seats, the bank's single fishing
spot, a picnic table's benches. At cast time the Director
*claims* sockets (seeded order) so actors never stack: two
kids get swing-A + ground-B, four campers get fire seats
1-4. This replaces the vague "anchor capacity" TODO and is
the real answer to sprite stacking (visual offsets are only
the residual fix). Data shape: `sockets` block per item —
`{id, px_offset, facing}` — anchors bind to a socket, not
just an item.

### Ambient audio beds

`audio.gd` becomes a stem mixer: base loop + phase layers
(evening guitars) + weather layers (rain patter + low-pass) —
crossfaded, not switched. Plus a **spatial layer**: a `zones`
block in layout JSON (pond → frogs/lap, treeline → birds,
fire → crackle, hut yard → quiet), gains driven by camera
distance — the campsite mix moves as the view pans.

## Broader architecture analysis (same pass)

| Aspect | Verdict | Action |
|---|---|---|
| Sim boundary | `seating`/`econ`/`game` logic is nearly pure; ECS sim joins it | Keep Nodes out of `systems/` — lint: no `Node` types below `ui/` |
| Commit boundary | `bought_today` covers purchases only | Extend to a **day action log**: move/store/return/unlock/clear all undoable-until-Goodnight |
| Event flow | signals + trigger dicts today | `EventLog` for night summary/journal/analytics — one ordered list per day |
| Content lint | ~~hand-authored~~ **in-test lint shipped**: decor⊆walkable, no dead cells, pads walkable+reachable, fire solid, errands grounded | Extend to: neighbours symmetric; r-reach ≤ ~3 pads; MASK↔nav cross-check (water cells ⊆ blocked) when a MASK parser lands |
| Save/migration | `state_dict`+`_migrate` works | Actors excluded by design; add migration matrix to tests when schema bumps |
| Pathfinding | **Cast-time static cost routing** — the map dictates the path, not the actor: `nav.blocked` cells (water/fire/treeline) + soft pad cost in layout JSON; LOS fast path else A* on the cell grid, emitted as `goto` chains. Deterministic, pure-data, no runtime navmesh/physics | Done — `_route`/`_goto_legs` in SimDirector; dynamic targets (flee home, goto tag/percept) stay straight-line, noted limitation |
| Tile-as-data | Our split-list version of their per-tile record: `nav.blocked` (nav layer), `decor_cells`/`pads`/`bank_cells` (gameplay layer). Same substance | **Placement deadlock guard added** — `_strands_any` flood-fills walkable cells before/after a drop; sealing a reachable region rejects the placement (covers buy/move/place_stored). Occupant-per-tile for movers rejected — pos queries suffice |
| Map layers | Painterly equivalent of the L0/L1/L2 tilemap model: baked ground PNG + tintmap (terrain), `PROPS` table (static env), layout JSON (interactive). No runtime TileMapLayer — that's the Eastward approach; Terrains auto-tiler is authoring-tool material, not runtime | **Layout-integrity lint added** (test_seating): decor⊆walkable, no dead cells, pads walkable+mutually reachable, fire solid, errands on/near ground. FastNoiseLite procedural maps rejected for runtime — sites are authored content; possible offline tool role later |
| Reserved zones | Off-limits regions are implicit across 6 keys (pads, fire, nav, bank, decor, crew_plots) | Site 2 schema: `reserved: [{id, kind, cells}]` — crew plots, bank apron, fire yard declare their exclusion explicitly; lint reads them instead of inferring |
| Site portability | Engine layer is site-agnostic: no Pinewatch refs in `sim/`. Site = layout JSON contract (`pads.spots`, `errand_spots`, `nav`, `decor_cells`) + scenario table. `cast_night` is hand-authored Pinewatch content pending the scenario matrix | Done — `_bank` returns null without `errand_spots.pond` (angler falls back to idle); remaining site data is the planned JSON matrix |
| Staff AI | Not in v1 | If staffing lands: per-agent task queue, not a job-board system |
| Smell audit (2026-10-13) | **SimGrid** now the single home of CELL + nav/walkable/reachable parsing (was duplicated in director + game.gd + test) | Program **labels** replace magic jump indexes (`goto:"flee"` resolves at schedule build — `goto:5/7/11`, `-1` patch, `flee_i+4` are gone). Dead keys removed (`lookout` dup, `bank_cells`). Stale `[96,72]` fallbacks in errands.gd gated — no forage spot → no nodes |
| Remaining smells | `cast_night` ~150 lines = content in engine (by design; scenario JSON is the fix). `pinewatch_test.gd` 1525 lines is a testbed becoming the real scene — split when it ships. `game.gd` 1.6k-line autoload — watch it. `visit=spots.keys().slice(0,3)` leans on dict order | Patrol `emit bark` is untagged (ambient) vs investigate `["alarm","noise"]` — semantic asymmetry, keep. Git history has one cosmetic duplicate commit |

## The cozy UX contract (cross-cutting, applies to every phase)

Player drive in this genre: stress-free autonomy, sensory
satisfaction, gentle nurture. These are the rules that translate
the backend above into that feeling — with honest status:

| Rule | Our form | Status |
|---|---|---|
| Progression never moves backward | Bad night = fewer tips; walk-ins leave quietly; nothing the player built is ever lost or downgraded | Structural (GDD "no fail") — encode as test invariants: floor ≥ 0, resolve never removes |
| Time freezes during edit | Batch phases — there is no realtime shop clock to pause; sim clock pauses with panels (three clocks rule) | Guaranteed by architecture |
| Spectating is the reward | The night cast IS the ant-farm — watching kids at the swing and the dog's rounds is the payoff, not a chore-skip | Built (D4) — presenter + scenario data remaining |
| Opt-in tactility | Errands stay manual and tactile (forage/fish are rolls with feel, not menu clicks); nothing is auto-played | Needs the tactile pass when errands land (D2.2) |
| Juice comes from sim signals | `emote`/`heard`/`percept` transitions drive presenter juice: squish-stretch on flee, "!" bubble on flinch, soft sfx on bark; coins in the night summary are physical pickups, not ledger deltas | Sim signals exist; presenter maps them (D4 view) |
| Challenge ceiling | "Meaningful interactions, never too much challenge" — the seat puzzle is cleverness *rewarded*, not competence *tested*; a wrong layout is still a fine night, just less rich | Structural (no-fail floor) — keep as the D2 tuning rule |
| Attachment cadence | Retention = missing the place: **every day ends with one small visible growth AND one anticipated tomorrow** (a regular returning, a letter waiting, a restoration finishing) | Vehicles exist (bookings/arcs/letters/crew) — make it a day-generator invariant |
| Abundance, not scarcity | The site always feels *provided* — pantry stocked enough to cook, guests always arriving; pressure is arrangement, never survival | Economy watch-item: coins may floor at 0 for pacing but nothing should read as deprivation |
| Nothing is "missed" | Daily systems are **offers, not expirations** — ungathered forage nodes persist (capped 12, husks fade); fish resets are restock caps; letters wait in the journal | **Fixed** — forage wipe at day-end was the one true FOMO in the game |

Micro/meso/macro rhythm (already staggered, keep it that way):

- **Micro (seconds):** pet the dog, watch a flinch, collect a
  crew bubble, the Clear transform's ~2 s reveal
- **Meso (minutes):** the day loop itself — prep errands,
  cook, seat, watch the night resolve
- **Macro (hours):** pad expansion, journal pages, site
  unlocks, real-time crew restorations

The checklist adapted: no bankruptcy ✓ / edit freezes time ✓ /
manual chores tactile (in progress) / spectate a living world ✓.
