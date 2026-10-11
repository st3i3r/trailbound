# GAP ANALYSIS — My Café 3D: toy vs production

> **Phase A closure (Oct 10, 2026):** gaps #1 (audio — procedural WebAudio engine, zero assets), #6 (pressure — telegraphed rushes + Elena the critic), #7 (starter — sparse 15-cozy opening), #8 (economy — soft caps, duplicate penalty, ingredient stock), #9-partial (retention — daily quests), #12 (iOS — context-loss recovery), and the analytics foundation are now CLOSED. Test suite: 22 → 58 green. Statuses below marked ✅ where closed.

**Method:** read all of `index.html` (1,655 lines), `server.py` (1,201 lines),
`tests/test_endpoints.py` (354 lines, 22 tests), `README.md`, and
`PRODUCTION_PLAN.md` (704 lines, the target spec). Every count below was
enumerated from the code, not estimated. Status values: **DONE** = shipped and
verified · **PARTIAL** = exists but incomplete vs plan · **MISSING** = not present.
Effort: **S** < 1 day · **M** = days · **L** = weeks.

**One-line verdict:** the tech foundation is real (server-authoritative economy,
working 3D, scripted FTUE, 22 green tests). Everything that makes a player stay
past day 3 — audio, story, progression, events, retention, social, content volume —
is MISSING. It is a polished prototype, not a game.

---

## Content census (verified counts vs plan launch targets)

| Content | In code | Plan target | Gap |
|---|---|---|---|
| Decor items (coin-buyable) | 12 | 40 (6 sets × 4 + 16) | **28 items, 0 sets** |
| Premium decor (Stars-locked) | 5 | included in 40 | exist but unpurchasable (no bot) |
| Playable drinks | 6 | 12 | **6** |
| Locked drink stubs | 6 (name + icon only) | — | stubs, not content |
| Ingredients | 6, 30/day stock ✅ | 8, 30/day stock | 2 ingredients |
| Regulars | 1 (Maya) | 5 | **4 regulars** |
| Story beats | 1 (Maya intro modal) | 15 (5 × 3) | **14 beats** |
| Dialogue choices | 0 | 2-option choices per beat | all |
| Playable rooms | 1 (Main Hall) | 3 | 2 stubs, **no unlock path exists** |
| Organic events | 2 (telegraphed rush, critic) ✅ | 4 (rush, viral, critic, rivalry) | **2 (viral crowd, rivalry)** |
| Audio (music/SFX/ambience) | procedural WebAudio engine ✅ | ~15 SFX + 3 loops + café bed | volume/content tuning only |
| Analytics events instrumented | 12 core events ✅ | ~35 named events | extended events |
| Push notifications | 0 (shapes documented in README) | 6 triggers + scheduler | **all (needs bot token)** |
| Daily quests | 3/day from 6-quest pool ✅ | 3/day | quest variety over time |
| Photo mode / share cards | 0 | both | all |
| Group orders / referral / leaderboard | 0 / 0 / 0 | all three | all |
| Visit tips / loves | 0 (tour is read-only) | both | all |
| Café level / XP | 0 | 30 levels | all |
| Decor set bonuses | 0 | 6 sets | all |
| Recipe mastery | 0 | per-drink mastery | all |
| Settings / help / codex | 0 | settings sheet | all |
| Recipe book view | 1 text line (`bookLine`) | full view + mastery badges | ~all |
| Regulars view | 0 | cast + arc progress | all |
| Privacy policy / terms | 0 | required pre-launch | all |

---

## 1. Gameplay depth — PARTIAL → STRONG (Wave 2)

**Wave 2 (2026-10-10) update:** three progression systems landed, all
server-authoritative, all tested (108-test suite):
- **Café levels (30):** 1 XP/serve +1 when tip rounds ≥1; thresholds
  20·n(n+1)/2 cumulative (L2 at 60 XP); 25·level coins per level-up; every
  5th level a free decor from the player's lowest-owned set (server picks).
  Level-up modals queue through the FTUE.
