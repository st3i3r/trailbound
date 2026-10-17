# Trailbound — Redesign Plan (production-grade v2)

**Date:** 2026-10-17
**Status:** Approved for implementation (user: "Approve, write the details plan")
**Supersedes:** `PLAN_gameplay.md` (2026-10-13 depth audit — every item listed
there is now shipped; that file is replaced by this one).

This plan is the product/engineering delta on top of `GAME_DESIGN.md` v3.1
and `ARCHITECTURE.md`. It does **not** rewrite the design; it adds the
systems that make the game production-grade: stakes, replayability, a 4th
site, a cosmetic IAP, social, accessibility, audio, cloud save, CI, and
store readiness. It respects the cozy contract (no energy, no premium
currency, no gacha, no fail state, no paywalls).

## 0. Non-negotiables (inherited)

- Deterministic seating puzzle with full preview + breakdown strip.
- Single currency, no debt/upkeep/decay. Refund-until-Goodnight.
- No fail state, no energy, no premium currency, no paywalls.
- Real-time crew never blocks the arc and never expires.
- Ethical ads: rewarded only (double tips, crew speed-up), occasional
  interstitial between days, one-time Remove Ads.
- Leaf-subsystem pattern (D-ARCH-2): new systems ship as `systems/*.gd`
  leaves with one-line delegates on Game. No new autoloads.
- 14 test suites + `--smoke` stay green at every commit.

## 1. Vision delta (what changes vs. v3.1)

| Area | v3.1 | Redesign |
|---|---|---|
| Arc length | 3 sites, ~34 days | 4 sites (add Glasscoast), ~40 days |
| Stakes | none (a 1★ night still pays) | soft-fail Reputation (no game over) |
| Puzzle variety | identical shape, different numbers | night modifiers (Storm/Quiet/Full house/Festival) |
| Post-arc | Volume II (v1.1) | restorations integrated into the arc; + New Game+ |
| Monetization | rewarded ads + Remove Ads | + one cosmetic "Trail Pass" IAP ($4.99) |
| Social | none | photo postcards (share a camp code) |
| Retention | Trail Daily (1/day) | + Weekly Trail (7-day seeded arc) |
| Accessibility | reduced motion/flashing, text scale, left-handed | + color-blind, dynamic type, calm mode, screen-reader labels |
| Audio | generated WAVs | licensed/CC0 set |
| Platform | mock SDKs | real UMP/IAP/Firebase/crash/cloud save |
| Ops | local runs only | CI (sim + 14 suites + smoke) |

## 2. Phase plan (4 weeks each, with gates)

Each phase ends with a re-plan checkpoint (per §29 of GAME_DESIGN). No
phase starts until the previous one's tests are green and the sim guardrails
hold.

### Phase 1 — production floor (4 weeks)
**Goal:** the game is shippable to a closed test without embarrassment.

1. **Reputation soft-fail** (`systems/reputation.gd` leaf)
   - New `reputation` float (0–5) per site, derived from rolling 15-review
     mean (already computed in `rating()`).
   - Below 2.0: next morning's board shows one fewer request.
   - Below 1.0: one regular skips that night.
   - Never ends the run; recoverable in 2–3 good nights.
   - "Demand at the gate" becomes functional: turning away 2+ parties in a
     night reduces tomorrow's board by one.
   - Files: `systems/reputation.gd`, `game.gd` delegates, `seating.gd` (board
     size), `pinewatch_test.gd` (gate visual already exists).
   - Tests: `test_reputation.tscn` (new) — below-threshold board shrink,
     recovery, gate visual.
   - Guardrail: median arc still completes day 30–40.

2. **Night modifiers** (data + scoring hook)
   - New `modifiers` table in `data/modifiers.json` (Storm/Quiet/Full house/
     Festival). Rolled at morning, seeded by save+site+day.
   - `Seating.resolve_guest` gains a `modifier` param applied to the stars
     formula (one term delta per modifier).
   - UI: chip on the booking board + night summary.
   - Files: `data/modifiers.json`, `seating.gd`, `game.gd` (roll), UI sheets.
   - Tests: extend `test_seating` with modifier cases.
   - Guardrail: modifier nights must not break the 1.4 purchases/day floor.

3. **Glasscoast (4th site)**
   - New layout `layouts/glasscoast.json`, site row in `sites.json`,
     `SITE_STAGE`/`SITE_PROPS` entries, painted ground + object layer.
   - New archetypes? Reuse existing mix; add "Photographer" (already in
     Volume II draft) as a Glasscoast regular.
   - Art: reuse the PixelLab pipeline; one new ground bake + objects.
   - Tests: extend `test_content` (layout lint), add `test_glasscoast.tscn`
     smoke (travel there, seat, goodnight).
   - Guardrail: arc complete day ≤ 45 with Glasscoast.

