# TRAILBOUND — Game Design & Asset Bible

> Working title. A cozy camping/travel game for Telegram Mini Apps (mobile-first, works on
> desktop Telegram + web). Visual target: `example.png` — fixed 3/4 isometric diorama,
> chunky outlined pixel art, saturated dusk palette.
>
> This doc is the contract: **story → gameplay → asset manifest → budget**.
> No art is generated until this is approved.

---

## 1. Premise & Story

**You're restoring the trail's forgotten rest stop.**

Deep in the woods sits an old campsite on the Grand Trail — once beloved, now overgrown.
You arrive with a backpack, a battered tent, and your grandfather's **trail journal**: a
guidebook he kept as the camp's last warden, stamped at every waypoint from Whisperwood to
Glasscoast. The final pages are blank. *"The trail remembers those who tend it. Finish the
book for me."*

So you hike out each day — foraging, fishing, photographing — earn a little money, spend it
on gear and comfort, and slowly turn the clearing back into the place every traveler hopes
to find at dusk. Travelers start stopping again. They pay, they tell stories, they leave
hints about places your grandfather never reached.

**Why this story:**

| Design need | What the story provides |
|---|---|
| Reason to leave camp and return | Day trips outward, hosting in the evening |
| Reason locations unlock in order | Journal chapters — the trail unfolds |
| Long-term goal beyond money | **Complete the journal**: stamps, species, visitor autographs |
| Emotional hook | Restoration + hospitality — cozy, not conquest |
| Content runway | Grandfather's margins hide teasers (seasons 2+ = mountain, sea) |

**Tone:** warm, quiet, gently funny. Modern characters (hoodies, thermoses, film cameras),
zero magic. The companion is a stray **dog** who adopts you — not a familiar, just a good
dog who sometimes digs up mushrooms.

---

## 2. Player Fantasy & Pillars

**Fantasy:** *the free life of a trail camper — days outdoors, evenings by the fire, a camp
that slowly becomes home.*

1. **Wander, don't work.** Activities are self-paced; failure is a shrug and a story.
2. **Alive in 10 seconds.** Cold open must already feel inhabited: fire crackling, smoke,
   fireflies, the dog's tail.
3. **Every trip ends with a decision.** Coins compete: gear vs. comfort vs. the next page
   of the journal. There is no "right" spend.
4. **Gear is progression.** One purchase = one new thing to do. Never a stat stick.
5. **The journal remembers.** Everything collected is a page filled — visible, shareable
   progress (Telegram-native bragging rights).

---

## 3. Core Loops

### Moment-to-moment (activities)

| Activity | Where | Mechanic | Unlocks via |
|---|---|---|---|
| **Foraging** | Forest, Valley | Nodes spawn per visit with a rarity table. Tap → player walks → collect (−1⚡). Rare Goldcap spawns. | free |
| **Fishing** | River, Sea | Cast → wait → **strike-window tap** → hold/release tension minigame → catch by species table + weight record | Fishing Rod |
| **Cooking** | Campfire | Combine 2 ingredients → meal. Known pairs (mushroom+herb = Trail Stew) pay more than random mash. Recipe discovery = mini-puzzle | free |
| **Hosting** | Camp (evening) | Travelers arrive with wants → serve item/meal → pay + charm. Some give quests or map hints | camp upgrades |
| *Biking* | Valley | Trail-runner dodging/collect minigame | Bike (S2) |
| *Climbing* | Mountain | Route-pick minigame | Boots (S2) |

### Session loop (one day ≈ 3–5 min)

```
☀ Wake (energy refilled) → 🗺 pick destination → activity until energy runs low
→ 🏕 return to camp → travelers waiting → cook/serve → journal entry auto-writes
→ 😴 Sleep (save)
```

### Meta loop (weeks)

Coins → gear (each unlocks an activity/location) → new stamps/species → camp upgrades
(comfort → charm → richer travelers) → **journal pages fill** → prestige = completed
Grand Trail Guide.

---

## 4. Systems Spec

### 4.1 Energy & days
- 10⚡/day base; Lantern +3; Tent Mk.II +2 (better rest).
- Forage node = 1⚡. Fishing cast = 1⚡. Hosting/cooking = free (evening phase).
- Sleep anytime → next day, respawns reset, autosave.

### 4.2 Economy (v1 numbers)

| Income | Yield | Effort |
|---|---|---|
| Sell raw forage | 3–45c | low |
| Cooked meal served | 30–60c | medium (2 items + a visitor who wants it) |
| Fish sold/served | 12–85c (koi jackpot) | medium skill |
| Quest from traveler | 40–120c + hint | occasional |

| Prices | |
|---|---|
| Fishing Rod | 150c (day-1 reach — the first "aha") |
| Forager's Net | 220c (forage ×2) |
| Camp Lantern | 180c (+3⚡) |
| Tent Mk.II | 400c (+4 charm, +2⚡) |
| Valley pass (trail fee) | 500c |
| Mountain boots → Sea kayak | 800c → 1500c (S2 runway) |

Target pacing: rod day 1, valley ~day 3–4, one meaningful purchase choice per day.

### 4.3 Charm & travelers
- Charm = camp comfort score (upgrades + decorations). Drives traveler frequency, tips,
  and *tier* of visitors (the photographer only stops at charming camps).