- **Decor set bonuses:** completing all items of a set (6 sets; arc items
  count once unlocked+placed; premium excluded) gives +15% cozy
  multiplicative on those items. Per-set x/y progress + gold badge in the
  decor panel, toast on completion.
- **Drink mastery:** correct serves counted per drink; ★/★★/★★★ at 10/25/50
  serves → +5%/+10%/+15% base price before tip math. Stars in the recipe book.

**Still missing vs the plan's depth audit:** brew-queue planning (no second
brew slot), day-end spend *decision* (summary shows numbers, no choices),
room unlocks, ingredient-shortage events, weekend rivalry.

**Exists.** The minute-to-minute triage loop is real and server-authoritative
(`server.py`: `spawn_customer` ~L396, `advance` ~L478, `_a_brew` ~L890,
`_a_serve` ~L920): customers arrive on rep-scaled timers, patience rings are
real deadlines, brewing is timed (4s base, `brew_time()` ~L360), serving the
right drink pays price + 20%×tip-mult. Recipe discovery by experimentation
works. The FTUE teaches it in <3 min (`index.html` FTUE controller ~L1338–1530).

**Decisions the player actually makes today:** which customer to tap first
(weak — bubbles show patience but no triage pressure at 4 max customers and
60s+ patience), which 1–3 ingredients to brew (real, but only 6 recipes to
find), where to place decor (real but shallow — see #7), when to end the day.

**Missing vs plan's depth audit (§3):** the plan's minute layer requires brew
*queue* planning (no second brew slot exists — one brew at a time, nothing to
plan), discovery *risk* (no ingredient stock, so experimenting is free — the
"risk it or play safe" decision doesn't exist), and pre-brew before telegraphed
rushes (no organic rushes exist). The sitting layer requires a spend *decision*
at day end (the summary shows numbers but presents no choices — coins just
accumulate) and coziness-per-tile layout puzzles (no sets, no caps, so the
answer is always "buy the highest cozy/tile you can afford" — a spreadsheet,
not a puzzle). The lifetime layer requires café *identity* choices (no sets,
no room unlocks, no arc choices — nothing to specialize in). The social layer
doesn't exist.

**Effort to close:** M for queue/stock/rush mechanics; L for sets + identity
systems.

## 2. Content volume — MOSTLY DONE (Wave 1 + Wave 2)

**Wave 1 (2026-10-10) update:** 40 decor in `CATALOG` (35 across 6 sets:
blush-parlor 7, teal-terrace 7, golden-hour 7, botanical 5, noir 5, festival 4;
5 premium pack; 2 arc-reward locked), 12 recipes (incl. story-locked
`nightingale`).
**Wave 2 update:** the collection structure the plan asked for now exists —
set bonuses (see §1), arc-reward decor granted by story beats
(`brass-clock`, `signed-edition`), referral trophy (`friendship-fern`,
in no set, not for sale).

**Still missing:** room unlocks (Terrace/Lounge), season structure, 2 extra
ingredients the plan mentions.

**Exists:** 17 decor builders in `index.html` `BUILDERS` (~L605–813), 12
coin-buyable + 5 premium; 6 recipes in `server.py` `RECIPES` (~L64); 6 locked
recipe stubs (`LOCKED_RECIPES` — name/icon/hint only, zero gameplay).

**Missing:** 28 more decor to hit 40, 6 more drinks to hit 12, 2 ingredients,
and — more important than raw counts — **zero collection structure**: no sets,
no set bonuses, no wildcards. The plan's whole "why keep decorating" answer
(§4: 6 sets with mechanical bonuses) is absent, so decor #13 adds nothing that
decor #12 didn't.

Content exhaustion math: a player discovers all 6 recipes in ~2 days and can
buy the full 12-item catalog within the first week (starter grants 58 free
cozy; 150 starting coins + streaks). After that there is nothing new to get.
**Effort:** M per 10 decor items (procedural) + catalog wiring; L for the
set-bonus system.

## 3. Narrative — STRONG (Wave 2: 14 new beats)

**Wave 2 (2026-10-10) update:** a server-side arc state machine per regular
(`{beat, pool, progress}` in the `w2` blob; triggers checked on serve/day
rollover; all modals/quests suppressed until `ftue_done`). 14 new beats:
- **Maya 2–3:** guided mint-mocha discovery while she's seated (hint chip in
  the serve panel) → 5 more serves → "Published": `signed-edition` decor via
  `grant_decor_unlock` + dedication modal. FTUE beat 1 unchanged.
- **Mr. Chen** (grey-sepia, pocket-watch): pool at 10 lifetime serves →
  stopwatch intro → 5 consecutive espressos with brew-ready→serve <20s (any
  other/wrong serve resets) → espresso served to him → `brass-clock` +
  ticking note.
- **Zoe** (pink/gold, phone): pool at cozy ≥40 → photo modal +100 coins
  (references photo mode) → 3 correct serves → viral crowd (10 customers/3
  min via scheduled spawn waves) → brand-deal 2-option choice: accept +800
  coins + 📢 sponsored flag on the visit card + purist (Maya/Chen) patience
  −10% for 3 days, or decline +0.2★ rep. Server-enforced.
- **Rafi** (teal scrubs, evening-only at rep ≥4★ — the Phase-A evening
  crowd): pool at 4★ → 3 distinct evenings served → "The Nightingale"
  invented (`grant_recipe_unlock("nightingale")`, he orders it thereafter) →
  serving him the nightingale → ward rush (5 at once, mocha/nightingale).
- **Elena** (extends the existing critic, not duplicated): 3-visit arc —
  3/3 scores ≥4 → "Five Stars" (+0.5★, 3-day surge); 0–1/3 → scathing
  (−0.5★) + comeback quest (next visit scores double); 2/3 → mixed, no arc
  outcome. Per-visit scoring unchanged.

Regulars are distinguishable in 3D (palette + cached-geometry accessories:
pocket-watch disc, phone, scrub cap, Maya's bun). New regulars enter the
walk-in pool (30% of spawn ticks) only after beat-1 conditions are met.

**Still missing:** plan's Maya beat-1 dialogue *choice* (patience vs tip
trait — superseded by the FTUE beat), seasons adding ≥1 regular.

**Exists:** Maya the novelist — seeded deterministically as the first customer
(`server.py:seed_maya_if_needed` ~L440), teal-cardigan 3D look
(`index.html:makeCustomerFigure` ~L897), 1-hour patience so she never walks out
mid-FTUE, and one intro modal after the first serve (`showMayaDialogue`
~L1512: the chapter-three line). It's a good beat.

**Missing:** everything else. Beats 2 and 3 of Maya's arc (the plot-twist
guided discovery, the published-book decor reward) don't exist. The other four
regulars (Chen, Zoe, Rafi, Elena) don't exist. There is **no arc system at
all** — no beat tracking, no 2-option dialogue choices, no mechanical unlocks
from story, no "Maya has something to tell you" return hooks. The plan's
non-negotiable rule — "no arc is purely cosmetic; each unlocks a recipe, decor
item, or event" — is satisfied by zero arcs because there are no arcs.

