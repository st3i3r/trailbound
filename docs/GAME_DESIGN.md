# TRAILBOUND — Game Design & Asset Bible

> Working title. A cozy camping/travel game for Telegram Mini Apps (mobile-first, works on
> desktop Telegram + web). **Visual target: `reference/eastward.jpg`** — fixed 3/4 tilted
> top-down (flat ground, object fronts), painterly soft-dithered pixel art, bright
> daylight lush palette. `reference/example.png` = secondary ref for prop density and
> ember-light dusk mood (delivered by our day/night tint, not the base style).
>
> This doc is the contract: **story → gameplay → asset manifest → budget**.
> No art is generated until this is approved.

---

## 1. Premise & Story

**You're reopening the trail's chain of forgotten rest stops.**

Your grandfather wasn't just a camper — he was the Grand Trail's last warden, keeper of a
whole chain of rest stops from Pinewatch to Glasscoast, each stamped in his **trail
journal**. The trail fell quiet when he stopped. You arrive at the first overgrown site
with a backpack, a battered tent, and that journal. *"The trail remembers those who tend
it. Finish the book for me."*

So you rebuild, one site at a time: open the clearing, host travelers, earn, decorate and
upgrade until the site earns its stars — then walk further up the trail and open the next.
Each site is grandpa's next journal chapter: river camps with docks, a valley meadow camp,
a windblown coast camp. Travelers return, the trail wakes up, and the journal fills in.

**Why this story:**

| Design need | What the story provides |
|---|---|
| Reason to leave camp and return | Day trips outward, hosting in the evening |
| Reason sites unlock in order | Grandpa's chain — journal chapters = site arcs |
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

### Meta loop — v2: THE CAMPSITE CHAIN (progression = new sites)

```
Open site → visitors arrive & pay → upgrade site (decor/accessories = capacity+charm)
→ hit milestone (★ rating / guests hosted / special event)
→ OPEN THE NEXT SITE down the trail → new terrain + visitors + amenity → repeat
```

**Sites = progression.** Each campsite is a level:

| # | Site | Amenity (its activity) | Milestone to next |
|---|---|---|---|
| 1 | Pinewatch Forest | foraging + campfire | host 20 guests / 2★ |
| 2 | Whisper River | fishing + dock | 3★ + rod owned |
| 3 | Lantern Valley | trail riding | 3★ + bike owned |
| 4 | Glasscoast | kayak + shell hunt | 4★ + special event |
| 5 | Snowpass Mountain | climbing | arc-2 |

**How a site works (light management, v1):**
- Site has **build slots** (plots, fire, tables, lights, amenity) — pick what goes in
  each; free-form drag-placement deferred to P3
- **Tonight's capacity = beds + food + fire** → how many guests arrive at dusk
- Guests pay + rate → money buys decor/accessories → **charm/rating → better guests
  + more capacity** (the camp visibly transforms = the reward)
- **Money is for building the CURRENT site; milestones unlock the NEXT** — coins
  never gate progress, achievement does
- Old sites persist: revisit anytime (events, postcards); caretaker income later
- **What carries:** coins, gear catalog, dog, journal, rating. Each site's build state
  saves independently
- The **trail map screen** becomes the site map: current / locked / reopened sites —
  a literal visual of the trail waking up

**Why this is stronger:** the old design's "unlock a location" was a paywall beat;
the new one is an *achievement* beat — you earn the next site by running the current
one well. Retention-wise each site is a self-contained mini-arc (~weekly), which is
exactly the 3-month cadence: new site ≈ new arc ≈ one monthly content batch.

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
| Mountain boots → Sea kayak | 800c → 1500c (S2 runway) |
| Consumables (firewood bundle, bait, ice) | 5-15c — recurring sink |

Target pacing: rod day 1, site-2 (Whisper River) ~day 5 via 2★ milestone — coins buy
*builds*, stars buy *expansion* (§3 meta v2).

### 4.3 Guests — the full lifecycle (management core)

**Charm** = site comfort score (build mix + decor). Drives booking frequency, tip rate,
and *tier* of guests (the photographer only books at 3★+ sites).

