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

## Phase D2 — the missing half of the day (next)

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

## Depth rules going forward

- Every backend verb needs a scene path before it counts as
  "done" — backend-only systems are inventory, not gameplay.
- Determinism: placement legality is data-driven (decor_cells),
  never ad-hoc pixel checks.
- The authored scene stays fixed (GDD §5.8): Build mode edits
  decor_cells only.
