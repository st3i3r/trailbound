# Trailbound — Post-launch Plan (v1.0 → v1.4+)

| | |
|---|---|
| Date | 2026-10-17 |
| Status | Approved. Replaces the same-day "redesign v2" draft, which pulled v1.1+ content into launch scope |
| Amends | `GAME_DESIGN.md` §29 Phase 7 and §33.2 via **D-29** (2026-10-17); D-26 and D-28 amended; Q14/Q15 re-dated |
| Schedule of record | `GAME_DESIGN.md` §33.2, as reordered here. This plan adds the file/test detail behind it |

**Headline:** v1.0 ships exactly the design (three sites, ~34 days, ads + Remove Ads). The first
update is a small, data-driven **depth update** — Reputation soft-fail, night modifiers, Glasscoast —
then the design's own post-launch priorities follow: Volume II, platform, Seasons, the coast.

## 0. Why this order

- **v1.0 is done content-wise.** The design's remaining pre-launch work is store readiness (§29
  Phases 5–6). Nothing in this plan enters the launch build.
- **v1.1 fixes the game's known soft spots with real data in hand**: a 1★ night still pays (no
  consequence texture) and every site plays the same puzzle shape (no night variety). Reputation +
  modifiers are cheap relative to Volume II and address exactly that.
- **v1.2+ follows the design doc's priorities**: Volume II is the finale's promise and the coin
  sink; platform + social come next; Seasons are festival-timed and cannot be rushed.
- Everything new ships as a leaf subsystem (D-ARCH-2): one scene stays, no new autoloads, one-line
  delegates on Game. [S] items are Should; [C] items are Could.

## 1. Non-negotiables (inherited, unchanged)

- Deterministic seating puzzle, full preview, breakdown strip. No RNG in scoring.
- Single currency; no debt, upkeep, decay; refund-until-Goodnight.
- No fail state, no energy, no premium currency, no paywalls, no streaks, no FOMO (§33.6).
- Real-time crew never blocks the arc; coins never buy time.
- Ethical ads only: rewarded (double tips, crew speed-up), capped interstitial between days, one-time
  Remove Ads (§24).
- Every update re-runs the sim and its guardrails before release (§33.6); full `--smoke` + all
  suites stay green at every commit.

## 2. Phase 0 — Guardrails (before any feature work)

Goal: every later change is CI-guarded, and release data exists to steer v1.1.

1. **CI workflow** — `.github/workflows/ci.yml`: headless Godot 4.7.2, run the 14 suites +
   `--smoke`, and `python tools/sim.py` in guardrail mode (the report exists; add a nonzero exit
   when a §6.9 guardrail breaks).
2. **Push `master` to `origin`** and enable branch protection so a red build blocks merges.
   (Master is currently local-only ahead; this is the one user-side prerequisite.)
3. **Analytics event schema** defined now so Phase 1's Firebase wiring implements it on day one:
   `day_complete`, `phase_enter`, `ad_impression`/`ad_fill`, `iap_funnel`, `daily_played`,
   `session_start`. The Phase 2 gate reads these; do not ship Phase 1 without them.

**Done when:** green CI on master; a deliberately perturbed guardrail turns the job red;
event schema checked into the repo.

## 3. Phase 1 — Store readiness → v1.0 ships

This is §29 Phases 5–6, executed as written. No new product scope.

- **Platform SDKs** (GDD §29 Phase 5): AdMob + UMP consent and privacy options; Remove Ads
  (purchase, pending, restore, refund — verified with license testers); Firebase
  Analytics/Crashlytics/Remote Config; the Daily reminder and crew notification with quiet hours and
  caps. Acceptance: the §29 Phase 5 row, verbatim (test units incl. no fill, EEA debug geography,
  §23 budgets with ads on).
- **Privacy/legal**: policy + Play data-safety updated for the SDKs; `LEGAL/` docs refreshed.
- **Store**: closed test (12 testers × 14 days, English + Vietnamese), listing, pre-launch report,
  staged rollout 10/50/100%, vitals watch. Acceptance: §29 Phase 6 row (crash-free ≥ 99.5%).
- **Cloud save**: not in v1.0 by design — Android Auto Backup covers device moves (§22); Play Games
  Saved Games arrives with v1.2. Residual risk accepted and tracked (see §7).
- **Do start Phase 2's sim work during the closed test** — GDD already plans this, and it is the
  only way v1.1 ships 4–6 weeks after rollout.

**Cut rule:** if the closed test slips, postpone v1.1's start, never the store fixes.

## 4. Phase 2 — v1.1 "Depth update"

Order matters. Sim before UI, always.

0. **Sim-first (mandatory, gate).** Extend `tools/sim.py` with the Reputation and modifier terms and
   run all variants × seeds **before** writing UI or shipping data. Per the GDD convention, any
   change to §6 re-runs Appendix C; this plan re-runs §6.9 and reports before/after medians. If a
   guardrail cannot hold (arc 30–40, casual ≤ 50, purchase floor), tune the terms — not the
   guardrail — until approved.
1. **Reputation soft-fail** — new leaf `systems/reputation.gd`, state `reputation` per site
   (derived from the existing rolling 15-review mean). Below 2.0: next morning's board is one
   request smaller. Below 1.0: one regular skips the night. Never ends the run; recovers in 2–3 good
   nights. The trailhead queue (already visual) becomes functional: 2+ parties turned away in a
   night shave tomorrow's board by one. Game keeps 1-line delegates; save schema bump + migration
   fixture (§30).