- Max 2–3 travelers waiting; patience drains over ~45s; ignoring them costs nothing but
  the lost sale.

### 4.4 The Journal (retention + collection)
Pages auto-fill:
- **Trail stamps** — one per location visited
- **Field notes** — species collected (Foragedex ~12, Fishdex ~10)
- **Guestbook** — every traveler type served signs it (~8)
- **Recipes** — discovered cooking pairs (~6)
- Completion % is the share-bait stat.

### 4.5 The dog
Adopted on day 2 (scripted). Follows the player on trips; occasionally digs up a bonus
item (visible sparkle → walk over). Pure charm + a light economic trickle. 4-dir walk +
sit + happy-bark frames needed.

---

## 5. Scene & UX Structure (mobile-first)

| Screen | Contents |
|---|---|
| **Scene view** | Fixed iso diorama. Tap-to-walk. Interactables glow. Fixed camera, pinch-zoom allowed |
| **HUD** | Top pills: 🪙 coins · ⚡ energy · day · 🗺 map button. Sleep button floats right |
| **Bottom sheet** (journal-page styled) | Context panel: camp = backpack + COOK + shop; forest = bag; river = tackle + log |
| **Map overlay** | Location cards with unlock state — the trail map is itself a generated illustration |
| **Journal overlay** | Tabbed pages (stamps/species/guestbook/recipes) |
| **Shop** | Outfitter kiosk cards |

**UI art direction (fixing "too bad"):** warm cream journal paper cards, forest-green +
ember-gold palette, chunky rounded controls, hand-drawn-feel icons (PixelLab-generated UI
kit), soft drop shadows, chunky serif headings. All DOM — crisp text, safe-area aware,
thumb-reachable. The current prototype UI is wireframe only.

---

## 6. Locations (v1 shipped / teasers)

| Location | Status | Palette | Content |
|---|---|---|---|
| Pinewood Camp | ✅ hub | green/dusk | hosting, cooking, upgrades |
| Whisperwood | ✅ forest | deep green | forage nodes ×7 |
| Silverbank River | ✅ activity | green + blue bank | fishing |
| Sunpetal Valley | 🔒 500c | golden meadow | forage tier-2 (honey, flowers) + bike teaser |
| Cloudrest Peak | 🔒 S2 | rock/snow | climbing (needs boots) |
| Glasscoast | 🔒 S2 | sand/sea | sea fishing (needs kayak) |

---

## 7. ASSET MANIFEST — the PixelLab list

Style lock: `example.png` as style reference on every call where supported
(`style_image` / `style_images` / `color_image` on pixflux). Camera view:
**"low top-down" (~20°, classic 3/4 RPG)** for characters/objects — that matches the
steep example.png look. All props `no_background`.

### Tool map — which tool for which asset (with REAL USD prices)

| Tool | $/call | Use for |
|---|---|---|
| `create_image_pixen` (≤256px) | **$0.007–0.009** | static props, item icons, fish shadows — the workhorse |
| `create_image_pixflux` | **$0.008–0.013** | same, supports forced palette via `color_image` |
| `create_map_object` | **$0.010** | props style-matched to a map image (`background_image`) |
| `create_isometric_tile` | **$0.016** | iso blocks (grass/dirt/water/cliff), 32–64px, init-image support |
| `create_tiles_pro` | **10–15 gens + Tier-1 gate** | SKIP unless subscribed — iso sets w/ custom `tile_view_angle`/`tile_depth_ratio` |
| `create_path_tiles` | tiles_pro family | same gate — paths via `create_isometric_tile` variants instead |
| `create-character-4-directions` | **$0.011** | cheap 4-dir character from scratch |
| `create-character-v3` (+reference) | **$0.041** | 8-dir character keeping a sprite's identity |
| `generate-8-rotations-v3` | **$0.034** | rotate OUR south-facing sprite into 8 dirs — cheaper than create-v3 |
| `animate-character` template | $0.032/dir (64px) | real walk cycles; 4-dir walk ≈ $0.13 |
| `animate_character` v3 | $0.013/dir (64px, 4f) | cheaper custom anims |
| `animate_image` (v3) | **$0.022–0.042** | animate ANY frame — campfire, tree sway, flag; free-tier OK |
| `animate-with-skeleton` | $0.014–0.016 | if a skeleton rig fits better |
| `create_ui_asset` | 10–25 gens | 1–2 hero panels max; rest CSS |
| `correct_pixelart`/`reduce_colors`/`unzoom` | **~$0.001** | palette-lock every asset — the consistency cheat |
| `edit_image_pixen` | $0.012 | variant farming (tent tiers, recolors) |
| `create_1_direction_object` | $0.08 | batch: ≤85px style ref → **16 style-matched objects in ONE call** |

**Reality check:** the entire P0 manifest below ≈ **$0.60 in USD credits** — generation units were the scary unit; dollars aren't. The real constraints are (a) Tier-1-gated tools (tiles_pro, consistent-style, ui_asset, pixminimax, 8-dir objects) and (b) trial's 1-concurrent-job limit.

### 7.1 Reference teardown — every asset in example.png

