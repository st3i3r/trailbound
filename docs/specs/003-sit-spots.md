# Spec 003 — Sit spots (benches as sim affordances)

Status: **Decided** — blocked on the actor view presenter
(PLAN_gameplay "Actor view presenter", D4). Source: design input
`bench.txt`, audited 2026-10-13.

## Problem

Placed seating (bench, stools, picnic table — `decor.json` effect
`seats`) should be *lived-in*: evening guests walk to a bench, sit,
idle, emote, return to their pad. Placement changes the night — the
Animal-Crossing property already live for `swing`/`dog_bed`.

## Audit of the input doc (bench.txt)

The doc proposes Smart Objects *without* an AI layer: `Area2D`
`body_entered` capture, bench-owned `_process` stat ticking
(`relaxation_score`→auto-release), `randf()` emote spam,
`z_index` locks, `CozyClock`/`EventManager` references.

Our sim already is the named SOTA pattern — SimWorld ECS with
`_near_tag` ("Smart-Object lookup, Sims affordances"):

| Doc mechanism | Our equivalent / why it's rejected |
|---|---|
| `body_entered` → auto-sit | `{"op":"goto","tag":X}` program step + affordance tags — capture would grab passersby mid-route; sitting is a cast decision |
| `Marker2D` sit targets | decor `cells` → `ctx.items`/`item_pt`; per-slot offsets = the planned `sockets` block `{id, px_offset, facing}` |
| `z_index` lock | `world.y_sort_enabled` — snap to the seat point sorts automatically |
| `relaxation_score` tick → release | `wait`/`jump` steps — deterministic; no NPC stat meters exist (D-UI-8) |
| `randf() < 0.15` emotes | `emote` comp + ops — seeded, persona-scored via `respond` bands |
| `EventManager.incident`/`CozyClock` | `w.ctx.weather` already plumbed; no clock exists (spec 002) |
| `EmoteBubble.tscn` raw tween | presenter renders `emote` comps through `UIFeel` policy (juice map row) |
| Per-bench `_process` accumulator | `SimWorld.tick` owns all ticking; furniture is perceived, never ticks |
| `CollisionShape2D` footprint | `nav.blocked` cells + cast-time A* — no runtime physics pathing |

**Usable intent kept:** slots-on-furniture (our `sockets`),
context-keyed emotes (storm-sigh / night-zzz / day-heart), the
rest-verb gesture.

## Integration path (when the presenter lands)

1. **Data:** `decor.json` rows gain `sockets`:
   `[{"id":"L","kind":"seat","px_offset":[x,y],"facing":"south"},
   ...]` — bench gets 2, stools 1, picnic table's benches 4.
   `kind` is the socket category (seat / surface / hang) — slots
   are typed so a floor cushion can't claim the shelf point
   (spec 004 item B).
2. **Cast:** `SimDirector.cast_night` spawns one `sit_spot` entity
   per socket per placed bench (tagged, `pos` = cell origin +
   offset). Director *claims* sockets at cast time (seeded order) —
   the PLAN "Sockets" item, bench as its first consumer beyond pads.
3. **Programs:** restful archetypes (reader/elder classes) add a
   branch — `goto tag:sit_spot` → `anim sit` → `wait` → `emote` →
   walk home. Occupied sockets stop advertising (claim retags the
   entity) so a second guest takes the other seat or skips.
4. **Emotes:** `select` branches on `ctx.weather` pick the icon —
   `heart` clear evening, `zzz` late idle, `sigh` storm. Authored
   ops, never `randf` — determinism contract stands.
5. **Player:** the rest verb is separate — sit-at-fire beat rides
   on the hearth (ember light already pops at dusk); not NPC-
   furniture plumbing.

## Dependency

`cast_night` is exercised only by `test_sim.gd` today — the scene
renders 3 anchored idlers + static `guest_nodes`; no view presents
a `SimWorld` yet. Land behind: actor view presenter → emote-icon
rendering (juice map) → then this row.

**Presenter contract (D-ARCH-7, pinned 2026-10-13):** when the view
presenter lands it must tick `SimWorld` at a **fixed dt through an
accumulator** — never render delta — with RNG only via `_rng_for`
streams and iteration order = cast order. `test_sim.gd` already
ticks fixed steps (`w.tick(0.25)`); the live tick must match or
same-seed replays drift. This is the standard determinism
prescription (fixed step + seeded RNG + ordered iteration).