**Effort:** L (arc engine: beat state machine + dialogue UI + unlock hooks) +
M per regular's 3 beats of content.

## 4. UI/UX — PARTIAL

**Exists:** FTUE coach marks (spotlight + tooltip + skip, ~L1338–1530),
HUD (coins/rep/cozy/day), Serve/Decorate sheets, catalog grid with category
tabs, ingredient bar, brew/serve buttons, room tabs, end-of-day summary modal,
toast system, visit banner + tour mode, ⌂ camera reset. The first-3-minutes
experience is genuinely built.

**Missing vs plan §5 screen map:** Settings (audio toggle, reduced motion,
text size — none exist), Help/FAQ (none), Recipe book *view* (one text line
`bookLine` ~L1214, no browsable book, no mastery badges), Regulars view (none),
Photo mode (none), Shop sheet (Stars buttons exist as a row, no catalog
sheet), error states beyond toasts (no offline screen, no reconnect flow, no
"sync failed, retry" UX), accessibility (no reduced-motion toggle, no text
scaling; patience ring is color + arc — the "!" under 15s from the plan isn't
there), 2D fallback button on WebGL failure (`#glerr` ~L~190 shows a dead-end
message; plan required a "try 2D mode" button).

**Effort:** M for settings/help/recipe-book/regulars views; S for the 2D
fallback and "!" indicator.

