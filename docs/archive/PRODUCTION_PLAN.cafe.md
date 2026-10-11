# My Café 3D — Production Plan

**The master reference for turning the prototype into a deep, production-grade game.**
Status: prototype (2D client + 3D scene shell) built and verified at `~/workspace/cafe-builder-3d/`.
Companion: `README.md` (deploy), `server.py` (authoritative backend), `index.html` (three.js client).

> Bar for this document: every system must answer **"what real decision does the player make?"**
> If a system has no decision in it, it doesn't ship.

---

## 1. Vision & Design Pillars

**One-sentence pitch:** *Build the corner café everyone loves — design it in 3D, master the craft of drink-making, and win the hearts of regulars whose stories unfold over weeks.*

### Pillars (each is a testable rule — if a feature violates one, it gets cut or redesigned)

1. **Every decoration changes gameplay, never just looks.**
   *Test:* removing any decor item from the floor must change at least one number — patience, tips, seats, or a set bonus. There are no pure-cosmetic items at launch. (Already true in the prototype: coziness → patience ×(1+cozy/100), tips ×(1+cozy/80); tables/armchairs provide seats; chalkboard/jukebox carry tip bonuses.)

2. **Alive in 10 seconds.**
   *Test:* from cold open, a customer walks through the door and steam rises from a cup within 10 seconds. If the café ever feels like a dollhouse, we failed. This is the ant-farm rule — the thing that makes idle settlement builders (the genre in the ad Viet saw) impossible to put down.

3. **Every session ends with a decision, not a timer.**
   *Test:* the end-of-day summary always presents a meaningful spend choice — at least two affordable upgrades the player must pick between (e.g., "expand the hall" vs. "buy the espresso machine"). Coins must never sit idle without tension.

4. **Depth is data, not code.**
   *Test:* a full season — 20 decor items, 2 drinks, 1 story arc — ships as JSON + art with zero code changes and zero client update. The catalog, recipes, regulars, and events are all data files the server serves.

---

## 2. Narrative & Characters

### Player fantasy
You are not "a barista." You are the person who built *the* café on the street — the one with your name on the chalkboard, where the novelist writes her chapters and the nurse survives his night shifts. The fantasy is **ownership + belonging**: this place exists because of you, and these people come back because of you.

### The cast — regulars with multi-week arcs (Coffee Talk-style, but mechanical)

Story is not cutscenes bolted onto a tycoon game. Each regular's arc **unlocks or modifies a mechanic**: a recipe, a decor item, an event, a trait. Arcs advance through serve counts + 2-option dialogue choices; choices have mechanical consequences (tips, traits, unlocks).

**1. Maya Okafor — the novelist.** Always ten minutes early, always the corner armchair.
- Signature order: latte → (arc) mint mocha.
- Arc *"The Last Chapter"* (3 beats over ~2 weeks):
  - **Beat 1 — Blocked.** She's stuck on her ending. Choice: *"Take your time, the café isn't going anywhere"* (+her patience trait permanently) vs. *"Writer's block loves a deadline"* (+tip generosity trait). Both are good; they shape *how* she rewards you.
  - **Beat 2 — A plot twist.** She asks for "something that tastes like a plot twist." This is a **guided recipe discovery**: the game hints at chocolate+espresso+mint. Discovering mint mocha *for her* triggers the beat.
  - **Beat 3 — Published.** Her book's dedication page names your café. Reward: **"Signed First Edition"** — a bookshelf skin, unique decor, +6 cozy. Permanent.
- Mechanic taught: **decoration matters** — Maya only becomes a regular once coziness ≥ 20. Her patience is 2× normal (she camps), so she's your stable income anchor.

**2. Mr. Chen — the retired watchmaker.** Precision obsessive. Times everything.
- Signature order: espresso, and he notices if it's not fresh.
- Arc *"The Perfect Pour"* (3 beats):
  - **Beat 1 — The stopwatch.** He times your brew-to-serve with a visible stopwatch. unimpressed.
  - **Beat 2 — Five in a row.** Serve 5 consecutive espressos with brew-to-serve < 15s. This teaches **brew-queue planning** — the core minute-to-minute skill.
  - **Beat 3 — The clock.** He gifts an **antique brass clock** (wall decor, unique, +8 cozy, faint ticking SFX near it).
- Mechanic taught: **speed and queue discipline**.