**Guest types & stay length:**
| Type | Stay | Needs | Pays |
|---|---|---|---|
| Meal-stop hiker | evening | 1 meal | 30-60c |
| Overnight camper | evening + breakfast | plot + meal + fire | 80-150c |
| Family (4) | overnight | 2 adjacent plots + play space + group meal | 200-350c |
| Regular | recurring | remembers your site; expects favorite meal | +50% tip |
| Elite (blogger, warden's friend) | overnight | 4-5★ site, signature dish | big review / story |

**Plot assignment = the nightly management puzzle.** Guests book specific plots;
adjacency matters — anglers seated together swap stories (+tips), kids next to the
fire = happy family, a couple shoved between a scout troop = complaint. Full site →
**turn-away choice**: lose the sale vs squeeze (crowding = rating hit).

**Satisfaction score per guest** (0-5★) = f(bed quality, food match, fire warmth,
adjacency, dog pet, weather cover). Site rating = rolling average; individual reviews
pop as speech bubbles. Negative events exist: rainy night + cheap tent = 2★ review.

**Service requests beyond food:** take their photo · fix a bike · tell a trail story ·
pet their dog. Small interactions, big charm — served guests linger, chat, leave tips.

**Max visible guests** 4-6; no hard patience failure (cozy) — ignored guests just
leave, costing the sale and a tiny rating tick.

### 4.4 Demand & the nightly economy

- **Demand curve:** weekend nights busy (5-6 guests), weekdays quiet (2-3), rain
  halves bookings, events spike. The **forecast** (breakfast letter) tells you
  tomorrow's demand → you plan firewood, meals, and whether to open new plots.
- **Menu choice = demand steering.** Setting tonight's menu (stew / fish / pie)
  attracts matching guests: hikers want stew, van-lifers want fancy. One morning
  decision shapes the evening.
- **Supply:** meals need ingredients (forage/fish = the activity layer's job);
  **fire needs firewood** (chop = 1⚡ or buy bundles); cooler upgrade extends
  ingredient shelf-life (raw forage spoils next day, cooked meals same evening).
- **Turn-away:** full camp + extra booking → decline (lost sale) or squeeze (+1 cot,
  -adjacency for everyone). Scarcity is the decision, not the grind.
- **Late-game sinks:** seasonal-exclusive decor, consumables (wood, bait, cooler ice),
  deluxe decor tiers — coins never inflate.

### 4.5 Activity depth upgrades

- **Foraging:** quality tiers (normal/gold glint), weather modifiers (rain = more
  mushrooms, fewer flowers), **replant** — leave the root (1 free action) and the
  node regrows in 2 days instead of 4. Node states: sprout → full → harvested.
- **Fishing:** **bait crafting** (mushroom scrap → bait = activity interlock), spot
  choice along the bank, dawn/dusk species, weight records + leaderboard.
- **Cooking:** timed pot (left too long = burnt → compost or sad-meal), recipe
  quality tiers, **site signature dish** (forest = Trail Stew, coast = chowder —
  signature on the menu raises that site's charm).
- **Hosting:** adjacency bonuses, ambiance multipliers (lit lanterns + music +
  fire = evening "golden hour" tip bonus).

### 4.6 Upkeep & decay — the daily management pulse

Light maintenance so logging in matters beyond collecting:
- **Firewood depletes** nightly (woodpile visual states: full → low → empty); a cold
  site = cold guests = rating hit
- **Mud after rain** (decal overlay; swept away next visit or with a broom upgrade)
- **Tent pegs loosen** (tap to fix, 30s task); **cooler ice melts**
- Visiting an old site restocks it — keeps reopened sites on your route

### 4.7 Cross-site supply chain — why multiple sites matter

Sites aren't parallel saves; they're a network:
- Each site produces its specialty (forest: mushrooms+wood, river: fish, coast:
  shells+kelp, valley: honey+flowers)
- **Supply runs:** load the pack mule / send the **dog courier** (bandana bag!),
  deliver forest mushrooms → coast camp's chowder unlocks; river fish feeds any site
- Specialty-gated meals make every site depend on your network → reopening old
  sites = ongoing purpose, not nostalgia
- v1: one delivery UI + per-site inventory. P2: auto-routes, market trades.

### 4.8 Site specialization

Build mix declares an identity per site: **family campground** (play props, group
plots) · **angler's lodge** (dock, smoke rack, fish menu) · **stargazer retreat**
(telescope, dark-sky lights, quiet corner). Specialization shifts the guest pool
and unlocks themed events. Replay value: your forest camp ≠ my forest camp.

### 4.9 Warden ranks (account progression)

Site stars build **Warden Rank 1-10** — the account-level title:
- Rank gates decor tiers, elite guests, and site count
- Rank badge on profile/postcards; leaderboards sort by rank
- Rank-up = celebration moment (banner + letter from the ranger HQ)

### 4.10 Hazards (light mischief, never fail states)

- **Raccoon** raids uncovered food at night (cooler = defense; funny chase-off anim)
- **Bear** wanders the mountain site (dog barks it off — the dog earns his keep)
- Sudden downpour test: uncovered firewood gets wet. Light stakes, great stories.

### 4.11 Guest pets & barter

- Some guests bring dogs — they play with yours while you cook (0-cost joy)
- **Barter offers:** a guest proposes item-for-item (angler trades a lure for
  dinner). Charm > coins sometimes — the trail economy isn't only money.

### 4.12 Prestige — Trail Fame (post-arc)

After the chain is complete: **Trail Fame** soft-reset — restart the trail with a
permanent reputation bonus + legacy journal pages. Standard cozy live-ops loop;
P3 implementation, designed-in from the schema (per-site state already isolated).

### 4.13 Explicit NO-list (scope traps)

| Tempting | Verdict |
|---|---|
| Staff/payroll sim | ❌ dog + ranger cover the fantasy |
| Free-form build editor v1 | ❌ slots give 80% of the feel; P3 |
| Hard patience/fail states | ❌ cozy = low pressure; leave = lost sale only |
| Skill trees / RPG stats | ❌ the journal is the progression |
| PvP / competitive | ❌ wrong audience entirely |

### 4.14 The Journal (retention + collection)
Pages auto-fill:
- **Trail stamps** — one per location visited
- **Field notes** — species collected (Foragedex ~12, Fishdex ~10)
- **Guestbook** — every traveler type served signs it (~8)
- **Recipes** — discovered cooking pairs (~6)
- Completion % is the share-bait stat.

### 4.15 The dog
Adopted on day 2 (scripted). Follows the player on trips; occasionally digs up a bonus
item (visible sparkle → walk over). **Courier duty:** delivers supply runs between your
sites (§4.7). **Defense:** barks off the bear (§4.10). Pure charm + a light economic
trickle. 4-dir walk + sit + happy-bark + courier-bag frames needed.

---

## 5. Scene & UX Structure (mobile-first)

| Screen | Contents |
|---|---|
| **Scene view** | Fixed 3/4 tilted top-down (Eastward view). Tap-to-walk. Interactables glow. Fixed camera, pinch-zoom allowed |
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

## 6. The Site Chain (v2 — campsites ARE the locations)

Each site = one managed campsite + its local activity (§4.x). Progress = reopening
the chain; milestone-gated, never coin-gated.

| # | Site | Status | Palette | Amenity / specialty | Guests |
|---|---|---|---|---|---|
| 1 | **Pinewatch Forest** | ✅ start | green/dusk | forage, campfire · mushrooms+wood | hikers, family, scout |
| 2 | **Whisper River** | 🔒 2★ | green + blue bank | fishing, dock · fish | anglers, photographers |
| 3 | **Lantern Valley** | 🔒 3★ | golden meadow | trail riding · honey+flowers | cyclists, van-lifers |
| 4 | **Glasscoast** | 🔒 4★ | sand/sea | kayak, shell hunt · shells+kelp | surfers, families |
| 5 | **Snowpass Mountain** | 🔒 arc 2 | rock/snow | climbing · herbs | elite, bear |

**Activity access model:** your current site's amenity is free; visiting other
*reopened* sites uses their amenities (that's why the supply chain works — you walk
your own network). The old "travel to a location" loop is absorbed: destinations
are now the sites themselves, each a business to run.

---

## 7. ASSET MANIFEST — the PixelLab list

**Style lock v2 (Eastward, approved):** `reference/eastward.jpg` as style/color reference
on every call where supported (`style_image` / `color_image`). Camera view:
**"high top-down" (~35-40°)** for characters/objects AND terrain — the Eastward
3/4 tilt: flat ground plane, object fronts visible, Y-sort depth. **No iso diamonds,
no Wang sets.** All props `no_background`. Base mood: bright daylight; the
example.png ember-dusk look is recreated at dusk via scene tint + glow (0 gens).

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

### 7.2 P0 — the diorama (~$0.70 USD, ~55 gens) — *superseded by §7.16 (Eastward view)*

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
render   = PixiJS Container tree + Y-sort depth adapter (3/4 tilted top-down)
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

#### P1 cast — ~20 gens (idles only; walks deferred to P2)

Travelers mostly *sit at camp* — south-facing idle is 80% of their screen time.
Generate sprites + idle now; add walk×4 (~14 gens/char) only for those who
visibly hike in (hiker, photographer, family arrival).

| Char | Prompt | Anims | Gens |
|---|---|---|---|
| hiker | middle-aged hiker, red flannel, big grey backpack + bedroll, walking poles | idle_s (+walk later) | 2 |
| photographer | young photographer, mustard rain jacket, camera on neck strap, beanie | idle_s (+walk) | 2 |
| old angler | elderly fisherman, grey beard, bucket hat, green vest, fishing rod | idle_s | 2 |
| kid scout | small kid scout, oversized green backpack, cap, freckles | idle_s | 2 |
| van-lifer | relaxed woman, denim overalls, purple bandana, coffee mug | idle_s | 2 |
| **dad (family)** | dad camper, beanie, green plaid shirt, holding thermos | idle_s | 2 |
| **mom (family)** | mom camper, fleece vest, ponytail, holding trail map | idle_s | 2 |
| **boy (family)** | ~10yo boy, oversized backpack, backwards cap, stick in hand | idle_s + **run×4 later** | 2 |
| **girl (family)** | ~7yo girl, pigtails, tiny backpack, marshmallow on stick | idle_s + **run×4 later** | 2 |
| cyclist | cyclist, helmet, sporty jersey, sunglasses pushed up | idle_s | 2 |

**The family unit** (dad+mom+boy+girl) is a first-class visitor archetype:
arrives as a group, takes two blankets, places a group meal order (bigger
reward), kids run around the fire — the best "alive camp" moment per gen spent.
Kid anims: `run` ×4 + `play` — they never walk calmly anyway.

**Player skins** — v1 ships ONE protagonist (the campsite keeper = you).
Variants later: palette-swap recolors ≈ 0 gens; alternate body sprites
~15-17 gens each → natural Stars cosmetic item.

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

**Transitions — v2 (Eastward flat ground):** no Wang sets. Terrain meets terrain via
**edge strips** — one soft border strip per material pair + corner caps where needed:
shore edge (grass→water), bank edge (dirt→water), path edge (grass→path),
sand→water shoreline, rock/cliff face strips.
→ **~5 edge sets ≈ 25-40 gens** (was 7 Wang sets ≈ 70-105 — the iso switch saved ~50)

**Perimeter frame:** each site's boundary = fence/cliff-band/forest-wall PROPS
(the cozy enclosure reads as objects, not tiles) — counted in props, ~0 extra here.

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
| travelers ×10 (incl. family) | 10 | idle×10, sit-var×4, eat×2, walk×8 (hiker+photo), **kid run×8 + play×2** = ~36 |
| portraits ×8 | 8 | — |
| critters ×6 | 6 | fly/hop/flutter/jump/gull/graze = ~8 |

#### Management-depth delta (§4.3–4.12 — v2 spec)
| System | New assets | Gens |
|---|---|---|
| Guest lifecycle | overnight tent-occupied variant, breakfast tray, star-review bubble | 3 |
| Upkeep/decay | woodpile ×2 extra states, mud decal, wet-firewood variant | 4 |
| Cooking depth | burnt meal variant, bait items ×3, sprout-node state ×8 (batched) | 5 |
| Hazards | raccoon (sprite + scurry + steal), bear (sprite + wander) | 6 |
| Pets/courier | guest dogs ×2 palettes, courier bandana-bag accessory | 3 |
| Supply chain | supply crate, delivery box, loaded-pack variant | 3 |
| Warden ranks | badges ×10 + rank-up banner (batched) | 3 |
| Specialization | lodge/retreat/family icons ×3, themed props ×3 batched | 4 |
| Signature dishes | dish cards ×5 (batched) | 2 |
| Plot/booking UI | plot markers, booking board, kids' play props (ball, kite) | 4 |
| Trail Fame | prestige emblem | 1 |
| **Management delta total** | | **~38** |

#### Non-art production assets (0 gens, still required)
audio SFX ~35 (ambience ×8, actions ×15, UI ×7, dog ×3, music ×3 loops) ·
save_version + migrations · zod catalog schemas · CI/CD + Playwright smoke ·
Sentry · analytics funnel events · remote economy config · i18n extraction ·
a11y pass · TMA checklist (BotFather, banner, description, rating, safe areas,
HTTPS) · Stars cosmetic catalog · LEGAL (have)

### 7.14 FINAL totals

| Block | Gens |
|---|---|
| Terrain (Eastward flat: tiles + 5 edge strips, no Wang) | ~60-80 |
| Props/accessories (all scenes, ~150 items, batched) | ~120-150 |
| Characters (statics + rotations + all anims) | ~90-110 |
| Scene/critter anims | ~25-35 |
| VFX + UI + icons + states | ~60-80 |
| Story/launch/meta art | ~30-40 |
| Management-depth delta (§4.3-4.12) | ~40-55 |
| Iteration buffer (~25% regen rate) | ~110-140 |
| **COMPLETE GAME** | **≈ 545-695 gens** |

**≈ 30-38% of the ~2,000/mo pool.** Remaining headroom covers misses,
A/B art variants, and P3 content (seasons, tent interior, events).

### 7.16 MASTER GENERATION LIST — consolidated build order

Every asset we generate, deduplicated, in the order batches should run.
`[A]` = animated (needs anim frames), `[S]` = has state variants (counted),
`[B]` = batchable at 32px (64 items per ~10 gens via consistent-style).

#### BATCH 0 — style lock (gate: approve before anything else) ~15 gens
- player south sprite (iterate prompt until approved)
- grass tile sample + shore-edge strip sample (grass→water)
- 1 prop sample (tent t1) + `reduce_colors` palette lock

#### BATCH 1 — terrain ~60-80 gens (Eastward flat ground — was 110-140)
- **Ground tiles:** grass ×5 (plain/tuft/flowers/worn/sparkle) · dirt ×3 (bare/tilled/mud) · sand ×3 (plain/rippled/shell) · rock ×3 (boulder/gravel/smooth) · stone path · wood planks ×2 · shallow water ×2 · deep water ×2 · puddle decal ×3
- **Path:** dirt-path tiles (straight/turn/end variants, ~6-8 tiles, no autotile needed at this view)
- **Edge strips ×5 sets** (~5-8 gens each): shore edge · bank edge · path edge · shoreline (sand→water) · cliff-face strips
- **Perimeter:** fence/cliff-band/forest-wall props — frame the enclosure (in batch 2/3)
- **Waterfall:** static + [A] flow 4f

#### BATCH 2 — camp props ~90 items, ~60-80 gens
- **Sleep:** tent t1/t2/t3 `[S]` · tarp · hammock `[A]` · bedroll · sleeping bag · dog bed
- **Cook/eat:** fire ring unlit/lit `[S+A]` · tripod+pot ×3 states `[S]` · stove · cooler · kettle · mugs · thermos · camp table · chairs ×2 · log bench · stump seats · picnic blankets ×2
- **Storage:** crates · barrel · sack · backpack prop · gear rack · basket
- **Light:** lantern post unlit/lit `[S]` · string lights `[A]` · torch `[A]` · tent lantern · fire-pit t2 `[A]` · embers
- **Info:** notice board · chalkboard/menu board · trail signs ×3 · map table · guestbook stand · booking board · plot markers ×4
- **Comfort:** guitar · books · camera tripod · binoculars · planter · welcome flag `[A]` · wind chime `[A]` · clothesline+towels `[A]`
- **Dog:** doghouse · bowl · bone · leash post · courier bandana-bag
- **Fishing:** rod prop · rod rack · tackle box · bait bucket · creel · net
- **Bike:** bicycle · rack · repair stand · pump · trail markers
- **Chores:** woodpile ×3 states `[S]` · axe-stump · log rounds · broom
- **Boundaries:** fence straight/corner/gate · rope fence · stone wall
- **Management:** supply crate · delivery box · loaded-pack variant · kids' play props (ball, kite) · mud decal · wet-firewood variant
- **Shop:** outfitter van · ranger kiosk
- **Clutter batch `[B]`:** mushrooms, flowers, tufts, pinecones, leaves, rocks, pebbles, stepping stones — 64 @32px in 1-2 calls

#### BATCH 3 — site prop sets ~50 items, ~45-60 gens
- **Forest:** forage nodes ×8 **×3 states** (sprout/full/harvested) `[S]` · hollow log · ferns · mossy rock · leaf piles · tall grass · cache dig-spot · dense trees ×3 `[A sway]`
- **River:** dock · bridge · cattails · reeds · lilypads · stepping stones · canoe `[A bob]` · shore rocks
- **Valley:** wildflower meadow tiles · vista rock · viewpoint bench · sign · stream `[A]` · kite `[A]`
- **Coast:** shells · starfish · driftwood · tide pools · beach grass · kayak · umbrella · beach blanket · buoy · sea cliff
- **Mountain:** boulders · summit flag `[A]` · climbing props · cairns · pine variants ×2

#### BATCH 4 — characters ~90-110 gens (static + rotations + anims)
- **player** — sprite + 8-rot + anims ×11 (idle, walk×4, gather, cast, reel, carry, sit, sleep, celebrate, eat)
- **dog** — quadruped sprite + 8-rot + anims ×10 (idle, walk×4, sit, dig, bark, sleep, heart-react) + courier-bag variant
- **ranger** — sprite + idle, wave, talk
- **travelers ×10** (hiker, photographer, old angler, kid scout, van-lifer, dad, mom, boy, girl, cyclist) — sprites + idles; sit-variants ×4, eat ×2, walks for arrivals, kid run×4 + play
- **portraits ×8** (32-48px busts for journal/dialogue)
- **guest dogs ×2** (palette variants)
- **hazards:** raccoon `[A scurry,steal]` · bear `[A wander]` (mountain)

#### BATCH 5 — scene/world anims ~25-35 gens
- **critters:** bird-fly · squirrel-hop · butterfly · frog-jump · seagull · goat (mtn)
- **fire:** campfire loop · torch · fire-pit-t2 · ember-glow · smoke · steam
- **water:** waterfall · fish-jump · fish-shadow · bobber · ripple-ring · canoe-bob · wave loop
- **life:** tent flap · hammock sway · (tree/flag/chime/towels/lights counted in batch 2/3)

#### BATCH 6 — items, food, UI, VFX ~60-80 gens
- **Meals ×8** (stew, berry pie, skewers, sandwich, tea, grilled fish, s'mores, soup) + burnt variant + **signature dish cards ×5**
- **Ingredients ×9** + bait ×3 + honey/acorn/catfish extras
- **Gear icons ×12** · stamps ×8 · warden badges ×10 · HUD icons ×5 (coin/⚡/charm/day/★)
- **Bubbles/markers:** want-bubble + tail · review-star pop · !/? marks · coin-fly · energy glow
- **UI widget sheet** `[B]` — 64 widgets @32px (buttons, slots, bars, frames) in 1-2 calls + journal page frames + menu board frame
- **Journal:** cover · stamps · recipe cards ×8 · dex entry frames
- **Map screen:** 320px top-down illustration · pins ×6 ×locked/unlocked `[S]` · path line · you-are-here marker
- **Story:** letter pages ×5-8 · sepia photos ×3 · grandfather portrait · journal prop
- **Onboarding:** hand pointer · paw-trail decal · first-time dialog frames
- **VFX `[A]` ×10:** unlock burst · sparkle · stamp-press · splash · level rays · heart pop · ZZZ · catch burst · serve ding · rank-up rays
- **States/errors:** offline illustration · error toast frame · empty inventory · empty camp · postcard frame+template

#### BATCH 7 — launch/meta ~30-40 gens
- app icon 512px · splash/loading card · title card · promo key-art ·
  bot avatar + banner · warden-rank banner

#### FREE LAYER — 0 gens (engine-side)
day/dusk/night tint · rain/fog particles · glow overlays · fireflies ·
water shimmer · bob/tween micro-motion · palette-swap variants ·
want-bubble pulse · wet-sheen · mirroring E→W

#### Grand totals
| Block | Gens |
|---|---|
| B0 style lock | ~15 |
| B1 terrain (Eastward flat — no Wang) | ~60-80 |
| B2 camp props | ~60-80 |
| B3 site props | ~45-60 |
| B4 characters | ~90-110 |
| B5 world anims | ~25-35 |
| B6 items/UI/VFX | ~60-80 |
| B7 launch | ~30-40 |
| Iteration buffer ~25% | ~110-140 |
| **COMPLETE** | **≈ 545-695** |

### Operational notes (from docs)
- **Map objects auto-delete after 8h** → download PNGs immediately at generation time.
- Downloads are unauthenticated UUID URLs (`/mcp/characters/{id}/download`, `/mcp/tilesets/{id}/image`) — safe to fetch then archive locally.
- Prefer `image_url` over inline base64 for references >32px (MCP clients truncate base64 args).
- MCP server configured at `.devin/config.json` (env `PIXELLAB_TOKEN`) → native tool calls in future sessions; REST `v2` remains the scripted-batch path.

---

## 8. The 10-day arc — retention design

**Core insight:** cozy games don't retain through challenge — they retain through
*unfinished business* (a journal half-filled, a camp half-built) and *tomorrow
promises* (a letter arriving, rain ending, a rare spawn announced). Session
length stays 3-5 min; the design goal is making **tomorrow's session feel
worth having.**

### 8.1 The story IS the retention mechanism

- The journal has **10 blank pages**. Every morning the ranger delivers one
  of grandpa's letters — story beat + hint about tomorrow's content +
  occasional gift (his old tackle box → +fishing luck).
- Each night the game **writes your day as a journal entry** — your own
  progress becomes the story. Players return to see their journey written down.
- **Day-10 letter** reveals grandpa's secret spot → first-arc finale →
  "the trail continues" hook for arc 2.
- **Forgiveness rule:** missed days deliver letters late. Never punish absence
  in a cozy game — that kills the vibe harder than any churn.

### 8.2 The actual 10 days

| Day | What happens | Tomorrow's hook |
|---|---|---|
| 1 | Arrive; ranger greets; stray dog adopts you; first forage + cook | letter hints at the river |
| 2 | Buy rod → **fishing unlocks** (first gear-gate dopamine) | angler visits, mentions the golden koi |
| 3 | Letter gift: grandpa's tackle box; **family visits** (group order) | rain forecast |
| 4 | **RAINY DAY** — fish bite more, forage halved, camp feels extra cozy | clear skies |
| 5 | **Valley unlock** (500c) — new species, new diorama | photographer coming |
| 6 | Photo-spot quest; angler returns to check your koi progress | bike in stock |
| 7 | **Bike** → valley trail-riding activity | coast rumor |
| 8 | **Rare spawn day** — goldcaps ×3; angler's big-fish story arc | letter: "the coast holds something" |
| 9 | **Coast unlock** (1500c) — kayak, shells, new fish | journal ~70% |
| 10 | **Grandpa's secret spot revealed** + stamp finale | arc-2 hook |

### 8.3 Daily return drivers (habit systems)

- **Breakfast forecast** — weather + rare-spawn hint at day start; different
  day = different optimal plan (rain = fish day, not forage day)
- **Daily quest card** — 3 small tasks → coin bonus + stamp progress
- **Dog bond** — feed the dog daily → bond level → better cache finds;
  a daily habit with mechanical payoff and emotional weight
- **Visitors with memory** — the angler tracks your koi progress, the
  photographer returns every 3 days, the family comes back on weekends.
  NPCs remembering you is the cheapest retention mechanic there is
- **Node regrowth** — yesterday's cleared spots are fresh again; no
  location ever "dies"
- **Guestbook** — travelers sign on departure; collecting signatures is
  the relationship metagame

### 8.4 The real reward: the camp grows

The strongest retention lever is **visible progression on the diorama itself**:
day 1 = bare clearing, old tent, cold pit → day 10 = string lights, tier-2 tent,
flower beds, doghouse, kids playing by the fire. Every purchase changes the
scene itself = screenshot-worthy = shareable (postcard feature).

### 8.5 Economy pacing for 10 days

Gear ladder — one purchase lands every ~1-2 days:
rod 60 → net 90 → lantern 120 → tent2 200 → bike 300 → stove 400 → decor 50-500∞

Unlock ladder: forest/river free → valley 500 (d4-5) → coast 1500 (d8-9) →
mountain tease (arc 2). Income grows via group meals, rare fish, quest bonuses.

### 8.6 What killed retention — and the fix

| Problem | Fix |
|---|---|
| Foraging = walk+tap | sparkle→decay timing, dog-dug caches, announced rare spawns |
| Interchangeable visitors | recurring cast with memory + the family unit |
| Cleared locations dead | species rotate, rare-spawn days pull you back |
| Identical days | weather/forecast changes optimal strategy daily |
| No visual payoff | camp upgrades visibly transform the diorama |
| Story as wallpaper | letters = delivery mechanism; your days become the journal entries |

### 8.7 The 3-month model (post-arc survival)

Day-10 ends the story — months 1-3 must run on *cadence + collection + social*.
The proven genre structure (Animal Crossing is the reference):

**Monthly — one new arc (~100-150 gens each, the sub funds it):**
- M2: **Snowpass Mountain** — rock/snow terrain, climbing verb, mountain tea,
  goat critter, letter arc "grandpa's winter"
- M3: **Ember Desert / Twilight Hollow** — new terrain set + night-exclusive
  foraging (lantern finally pays off) + arc-3 letters
- Each arc = 1 Wang transition set + ~30 props + 1-2 visitors + 5 species +
  gear tier. Fits inside the monthly pool with room to spare.

**Weekly — rotating events (data + a few props, near-zero cost):**
- Fishing Friday (tournament — biggest catch leaderboard)
- Market Saturday (**trader van** visits, rotating stock — the reason to
  check the shop every week; Animal Crossing's Redd/turnip model)
- Mushroom Sunday / Meteor Monday (night event, lantern-gated)
- Events are JSON entries + reuse of existing scenes — cheap to author,
  gives the "what's on this week" check-in

**Seasonal — reskins, not new scenes:**
autumn leaves / winter snow / spring bloom on existing tilesets + seasonal
props + limited species. ~30-50 gens per season via variant passes —
the biggest retention-per-gen lever in the whole plan.

**Evergreen endgame systems (built once):**
- **Camp rating 1-5★** — charm + decor + quests → better/elite visitors
  (food blogger at 4★, **grandpa's old friend at 5★** = story payoff)
- **Collections** — fish dex (~20 species incl. 1 legendary/location),
  recipe book, stamp album, guestbook signatures, photo spots
- **Visitor storylines** — each traveler has a 3-visit arc: angler's big
  fish, photographer's exhibition, the family's weekend tradition,
  kid scout's badge. Resolves over weeks, not days
- **Dog bond** — levels unlock tricks + better finds (long-tail habit)
- **Decorating** — decor catalog grows monthly; camp-as-canvas is the
  actual endgame expression for this genre

**Social (Telegram-native, no realtime multiplayer needed):**
- **Async camp visits** — see friends' camps, leave guestbook signatures +
  small gifts; the strongest TMA-native hook available
- **Postcards** — composite your camp → share to chat (already in manifest)
- **Leaderboards** — biggest fish / fastest journal / most signatures
  (Telegram high-score API is free)

**Honest math:** 3-month survival for indie games is hard — good casual D30
is ~5-10%. The goal isn't "everyone stays," it's "people who connect get
3 months of reasons." What that demands: **ship something new every week**
(event or arc), which is why the manifest-driven pipeline matters — new
content = catalog rows + small art batches, not code changes.

## 9. Build order after approval

1. Approve this doc (story + loop + manifest).
2. **P0 generation pass** (style-locked to example.png) → assets drop into manifest.
3. Reskin `game.html` loop with P0 art + real UI styling → **the honest playable demo**.
4. Playtest → adjust economy/pacing → P1 pass.
5. Only then decide if the real client (Vite+React+TS+PixiJS + server.py rewrite) is warranted.

## 10. Security note
DONE — token moved to `PIXELLAB_TOKEN` env var in `tools/pixellab_gen.py`
(see `.env.example`). `.devin/config.json` references the same env var.
