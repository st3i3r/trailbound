# Batch A-R run — 2026-10-13

Spend: **7 jobs × 15 gens = 105** · selected 70 objects · `trailbound-ar` tag.
Flat pricing verified: 4/16/64-slot grids all cost 15 — pack slots full,
auto-fills are free bonuses in the same style.

## Jobs

| Job | Canvas | Selected | Landed |
|---|---|---|---|
| J1 tents+table | 160 | 4/4 | `dome_tent_{sage,amber,slate}`, `camp_table_fold` |
| J2 camp gear | 160 | 4/4 | `cooler_box`, `folding_chair_pair`, `propane_stove`, `solar_lantern` |
| J3 undergrowth | 85 | 16/16 | A-R2 all 5 + `dry_bag` + bonuses: `rock_mossy_s`, `mushrooms_orange`, `debris_log_mossy`, `pine_sapling`, `root_gnarled`, `stump_mushroom`, `debris_brambles`, `debris_branch_pile`, `bush_clover`, `duffel_bag` |
| J4 shore | 85 | 9/16 | Edges/corners/accents — model drew filled bank tiles not bare rims; kept as composed-shore vocabulary (`shore_edge_*`, `shore_corner_*`, `shore_islet`, `shore_steps_water`, `shore_cape_tip`) |
| J5 canopies | 160 | 4/4 | `canopy_{broadleaf,maple,feathery,cherry}` — clean T2 splits |
| J6 trunks | 85 | 16/16 | `trunk_{broadleaf,maple,feathery,cherry}` + bonus vocabulary: birch, ancient, pine, aspen, roots, twin, mossy, **hollow**, burl, yfork, stumps dead+burnt |
| J7 decals | 40 | 41/64 | A-R5 all 6 + 35 forest-floor decals (pinecones, nests, lily pad, ivy, sprouts…) |

## Pipeline learnings (now in PROMPT_PACK §6)

- Review objects **auto-finalize** — select promptly after `review`
  status; a 404 on select means frames already became objects
  (`list_objects` recovers them).
- Selected frames receive NEW object ids → recorded in `jobN_meta.json`.
- Ship resize is per-family: organic/curves → LANCZOS, hard edges →
  NEAREST (`tb_post --resample smooth|sharp`).
- Canvas-vs-display ≤1.8×; gen at display×1.2–1.8.
- Shore-ring spec needs rework: "fitted stones, no fill" produced filled
  bank tiles — if a real 8-way ring is still wanted, describe it as
  edge tiles with water-side context (the kept set composes organically).

## Next steps (not done here)

- `tb_grade` → palette snap → `tb_post` (contact shadow, anchor,
  ship-resize) → stage → integrate.
- `pinewatch_test.gd`: `tent_green`/`tent_red` → `dome_tent_*`;
  TENTS const + placements; old canvas tents → `_superseded/`.
- T2 composite: canopy + trunk + shadow via `tb_post`.
- `tb_variant` seasonal variants on canopies + shipped pines.
- H3 states on `dome_tent_sage/amber` via `create_object_state`.