**3. Zoe Park — the lifestyle influencer.** 200k followers. Orders the photogenic one.
- Signature order: iced latte.
- Arc *"Going Viral"* (3 beats):
  - **Beat 1 — The photo.** Triggers only if coziness ≥ 40. She photographs your café — this opens **Photo Mode** and prompts your first share card.
  - **Beat 2 — The surge.** Her post brings a **viral crowd event**: 10 customers in 3 minutes. Survive it.
  - **Beat 3 — The brand deal.** Choice: accept (instant 800 coins, but a "sponsored" poster appears and purist regulars' patience −10% for 3 days) vs. decline (+0.2★ rep, Maya approves). A real values decision with real costs.
- Mechanic taught: **virality and its trade-offs**.

**4. Rafi Haddad — the night-shift nurse.** Evening only. Barely talks at first.
- Signature order: double mocha.
- Arc *"The Long Shift"* (3 beats):
  - **Beat 1 — Exhausted.** One-word answers. Serve him 3 evenings in a row to unlock Beat 2.
  - **Beat 2 — The Nightingale.** You invent a drink *for him*: mocha + caramel = **"The Nightingale"** (new recipe, 20 coins, evening-only demand boost). Recipe discovery with emotional weight.
  - **Beat 3 — The whole ward.** He brings his team → **group order event** (see §8).
- Mechanic taught: **the evening crowd** (the 4★ unlock) and off-peak play.

**5. Elena Voss — the critic.** You never know when she's coming.
- Signature order: unknown — mystery visits.
- Arc *"The Review"* (3 beats across weeks):
  - Three unannounced visits. Each is scored: correct drink (+), served fast (+), coziness ≥ thresholds (+).
  - **3/3 → "Five Stars."** Front-page review: +0.5★ rep instantly, customer surge for 3 days.
  - **0–1/3 → scathing review.** −0.5★ rep. You rebuild. (This is survivable by design — the comeback *is* the story.)
- Mechanic taught: **stakes**. She is the pressure system that makes perfect play matter.

### Story integration rules (non-negotiable)
- No arc is purely cosmetic. Each unlocks a recipe, a unique decor item, or an event.
- Dialogue choices are always 2 options, always both viable, always mechanically distinct.
- Arcs are paced by *play*, not by pay: no arc step can be skipped with Stars.
- New seasons add ≥1 new regular with a full 3-beat arc (content plan §14).

---

## 3. Core / Session / Lifetime Loops

### Minute-to-minute: THE TRIAGE GAME (sessions are won or lost here)
Customers arrive on timers (~25s base, scaled by rep). Each has a visible patience ring. Brewing takes 4s (one at a time until the second machine). You must constantly decide:
- **Which customer do I serve first?** (patience math under time pressure)
- **Which drink do I brew *next*?** (queue planning — brew for the customer who'll time out second, while serving the one who's critical now)
- **Do I risk a discovery brew** (unknown combo, might be sludge) **or play it safe?**
- **Rush event incoming in 30s — do I pre-brew?** (pre-brewed drinks wait in the "pass"; a second drink slot is the first meaningful convenience upgrade)

### Per-sitting: THE DAY (5–15 minutes)
- Serve the day's customers, manage 1–2 rush events, hit the day target.
- **The spend decision** (Pillar 3): end-of-day summary shows earnings and 2–3 affordable upgrades. Coins are always *almost* enough for the thing you want most.
- **Layout optimization**: coziness-per-tile is a genuine spatial puzzle. A 2×2 rug (+6 cozy, 4 tiles = 1.5/tile) vs. four lanterns (+16 cozy, 4 tiles = 4/tile, but 140 coins vs 60). Players who do this math feel smart — that's depth.
- **Discovery experiments**: 1–2 "what if I try…" brews per day.

### Lifetime: THE CAFÉ (weeks/months)
- Reputation climb 1★→5★, room unlocks (Hall → Terrace → Lounge), regular arcs unfolding, decor set collection, season passes.
- The long decision: **what kind of café is this?** Max-cozy literary haven (Maya's crowd, high tips, slow)? High-throughput commuter stop (many seats, fast brews, volume)? The systems support both — and the visit card shows it.

### Depth audit

| Layer | Real decision | Skill tested | Mastery signal |
|---|---|---|---|
| Minute | Serve order, brew queue, discovery risk | Triage under time pressure, working memory | Zero-walkout streaks; "perfect rush" (5 serves/60s) |
| Sitting | Spend allocation, layout, day targets | Economic planning, spatial optimization | Max cozy/tile layouts; all recipes found |
| Lifetime | Café identity, arc choices, season focus | Long-horizon planning, values trade-offs | 5★, full set collection, all arcs complete |
| Social | Whose café to visit/tip, group orders | Reciprocity, showcase craft | Visit card that makes friends jealous |

**Anti-shallow checklist** (run every feature through this before shipping):
- [ ] Does the player make a decision with incomplete information?
- [ ] Can a skilled player measurably outperform a casual one at this?
- [ ] Does it interact with at least two other systems?
- [ ] Would removing it make the game shallower?

---

## 4. Systems Design

### Economy — faucets, sinks, inflation control

**Faucets (coins in):**
| Source | Amount | Notes |
|---|---|---|
| Perfect serve | 8–20 price + ~20–40% tip (cozy-scaled) | Core faucet |
| Wrong drink | half price | Failure still pays a little — no death spirals |
| Sludge | +2 | Comedy consolation |
| Daily streak | 25 → 2000 (day 1–7+) | Already in server |
| Visit tips | visitors leave up to 10 coins, friend receives 8 | Capped 5/day/friend — anti-farm |
| Event rewards | 100–800 | Rush survival, viral crowd, rivalry |
| Arc completions | 200–500 + unique decor | Story pays |

**Sinks (coins out):**
| Sink | Cost | Notes |
|---|---|---|
| Decor | 20–500 | Tiered by café level |
| Hall expansion 8×6→10×8 | 500 | Already in server |
| Sunny Terrace unlock | 2,500 | Mid-game goal |
| Upstairs Lounge unlock | 8,000 | Late-game goal |
| Recipe hint | 50, scaling +25 per hint bought | Discovery stays earned |
| Ingredient restock | 20/refill (see below) | Planning sink |
| Renovation (move-all mode) | 100 | QoL sink |

**Inflation control (the unsexy work that keeps the economy alive for months):**
- Coziness soft caps: patience multiplier caps at +75% (75 cozy), tips at +100% (80 cozy). Beyond that, decor is expression, not power. (Server currently uncapped — **change before launch**.)
- Decor price tiers unlock with café level; early items never become trivially spammable for late-game cozy (diminishing returns per duplicate: 2nd copy of an item gives −25% cozy, 3rd −50%).
- Target faucet/sink ratio: **1.0–1.2** daily per cohort. If ratio > 1.5 for 3 days → hotfix sink (event entry fee, renovation costs).
- Target earnings: day-1 player ~250 coins/day; day-30 ~2,500/day. Tune spawn/tip numbers to hit this in soft launch.

**Ingredient stock (new depth lever — planned, not in prototype):**
Each ingredient has daily stock: 30 units, restores at day rollover. Brewing consumes 1 unit per ingredient in the combo. Running out mid-rush is a *planning failure you can feel*. Refill anytime for 20 coins. This turns "which drink" into "which drink *can I afford to keep making*" — and makes the espresso machine upgrade (faster brew) compete with stock management. **Server change required.**

### Progression

- **Café level** (new): XP = 1 per serve, 5 per discovery, 10 per arc beat. Levels gate catalog tiers (Lv 3: lighting+, Lv 5: premium-adjacent coin items, Lv 8: Terrace). ~30 levels; curve: level n needs 50×n XP.
- **Reputation 1–5★** (exists): 4★ unlocks evening crowd (exists); 3★ unlocks the Critic's first visit (new); 5★ unlocks "Landmark" status — your visit card gets a gold frame and you appear in the region showcase (new).
- **Recipe mastery** (new): brew a drink 25× → *Mastered*: −0.5s brew time for that drink. Earned power, never sold. Displayed as a badge in the recipe book.
- **Room unlocks**: Hall (start) → Terrace (2,500 coins + Lv 8) → Lounge (8,000 coins + Lv 15 + 4★ rep). Each room has its own coziness pool and customer capacity — expansion is horizontal, not just bigger numbers.

### Collection — decor sets (the answer to "why keep decorating")

6 launch sets × 4 items. Placing 3+ of a set in one room → **set bonus**:
| Set | Items | Bonus |
|---|---|---|
| Writer's Nook | bookshelf, armchair, paper lantern, rug | +15% patience |
| Barista's Pride | espresso machine, bar counter, chalk menu, neon sign | −10% brew time |
| Garden Corner | fern, ivy, bonsai, (seasonal plant) | +10% tips |
| Night Owl | lantern, neon sign, jukebox, velvet sofa | evening spawns +25% |
| Minimalist | (4 low-cozy modern items) | +5% rep gain |
| Heritage | clock (Chen), signed edition (Maya), +2 | +10% all, the prestige set |

Set completion → showcase badge on the visit card. Sets are the collection game *and* the strategy game: which bonus fits your café identity?

### Difficulty & pressure systems
- **Rush events** (exists as Rush Hour ad; add *organic* rushes): telegraphed 30s ahead ("Lunch rush incoming!"), 2× spawns for 3 min, 1–2 per day. Surviving with zero walkouts → "Rush Survivor" bonus (150 coins).
- **The Critic** (§2): unannounced, high stakes.
- **Ingredient shortage** (weekly event): one random ingredient is "sold out" for the day — regulars who want it must be served substitutes (wrong-drink penalty waived, small tip bonus for creativity). Forces menu adaptation.
- **Rivalry** (weekly): Ben's café across the street. Serve-count race over the weekend; winner gets the "Neighborhood Favorite" banner (+5% spawns for a week). Leaderboard is you vs. a tuned bot café + friends who opt in.

### Target tuning numbers (server constants to set/adjust)

| Constant | Prototype | Production target | Notes |
|---|---|---|---|
| DAY_LEN_S | 180 | 180 | Keep — fits Telegram sessions |
| BASE_SPAWN_S | 25 | 22 | Slightly busier at launch |
| PATIENCE_BASE_S | 60 | 55 | Tighter with cozy soft-cap |
| Cozy patience cap | none | +75% | **Add** |
| Cozy tip cap | none | +100% | **Add** |
| Duplicate cozy penalty | none | −25%/−50% | **Add** |
| REP_UP / DOWN | 0.08 / 0.15 | 0.06 / 0.12 | Slower rep = longer climb |
| Evening unlock | 4.0★ | 4.0★ | Keep |
| STREAK_BONUSES | to 2000 | to 2000 | Keep — strong D7 driver |
| Brew base | 4s | 4s | Keep; mastery −0.5s |
| Ingredient stock | ∞ | 30/day | **Add** |

---

## 5. UI/UX

### Screen map & flows
```
MAIN (3D viewport + HUD)
 ├── Serve sheet (customers → brew → serve; default tab)
 ├── Decorate sheet (catalog → ghost place → move/sell)
 ├── Recipe book (discovered/learnable; mastery badges)
 ├── Regulars (cast, arc progress, next beat hints)
 ├── Visit card / Photo mode
 ├── Shop (Stars catalog; seasonal pass)
 └── Settings (audio, reduced motion, text size, help)
TOUR MODE (read-only, via ?startapp=visit_<id>): viewport + tip button + "Open my café" CTA
```

Flows are shallow: **no screen is more than 2 taps from MAIN**. Sheets slide up over the viewport; the 3D scene stays visible behind (it's the star — never cover it fully).

### FTUE — first 3 minutes, beat by beat ("easy in 3 minutes" bar)

| Time | Beat | Design note |
|---|---|---|
| 0:00 | Cold open. Camera slowly orbits the empty-but-charming starter café (pre-placed: 1 table, 2 armchairs, 1 fern — never an empty room). "Welcome back, {name}" — haptic tick. | Alive-in-10-seconds: door bell rings at 0:06, Maya walks in. |
| 0:15 | Maya's order bubble pulses. Tap her → order card: "Latte, please." One pulsing button: the customer. | No text tutorial. Pulsing = the tutorial. |
| 0:30 | Serve sheet opens. Espresso + milk ingredient buttons pulse. Tap, tap → BREW pulses. | Max 2 ingredients for the first brew. |
| 0:35 | Pour animation + steam hiss + progress ring. Haptic on complete. | The ASMR moment. Make it *satisfying*. |
| 0:45 | SERVE pulses → coin fountain + happy chime + "+14 coins (tip 2.8)". Maya hearts. | First dopamine hit < 1 minute. |
| 1:00 | "Your café needs warmth." Guided ghost: free potted fern, one legal tile highlighted. Place → coziness 3 → patience numbers visibly tick up on the next customer. | Teaches Pillar 1 *by doing*: decoration changed a number. |
| 1:30 | Second customer arrives unguided. Hint chip (not modal): "Tap a customer to take their order." | Fading guidance. |
| 2:00 | Catalog teaser: "12 decorations waiting" badge pulses once. Not forced. | Curiosity, not interruption. |
| 2:30 | Day bar fills → end-of-day summary: served 2, earned 31, "Day 2: new customers, new stories." Streak explained in one line. | Pillar 3: session ends with a decision preview. |
| 3:00 | Free. MainButton: "🌙 End day". | |

**FTUE rules:** no modal before the first serve; every teaching is a pulse, never a paragraph; the whole thing is skippable (a subtle "Skip" that grants the fern); completion fires `ftue_complete` analytics.

### 3D touch interaction patterns
- **Orbit:** 1-finger drag rotates azimuth (clamped ±65° from default so players never get lost behind walls); pinch zooms 6–16 units; 2-finger drag pans, clamped to room bounds. Polar angle fixed ~55° — the diorama look, no motion sickness, always readable.
- **Placement:** tap catalog item → ghost preview follows raycast on floor; green = valid, red = blocked (overlap/out-of-bounds); haptic tick on validity change; tap to commit. Invalid tap → gentle shake + error haptic, never a modal.
- **Selection:** tap customer bubble (HTML overlay, 44px min touch target) → selected (gold ring in 3D + order card in sheet). Tap placed decor → move/sell panel.
- **Camera assist:** double-tap a customer to focus camera on them; auto-reframe on room switch.
- **WebGL failure:** the existing `#glerr` fallback stays, but add a "try 2D mode" button that loads the 2D canvas client — nobody gets a dead screen.

### HUD layout (portrait, thumb-first)
- **Top:** shop name + greeting | coins, rep, cozy, day+progress (4 compact stats — already in prototype).
- **Viewport:** 3D scene, ~340px, bubbles overlaid.
- **Mode toggle:** Serve / Decorate (already in prototype).
- **Bottom sheet:** context actions. BREW and SERVE are the biggest buttons on screen — they're tapped hundreds of times per session.

### Accessibility
- Patience ring: color (green→amber→red) **+** shrinking arc **+** "!" icon under 15s — never color-only.
- Text: minimum 12px, user-scalable via settings (S/M/L).
- Reduced motion toggle: disables particles, camera auto-sway, bubble bounce.
- No essential information carried by audio alone (visual mirrors for every SFX cue).

### Telegram-specific UX
- **Theme:** map `tg.themeParams` to CSS vars on load and on `themeChanged` — the game must look native in both Telegram light and dark.
- **Haptics:** `impactOccurred("light")` on place/select; `notificationOccurred("success")` on happy serve/discovery; `("error")` on invalid; `("warning")` on walkout. Haptics are the game's *feel* — budget them deliberately.
- **MainButton:** contextual — "🌙 End day" in Serve mode, "✅ Done" in Decorate mode, "📸 Share" in photo mode.
- **SettingsButton:** opens help/FAQ sheet.
- **Offline/degraded:** no network → demo mode with banner (exists); reconnect → offer cloud sync merge (server wins on coins, client wins on nothing — keep it simple and honest).
- **Viewport:** `tg.expand()`, disable vertical scroll, respect safe-area insets (already handled).

---

## 6. Art Direction Bible

> **Locked direction (Oct 10, 2026): candy-saturated tycoon cheer.** The reference is the Facebook-era restaurant-tycoon look — but we *interpret, not copy*: it stays our 3D game, just warmer, fuller, brighter. The single most important art decision is **camera framing**: the default view shows the ENTIRE establishment in one portrait frame (floor, walls, door, all decor) — the player sees their whole café at once, every session.

### Palette (hex — the single source of truth)
| Role | Hex | Usage |
|---|---|---|
| Honey oak light | `#F0CF8E` | Tabletops, trim |
| Honey oak | `#DFA860` | Furniture bodies |
| Honey oak dark | `#B57E3E` | Legs, frames |
| Cream | `#FFF8EA` | Table tops, cushions, cups |
| Blush pink | `#F2A0B5` | Tablecloths, armchairs, rug |
| Coral | `#E86A7A` | Accents, pots |
| Teal | `#35B5A8` | Pillars, floor border band, counter panels, pots |
| Lavender | `#C9A8E0` | Wallpaper pattern |
| Gold/brass | `#F5C542` | Trim, frames, pinstripes, premium |
| Candy green | `#3FAE6A` | Foliage |
| Candy green light | `#62D68A` | Foliage highlight |
| Character brights | `#FF6B9D` `#FFD93D` `#35B5A8` `#FF8C42` `#9B7BFF` `#5BC8FF` | Customer shirts |
| Warm cream bg | `#F6E7CD` | Scene background/fog (day) |
| Golden evening | `#FFC98F` | Scene background/fog (evening) |
| UI cream | `#FFFDF7` | Cards, panels |
| UI sand | `#FFF3DC` | Buttons, tabs |
| UI cocoa text | `#6B4A2F` | Text on cream |
| UI pink CTA | `#F06A8A` | Primary buttons, active states |

**Rule:** every asset's dominant colors must come from this table. If it isn't on the table, it doesn't ship. Muddy browns and dark walnut are banned; near-black `#2E2A26`-style fills are banned except tiny hardware details.

### Pattern rules (new — from the reference)
- **Floor:** cream/beige checkerboard marble tile with faint veining + grout lines, ringed by a **teal border band with gold pinstripes** inset from the room edge. Pattern is canvas-generated (1024px max), tile size = 1 world unit.
- **Walls:** lavender-cream damask/diamond lattice wallpaper (canvas texture, 3× horizontal repeat), **teal pillars with cream capitals + bases** at ~2-tile intervals on both walls, **cream architrave trim** along the top. Two-wall dollhouse view is kept.
- **Furniture:** ornate beats plain — tablecloths (blush skirt + cream top + gold trim line), counters with gold trim strips and teal front panels, lamps in pink/yellow/teal, decorative (non-plain) pots.
- **Density rule:** *no empty-feeling first frame.* The starter Main Hall ships pre-decorated and abundant (tables with cloths, chairs, plants, lamps, rug, counter — 14 placements, 6 seats). A new player's first screenshot must look like a café, not a warehouse.

### Poly & texture budgets
| Asset class | Tri budget | Texture | Examples |
|---|---|---|---|
| Small prop | ≤ 800 | 256px or vertex color | cups, books, bulbs |
| Furniture | ≤ 2,000 | 512px | tables, chairs, machines |
| Hero/premium | ≤ 6,000 | 512px | chandelier, jukebox, sofa |
| Customer | ≤ 1,500 | vertex color + 1 256px face atlas | all characters |
| Room shell | ≤ 5,000 | 1024px floor atlas | floor, walls |
| **Scene total** | **≤ 150,000 tris** | **≤ 100MB texture memory** | Full café + 10 customers |

### Lighting rules
- Hemisphere (`#FFF6E6` sky / `#FFD9AE` ground, 1.25) + directional (`#FFF3E0`, 1.35, from upper-left-front) + ambient `#FFE2C0` 0.55. Bright cheerful daylight — the scene should feel sunlit, never moody. (Updated from the darker prototype values.)
- **No shadow maps on mobile.** Blob shadows only (radial-gradient planes, soft 0.22 alpha). This is a hard rule, not a suggestion.
- Emissive materials for lanterns/neon/chandelier — they're the "lights" the player *sees*.
- Day→evening lerp: over the 3-minute day, background/fog lerps `#F6E7CD`→`#FFC98F`, dir light warms `#FFF3E0`→`#FFB066`, lantern emissive intensity 0.9→1.4. Evening is **warm golden, never dark** — the café glows, it doesn't go nightclub.

### Style do / don't (brief-ready for the AI 3D pipeline)
**DO:**
- Candy-saturated tycoon cheer: blush tablecloths, teal pillars, gold trim, patterned tile — the *feeling* of the classic restaurant-tycoon look, rendered as clean 3D (interpret, don't copy sprite art).
- Full-establishment framing: default camera shows the whole hall in one portrait frame (~61° oblique). Every new decor item must read at that distance.
- Rounded, chunky forms — "wooden toy" feel. Bevel everything visually (no razor edges).
- Exaggerate the readable silhouette: a chair must read as "chair" at 40px tall.
- Front-biased detail: the camera never goes below the horizon or behind walls — spend polygons where the camera looks.
- Consistent scale: 1 tile = 1 world unit; seat height 0.45; door 1.6 wide. All builders obey this.
- Pattern discipline: checkerboard floor + damask walls + teal/gold trim are the visual signature. New rooms/seasons reskin the *pattern colors*, never the pattern language.

**DON'T:**
- Photorealism, PBR metalness > 0.45 (except gold trim), muddy browns, dark walnut, near-black fills, cool/blue-dominant palettes.
- Literal pixel-art copying — we want the reference's *warmth and density*, not its sprites.
- Baked text in textures — **all text is HTML overlays** (localization; the game will need Vietnamese/English at minimum).
- Transparency sorting traps: no overlapping transparent planes (steam uses additive sprites, capped at 12).
- Anything that needs more than 2 lights to look right.

### Proposed catalog additions (need server catalog IDs — future work)
The reference's two showpiece items have no current catalog ID; don't shoehorn them onto wrong IDs. When the catalog expands: `garden_fountain` (2×2, teal + gold + animated water disc, high cozy) and `upright_piano` (2×1, cream + gold, the musical showpiece next to the jukebox). Both follow the palette/pattern rules above.

### AI 3D generation brief template (for the later Tripo/Meshy/Rodin pipeline)
```
Subject: [item name], candy-tycoon 3D game prop
Style: saturated cheerful tycoon look — blush pink #F2A0B5, teal #35B5A8, gold #F5C542,
  honey oak #DFA860, cream #FFF8EA. Rounded chunky "wooden toy" forms. INTERPRET the
  Facebook-era restaurant-tycoon feeling; do NOT copy pixel-art sprites.
Topology: quad-dominant, ≤[800|2000|6000] tris, clean edge loops
Textures: single 512px albedo, flat colors from palette, no baked text, roughness 0.6-0.95, metalness 0 (gold trim ≤0.45)
Scale: fits [WxH] tiles, 1 tile = 1 unit, origin at floor center
Views: front 3/4 primary (camera fixed ~61° oblique, whole-room framing)
Negative: photorealistic, sharp edges, muddy browns, dark/moody, blue dominant, text, transparency
Seed: cafe_[item_id]_v1 (fixed per item for style consistency)
Format: GLB, +Z front, Y up
```
Pipeline: generate → auto-check (tri count, palette histogram vs. bible, scale) → human keep/reject → drop into `art/` → catalog entry points at GLB. **No code changes** — the client already renders catalog entries by id; GLB just replaces the procedural builder for that id. Procedural builders now approximate the locked palette/density/mood; hand-detailed GLBs are the later upgrade for sprite-level richness.

---

## 7. Audio Plan

Audio is a retention system, not decoration. *Good Pizza Great Pizza* proved cozy ASMR audio keeps players in-session longer. Our bar: **the game should be pleasant to listen to with eyes closed.**

### Ambience (WebAudio, all synthesized or CC0 loops — $0)
- **Café bed:** low murmur (filtered noise + randomized soft syllable blips, never intelligible), cup clinks (random 8–20s), door bell on customer enter.
- **Day/evening mix:** bed brightens at open, warms and quiets toward evening; rain variant on "rainy day" events.

### Music direction
- **Style:** lo-fi acoustic — nylon guitar + soft piano + brushed snare, 70–80 BPM, warm and unhurried. No vocals, no EDM, nothing with a drop.
- **Tracks:** `day_loop` (3:00, seamless), `evening_loop` (3:00, sparser), `rush_sting` (8s, tempo lift for rush events only).
- **Loop strategy:** crossfade 4s at loop point; duck −6dB under dialogue beats; mute-able separately from SFX ("cozy audio" toggle in settings).

### SFX list (trigger → sound)
| Trigger | Sound |
|---|---|
| Ingredient tap | soft wooden *tok* (pitch rises per ingredient — the combo becomes a little melody) |
| Brew start | gas ignite + **pour loop** (the ASMR centerpiece — rich, close-mic'd liquid pour, 4s) |
| Brew complete | kettle *ding* + steam hiss |
| Happy serve | coin arpeggio (pentatonic, randomized start note) + soft chime |
| Wrong drink | muted *thunk* |
| Sludge | wet *splat* + record-scratch-lite (comedy, not punishment) |
| Walkout | low door-bell + disappointed exhale |
| Recipe discovered | page turn + rising chime |
| Decor place | satisfying wooden *thunk* + tiny dust poof |
| Decor sell | coin slide |
| Day end | gentle evening guitar phrase |
| Critic enters | single low piano note (dread, subtle) |
| UI tap | soft click (never harsh) |

### ASMR opportunities (explicit design targets)
- The **pour loop** and **steam hiss** must be the best-sounding 4 seconds in the game — players hear them hundreds of times.
- Coin arpeggio pitch-rises with tip size — big tips *sound* bigger.
- Rainy-day variant: rain on windows + thunder-soft rumble, music drops to piano only.

### Implementation notes
- All audio via WebAudio API, no libraries. AudioContext resumes on first user gesture (FTUE tap handles this).
- Total audio budget: ≤ 2MB (synthesized + tiny loops). Generate with AI audio tools or CC0 libraries; keep a `audio/` manifest as data.

---

## 8. Social & Viral

Concrete mechanics, not "add sharing." Every mechanic names the **sender incentive** and the **receiver hook**.

### 1. Visit-a-friend (exists — deepen it)
- Tour mode via `?startapp=visit_<shop_id>` (read-only, exists).
- **Leave a tip:** visitors can tip the host 10 of their own coins → host receives 8. Capped 5 tips/day/friend (anti-farm). *Sender incentive:* "Generous Visitor" badge progress. *Receiver hook:* push "☕ Maya tipped your café 8 coins!" — a reason to open the app.
- **Steal this layout:** visitors can "love" a decor arrangement (once per café per week) → most-loved layouts appear in the region showcase. *Sender incentive:* curating taste. *Receiver hook:* prestige.

### 2. Visit cards / photo mode (the shareable artifact)
- Photo mode: hides all UI, free orbit, "📸" capture → generates a **visit card**: 3D snapshot + café name, ★ rep, cozy score, signature drink, deep link `t.me/<bot>?startapp=visit_<id>`.
- One-tap share to chats. *This is the primary UA asset* — every card is an ad made by a player. Zoe's arc (§2) teaches it in-game.

### 3. Group orders (group-chat integration)
- "Start group order" → share link to any group chat → friends open the mini app (no new install) and add their drink to the order (max 6) → you fulfill them in a special group-order queue (all patience rings synced, generous 90s).
- Fulfill all → everyone (including you) gets a streak bonus + the group gets a "☕ Café Crew" badge.
- *Sender incentive:* host bonus (200 coins). *Receiver hook:* friends play without committing — the perfect trial.

### 4. Referral
- Inviter and invitee each receive the **Friendship Fern** — a unique decor item (+5 cozy, unobtainable otherwise). Not coins (coins inflate; exclusivity doesn't).

### 5. Friend leaderboard (opt-in)
- Rank friends by rep and coziness. Weekly reset. Winner gets a "🏆 Neighborhood Favorite" banner on their visit card for the week. Zero server cost (computed on read).

### Anti-grief rules
- Visits are read-only; tips are capped; no chat in tour mode (Telegram chat already exists); block list respected (blocked users can't visit).

---

## 9. Monetization Design

### F2P constitution (violations need Viet's explicit sign-off)
1. **Stars buy cosmetics, convenience, and content — never power.** No Stars→coins conversion. No rep purchase. No patience extensions for sale. No arc skips.
2. **Everything gameplay-relevant is earnable free.** Paid items are shortcuts or expressions, never gates.
3. **Ads are always opt-in and rewarded.** No interstitials. Ever.

### Stars catalog
| Item | Price | Type | Why it's fair |
|---|---|---|---|
| Golden Espresso Machine | 150 ★ | Convenience (2× brew speed, permanent) | Time, not power — skilled free players still win on triage |
| Designer Decor Pack | 100 ★ | Cosmetics (5 exclusive items, high cozy) | Cozy is capped (§4) — exclusivity, not advantage |
| Remove ads | 50 ★ | Convenience | Standard |
| Seasonal pass (premium track) | 200 ★ | Content (exclusive set + café skin + early access) | 45-day season, ~30 tiers |
| Extra brew slot (7 days) | 60 ★ | Convenience | Rental, not permanent power |

*Deliberately absent:* coin packs, rep boosts, room unlocks, recipe unlocks. Rooms stay coin-only (Pillar 1: decoration/progression is gameplay).

### Rewarded-ad placements (AdsGram)
| Placement | Reward | Caps |
|---|---|---|
| Rush Hour | 2× spawns, 5 min | 1/session, 120s server cooldown (exists) |
| Instant decor delivery | skip "delivery wait" (new: premium decor has 60s delivery — ads skip it) | 3/day |
| Second wind | +30s patience for all current customers, once per day | 1/day |
| Extra brew slot | 10 min | 2/day |

Max **5 rewarded ads/day** — ad fatigue kills retention faster than it earns.

### Seasonal pass structure
- 45-day season, 30 tiers, free track + premium track (200 ★).
- Free track: coins, ingredients, 1 exclusive decor at tier 30.
- Premium track: full exclusive 4-item decor set (with set bonus), café skin (floor/wall theme), profile frame.
- Tier XP from daily quests — completable free in ~30 days of normal play (no FOMO extortion; the pass is a *thank-you*, not a treadmill).

### Targets (labeled assumptions — verify in soft launch)
- Payer conversion: **1–3%** of MAU (assumption; Telegram mini-app norm per genre research).
- ARPDAU: **$0.02–0.06** blended (Stars + ads) (assumption).
- Ad ARPDAU ≈ Stars ARPDAU at launch (assumption; ads usually lead in casual).
- LTV target: **$0.50–1.50** per acquired user (assumption — sets the UA budget ceiling: never pay more than $0.30/install).

---

## 10. Retention & Live-Ops

### Daily player cadence (the "why open today" stack)
1. **Streak** (exists): escalating coins 25→2000. The D1→D7 bridge.
2. **Daily quest** (new): 3 tasks refreshing at local midnight — e.g., "Serve 10 customers / Earn 300 coins / Place 1 decor" → 150 coins + 10 XP. Completable in one sitting.
3. **Regular beats**: arcs advance a beat every few days of play — "Maya has something to tell you…" is a stronger hook than any quest text.
4. **Shop refresh**: catalog "featured" item rotates daily (small discount) — the collection itch.

### Weekly cadence
- **Weekend rivalry** (Fri–Sun): vs. Ben's café. Serve-count race. Winner banner.
- **Critic window**: Elena *may* visit any day you're ≥3★ — the ambient tension.
- **Ingredient shortage** (one weekday): forces adaptation.

### First-90-days event calendar (template)
| Days | Event | Goal |
|---|---|---|
| 1–7 | Welcome Week: 2× streak coins, guided quests | D7 retention |
| 8–14 | "Maya's Chapter" — first arc beat guaranteed | Story hook |
| 15–21 | First rivalry weekend | Competitive hook |
| 22–30 | Season 1 tease: Autumn Harvest catalog preview | Anticipation |
| 30–75 | **Season 1: Autumn Harvest** (20 decor, 2 drinks, 1 regular, pass) | Content depth |
| 45 | Mid-season event: "The Critic Returns" | Stakes |
| 75–90 | Season 1 finale + Season 2 tease (Winter Hearth) | Rollover |

### Seasons (the content treadmill, made sustainable)
- 45-day seasons. Each: **theme + 20 decor items (1 full set + 16) + 2 drinks + 1 regular with 3-beat arc + pass**.
- Why these numbers: 20 decor = ~2 weeks of collection at 1–2/day; 2 drinks = discovery stays fresh; 1 arc = 3–6 weeks of story. A season must feel *complete* but not exhaustible.
- Season themes year 1: Autumn Harvest → Winter Hearth → Spring Bloom → Summer Terrace. (Terrace unlock syncs with Summer — poetry the players will notice.)

### Push notification strategy (bot `sendMessage`, needs opt-in at FTUE end)
Rules: max 2/day, never during 22:00–08:00 local, every push deep-links into a *specific* game state.
| Trigger | Copy |
|---|---|
| Day rollover (morning) | "🌅 Morning rush at {shop}! Maya's already in line — Day {n} is brewing." |
| Customer impatience | "😰 {name} has been waiting 45s at {shop}… their patience is almost gone." |
| Walkout (1/day max) | "🚪 A customer just walked out of {shop}. They couldn't find a seat." |
| Season drop | "🍂 The Autumn Harvest catalog just dropped — 20 new items your regulars will love." |
| Comeback (3d absent) | "☕ We saved your regulars' seats at {shop}. +{n} catch-up coins waiting." |
| Friend activity | "💛 {friend} tipped your café 8 coins!" |

### Comeback mechanics
- 3+ days absent → catch-up coins (50% of estimated missed earnings, cap 500) + "Welcome Back" exclusive plant + one regular's "we missed you" beat. Never punish absence; always reward return.

---

## 11. Analytics & KPIs

### Targets (labeled — validate in soft launch, then commit)
| Metric | Target | Notes |
|---|---|---|
| D1 retention | ≥ 40% | FTUE quality gate |
| D7 retention | ≥ 20% | Streak + arcs working |
| D30 retention | ≥ 10% | Season-worthy |
| Avg session | ≥ 8 min | ~2.5 day-cycles |
| Sessions/day (active) | ≥ 2.2 | Push + streak working |
| FTUE completion | ≥ 70% | |
| D7 payer conversion | 1–3% | Assumption |
| Crash-free sessions | ≥ 99% | |

### Onboarding funnel (every step instrumented)
`app_open → ftue_start → first_brew → first_serve → first_decor → day_end_1 → day_2_open`
Alert if any step-to-step conversion < 60%.

### Session & economy health
- Serves/session, walkouts/session (walkout rate > 15% → difficulty too high).
- **Faucet/sink ratio** per day-age cohort — the economy's vital sign. Alert at >1.5 or <0.7.
- Median coins by account age — detects hoarding (need sinks) or poverty (need faucets).
- Cozy distribution — if everyone caps at 75, the cap is the game (raise content, not the cap).

### Exact events to instrument
```
session_start {source: direct|push|visit|group}
ftue_step {step, skipped}
brew_start {combo_len} / brew_complete {drink, discovered}
serve_result {event: happy|wrong|sludge, payout, tip, patience_left_pct}
recipe_discovered {drink, via: experiment|arc|hint}
decor_bought {item, cost} / decor_placed {item, room} / decor_sold {item}
expansion_bought {room} / room_unlocked {room}
day_end {day, served, earned, rep_delta, walkouts}
rush_start {type: organic|ad} / rush_end {served, walkouts}
ad_offer / ad_start / ad_complete / ad_reward {placement}
stars_invoice_start / stars_invoice_success {item, stars}
visit_in {host} / visit_tip {host, amount} / visit_out
share_sent {type: card|group_order|referral}
push_sent / push_open {trigger}
quest_complete {quest} / season_tier {tier, track}
critic_visit {score} / arc_beat {regular, beat, choice}
```
Implementation: append-only `events` table (SQLite now, ClickHouse/BigQuery later); batch-upload from client every 60s to survive WebView kills.

---

## 12. Backend & Anti-Cheat

### Authoritative boundaries (the server owns these — the client is a renderer with opinions)
- Coins, inventory, placements (collision-checked), recipes learned, brew `ready_at`, customer spawn schedule, patience deadlines, rep, day rollover, streaks, visit snapshots, quest state.
- The client may **predict** (show coins optimistically) but the server **decides** (`/api/sync` re-validates every action — already the architecture).

### Rate limits (exist — tighten for production)
| Endpoint | Limit | Notes |
|---|---|---|
| `/api/sync` | 1 per 2s per user | Already in server |
| `/api/ad/reward` | 120s cooldown | Already in server |
| `/api/stars/invoice` | 1 per 60s | **Add** |
| `/api/visit` | 30/min per IP | **Add** (scraping guard) |

### Ad-completion verification upgrade path
Current: client-asserted behind server cooldown (fine for prototype). Production: **AdsGram server-to-server callback** → verify signature → grant reward → idempotency key per reward. Documented in README as TODO; implement before any real ad spend.

### Abuse cases & mitigations
| Abuse | Mitigation |
|---|---|
| Clock skew (fake brew-ready) | Server `now` only; client timestamps ignored |
| Action replay | Idempotency key per action batch; server dedupes 60s window |
| Save editing | All state server-side SQLite; client holds no authority |
| Visit-tip farming (alt accounts) | 5 tips/day/friend cap; tips cost the *sender* 10 coins |
| Referral farming | Friendship Fern is unique-per-account-pair; Telegram ID is the identity |
| Multi-account | Telegram ID-bound; accept residual (F2P norm) |
| Economy exploit (dup bug) | Faucet/sink monitoring (§11) catches it before players do |

### Data & durability
- SQLite WAL mode; hourly snapshots to local backup dir; daily off-box copy (rclone to any S3-compatible — $0 tiers exist).
- Per-user data export on request (Telegram DMs the bot "my data" → JSON dump). Good practice, cheap.

---

## 13. Tech & Hosting

### As it stands (keep)
- **Client:** three.js vendored (`vendor/three.module.js`, 691KB → ~170KB brotli), vanilla JS module, WebGL2, HTML overlay bubbles. Zero build step — a feature, not a limitation.
- **Server:** Python 3 stdlib only (`http.server` + `sqlite3`), ~1,066 lines. Single process is fine to thousands of DAU.
- **Hosting:** `cloudflared` tunnel for free HTTPS (Telegram requires it); systemd unit; file logging.

### Production upgrades (in order)
1. **Now:** SQLite WAL + hourly backup cron + `/healthz` + structured JSON logs + log rotation.
2. **Soft launch:** brotli/gzip static serving with content-hash filenames for `vendor/`; `Cache-Control: immutable` on vendored three.js.
3. **CI (GitHub Actions, $0):** `py_compile` → `node --check` on extracted client JS → endpoint smoke tests → **headless render screenshot** (Playwright/Chromium, WebGL via SwiftShader) with pixel-diff gate on the starter café scene. The screenshot test is the highest-value CI addition — it catches "3D renders black" before players do.
4. **Scale triggers:** >10k DAU or SQLite write contention → Postgres migration (schema is already relational-clean); >50k DAU → split static CDN (Cloudflare R2 + cache) from API box.
5. **Never needed:** Kubernetes, microservices, a JS framework. The stdlib server is a moat — fewer moving parts than any competitor.

### Real-device testing plan (iOS Safari is the hard case)
| Device | What breaks | Test |
|---|---|---|
| iPhone SE / 11 (Safari) | Memory kills WebGL context; **no WebGPU** (WebGL2 only — confirmed current) | Cold load, 30-min soak, orientation change (no context re-init) |
| Low-end Android (Mali GPU) | Shader compile time, fill rate | FPS during 10-customer rush; blob shadows vs. off |
| Mid Android (Snapdragon 7xx) | Thermal throttle | 20-min session FPS curve |

**Budgets:** JS heap < 150MB, texture memory < 100MB, cold load < 4s on 4G, 30fps floor during rush.
**Context-loss handler:** `webglcontextlost` → show "taking a breather…" → `webglcontextrestored` → rebuild scene from server state (never from client cache). Test by forcing via `WEBGL_lose_context` in QA.

---

## 14. Content Plan

### Launch catalog (why these numbers)
| Content | Launch qty | Rationale |
|---|---|---|
| Decor items | **40** (12 base + 28: 6 sets × 4 + 4 wildcards) | ~2–3 weeks of collection at 1–2/day; sets make 24 of them *strategic* |
| Drinks | **12** (6 known + 6 discoverable: 2 arc-locked, 2 hint-gated, 2 pure discovery) | Discovery stays alive past week 2 |
| Regulars | **5** (Maya, Chen, Zoe, Rafi, Elena) × 3 beats = **15 story beats** | 6–10 weeks of story at natural pace |
| Rooms | 3 (Hall open; Terrace, Lounge unlockable) | The lifetime spatial arc |
| Events | 4 (organic rush, viral crowd, critic, rivalry) | Weekly rhythm covered |
| Ingredient set | 8 (6 base + 2 seasonal-locked) | Stock management has texture |

### Season 1: Autumn Harvest (day 30)
- 20 decor (full "Harvest" set of 4 + 16 autumn items: pumpkins, blankets, amber lighting)
- 2 drinks: **Pumpkin Spice Latte** (espresso+milk+seasonal spice), **Apple Cider** (new ingredient: apple)
- 1 regular: **The Poet** — writes a haiku about your café each visit; 3-beat arc unlocks the "Haiku Wall" decor
- Season pass (free + 200★ premium), season quest chain
- Terrace synergy: autumn items are terrace-weighted (drives the 2,500-coin unlock)

### Content production pipeline (solo dev + AI agents, $0)
1. **Style bible lock** (§6) — agents generate against it, humans approve against it.
2. **Procedural first:** every item ships as a primitives builder on day one (the 17 builders in the client prove this works).
3. **AI upgrade:** Tripo/Meshy GLBs replace builders per-item when the pipeline is ready — catalog entries are data, so this is a file drop, not a code change.
4. **Agent QA pass:** tri-count check, palette-histogram check vs. bible, scale check, screenshot render check — automated, per item.

---

## 15. Roadmap

### P0 — Prototype ✅ DONE
2D client + server + 3D scene shell with 17 procedural builders. Verified: 33 endpoint checks.
*Exit: met.*

### P1 — Vertical slice (4–6 weeks)
Render loop, orbit/zoom/pan, customer characters + walk-in/out, bubbles + patience rings, brew/serve fully in 3D, FTUE (§5), Maya's full arc, analytics events (§11), ingredient stock, cozy soft caps.
*Exit criteria:* 10 testers complete FTUE unassisted; 30fps on iPhone SE during rush; faucet/sink ratio 1.0–1.3 in tester data; zero critical bugs.

### P2 — Soft launch (4 weeks)
200–500 users via Telegram channels/groups (no paid UA). All monetization live (Stars test → production). Full cast (5 regulars), 40 decor, 12 drinks, events. Balance pass from real data. Push notifications live.
*Exit criteria:* D1 ≥ 35%, D7 ≥ 15%; crash-free ≥ 99%; ARPDAU measured (validates §9 assumptions); economy ratio stable 2 weeks.

### P3 — Launch
Visit cards + group orders + referral (the viral stack, §8) polished and promoted. Season 1 content locked. Launch push: Telegram channel partnerships (rev-share, not upfront — $0 UA), "design my café" community contest with the Designer Pack as prize.
*Exit criteria:* 5k MAU; D30 ≥ 8%; payer conversion ≥ 1%.

### P4 — Live-ops (ongoing)
45-day seasons per §10 calendar. AI art pipeline online (GLB upgrades). Terrace → Lounge progression live. Quarterly: new regular, new room experiment, systems tune from analytics.
*Exit criteria (per season):* D30 stable or growing; season pass uptake ≥ 5% of MAU; content exhaustion (players finishing the season catalog) < 20%.

### Scope order (if cuts are needed, cut bottom-up)
Story arcs > core triage feel > decor sets > seasons > photo mode > group orders > rivalry > audio variants. **Never cut:** server-authoritative economy, FTUE, coziness mechanics, analytics.

---

## 16. Risks & Mitigations

| # | Risk | Likelihood / Impact | Mitigation (concrete) |
|---|---|---|---|
| 1 | **Art volume.** A decoration game needs hundreds of items; solo dev can't hand-make them. | High / High | Procedural-first (17 builders prove it); AI pipeline (Tripo ~$0.20–0.30/item when budget exists, Hunyuan3D/TRELLIS.2 self-hosted free); catalog-as-data means artists/agents ship without code. Launch needs only 40. |
| 2 | **UA cold start.** No paid UA budget; Telegram discovery is weak for games. | High / Existential | $0 UA stack: visit cards (player-made ads), group orders (friends trial free), referral fern, Telegram channel rev-share partnerships. Target: K-factor ≥ 0.3 before any spend. Never pay >$0.30/install (LTV math, §9). |
| 3 | **iOS Safari perf.** Memory kills, no WebGPU, context loss — the hard platform. | Med / High | WebGL2-only target (already); blob shadows (no shadow maps); <150k tris / <100MB textures; context-loss handler with server-state rebuild; real-device testing (§13) as a P1 exit criterion, not an afterthought. |
| 4 | **Economy exploits.** Dupe bugs or faucet imbalance kill a F2P economy in days. | Med / High | Server-authoritative everything (§12); faucet/sink monitoring with alerts (§11); idempotency keys; soft caps on cozy; no Stars→coins conversion (removes the worst exploit class: paid duping). |
| 5 | **Content treadmill.** Seasons every 45 days will exhaust a solo dev. | High / Med | Depth-is-data (§1.4): seasons are JSON+art, no code; AI pipeline for volume; 45-day (not 30-day) cadence; seasons designed to be *completable* so a missed season isn't punishing (FOMO-light). |
| 6 | **Shallow-game trap.** The prototype's loop (tap-brew-serve) gets old in a week. | Med / High | This whole document is the mitigation: triage skill (§3), set bonuses (§4), arcs with mechanical unlocks (§2), pressure systems (§4), mastery badges. Every feature passes the anti-shallow checklist (§3). |

---

## Appendix: What's already built vs. what's planned

| System | Prototype status | Production change |
|---|---|---|
| Server (Python stdlib, SQLite) | ✅ Done, 33 checks | Add: ingredient stock, cozy caps, duplicate penalty, café level/XP, quests, sets, `/healthz`, WAL |
| 3D scene (three.js, WebGL2) | 🟡 Shell + builders; render loop in progress | Add: customers, bubbles, orbit, placement ghost, day/evening lerp, photo mode |
| Catalog (12+5 items) | ✅ Done | Expand to 40; add sets + bonuses |
| Drinks (6) | ✅ Done | Expand to 12; add mastery |
| Reputation (1–5★) | ✅ Done | Add critic unlock at 3★, Landmark at 5★ |
| Rooms (Hall + 2 locked) | ✅ Done | Unlocks: Terrace 2,500 / Lounge 8,000 |
| Visit links | ✅ Done | Add tips, loves, showcase |
| Stars / AdsGram | 🟡 Hooks, TODO keys | Production: S2S ad verification, pass |
| Story/regulars | ❌ Not started | §2 — the biggest content lift |
| Analytics | ❌ Not started | §11 event list |
| Audio | ❌ Not started | §7 |
| FTUE | ❌ Not started | §5 beat-by-beat |

*Legend: ✅ done · 🟡 partial · ❌ planned*