Complete inventory extracted from the 393px reference. This is the coverage bar — our
manifest must match every category, with camping-world equivalents (modern humans, not
fantasy animals):

| Category | In example.png | Our equivalent |
|---|---|---|
| **Ground** | Mostly-FLAT grass diamond; dirt-path patches; cliff/earth edge ONLY at island perimeter | flat grass tiles + dirt patches + perimeter cliff rim (fix: not raised blocks) |
| **Water** | Stream → waterfall → pond at bottom-left; swim rings | river strip + pond + shoreline; waterfall anim |
| **Trees** | 1 big canopy tree (treehouse base), 3+ tall conifers, small pines, bushes | big oak ×1, conifer ×2-3, pine ×2, bush blobs ×3 |
| **Structures** | treehouse platform+ladder+string lights; mushroom house; camper van w/ roof cargo; green A-frame tent | ranger kiosk (have shop_0), **camper van = outfitter shop**, tent ×3 tiers, notice board |
| **Fences** | wooden post fences along 3 edges + pond enclosure | post fence straight/corner/gate segments |
| **Fire** | campfire ring + tripod + hanging pot | same (we have assets) |
| **Furniture/decor** | 2 picnic blankets (checkered), BBQ/food table, stumps, planter box w/ flowers | picnic blanket, camp table, stumps, log bench, planter, hammock |
| **Lights** | string lights on treehouse + mushroom doorframe; campfire glow | string-light strand, lantern posts, fireflies |
| **Characters** | ~10 chibi animals: DJ, foxes, cat, dragon, hedgehog, 2 in swim rings | player camper, ranger, dog, 4-6 travelers (modern chibi humans) |
| **Ground clutter** | mushrooms, flowers, grass tufts, pebbles, star decals | same + forage nodes |
| **Props** | chalkboard sign, food items on blankets | sign, meal items, tackle box, backpack |
| **UI** | none — just the logo top-left (the diorama IS the presentation) | our HUD must be equally light: floating pills + journal sheet that doesn't fight the scene |

### 7.2 P0 — the diorama (~$0.70 USD, ~55 gens)

| Asset | Tool | Est. USD |
|---|---|---|
| Flat grass tiles ×5 (plain, tuft, flowers, worn, sparkle) | `create_isometric_tile` ×5 (thin tile shape) | $0.08 |
| Dirt-path blend tiles ×3 + pebble patch | `create_isometric_tile` ×4 | $0.06 |
| Perimeter cliff rim: N/E/S/W edges + 4 corners | `create_isometric_tile` ×8 (thick/block shape) | $0.13 |
| Water: river strip, pond, shoreline edge, waterfall | `create_isometric_tile` ×4 | $0.06 |
| Camp: tent_t1, campfire ring+pot, tripod, log bench, stump, lantern post, crate stack, notice board, trail sign | `create_map_object` ×9 (background_image=terrain shot → auto style-lock) | $0.09 |
| Trees: big oak, conifer ×2, pine ×2, bush ×3 | `create_map_object` ×8 | $0.08 |
| Decor: picnic blanket, camp table, planter box, hammock, fence straight+corner+gate | `create_map_object` ×6 | $0.06 |
| Lights: string-light strand, glowing lantern | `create_map_object` ×2 | $0.02 |
| **Player camper** (hoodie+cap+backpack, south sprite) | `create_image_pixen` | $0.008 |
| Player 4-dir rotations | `generate-8-rotations-v3` (take S/W/E/N) | $0.03 |
| Player walk cycle 4-dir | `animate-character` template `walking` ×4 | $0.13 |
| Ranger (idle at kiosk) | pixen + rotate | $0.04 |
| **Dog** (follows, sits, digs) | `create-character` quadruped `template='dog'` + walk anim | $0.06 |
| Campfire lit 4f + waterfall flow + tree sway | `animate_image` ×3 | $0.08 |
| Palette-lock batch (all PNGs → shared ramp) | `reduce_colors` ×3 | $0.01 |
| **P0 total** | | **≈ $0.87** |

### 7.3 P1 — the loop content (~$0.55 USD)

- Forage nodes ×8 (mushrooms×2, berry bush, herb, log, flowers, goldcap, beehive) → pixen $0.06
- Fishing: dock, swim ring, tackle box, rod item, fish silhouettes ×3 → $0.05
- Travelers ×4 (hiker, photographer, old angler, kid scout) + walk anims → $0.30
- Item/gear icon set ×14 → **one `create_1_direction_object` batch (≤85px ref → 16 style-matched objects)** → $0.08
- Trail-map illustration + 4 location cards → pixen ×5 → $0.05
- **UI hero panel** (journal sheet, styled on our palette) → `create_ui_asset` → ~15 gens (Tier-1)

### 7.4 P2 — depth (~$2–3 USD, later)
tent_t2/t3 · BBQ table w/ food · fairy-light variants · 3+ travelers · swim rings in pond ·
valley/coast tile art · recipe art · 2nd UI panel · stamp badges · seasonal reskins.

### 7.5 Budget math — Tier-1 reality
- **P0+P1 ≈ $1.50 USD-equivalent ≈ ~120 gens** of the ~2,000/month Tier-1 pool → **~16× headroom** for iteration, misses, and variants.
- Tier-1 also unlocks `create_tiles_pro` (native-angle terrain) and `create_ui_asset` (real pixel UI).
- Sequential generation only (~1 concurrent job) → the batch script queues + auto-downloads (map objects expire in 8h).

