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
| — | `try-on`: outfit transfer → re-dress travelers from one base sprite (variant NPCs nearly free) |
| — | `create-instant-character`, `extend-map-v2`: **Tier 2 — NOT in $12 plan** |
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
The PixelLab token is currently hardcoded in `prototype/pixellab_gen.py`. Move to
`PIXELLAB_TOKEN` env var before any commit.