## 5. Art — PARTIAL (placeholders, cohesive but thin)

**Exists:** 17 procedural builders, all in the locked candy palette
(`PAL` ~L~580), canvas textures (checkerboard marble floor, damask wallpaper,
rug, poster, chalkboard, bookshelf spines), blob shadows, day→evening lerp,
full-establishment camera. It reads as one game. The art bible (§6) is written
and precise enough to brief the AI pipeline.

**Weakest builders** (boxes-with-paint, will not survive side-by-side with
real assets): `poster` (~L713 — a box + a textured plane), `chalk_menu`
(~L722 — two planes), `cozy_rug` (~L732 — a textured box), `hanging_ivy`
(~L677 — floating spheres). Strongest: `espresso_machine` (~L739),
`bar_counter`, `neon_sign` — actual composed forms. Customers are faceless
capsules with hair caps (`makeCustomerFigure` ~L897) — no faces, no walk
animation beyond a bounce, no sit pose variation.

**Missing:** the entire AI-GLB upgrade path is documented, not built; no
`art/` drop-in loader exists yet (builders are per-ID so it's *pluggable*,
but nothing loads a GLB today); `garden_fountain` / `upright_piano` from the
plan have no catalog IDs.

**Effort:** M to wire the GLB loader; L+ for the asset pipeline itself
(generate → auto-QA → approve loop).

## 6. Audio — ✅ DONE (Phase A)

**Confirmed zero:** `grep -i "audio\|AudioContext\|new Audio\|sound\|music"`
across `index.html` returns nothing. No WebAudio, no files, no mute toggle,
no settings entry. The game is completely silent.

**Plan requires (§7):** café ambience bed (murmur, clinks, door bell),
2 music loops + rush sting (lo-fi acoustic, 70–80 BPM), 13 named SFX with
explicit triggers (pour loop as "the ASMR centerpiece", coin arpeggio that
rises with tip size, discovery chime, walkout exhale, critic piano note),
and an audio manifest as data. *Good Pizza Great Pizza* proved cozy audio is
a retention system; we have none of it.

**Effort:** M for synthesized WebAudio SFX (no libraries needed); L for
music loops + ambience mix.

## 7. Economy & balance — ✅ GUARDED (Phase A)

**Exists:** faucets (serves 8–20 + tips, wrong-drink half price, sludge +2,
streak 25→2000) and sinks (decor 20–200, expansion 500) all server-side;
`hint` action (30 coins flat). 22 tests pin the math.

**Missing — every item the plan flagged "change before launch" (§4) is still
missing, verified in `server.py`:**
- Cozy soft caps: **absent** — `patience_mult()` (~L344) is `1 + cozy/100`
  uncapped; `tip_mult()` (~L348) is `1 + cozy/80` uncapped. Decor is pure
  power creep, no diminishing returns.
- Duplicate-decor penalty (−25%/−50%): **absent**.
- Ingredient stock (30/day): **absent** — brewing consumes nothing.
- Café level/XP: **absent**. Recipe mastery: **absent**. Daily quests: **absent**.
- Terrace/Lounge unlocks: **absent** — `_a_expansion` (~L~990) only does
  Main Hall 8×6→10×8 for 500; the Terrace/Lounge rooms are locked stubs with
  **no unlock action at all**. The 2,500/8,000-coin sinks from the plan don't
  exist, so the two biggest planned sinks are $0.