4. **SDK wiring (Platform real impls)**
   - UMP consent (Ads autoload), Remove Ads IAP (Platform.iap_restore +
     entitlement), Firebase Analytics, crash capture (report_nonfatal).
   - Replace mocks behind the same seams; no gameplay change.
   - Files: `autoload/ads.gd`, `autoload/platform.gd`, new `platform_android.gd`.
   - Tests: `test_platform` extended with consent/IAP mocks.

5. **Cloud save + account**
   - Anonymous Google Play Games sign-in; `cloud_save_push/pull` already
     fed by `Save.commit`. Add pull-on-boot + conflict resolution
     (newer-wins by day).
   - Files: `autoload/save.gd`, `autoload/platform.gd`.

6. **CI**
   - GitHub Actions job: run `tools/sim.py` guardrails + all 14 suites +
     `--smoke`. Fail the build on regression.
   - Files: `.github/workflows/ci.yml`, `tools/sim.py` (add guardrail mode).

**Phase 1 gate:** closed-test build, crash-free ≥99%, sim guardrails green
in CI, store listing draft.

### Phase 2 — depth + delight (4 weeks)
**Goal:** the game has a reason to come back daily and weekly.

7. **Trail Pass cosmetic IAP** ($4.99)
   - Campfire skins, tent variants, dog bandanas, hut paint. Zero gameplay
     effect. Stackable with Remove Ads.
   - Files: `autoload/ads.gd` (entitlement), `ui/settings_sheet.gd`,
     decor catalog rows with `unlock: "iap:trail_pass"`.

8. **Weekly Trail**
   - A 7-day seeded arc with a completion score (time + stars). Weekly
     leaderboard via Play Games (optional, opt-in).
   - Reuses the seeded-board + seeded-weather machinery; no new sim.

9. **Photo postcards (social)**
   - `Postcard.materialize(code)` already exists (§33.5). Add a "share camp"
     button in settings that copies a code; "visit camp" imports a
     wanderer guest into tonight's board.
   - No accounts, no servers — code-based, like Animal Crossing dream codes.

10. **Accessibility pass**
    - Color-blind palette swap (distinct shapes, not just hues).
    - Dynamic type beyond large/small (system font scale).
    - Screen-reader labels on the seating strip.
    - Calm mode (disables demand-queue visual + ambient pressure).
    - Files: `ui/ui_tokens.gd`, `ui/ui_kit.gd`, `ui/ui_feel.gd`,
      `pinewatch_test.gd` (calm mode flag).

11. **Licensed audio**
    - Replace generated WAVs with a licensed/CC0 set (2–3 tracks + SFX).
    - Budget: ~$500–1500. Keep the file-API loader (D-ARCH-4) so un-imported
      assets still work.

**Phase 2 gate:** closed-test retention data (D1/D7), audio + accessibility
review, store listing final.

### Phase 3 — content + polish (4 weeks)
**Goal:** v1 ships complete.

12. **Volume II restorations integrated into the arc**
    - The 6 restorations (Fire Tower, Pond Dock, Bamboo Treehouse,
      Bathhouse, Observatory, Long Table) become part of the arc: each site's
      restoration stages unlock the next site's pad tags. Coins flow into
      structure, not hoard.
    - Cut the "Bamboo Treehouse 9th pad" if it doesn't fit the 640px view
      (verify first).
    - Cut camp tier-ups (Signpost→Trail Gate, etc.) if the sim pass doesn't
      land.

13. **New Game+**
    - Replay the arc with a different trait-weight seed and a "veteran board"
      (more conflicts, tighter pads). Cheap content multiplier.

14. **Content polish**
    - Simplify the Food Blogger elite mechanic (3 traits, no elite flag).
    - Replace Moped/Chicken Coop cosmetics with 2 higher-quality hero
      cosmetics.
    - Verify VI string coverage; expand if thin.

15. **Phase 1 re-plan gate (§29)** — re-plan after Phase 1 data; this plan
    is a draft until then.

**Phase 3 gate:** store submission, launch.

## 3. Detailed task list (file-level)

### 3.1 Reputation subsystem
- New `systems/reputation.gd` (leaf, D-ARCH-2).
- `Game` fields: `reputation: Dictionary` (site → float). State in save.
- `reputation_tick(site, rating)` called from `goodnight()` flow.
- `Game.reputation(site)` public delegate.
- `Seating.board` takes a `reputation` param to shrink the board.
- `pinewatch_test.gd`: gate visual (already exists as queue at trailhead).
- Tests: `test_reputation.tscn`.

### 3.2 Night modifiers
- New `data/modifiers.json`.
- `Game.roll_modifier(site, day) -> String` (seeded).
- `Seating.resolve_guest(..., modifier)` applies the delta.
- UI: chip on booking board + night summary.
- Tests: extend `test_seating`.

