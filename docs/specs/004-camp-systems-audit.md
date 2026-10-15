# Spec 004 — Camp systems audit (six-system design input)

Status: **Landed** — item A shipped 2026-10-13; B folded into spec
003 (sockets/sit-spots live); C landed as decor `attract` rows +
board-roll bonus weights (cap ≈50% of base mix); D landed as
cast-time rare-beat rolls in `SimDirector.cast_night` (meteor +
night-swim rows, rolled off `w.rng`); E rejected with reasons below.
Source: `systems.txt` (six stitched systems), audited against code.

## Verdicts

| § | Their system | Verdict |
|---|---|---|
| 1 | Nightly ledger — `Rent × Campers × WeatherMod` itemized payout + save on Next Day | **Redundant — ours is better.** `goodnight()` already itemizes (fees+tips+meals+gather) into `night_summary`, commits at Goodnight, saves on sleep. Their weather-multiplier-on-earned-coins is punishing noise; ours shapes the *offer* upstream (demand matrix). Rejected |
| 2 | Upgrades — linear `UPGRADE_TIERS` → branching `BLUEPRINTS` w/ categories + `allowed_slots` | **Mechanism shipped** (pad shelter chain platform→cabin, flat-id hot-swap, `{id,cells}` saves). Seeds adopted: item B below. Branching-economy-tracks rejected as scope creep — cosmetic variants at a tier fit better |
| 3 | Maintenance — `accumulated_dirt` → trash overlay → [E] clean, dirty = yield 0 + rep penalty | **Genuinely new, needs design call** — item E. As written it's a penalty loop (pressure); the cozy-fit form suspends a *bonus* |
| 4 | Camper spawner + `ACTIVITY_WEIGHTS` phase rolls | **Mechanism rejected** — auto-spawn bypasses the board→seat puzzle; `randf` phase rolls break determinism and no runtime phase transitions exist inside a cast. Seeds adopted: items C + D |
| 5 | Tag-based cooking — tags+tiers, exact / fusion / dubious-failure branches | **2/3 branches shipped + one they don't have** (pair-match w/ `any_fish` proto-tags, `camp_mash` fallback, `oven_hint` keeps ingredients). The gap was the fusion tier — **item A, shipped** |

## Adopted / landed

- **A. Fusion cook tier — LANDED.** `data/fusion.json`: kind-pair →
  dish rows (fish+staple → Improv Fry-Up 15c, fish+forage →
  Campfire Poach 14c, fish+fish → Double Catch 16c, forage+staple →
  Camp Plate 12c, forage+forage → Forager's Mix 10c).
  `Game._fusion_match()` sits between `_match_recipe` and the
  `camp_mash` fallback — exact and oven-hint precedence preserved.
  Fusions sell as meals and log in `pairs_tried` but **stay out of
  `recipes_cooked`** — improvisations aren't cookbook discoveries.
  Deliberately no `staple+staple` row: two starches still produce
  slop — the failure tier survives. Smoke asserts cover all three
  outcomes.

- **B. Socket `kind` field — adopted.** The doc's `allowed_slots`
  categories fold into spec 003's socket schema: `{id, kind,
  px_offset, facing}` — slots are typed so occupancy claims can't
  cross categories (a cushion never claims a shelf point).

- **D. Seeded rare beats — adopted into PLAN D4.** Their
  "1%-night-swim" outlier idea lands as low-weight scenario rows
  rolled from `w.rng` **at cast time** — deterministic delight
  inside the contract, not `randf` at tick time.

## Design calls — decided 2026-10-14 (owner sign-off, SOTA pass)

- **C. Decor→demand attraction — ADOPTED (tag→mix form).**
  SOTA audit (Neko Atsume per-item visitor tables, AC Pocket Camp
  "loved furniture" gates, Sims lot traits, Cozy Grove decor tags,
  Bear & Breakfast prestige): attraction is always **per-item
  semantic** — never a scalar score — and never inflates raw
  headcount (`open_pads+1` stays the quantity law). Mechanism:
  decor rows gain `attract` (archetype or trait id; trait-level is
  primary — traits are the puzzle currency); at board roll, placed
  pieces add capped bonus weight into a copy of `archetype_mix`
  (cap ≈50% of base so site identity + weather stay louder).
  `Seating.board` signature unchanged — deterministic, same seeded
  rng. Legibility rule: the tag must show on the shop/card row.
  Stretch (parked): Pocket Camp form — a signature piece gates a
  one-shot named visitor; folds into the regulars/rare-beat rows.
- **E. Maintenance chore — REJECTED.** SOTA audit found **no
  cozy-genre decay on placed decoration, at all**: ACNH (Eguchi:
  absence acknowledged, never punished — weeds yield materials),
  DDV night thorns (persist harmlessly; clearing *pays* — players
  hoard them), Stardew (decay on production crops only, never
  furniture), B&B (litter = pickup-for-currency). Travellers
  Rest's dirtiness is the one suspend-effect that exists, and it
  is the core sim loop there *plus* automatable via hire. If a
  tend-verb is ever wanted, the genre-correct form is **yield
  nodes** — leaf-litter washing up near decor that pays materials
  on clear (never suspends, persists if ignored) — parked, since
  errand spots already fill the collect-walk slot.

## Rejected outright

`CozyClock`/`EventManager` (don't exist — spec 002), rent-multiplier
payouts, physics-capture triggers, `randf` outside seeded draws,
`z_index` locking under `y_sort`.