### UI note — "same UI as example.png"
The reference has **no HUD at all** — just the diorama + logo. That's the actual brief: the
interface must feel as light as the scene. Direction: floating pills only (coins/energy/day),
a journal-paper bottom sheet that slides up on demand (never permanently occupying screen),
want-bubbles attached to characters, and chunky rounded corners everywhere. No persistent
button walls. When the scene is idle, the game should look like the reference — pure diorama.
UI widgets come from `create-ui-elements` (Pro adds concept+palette guidance): an 8×8 grid at
≤32px = **64 widgets per 10-gen call** — buttons, slots, bars, frames in one shot.

### 7.6 Pipeline corrections (full docs pass — changes vs earlier plan)

| Wrong assumption | Correct tool / fact |
|---|---|
| Rotate + animate chars in separate calls | `create-animations-automatic` (Tier 1, ≤64×64): **character + 4 rotations + animation in all dirs in ONE call** — use for travelers; or `create-8-rotations-pro`: all 8 dirs in one call w/ up to 4 concept refs (10-25 gens) |
| Walk anims ~$0.05-0.13 each | `animate-with-text` (new): **64×64 4-16 frames = 1 gen**, free-tier, frame-1-preserved → walk/idle/gather for every char at ~1 gen each |
| Individual iso tiles for terrain | `create_tiles_pro` tileset mode: **16-tile Wang transition set** ("grass to water") + `terrain height` option raises first terrain into plateau w/ cliff face = **the island-perimeter look natively**; paths mode = 18-config autotile set; building mode = wall/door/stairs kit for kiosk/treehouse |
| No tool for trail-map screen | `create-map` pixflux is top-down/sidescroller only → generate the **trail-map screen illustration** (top-down, 320×320 Tier 1) |
| Can't reuse example.png style directly | `image-to-pixel-art`: convert reference crops → our palette, remove-bg; `consistent-style`: ≤32px→**64 imgs/10 gens**, 43-85px→16 imgs — feed our locked sprites as style refs for batch props |
| Skeleton anim = only quality path | `animate-with-skeleton` IS Tier 1 and best quality (reusable skeletons, "fixed head" tip keeps chibi faces stable) — reserve for player + ranger closeups; text-anim for the rest |
| — | `try-on`, `multi-image`, `create-instant-character`, `extend-map-v2`: **all Tier 2 — NOT in $12 plan** |
| MCP = local package | MCP is **remote HTTP** `https://api.pixellab.ai/mcp` + Bearer token; stdio-only clients bridge via `npx mcp-remote` |
| Manual fixes need Aseprite | **Pixelorama** = free in-browser editor w/ PixelLab built in → zero-cost touch-ups |
| Licensing risk | FAQ: no training on our inputs, commercial + Steam use explicitly allowed |

### 7.7 Stack & approach gaps (beyond PixelLab)

| Gap | Fix |
|---|---|
| **No audio in plan** | WebAudio procedural (fire crackle = filtered noise, blips) + free SFX (freesound/Kenney audio) — zero art budget needed |
| **No pixel font chosen** | Silkscreen/VT323/Micro5 (Google Fonts, OFL) — load early, it's half the "pixel game" feel |
| **Sprite packing** | Manifest loader + simple bin-pack script → one atlas PNG, fewer requests on mobile |
| **Telegram SDK not wired** | `@twa-dev/sdk` — initData, haptics (catch fish → bump), viewport lock, theme sync; prototype still works standalone |
| **localStorage only** | Fine for demo; real save → tiny backend endpoint keyed by Telegram user id |
| **Depth sort edge cases** | Painter-sort by (i+j) w/ entity Y-fine-tiebreak — already in compositor; add `z_offset` field for tall props |

### 7.8 Locked stack (approved)

```
client/  = Vite + TypeScript + PixiJS v8 + @twa-dev/sdk
render   = PixiJS Container tree + iso painter-sort adapter
           (game logic/entities engine-agnostic → Canvas-2D fallback stays possible)
assets   = manifest-driven (sprite path swap = art upgrade, zero code change)
sprites  = PixiJS Assets atlas packing, ScaleMode 'nearest'
effects  = additive glow sprites + scene tint filter (fire glow, dusk/day)
audio    = WebAudio procedural SFX + free packs
save     = localStorage (demo) → tiny backend keyed by Telegram user id (later)
font     = Silkscreen or VT323 (OFL)
perf gate= first check on Telegram Android WebView (weakest link)
```

PixiJS earns its place at client/ scaffold time — not in the prototype — for filters,
atlas packing, and particle headroom. Phaser/KAPLAY rejected: we own the game logic.

### 7.9 Cast generation sheet (prompts + per-char cost)