### 3.3 Glasscoast site
- `layouts/glasscoast.json`, `sites.json` row, `SITE_STAGE`/`SITE_PROPS`.
- Painted ground + object layer (existing pipeline).
- Art: ground bake + objects (PixelLab).
- Tests: `test_content` lint + `test_glasscoast.tscn`.

### 3.4 SDK wiring
- `autoload/platform_android.gd` (real impl behind `Platform` seam).
- UMP consent, IAP (Remove Ads + Trail Pass), Firebase Analytics, crash
  capture.
- Tests: extend `test_platform`.

### 3.5 Cloud save
- Anonymous Play Games sign-in; pull-on-boot + conflict resolution.

### 3.6 CI
- `.github/workflows/ci.yml`: sim guardrails + 14 suites + smoke.
- `tools/sim.py`: add guardrail mode.

### 3.7 Trail Pass IAP
- Entitlement in `ads.gd`; catalog rows with `unlock: "iap:trail_pass"`.
- UI in settings sheet.

### 3.8 Weekly Trail
- New `systems/weekly.gd` leaf; 7-day seeded arc; completion score.
- Optional Play Games leaderboard (opt-in).

### 3.9 Photo postcards (social)
- "Share camp" button → code; "visit camp" → wanderer guest.
- Reuses `Postcard.materialize`.

### 3.10 Accessibility
- Color-blind palette, dynamic type, screen-reader labels, calm mode.
- Files: `ui/ui_tokens.gd`, `ui/ui_kit.gd`, `ui/ui_feel.gd`,
  `pinewatch_test.gd`.

### 3.11 Licensed audio
- Replace generated WAVs; keep file-API loader.

### 3.12 Volume II integrated
- Restorations unlock pad tags; coins flow into structure.
- Cut Treehouse 9th pad if it doesn't fit.

### 3.13 New Game+
- Replay with different seed + veteran board.

### 3.14 Content polish
- Simplify Food Blogger; replace Moped/Chicken Coop; verify VI.

## 4. What I'm explicitly NOT doing

- No multiplayer, PvP, or competitive leaderboards.
- No premium currency or gacha.
- No more traits (13 is the right number; depth comes from modifiers).
- No engine rewrite (it's good; finish SDK + CI).
- No new autoloads (leaf subsystems only, D-ARCH-2).

## 5. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Solo dev scope creep | Phase 1 re-plan gate (§29) is mandatory; cut aggressively |
| Glasscoast art bottleneck | Reuse PixelLab pipeline; one ground bake + objects |
| SDK wiring complexity | Platform seam already exists; real impls slot in behind mocks |
| Reputation breaks sim guardrails | Run sim with reputation enabled; adjust guardrails if needed |
| Modifiers make puzzles unfair | Modifiers are known at morning (seeded); player adapts |
| Cloud save conflicts | Newer-wins by day; document in Save.md |
| Licensed audio cost | Budget ~$500–1500; CC0 fallback exists |

## 6. Verification per phase

- Every phase: full `--smoke` identical, all 14 suites + new suites green.
- Phase 1: CI green on a PR; closed-test crash-free ≥99%.
- Phase 2: D1/D7 retention data; accessibility review.
- Phase 3: store submission; launch.

## 7. Out of scope / cuts (if time runs short)

Cut in this order: camp tier-ups → Treehouse 9th pad → Weekly Trail →
photo postcards → New Game+. Keep: Reputation, modifiers, Glasscoast,
SDK, cloud save, CI, Trail Pass, accessibility, audio. The core game
ships with Phase 1 + 2 essentials; Phase 3 is polish.

## 8. Related docs

- `GAME_DESIGN.md` v3.1 — source of truth for rules (unchanged by this plan).
- `ARCHITECTURE.md` — D-ARCH-9..20 landed; this plan adds leaves
  `reputation`, `weekly` (new subsystems, D-ARCH-2 pattern).
- `UI_PRODUCTION.md` — production checklist; update as items ship.
- `LEGAL/PRIVACY.md`, `LEGAL/TERMS.md` — update for SDK wiring (Phase 1).

## 9. Status

- [ ] Phase 1.1 Reputation
- [ ] Phase 1.2 Modifiers
- [ ] Phase 1.3 Glasscoast
- [ ] Phase 1.4 SDK wiring
- [ ] Phase 1.5 Cloud save
- [ ] Phase 1.6 CI
- [ ] Phase 2.7 Trail Pass
- [ ] Phase 2.8 Weekly Trail
- [ ] Phase 2.9 Photo postcards
- [ ] Phase 2.10 Accessibility
- [ ] Phase 2.11 Licensed audio
- [ ] Phase 3.12 Volume II integrated
- [ ] Phase 3.13 New Game+
- [ ] Phase 3.14 Content polish
- [ ] Phase 3.15 Re-plan gate (§29)