- Visit tips, event rewards, arc-completion payouts: **absent** (faucets).

**The starter-cozy flaw (real, verified):** `default_rooms()` (~L230) grants
14 placements free. Counted cozy: 6+4+3+5+3+4+5+4+4+6+3+5+4+2 = **58 free
coziness** (~665 coins of decor) at minute zero, plus the FTUE's free table
(+5) → ~63. The plan's FTUE assumed a sparse starter (1 table, 2 armchairs,
1 fern) and gates Maya's regular status at cozy ≥ 20 — trivially satisfied.
A fresh player starts at ~84% of the (planned but unimplemented) patience cap.
The restyle's density rule ("no empty first frame") directly broke the
progression curve ("decoration is earned"). Pillar 1 — *every decoration
changes gameplay* — is violated in reverse: the first 58 coziness changed
nothing because you didn't choose any of it.

**Effort:** S for caps + duplicate penalty + starter rebalance; M for stock
system + room unlocks; L for level/quests/mastery.

## 8. Monetization — PARTIAL (hooks, zero live revenue)

**Exists:** Stars catalog code (`_handle_invoice` ~L1080: 150/100/50 ★,
`createInvoiceLink` XTR shape, `successful_payment` grant in webhook
~L1150 with `purchases` table dedupe), AdsGram rewarded-ad hook
(`ADSGRAM_BLOCK_ID` TODO ~L183, `/api/ad/reward` ~L1055 grants Rush Hour
with 120s server cooldown).

**What's real vs TODO:** nothing is live. No `BOT_TOKEN` has ever been
configured (all paths guarded by `TODO_` placeholders), so **no invoice has
ever been created, no payment ever completed, no ad ever served** — $0
revenue is possible today by construction. Ad completion is **client-asserted**
behind the cooldown; the plan's S2S verification upgrade is documented, not
built. The constitution items (no Stars→coins, rooms coin-only) hold in code,
but the seasonal pass, extra brew slot rental, and the 3 additional ad
placements from the plan don't exist.

**Effort:** S to go live once the bot exists (test Stars flow); M for S2S ad
verification; L for seasonal pass.

## 9. Social/viral — STRONG (Wave 2)