**Shared style block** appended to every character prompt (keep verbatim for
consistency — it's our "house style"):

```
chibi pixel art game character, ~2.5 heads tall, big head and hands, thick
dark-brown selective outline, saturated cozy palette (emerald green, warm
brown, ember orange, dusk violet), clean cel shading, no background
```

**Shared options**: `view="high top-down"` (~35°, matches example.png),
`direction="south"`, 64×64 canvas, transparent bg, `outline="selective outline"`.

**Generation pipeline per character** (the identity-consistent path):
1. `create-image-pixen` south-facing sprite — 1 gen; iterate prompt until right
2. `create-8-rotations-pro` method *Rotate character* (ref = step 1) — 10 gens
   @≤85px → take S/W/E/N, discard diagonals (fixed camera needs 4, mirror E→W)
3. `animate-with-text` (new) `"walking"` per dir — **1 gen each** @64×64
4. `animate-with-text` south-only extra actions — 1 gen each
5. Optional: `animate-with-skeleton` polish pass for the player only
   (fixed head → "always" keeps the chibi face stable across frames)

#### P0 cast — ~40 gens

| Char | Prompt (before style block) | Anims needed | Gens |
|---|---|---|---|
| **player** | young adult camper, teal hoodie, orange beanie, brown backpack, khaki shorts, hiking boots | idle_s + walk×4 + gather_s + fish_s + carry_s | 1+10+4+3 = **18** |
| **dog** | small scruffy brown-and-white terrier, red bandana, quadruped (`body_type=quadrupedal`) | walk×4 + sit_s + dig_s | 1+10+4+2 = **17** |
| **ranger** | friendly park ranger, olive shirt, wide-brim hat, khaki pants, enamel mug | idle_s + wave_s | 1+0+0+2 = **3** |

#### P1 cast — ~10 gens (idles only; walks deferred to P2)

Travelers mostly *sit at camp* — south-facing idle is 80% of their screen time.
Generate sprites + idle now; add walk×4 (~14 gens/char) only for those who
visibly hike in (hiker, photographer).

| Char | Prompt | Anims | Gens |
|---|---|---|---|
| hiker | middle-aged hiker, red flannel, big grey backpack + bedroll, walking poles | idle_s (+walk later) | 2 |
| photographer | young photographer, mustard rain jacket, camera on neck strap, beanie | idle_s (+walk) | 2 |
| old angler | elderly fisherman, grey beard, bucket hat, green vest, fishing rod | idle_s | 2 |
| kid scout | small kid scout, oversized green backpack, cap, freckles | idle_s | 2 |
| van-lifer | relaxed woman, denim overalls, purple bandana, coffee mug | idle_s | 2 |

Variant trick (Tier-1-safe): `edit-image-pro` / `create-sl-image-pro` with the
approved sprite as reference → outfit/color variants. (`try-on` is Tier 2.)

#### P2 — ambient + upgrades (~30-60 gens)
walk×4 for hiker/photographer (~14 each) · cyclist traveler · ambient wildlife
(bird, squirrel — `map_object` + `animate_image`, ~3 each) · seasonal reskins.

#### Totals
- **Full P0 cast ≈ 40 gens · P1 idles ≈ 10 gens · walks-when-needed +15/char**
- Everything lands in `prototype/assets/gen/` then manifest-swapped into
  `client/src/assets/manifest.ts` (`char.*` keys already reserved)
- Consistency controls: same style-image ref for all calls, `reduce_colors`
  batch at the end, feet-anchored south at bottom-center, 64×64

### 7.10 Production completeness audit (what the manifest was missing)

The §7.x manifest is scene-complete but not production-complete. A shipped
game needs these too — sorted by who makes them:

**PixelLab-generatable additions (~40-60 gens, add to P1):**
- **Food sprites** — the cook→serve reward objects: stew pot, skewers, sandwiches,
  drinks, pie (on-blanket meals like example.png shows) — `consistent-style` batch
- **Launch art** — app icon (512px, bot avatar + directory), title/splash card,
  promo key-art for sharing
- **Portraits** — character busts for journal/dialogue (32-48px heads)
- **VFX frames** — unlock burst, sparkle, level-up, stamp-press animations
- **Location pin icons** — map nodes locked/unlocked states
- **Journal art** — stamp/badge set, recipe card illustrations
- **Empty states** — "no travelers yet" campfire illustration, empty inventory art

**Non-PixelLab (separate tools/sources):**
- **Audio** — 🔴 biggest gap. PixelLab does zero audio.
  - SFX: Kenney/freesound packs (footsteps, splash, coins, UI) + WebAudio
    procedural (fire crackle = filtered noise — already stubbed)
  - Music: ambient campfire loop — AI music tool (separate service) or
    CC0 ambient tracks; budget ~2-3 loops (day/dusk/activity)
- **Monetization** — Telegram Stars: cosmetic gear + convenience (never
  energy-predatory; cozy audience punishes it). Decide model before launch.
- **Backend** — server save (multi-device + anti-cheat validation), remote
  config for economy tuning, Sentry error reporting, minimal analytics
  (retention funnel: open→first cook→day-2 return)

**Design/engineering gaps:**
- **Onboarding** — first-session flow unplanned; design the first 60 seconds
  (spawn at fire → dog arrives → first forage prompt) before any art spend
- **Retention systems** — daily quest card, guestbook signatures, streak
  lantern; cheap text systems, big payoff
- **Save versioning** — add `save_version` to state now; every schema change
  needs a migration or players lose progress
- **Catalog validation** — zod schemas on items/gear/locations JSON; a bad
  row in prod = broken economy
- **i18n-ready** — strings extracted day one; Silkscreen is Latin-only → need
  fallback font for Cyrillic/CJK later
- **A11y/perf budgets** — 44px min tap targets, colorblind-check palette,
  reduced-motion toggle, <3s cold start, <100MB RAM on Android WebView
- **CI/CD** — GH Actions: typecheck+build on push; Playwright smoke on the loop
- **TMA platform checklist** — BotFather setup, bot description/commands,
  HTTPS hosting (cloudflared for dev), Telegram header/safe-area testing,
  content rating

### 7.11 COMPLETE coverage matrix — every tile, state, object

Honest answer to "does 200 gens cover everything": **no — ~200 covers P0+P1.
A real complete game ≈ 400-550 gens** (still ~25% of monthly pool). The full
enumeration:

#### A. ALL terrain tiles (per scene needs)

| Material | Tiles needed | Scenes |
|---|---|---|
| grass | plain, tuft, flowers, worn, sparkle | all |
| dirt/earth | bare patch, tilled, mud | camp, forest, valley |
| **dirt path autotile** | 18-config set (straights, corners, T, cross, ends) | all |
| sand | plain, rippled, shell-dotted | coast |
| rock | boulder field, gravel, smooth | valley, mountain, river |
| stone path | laid stones | camp (upgrade look) |
| wood planks | dock, bridge, treehouse floor | river, camp |
| shallow water | wadeable edge | river, coast |
| deep water | pond, river main, sea | river, coast |
| waterfall | anim 4f | river |
| snow | only if seasons ship — P2 defer | mountain |

**Transitions (Wang 16-tile sets, 10-15 gens each):**
grass→water · grass→path · grass→sand · sand→water · grass→rock ·
dirt→water (muddy bank) · rock→water (sea cliff)
→ **7 sets ≈ 70-105 gens** (this is what real terrain costs — not loose tiles)

**Island rim:** cliff edge N/E/S/W + 4 corners + terrain-height plateau edge
(part of tiles_pro generation, counted above)

#### B. Scenes × tile mix

| Scene | Terrain | Unique props |
|---|---|---|
| Camp | grass, path, rim | all camp accessories below |
| Forest | grass, dirt, dense trees | forage nodes×8 (+empty/harvested state each!), hollow log, ferns, leaf piles, cache dig-spot |
| River | grass bank, water×2, planks | dock, bridge, bobber, cattails, fish-jump anim, canoe |
| Valley | grass, flowers, rock | wildflowers, vista rock, viewpoint bench, stream |
| Coast | sand, shallow, deep, rock | shells, starfish, driftwood, tide pool, beach grass, kayak, seagull |
| Mountain | rock, gravel, pine | boulders, summit flag, climbing props, goat? |

#### C. States — what costs ZERO gens vs what needs sprites

| State | Cost |
|---|---|
| day/dusk/night | **0 gens** — scene tint filter (locked in stack) |
| rain | **0 gens** — particle overlay + wet-sheen tint; +3 puddle decals optional |
| fog/wind | **0 gens** — mist overlay + existing sway anims |
| unlit vs lit fire/lantern/torch | sprite each (unlit state is a real asset!) + **0-gen** glow overlay (additive) |
| forage node full vs harvested | **2× node sprites** — this was missed: 8 nodes × 2 states |
| tent tiers t1/t2/t3 | 3 sprites (progression!) |
| fire pit tier upgrade | +1 sprite |

#### D. Fire & light objects (complete)
campfire unlit · campfire lit 4-8f · tripod+pot · lantern post unlit/lit ·
string lights · torch · fire pit t2 · embers prop · hanging tent lantern
(+0-gen glow overlays, fireflies procedural)

#### E. Water objects (complete)
waterfall anim · dock · bridge · swim ring · kayak/canoe · reeds/cattails ·
lilypads · fish silhouettes · bobber · splash frames · ripple decals ·
fish-jump anim (+0-gen shimmer shader)

#### F. Camping accessories (the REAL checklist)
**Sleep:** tent×3 tiers, tarp, hammock, bedroll, sleeping bag, dog bed
**Cook/eat:** fire ring, tripod, stove, cooler, kettle, mugs, thermos,
camp table, chairs×2, log bench, stump seats, picnic blankets×2
**Storage:** crates, barrel, sack, backpack prop, gear rack, basket
**Light:** lantern post, string lights, torch, tent lantern
**Info:** notice board, chalkboard, trail signs×3, map table, guestbook stand
**Comfort:** guitar, books, camera tripod, binoculars, planter, welcome flag,
wind chime, clothesline+ towels
**Dog:** doghouse, bowl, bone, leash post
**Fishing:** rod, rod rack, tackle box, bait bucket, creel basket, net
**Bike:** bicycle, rack, repair stand, pump, trail markers
**Chores:** woodpile, axe-in-stump, log rounds
**Boundaries:** fence straight/corner/gate, rope fence, stone wall
**Shop:** outfitter van, ranger kiosk (have shop_0)
**Clutter:** mushrooms, flowers, tufts, pinecones, leaves, small rocks,
stepping stones, pebbles — `consistent-style` @32px = **64/10gens**

#### G. Character states beyond walk (was missing)
player: +sit, +sleep (bedroll) · dog: +bark/excited, +sleep ·
ranger: +talk · travelers: sit-on-blanket variants ·
portraits ×8 (32-48px heads) for journal/dialogue

#### H. Items/icons — complete inventory
ingredients ×9 (+honey, acorn, catfish) · **MEALS ×8** (stew, berry pie,
skewers, sandwich, tea, grilled fish, s'mores, soup) · gear icons ×12 ·
stamps ×8 · coin/energy/charm/day icons

#### I. VFX frames
unlock burst · sparkle · level-up rays · stamp-press · splash ·
heart pop · ZZZ · ! / ? marks · smoke/steam (procedural covers particles)

#### J. Launch & meta art
app icon 512px · title/splash · promo key-art · map pins locked/unlocked ·
journal cover · empty states ×2

### 7.12 Corrected totals + ANIMATION LEDGER (was undercounted)

Static sprites ≠ animated game. Every anim = `animate-with-text`/`animate_image`
at **1 gen @64×64** (4-16 frames). The full ledger:

| Group | Animated things | Gens |
|---|---|---|
| **player** | idle, walk×4, gather, fish_cast, fish_reel, carry, sit, sleep | **9** (was 7) |
| **dog** | walk×4, sit, dig, bark, sleep, follow-idle | **10** (was 6) |
| **ranger** | idle, wave, talk | **3** |
| **travelers×5** | idle×5, sit-variants×3, walk×4 (hiker+photo only) | **16** |
| **critters** | bird-fly, squirrel-hop, butterfly, frog-jump | **4-8** |
| **fire** | campfire loop, torch, fire-pit-t2, ember-glow, smoke, steam | **6** |
| **water** | waterfall, fish-jump, fish-shadow, bobber, ripple-ring, canoe-bob | **6** |
| **wind/life** | tree sway×3, welcome flag, wind chime, towels, string-light sway, tent flap, hammock | **11** |
| **VFX** | unlock burst, sparkle, stamp-press, splash, level rays, heart-pop, ZZZ | **7** |
| **UI/misc** | want-bubble pulse (procedural), sleep transition | **0-2** |
| **ANIM TOTAL** | | **≈ 70-90 gens** |

Zero-gen (engine-side, real): day/dusk/night tint · rain/fog particles ·
glow overlays · fireflies · water shimmer · bob/walk-cycle tweening.

| Tier | Static + its anims | Gens |
|---|---|---|
| P0 | camp scene + cast (incl. anims) | ~70 |
| P1 | loop content + idles | ~65 |
| **P1.5** | food, portraits, VFX, node-states, tiers, fire/water, bike, accessory batches + all their anims | ~160-220 |
| P2 | valley/coast/mountain + walks + critters + anims | ~170-220 |
| Launch | icon, splash, promo | ~25 |
| **COMPLETE (static+animated)** | | **≈ 490-600 gens** |

**Revised verdict:** ~500-600 gens ≈ **25-30% of the ~2,000/mo pool** —
still comfortably inside Tier 1, but the earlier "~10%" claim counted
statics only. Animation roughly doubles the realistic budget.

### 7.13 FINAL audit — system-by-system (nothing ships unlisted)

Method: walk every system/screen a player can reach; each row = assets that
system touches end-to-end. ⛔ = missed in earlier passes. This section is the
**single source of truth** — any future asset request must map to a row here
or get added as one.

#### Per-system asset enumeration

| System | Assets (static + anim) | Missed? |
|---|---|---|
| **Fishing** | rod icon+prop, bobber, splash×3f, fish icons ×4 (minnow/trout/koi/catfish), fish-jump 4f, fish-shadow 4f, catch burst, "!" marker, tension UI, dock, ripple rings | ⛔ catfish, fish-shadow |
| **Foraging** | nodes ×8 ×2 states (full/harvested!), sparkle decal, pickup pop, item icons ×9, cache dig-spot, hollow log | ⛔ harvested states |
| **Cooking** | tripod+pot, stove, **pot states ×3 (empty/cooking/done)** ⛔, steam anim, recipe cards ×8, meal icons ×8, ingredient icons | ⛔ pot states |
| **Serving** | **want-bubble sprite + tail** ⛔, meal sprites ×8, serve ding VFX, heart pop, charm star, sit poses (in cast) | ⛔ bubble art |
| **Shop** | outfitter van, gear cards ×12, in-world gear props (rod rack, lantern, tent t2, bike rack, net), buy UI | |
| **Map/travel** | top-down map illustration 320px, pins ×6 ×locked/unlocked, path line, "you are here" marker, travel fade | |
| **Day cycle** | day icon, ZZZ, sleep anim, morning transition, energy bolt+bar | |
| **Journal** | cover, page frames, **stamps ×8**, recipe cards, guestbook signatures, dex entries | |
| **Story (was fully missed)** | ⛔ grandfather's journal prop, ⛔ letter pages ×5-8 (story delivery!), ⛔ sepia photo art ×2-3, ⛔ grandfather portrait | ALL missed |
| **Unlocks/quests** | unlock card, stamp-press anim, burst, daily quest card, streak lantern | |
| **Onboarding** | ⛔ hand/pointer sprite, ⛔ paw-trail decal (dog arrival), first-time dialog frames | |
| **Share/viral** | ⛔ postcard frame + template (composite camp → image to chat) | |
| **Feedback/VFX** | sparkle, unlock burst, level rays, heart, ! / ?, arrow marker, coin-fly, energy glow | |
| **States/errors** | ⛔ offline illustration, ⛔ error toast frame, empty inventory art, empty camp art | |
| **Boot/brand** | app icon 512, splash+loading bar, title card, bot avatar/banner | ⛔ bot banner |

#### Scene matrices (terrain+props+life)

- **Camp**: grass ×5, path autotile, rim edges+corners; shelter (tent×3, tarp),
  fire set (unlit/lit/pit-t2, tripod), light set (lantern×2, string, torch,
  tent lantern), furniture (blanket×2, table, chair×2, bench, stump, hammock),
  storage (crate, barrel, sack, backpack, gear rack, basket, cooler),
  info (notice board, chalkboard, signs×3, map table, guestbook),
  dog set, comfort set (guitar, books, camera-tripod, binoculars, planter,
  flag, wind chime, clothesline, woodpile, axe-stump),
  boundaries (fence s/c/gate, rope, stone wall), clutter batch (64 @32px),
  critters (squirrel, bird, butterfly), kiosk+van
- **Forest**: grass, dirt, dense-tree layer; nodes ×8×2, cache, hollow log,
  ferns, mossy rock, leaf piles, tall grass, deer?, owl? (dusk)
- **River**: bank grass, shallow+deep water, shore transition, rocks;
  dock, bridge, cattails, reeds, lilypads, stones, canoe, fishing set,
  waterfall anim
- **Valley**: grass, wildflower meadow, rock outcrops, stream; vista rock,
  viewpoint bench+sign, stream anim, kite?, butterflies
- **Coast**: sand ×3, shallow+deep sea, shore transition, sea cliff;
  shells, starfish, driftwood, tide pools, beach grass, kayak, umbrella,
  beach blanket, buoy, seagull anim, wave loop
- **Mountain**: rock, gravel, pine, snow cap?, cliff; boulders, summit flag,
  climbing props, cairns, flag-wave anim, goat?
- **Map screen**: 320px top-down illustration + pins

#### Character anim matrix (final)

| Char | Static cost | Anims (1 gen each) |
|---|---|---|
| player | 1 + 10 rotate | idle, walk×4, gather, cast, reel, carry, sit, sleep, **celebrate** ⛔, **eat** ⛔ = 11 |
| dog | 1 + 10 rotate | idle, walk×4, sit, dig, bark, sleep, **heart-react** ⛔ = 9 |
| ranger | 1 | idle, wave, talk = 3 |
| travelers ×5-6 | 5-6 | idle×5-6, sit-var×3, eat×2 ⛔, walk×8 (hiker+photo) = ~18 |
| portraits ×8 | 8 | — |
| critters ×6 | 6 | fly/hop/flutter/jump/gull/graze = ~8 |

#### Non-art production assets (0 gens, still required)
audio SFX ~35 (ambience ×8, actions ×15, UI ×7, dog ×3, music ×3 loops) ·
save_version + migrations · zod catalog schemas · CI/CD + Playwright smoke ·
Sentry · analytics funnel events · remote economy config · i18n extraction ·
a11y pass · TMA checklist (BotFather, banner, description, rating, safe areas,
HTTPS) · Stars cosmetic catalog · LEGAL (have)

### 7.14 FINAL totals

| Block | Gens |
|---|---|
| Terrain (7 Wang sets + rims + scene tiles) | ~110-140 |
| Props/accessories (all scenes, ~150 items, batched) | ~120-150 |
| Characters (statics + rotations + all anims) | ~90-110 |
| Scene/critter anims | ~25-35 |
| VFX + UI + icons + states | ~60-80 |
| Story/launch/meta art | ~30-40 |
| Iteration buffer (~25% regen rate) | ~110-140 |
| **COMPLETE GAME** | **≈ 550-700 gens** |

**≈ 30% of the ~2,000/mo pool.** Remaining headroom covers misses,
A/B art variants, and P3 content (seasons, tent interior, events).

### Operational notes (from docs)
- **Map objects auto-delete after 8h** → download PNGs immediately at generation time.
- Downloads are unauthenticated UUID URLs (`/mcp/characters/{id}/download`, `/mcp/tilesets/{id}/image`) — safe to fetch then archive locally.
- Prefer `image_url` over inline base64 for references >32px (MCP clients truncate base64 args).
- MCP server configured at `.devin/config.json` (env `PIXELLAB_TOKEN`) → native tool calls in future sessions; REST `v2` remains the scripted-batch path.

---

## 8. Build order after approval

1. Approve this doc (story + loop + manifest).
2. **P0 generation pass** (style-locked to example.png) → assets drop into manifest.
3. Reskin `game.html` loop with P0 art + real UI styling → **the honest playable demo**.
4. Playtest → adjust economy/pacing → P1 pass.
5. Only then decide if the real client (Vite+React+TS+PixiJS + server.py rewrite) is warranted.

## 9. Security note
DONE — token moved to `PIXELLAB_TOKEN` env var in `tools/pixellab_gen.py`
(see `.env.example`). `.devin/config.json` references the same env var.