2. **Night modifiers** — `data/modifiers.json` + one term in `Seating.resolve_guest`, rolled seeded
   at morning, shown on the board and in the night summary. Storm / Quiet / Full house / Festival
   first. **Solver check:** every modifier night must be solvable to at least its star target for
   the current build (the sim's seating solver already exists — reuse it in CI).
3. **Glasscoast** — site 4: layout, painted ground + objects via the existing PixelLab pipeline,
   site row, one new regular (reuse the Volume II draft archetypes). Unlocks from the Volume I
   finale, as the map teaser already promises. **Art-gated:** if the ground bake/objects are not
   ready at the cut, Glasscoast slides to v1.2 and the systems half ships alone. Cut order: Glasscoast
   → accessibility polish → nothing else (Reputation + modifiers are the core).
4. **Accessibility pass** — deliverables: color-blind-safe trait/socket shapes (not hue alone),
   dynamic type beyond large/small, calm mode (demotes the demand queue + ambient motion). Screen
   reader: **research spike only** — no public promise until the spike proves deliverable on Godot
   Android.
5. **Strings**: every new string EN + VI from day one; VI width lint stays advisory.

**Gate:** sim guardrails green (or an approved §6.9 amendment); suites + new
`test_reputation`/modifier cases green; crash-free holds on the update; D1/D7 read against v1.0.

## 5. Phase 3 — v1.2 "Volume II + platform"

- **Volume II** (§33.3) as designed: 5 pages/site, two restorations per site, Gatherings (~24
  briefs, solver-checked). Post-arc sim mode checks §6.11 guardrails (§6.11 numbers stand).
- **Trail Passport** (§33.5) + **Play Games**: achievements, the opt-in Trail Daily star
  leaderboard, Saved Games (cloud save). This is where cross-device sync lands, by design.
- Camp tier-ups and the staff/service layer remain parked unless their sim probes land.

**Gate:** §6.11 guardrails hold; leaderboard reset/date behaviour verified (Q6 note in §33.5).

## 6. Phase 4 — v1.3 "Seasons"

- Seasons of the Trail + first festival week (§33.4), timed for the next festival after v1.2
  (Mid-Autumn 2027 / Lunar New Year 2028 — re-verify dates against the real launch).
- **Camp Postcards [C]** (§33.5), the share-a-night code; `Postcard.materialize` already exists and
  is tested (`test_postcard`), so this is UI + import plumbing, not new codec work.

**Gate:** §33.4 seasonal guardrails (every season re-runs the sim); live-ops rules §33.6.

## 7. Phase 5 — v1.4+ "The coast"

The hidden cove, Snowpass and the "B." collar-tag reveal (Appendix D). Content only, same rules,
Q8 must be decided first (the cove's story gates the Pinewatch letters' foreshadowing).

## 8. Parked (not scheduled; each needs a design reason + sign-off)

- **Weekly Trail** (7-day seeded arc): dropped as originally drafted. If ever built: personal-best
  only, no competitive leaderboard, no streaks.
- **Cosmetic IAP** — renamed **"Camp Kit"** (the draft's "Trail Pass" collided with the Trail
  Passport). Zero-effect supporter pack; would need a §24/§26 amendment and explicit sign-off. Not
  scheduled, not in any version above.
- **Licensed audio swap** — budget-gated (~$500–1500). Only if playtests show the generated set is
  the ceiling; keep the file-API loader (D-ARCH-4) either way.
- **New Game+**, camp tier-ups, photo mode / shareable camp image (Appendix D "Later").

## 9. Explicitly not doing

- No premium currency, gacha, energy, paywalls, streaks, FOMO, timed exclusives.
- No competitive leaderboards beyond the design's opt-in Trail Daily stars board (v1.2).
- No more traits (13 is the number); depth comes from modifiers.
- No engine rewrite; no new autoloads (leaf subsystems only, D-ARCH-2).

## 10. Verification per phase

- **Every commit:** full `--smoke` + all suites; **every release:** sim guardrails + §30 device
  passes (§30 matrix incl. ads on/off, no fill, consent declined, Remove Ads refunded).
- **v1.0:** §29 Phases 5–6 acceptance rows; crash-free ≥ 99.5% in closed test.
- **v1.1:** sim-first report approved; solver-checked modifier nights; accessibility checklist;
  save migration fixtures green.
- **v1.2:** §6.11 guardrails; Play Games leaderboard date check.
- **v1.3+:** §33.6 ("every update re-runs the sim and its guardrails").

## 11. Risks

| Risk | Mitigation |
|---|---|
| Reputation/modifiers break §6.9 guardrails | Sim-first mandate; tune terms, not guardrails; before/after report is a gate |
| Modifier nights feel unfair | Seeded + shown at morning; solver-checked; §6.9 asks the player to adapt |
| Glasscoast art slips | Art-gated slide to v1.2; systems update ships regardless |
| SDK wiring drags (UMP/IAP/review) | It is already §29 Phases 5–6; accounts + testers early ("Do now", §29) |
| v1.1 doesn't move retention | It is cheap; D1/D7 + finisher share decide v1.2 scope, not vibes |
| Repo push / CI setup | Phase 0; branch protection; one user-side prerequisite |
| Solo-dev scope | Parked list is explicit; phase gates; cut Glasscoast first, never the sim |

## 12. Status

- [x] Plan v2 approved; GDD §33.2 / §29 Phase 7 / D-26 / D-28 / Q14 / Q15 amended via D-29
- [ ] Phase 0 — CI + sim guardrail mode + push + event schema
- [ ] Phase 1 — store readiness; v1.0 ships
- [ ] Phase 2 — v1.1 depth update (sim-first → Reputation → modifiers → Glasscoast → a11y)
- [ ] Phase 3 — v1.2 Volume II + Trail Passport + Play Games
- [ ] Phase 4 — v1.3 Seasons + Camp Postcards
- [ ] Phase 5 — v1.4+ the cove, Snowpass, "B." reveal
