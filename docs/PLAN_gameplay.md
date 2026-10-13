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

### Schedule ops (the canned-loop DSL)

`{"op":"goto","to":[x,y],"speed":n}` → blocks until `mover.arrived`
`{"op":"anim","name":"fish","fps":6}` → sets anim, advances
`{"op":"wait","t":2.0}` / `{"op":"emote","icon":"x","t":1}` /
`{"op":"jump","to":0}` (loop) / `{"op":"scene","id":"kids_tag"}`

### Systems (ticked in order)

`sys_schedule` → `sys_move` → `sys_scene` → `sys_life`.
`sys_scene` orchestrates duets (kids tag: one scene entity writes
both movers' targets — scripted pairs, never emergent AI).

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

### 4. EventLog — one ordered stream per day

```gdscript
st["log"]  # [{phase, kind, payload}] — append-only
{"phase":"evening","kind":"guest_seated","payload":{gid,pad,stars}}
```

Sinks: night summary reads it (what happened), journal pages
count from it (cumulative metrics), analytics mirrors it, the
Then/Now photo + share moments capture from it. Replaces
scattered counters — the audit trail IS the progression data.

## Actor view presenter (when actor art lands)

Thin node mirroring SimWorld — the only Node touching the sim:
`spawn sprite on new eid / lerp display position / anim comp →
frame / despawn`. Zero decisions in the presenter; all behavior
lives in sim comps. Presenter ticks from `_process`; the world
ticks at fixed dt accumulated from it.

## Broader architecture analysis (same pass)

| Aspect | Verdict | Action |
|---|---|---|
| Sim boundary | `seating`/`econ`/`game` logic is nearly pure; ECS sim joins it | Keep Nodes out of `systems/` — lint: no `Node` types below `ui/` |
| Commit boundary | `bought_today` covers purchases only | Extend to a **day action log**: move/store/return/unlock/clear all undoable-until-Goodnight |
| Event flow | signals + trigger dicts today | `EventLog` for night summary/journal/analytics — one ordered list per day |
| Content lint | decor_cells hand-authored, neighbours hand-authored | CI validator: decor_cells ⊆ core & unblocked; neighbours symmetric; errand spots on ground; r-reach ≤ ~3 pads |
| Save/migration | `state_dict`+`_migrate` works | Actors excluded by design; add migration matrix to tests when schema bumps |
| Pathfinding | Not needed — open field, waypoint tweens | Revisit only if obstacles dense; authored routes cover it |
| Staff AI | Not in v1 | If staffing lands: per-agent task queue, not a job-board system |
