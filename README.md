# ☕ Café Builder 3D — Telegram Mini App prototype

**Build YOUR coffee shop in 3D**: orbit around your café, decorate the
floor with procedurally-built low-poly furniture, craft drinks from real
ingredient combos (with recipe discovery), serve customers before their
patience runs out, and grow your reputation. Coziness isn't cosmetic —
it raises customer patience and tips.

**Same server as the 2D version** (`~/workspace/cafe-builder/`):
server-authoritative economy, rooms model, 17-item catalog, 6 recipes —
all validated server-side. Python standard library only, zero
`pip install`. Only the client is new: a **three.js (WebGL2)** 3D scene
instead of the 2D canvas.

**100% free stack** — three.js (MIT, vendored locally in `vendor/`),
primitives-only art, Python stdlib server, Cloudflare Tunnel for HTTPS.
No paid APIs, assets, or hosting anywhere in this build.

---

## 0. Quick local run (no Telegram needed)

```bash
cd ~/workspace/cafe-builder-3d
python3 server.py
# open http://localhost:8080/ in a desktop browser
```

Desktop browsers run in **local-server mode**: the page talks to the same
Python backend as Telegram would — one ruleset, server-authoritative,
no localStorage game state. A banner notes you're on the local identity;
everything else (economy, brewing, customers, saves) is the real thing.

**First-run tutorial (FTUE):** a brand-new player gets a scripted
coach-mark walkthrough — place a free table (granted server-side),
tap Maya the novelist's bubble, brew an espresso, serve her, and learn
the coziness→tips lesson. Skippable, resumes from `ftue_step` if you
close mid-way, never repeats for returning players. Tracked in the DB
(`ftue_step`, `ftue_done`, `ftue_grant_used`).

**Tests:** `tests/test_endpoints.py` spins up its own server on an
ephemeral port with a throwaway SQLite DB, runs 22 endpoint checks
(auth valid/tampered/expired, buy/place/move/sell incl. overlap & OOB
rejections, brew discovery/sludge/bad combos, serve payout math with
coziness, FTUE grant once-only + step flow + skip, Maya seeding,
rate-limit 429, visit 200/404, webhook 200, invoice 400s, catalog,
ad-reward cooldown), then shuts down cleanly. Stdlib only:

```bash
cd ~/workspace/cafe-builder-3d
python3 tests/test_endpoints.py
```

**Controls**: drag to orbit · scroll / pinch to zoom · tap a customer's
order bubble to take their order · Decorate mode: pick an item, tap a
floor tile to place (ghost preview shows fit), tap a placed item for
move/sell.

## 1. Create the bot (BotFather)

1. **@BotFather** → `/newbot` → name it (e.g. `MyCafe3DBot`). Copy the
   token → `BOT_TOKEN`. **Never commit it.**
2. `/newapp` → select your bot → title "My Café 3D", description,
   640×360 image → **Web App URL** = your public HTTPS URL from step 3.
3. `/setmenubutton` → point the menu button at the Web App URL.

## 2. Configure and run

```bash
cd ~/workspace/cafe-builder-3d
cp .env.example .env   # then edit: BOT_TOKEN, BOT_USERNAME, WEBAPP_URL
set -a; source .env; set +a
python3 server.py
```

`BOT_USERNAME` (without `@`) powers the viral share links:
`https://t.me/<BOT_USERNAME>?startapp=visit_<shop_id>` — friends get a
read-only 3D tour of your café.

## 3. Free HTTPS for Telegram (Cloudflare Tunnel)

Telegram requires an **https** Web App URL. The free path — no domain
purchase, no VPS:

```bash
# install once: https://developers.cloudflare.com/cloudflare-one/installation/
cloudflared tunnel --url http://localhost:8080
# → e.g. https://random-words.trycloudflare.com — use as WEBAPP_URL
```

Then register the webhook so `/start` buttons and Stars payments work:

```bash
curl "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" -d "url=$WEBAPP_URL/api/webhook"
```

The webhook answers `/start` with an **Open my café** button, handles
`/start visit_<shop_id>` with a read-only 3D tour link, auto-answers
Stars pre-checkout queries, and grants products on `successful_payment`.

> Note: `trycloudflare.com` URLs change on restart. For a stable URL,
> create a free Cloudflare account and route a tunnel to a hostname —
> still free.

## 4. Monetization TODOs