**Wave 2 (2026-10-10) update:**
- **Visit tips:** `POST /api/visit/tip` (auth'd, rate-limited): 10 coins
  visitor→host, cap 3/day per visitor→host pair (`visit_tips` table),
  self-tips rejected. "💰 Tip 10" button in the visit banner; host sees it
  in the day summary ("tips received") + a `tip_received` event ping.
- **Photo mode:** 📸 button hides HTML overlays (orbit stays live) → frame →
  capture → PNG download + share text
  (`☕ Visit my café! {name} ★{rep} 🛋️{cozy}\nhttps://t.me/<bot>?startapp=visit_{id}`)
  via `navigator.share`/clipboard fallback. Zoe's beat 1 teaches it.
- **Referral fern:** `friendship-fern` catalog trophy (+5 cozy, no set, not
  for sale). New signup with `?ref=<shop>` grants it to BOTH sides (referrer
  via `pending_grants` drained on their next state load). Visit mode shows
  "🌱 Join from this café" for `?ref=1` tours; webhook handles
  `/start visit_<id>_ref`.
- **Leaderboard:** `GET /api/leaderboard` (auth'd), opt-in `lb_opt_in`
  toggle, ISO-week buckets, top 20 by weekly coins earned (tracked via
  `earn()` at every coin faucet). 🏆 tab in the client.

**Still missing:** "love this layout"/showcase, group orders, friend-activity
push (needs bot token).

**Exists:** `GET /api/visit?shop=<id>` (~L~740) returns a public read-only
snapshot; `?startapp=visit_<id>` deep link + webhook `/start visit_*`
handler renders a 3D tour mode; share button builds the `t.me` link
(~L1330).

**Missing:** everything that makes a visit *do* something. No visit tips
(plan: tip 10 → host gets 8, capped 5/day), no "love this layout", no
showcase, no photo mode, no share cards (the plan's "primary UA asset" —
every card is a player-made ad), no group orders, no referral fern, no
leaderboard, no friend-activity push ("💛 Maya tipped your café"). A visitor
today looks and leaves; there is no sender incentive and no receiver hook,
so the viral loop has K-factor ≈ 0 by design.

**Effort:** M for tips/loves; L for photo mode + share cards; L for group
orders.

## 10. Retention/live-ops — PARTIAL (Wave 2: arcs + levels + mastery are the
second and third mechanisms; push/seasons still need bot token)

**Wave 2 (2026-10-10) update:** retention no longer rests on the streak alone —
café levels (30), drink mastery stars, 5 regular arcs with return hooks
("serve Chen 5 fast espressos", "3 evenings with Rafi"), and the Elena
comeback quest are all multi-session pulls. (Daily quests, the critic, and
the analytics foundation landed in earlier workstreams — this doc was stale.)

**Still missing:** push notifications (needs bot token), seasons/event
calendar, weekend rivalry, ingredient-shortage events.

**Exists:** daily streak with escalating bonuses (`apply_checkin` ~L520,
25→2000 — the D1→D7 bridge), 3-minute day cycle with end-of-day summary.

**Missing:** daily quests (plan: 3/day, 150 coins + XP), regular-beat return
hooks ("Maya has something to tell you" — no arc system to hang them on),
shop refresh/featured item, weekend rivalry, critic visits, ingredient
shortage events, seasons (no season structure, no Season 1 content), the
90-day event calendar (exists on paper only), push notifications (zero —
shapes documented in README, no scheduler, no opt-in at FTUE end), comeback
mechanics (no catch-up coins, no welcome-back beat). Retention today rests
entirely on the streak; if the streak doesn't hook by day 3, there is no
second mechanism.

**Effort:** M for daily quests + comeback; L for events system; L+ for
seasons pipeline; M for push (needs bot + scheduler + opt-in).

## 11. Analytics — ✅ FOUNDATION (Phase A)

**Verified zero:** no analytics, telemetry, or event-logging code anywhere in
client or server. No `events` table (the `events` column on `users` is a
20-item UI toast feed — walkouts and no-seat notices — not analytics).

**Plan requires (§11):** ~35 named events (`session_start`, `ftue_step`,
`brew_start/complete`, `serve_result`, `recipe_discovered`, `decor_bought/
placed/sold`, `day_end`, `rush_start/end`, `ad_*`, `stars_*`, `visit_*`,
`share_sent`, `push_*`, `quest_complete`, `critic_visit`, `arc_beat`…),
funnel alerting (<60% step conversion), faucet/sink ratio monitoring with
alerts at >1.5/<0.7, and the KPI targets (D1 ≥ 40%, D7 ≥ 20%, D30 ≥ 10%).
Without instrumentation, **no P1 exit criterion is measurable** ("faucet/sink
ratio 1.0–1.3 in tester data" — there is no tester data) and no balance
decision can be evidence-based.

**Effort:** M (append-only `events` table + client batch-upload every 60s,
per plan).

## 12. Backend/ops — PARTIAL (fine for 10 users, not for 10,000)

**Exists:** single-process `ThreadingHTTPServer`, SQLite with a global
`_db_lock`, `ON CONFLICT` upserts, FTUE forward-migrations via
`ALTER TABLE` + grandfathering, `/healthz`, 22-test suite (not automated).

**Not production-ready:** no SQLite WAL mode (default rollback journal —
write contention under concurrent users), no backups (plan: hourly snapshots
+ daily off-box copy — none), no log rotation or structured logs (bare
`print`), no monitoring/alerting, no CI (tests exist but run manually), no
`Cache-Control`/compression strategy for static assets (every load re-fetches
691KB three.js with `Cache-Control: no-cache`), no Postgres migration path
tested, no load testing (concurrency behavior under even 100 simultaneous
players is unknown), single box = single point of failure. The plan's
production upgrade order (§13.1) is 0% implemented.

**Effort:** S for WAL + backup cron + `/healthz` (exists) + log rotation;
M for CI (GitHub Actions: py_compile → node --check → tests → headless
screenshot gate); L for Postgres path.

## 13. Anti-cheat/security — PARTIAL (good bones, known holes)

**Enforced:** initData HMAC per call (`validate_init_data` ~L192, constant-time
compare), 2s sync rate limit, 25-action batch cap, all economy server-side,
placements collision-checked, brew `ready_at` enforced at serve time,
coordinate/type validation on every action, ad-reward 120s cooldown.

**Documented gaps (all real):** ad completion is client-asserted (a rooted
client grants itself Rush Hour every 120s forever — the cooldown only paces
it); no idempotency keys on action batches (replay within the rate window is
possible); no S2S ad verification; no anomaly detection on serve rates; no
input fuzzing of the action surface (validation is per-field hand-written —
`_apply_action` catches exceptions per action, which is good, but the 12
action types have never been fuzzed); the `purchases` table dedupes by payload
but payload includes a timestamp, so double-spend protection rests on
Telegram's delivery, not ours. Multi-account (Telegram ID-bound) accepted as
residual per plan.

**Effort:** M for S2S ad verification + idempotency keys; S for an action
fuzzer in tests/.

## 14. Performance — PARTIAL (context-loss recovery added; real-device test still needed)

**Measured:** 152 draw calls / 4,814 tris after the restyle (up from 48 —
pillars + dense starter). Under the 100-call/150K-tri budget *today*.

**Trajectory problem:** ~4–6 draw calls per decor item, zero instancing
(`InstancedMesh` appears nowhere in the client). At the plan's 40-item launch
catalog in a fully decorated 3-room café, that's 200+ draw calls before
customers — over budget on the exact devices the plan names as the floor.
Texture memory is fine (canvas textures, ≤1024px), JS heap unmeasured.

**Untested where it matters:** zero real-device testing. iOS Safari — the
plan's named hard case (memory kills WebGL context, no WebGPU) — has never
run this game. No `webglcontextlost` handler exists (grep: zero hits), so a
context kill = dead black viewport with no recovery path. No 30-min soak
test, no thermal-throttle check, no low-end Android check. The P1 exit
criterion "30fps on iPhone SE during rush" is currently a wish.

**Effort:** S for the context-loss handler (rebuild scene from server state);
M for instancing repeated decor; S+M for a real-device test pass (needs
physical devices).

## 15. Platform integration — PARTIAL

**Wired:** `tg.ready()/expand()`, MainButton ("🌙 End day" → confirm →
`end_day`), haptics helper (`impactOccurred`/`notificationOccurred` on
place/serve/discovery paths), `openInvoice` flow, `t.me/share/url` share,
graceful `tg == null` degradation everywhere.

**Stubbed or missing:** the HMAC *algorithm* is unit-tested with synthetic
init_data (`test_valid_init_data_auth` crafts a real `WebAppData` signature
against the placeholder token — that path works), but **no real
BotFather-issued init_data payload has ever been validated** and the end-to-end
Telegram WebView path (real initData → real user → real Stars) has never run.
`themeParams` never mapped (grep: zero hits) — the game ignores Telegram
light/dark theme.
No `SettingsButton`, no `viewportChanged`/safe-area handling beyond static
CSS, no Mini App Bar considerations, no closing-confirmation, no
`requestWriteAccess` for the push-notification opt-in the plan requires at
FTUE end. Offline → the page just fails fetches; the "demo mode with banner"
from the plan doesn't exist (local-server mode needs the server running).

**Effort:** S for theme mapping + SettingsButton; M for push opt-in flow;
S for one real-Telegram end-to-end test (the highest-value hour).

## 16. Legal/compliance — MISSING

**Zero:** no privacy policy, no terms of service, no data-handling
disclosure anywhere in the repo, README, or client. The server stores
Telegram user IDs, first names, and behavioral game data in SQLite with no
retention policy, no export path (plan §12 requires a "my data" DM export —
not built), no deletion path. For a Telegram mini app this is a launch
blocker, not polish: platforms and payment providers (Stars) expect it, and
"we'll add it later" is how you get delisted.

**Effort:** S (one page + `/privacy` route + data export/delete actions).

---

## TOP 12 gaps, ordered by PLAYER IMPACT (Phase A update)

~~1. **The game is silent.**~~ ✅ CLOSED — procedural WebAudio engine (pour/steam/coin arpeggio/murmur bed/generative pad), mute toggle persisted.
2. **Fun is unvalidated.** No human has playtested the triage loop. If serving isn't fun, everything else is paint on a broken toy. (S — play it)
3. **Content cliff at day ~7.** 6 recipes discoverable in 2 days, 12 decor buyable in a week, then nothing new. Players leave when the catalog ends. (L)
4. **Nothing to work toward.** No levels, no sets, no mastery — progression is rep + quests now, but no long-term goal exists. (L)
5. **Nobody lives here.** One story beat total; no regulars with arcs, no dialogue, no "Maya has something to tell you" reason to return. (L)
~~6. **Days are flat.**~~ ✅ CLOSED — telegraphed rush hours + Elena the critic's mystery visits give every day texture.
~~7. **You start rich.**~~ ✅ CLOSED — sparse 15-cozy starter; the FTUE table earns progress toward 20.
~~8. **No economy guardrails.**~~ ✅ CLOSED — soft caps (+75%/+100%), duplicate penalty (100/50/25%), 30/day ingredient stock + 20-coin restock.
9. **Retention is two mechanisms.** Streaks + daily quests live — no push, no comeback. D7 will still sag without them (needs bot token). (M)
10. **Social is a dead end.** Visits are look-don't-touch; no tips, no photo mode, no share cards. K-factor ≈ 0 by construction. (M–L)
11. **No money can move.** Stars/ads untested, unconfigured — revenue is $0 by construction, and ad rewards are client-asserted (exploitable on day one). (S–M)
12. **iOS Safari never tested.** Context-loss recovery added ✅, but no real-device test. A black viewport on iPhones is still the launch-ending risk. (S)

## Toy vs production — the 5 things that make it feel like a toy today

| # | Toy signal | What production looks like | Phase A |
|---|---|---|---|
| 1 | ~~**Silence.** No sound of any kind.~~ | Pour hiss, coin arpeggio, café murmur — the ASMR layer. | ✅ closed |
| 2 | **Nobody's home.** Faceless capsules; one story beat; no regulars. | 5 regulars with arcs, dialogue choices, return hooks. | Phase B |
| 3 | **Thin to earn.** No levels, sets, mastery — but daily quests now give structure. | 40-item set-based catalog, 30 café levels. | Phase B |
| 4 | ~~**No pushback.**~~ Rushes + Elena give days texture. | Weekend rivalry, viral crowd events. | ✅ partial |
| 5 | ~~**Starts solved.**~~ Sparse 15-cozy start; progression earned. | — | ✅ closed |

---

## Appendix: verified starter-cozy math

`default_rooms()` (`server.py` ~L230–257) grants 14 placements. Cozy values
from `CATALOG`: bar_counter 6 + espresso_machine 4 + chalk_menu 3 +
wooden_table 5 + potted_fern 3 + armchair 4 + wooden_table 5 + armchair 4 +
paper_lantern 4 + cozy_rug 6 + potted_fern 3 + bookshelf 5 + paper_lantern 4 +
poster 2 = **58**. FTUE grant adds wooden_table (+5) → **~63 opening cozy**.
Effects at open: patience ×1.63, tips ×1.79 (uncapped). Plan's Maya-regular
gate (cozy ≥ 20): passed before the first tap. Plan's proposed patience soft
cap (+75% at 75 cozy): a new player starts at 84% of it.