- [ ] `ADSGRAM_BLOCK_ID` in `index.html` (https://partner.adsgram.ai →
      Publishers → Ad block). Rewarded ads grant **Rush Hour**: 2× customer
      spawns for 5 minutes (`/api/ad/reward`, 120s server cooldown backstop).
- [ ] Stars catalog (live once `BOT_TOKEN` is real; enable Stars payments in
      BotFather → your bot → Payments). Amounts in `_handle_invoice`:
      **Golden Espresso Machine** (brew 2× faster forever, 150 Stars),
      **Designer Decor Pack** (5 exclusive items, 100 Stars),
      **Remove ads** (50 Stars).
- [ ] Production ad verification: verify rewards with the ad network's
      server-to-server callback instead of trusting the client alone.

## Game design reference

| System | Rule |
|---|---|
| 3D scene | three.js r170 (vendored), WebGL2, isometric orbit cam, blob shadows (no shadow maps), day→evening lighting shift, emissive lanterns/neon |
| Floor | rooms list; Main Hall 8×6 (expandable to 10×8 for 500 coins); Sunny Terrace + Upstairs Lounge stubbed locked |
| Decor | 41 items (40 Wave-1 + Friendship Fern trophy), 35 across 6 sets (blush-parlor 7, teal-terrace 7, golden-hour 7, botanical 5, noir 5, festival 4); coziness → patience ×(1+cozy/100) capped at +75%, tips ×(1+cozy/80) capped at +100%; duplicate copies give 100%/50%/25% cozy; completed set → +15% cozy multiplicative on its items; tables/armchairs provide seats |
| Drinks | 12 recipes (+6 locked stubs), 1–3 ingredients, order-free matching; brewing an unlearned correct combo LEARNS it; wrong combo = Mystery Sludge (+2 coins, −rep); `nightingale` story-locked (Rafi's arc) |
| Drink mastery | correct serves counted per drink; ★/★★/★★★ at 10/25/50 serves → +5%/+10%/+15% base price (before tip math); stars in the recipe book |
| Café levels | 30 levels; 1 XP/serve (+1 when tip rounds ≥1); thresholds 20·n(n+1)/2 cumulative; 25·level coins per level-up; every 5th level a free decor from the lowest-owned set; "Lv N • xp/next XP" HUD bar; modals queue through the FTUE |
| Regulars & arcs | Maya (FTUE + mint-mocha beat + published beat → Signed First Edition), Mr. Chen (10-serve gate → 5 fast espressos <20s → Antique Brass Clock), Zoe (cozy≥40 → photo +100 → viral crowd 10/3min → brand-deal choice: +800 & 📢 sponsored poster & purist patience −10%/3d, or +0.2★), Rafi (4★ evenings → 3 evenings → invents the Nightingale → ward rush of 5); all server-side, modals suppressed until FTUE done |
| Elena's arc | extends the critic: 3 scored visits → 3/3 ≥4 = "Five Stars" (+0.5★, 3-day surge); 0–1/3 = scathing (−0.5★) + comeback quest (next visit scores double); 2/3 = mixed |
| Visit tips | "💰 Tip 10" in tour mode: 10 coins visitor→host, cap 3/day per pair, self-tips rejected; host sees it in the day summary |
| Photo mode | 📸 button hides UI (orbit live) → frame → PNG download + share text (`☕ Visit my café! {name} ★{rep} 🛋️{cozy}` + `t.me` deep link) via navigator.share/clipboard |
| Referral | `?visit=<id>&ref=1` tours show "🌱 Join from this café"; new signup grants the Friendship Fern (+5 cozy trophy, no set, not for sale) to BOTH sides (referrer via pending grant) |
| Leaderboard | 🏆 tab: opt-in weekly board, top 20 by coins earned this ISO week |
| Tests | `python3 tests/test_endpoints.py` — 108 checks (~30s): auth, economy, FTUE, soft caps, duplicates, stock, rush, critic, quests, analytics, Wave-1 content, Wave-2 levels/sets/mastery/arcs/tips/referral/leaderboard; server spins up on an ephemeral port |
| Ingredient stock | 30 units per ingredient per day, restored at day rollover; each brew consumes its ingredients; stockout blocks brewing; full restock anytime for 20 coins |
| Brew | timed (4s base; bar counter −10%, espresso machine −25%, Golden Machine ×2); steaming cup appears on the bar while brewing; pour + steam-hiss audio |
| Customers | low-poly characters walk in from the door, sit at tables; HTML order bubbles projected from 3D (crisp text); patience bar in bubble; timeout → walkout (−rep); pop-in blip audio |
| Rush hours | telegraphed organic rushes: "🍳 Lunch rush in 60s!" banner → 3 min of 2× spawns, server-scheduled (~6 min cycle); stacks with ad-based Rush Hour |
| The critic | Elena Voss 🧐 mystery-visits (rep ≥ 3★, ~1/day): strict 45s patience, scored 1–5 on drink correctness + serve speed + coziness ≥ 40; ≥4 → +0.3★ rep, collectible visiting card, 3-day customer surge; ≤2 → −0.25★ |
| Quests | 3 daily quests from a 6-quest pool (serve N, earn tips, place decor, discover recipe, rep target, earn coins); server-tracked, coin rewards, claim in the 🎯 Quests tab, reset on day rollover |
| Audio | 100% procedural WebAudio, zero assets: pour/steam/coin arpeggio (pitch rises with tip)/UI clicks/pop-ins/fanfares, café murmur bed, generative pad music (brightens in evening); 🔊 mute toggle persisted; init on first gesture |
| Serve | correct: price + 20%×tip_mult tip, +rep, coin-burst FX; wrong drink: half price, −rep; sludge: +2, −rep |
| Reputation | 1–5★; 4★ unlocks evening crowd (faster spawns, +20% tips) |
| Day | 3-min demo days; end-of-day summary (served, earned, rep Δ, forecast) |
| Viral | `?startapp=visit_<shop_id>` deep link → read-only 3D tour mode (uses server-computed coziness) |
| Analytics | client batches events → POST /api/analytics (auth'd, rate-limited) → SQLite `analytics_events`; `scripts/analytics_summary.py` prints session→FTUE→returning funnels |
| iOS safety | `webglcontextlost` → warm overlay + tap-to-rebuild (reload fallback); pixelRatio capped at 1.5 on iOS |
| Tests | `python3 tests/test_endpoints.py` — 58 checks (~20s): auth, economy, FTUE, soft caps, duplicates, stock, rush, critic, quests, analytics; server spins up on an ephemeral port |

## Art upgrade path (paid, later — NOT needed for this build)

This build's art is 100% procedural primitives (boxes, cylinders,
spheres) with a fixed warm palette — charming, cohesive, and free. The
catalog is **data**: each item id maps to a builder function. The paid
upgrade path, when content volume matters:

1. Generate GLB assets with Tripo / Meshy / Rodin (~$0.20–1.50/item),
   or self-host Hunyuan3D 3.0 / TRELLIS.2 (open weights, $0/item).
2. Add a `BUILDERS[id] = () => loadGLB(url)` override — the placement,
   collision, coziness, and economy code doesn't change.
3. Optional free middle step: CC0 packs (Quaternius, Kenney) as GLB
   drops, re-textured to the palette.

Because decor stays data, seasonal packs ship as asset drops with zero
logic changes.

## Bot-push hooks (documented, stubbed)

Planned `sendMessage` calls (need a scheduler/cron + BOT_TOKEN):

- **Morning rush**: `"🌅 Morning rush at {shop}! Customers are lining up — open your café."`
- **Regular waiting**: `"☕ {name} is waiting at {shop} and patience is thin…"`
- **Daily decor drop**: `"🛋️ New in the catalog: {item}! Your regulars would love it."`

Shape for all three:
```json
{"chat_id": "<user_id>", "text": "…",
 "reply_markup": {"inline_keyboard": [[{"text": "☕ Open my café",
   "web_app": {"url": "WEBAPP_URL"}}]]}}
```

## Anti-cheat notes

- All economy server-side; recipes validated against the server book;
  placements collision-checked; brew `ready_at` enforced at serve time.
- `initData` HMAC-validated per call; syncs rate-limited (2s); ad rewards
  cooldown-gated (120s).
- A rooted client can still lie *within* caps. Upgrade path: ad-network
  S2S verification, anomaly detection on serve rates.

## Performance notes

- Pixel ratio capped at 2, antialias on, no shadow maps (blob shadows),
  no physics engine, fog + frustum culling by default.
- Shared geometries/materials via caches; canvas textures for floor,
  rug, poster, chalkboard, bookshelf (1 draw call each instead of many).
- Budget targets: <150k visible tris, <100 draw calls. A typical café
  (12 items, 4 customers) lands around ~90 draw calls — fine on mid-range
  phones; low-end devices may want pixelRatio capped at 1.5.
