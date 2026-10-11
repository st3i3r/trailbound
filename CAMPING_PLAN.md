# Trailbound — Camping Travel Sim — Design & Production Plan

**Master reference for the pivot: cozy isometric camping-travel game for Telegram Mini Apps.**
Supersedes the café-builder direction in `PRODUCTION_PLAN.md` (kept for the backend systems it documents, most of which carry over).
Companion: `README.md` (deploy), `server.py` (authoritative backend), `prototype/` (validated art pipeline + animated scene demo).

> Same bar as before: every system must answer **"what real decision does the player make?"**

---

## 1. Vision

**One-sentence pitch:** *Camp your way across a pocket wilderness — earn coins at each stop, gear up, and unlock the next postcard-perfect spot.*

**Fantasy:** you are a modern-day traveler with a home campsite at the edge of the map. Each location (forest, river, valley, mountain, sea) is a hand-crafted isometric diorama where you do small activity challenges — fish the river, forage the forest, bike the valley trail — earn coins and quest items, then come home to decorate your camp and buy the gear that opens the next place.

### Design pillars

1. **Wander, don't work.** The core verb is *explore + do*, never *serve on a timer*. Challenges are self-paced; failure is gentle (miss the catch, keep the day). Cozy, not stressful.
2. **Alive in 10 seconds.** Cold open = campfire crackling, fireflies, a camper waving from the trail. Scenes must never feel like dioramas you merely look at.
3. **Every trip ends with a decision.** Coins must always sit against two competing wants — new gear vs. camp decor vs. saving for the next location. If money piles up with nothing tempting to spend it on, the economy failed.
4. **Gear is the progression.** Rod unlocks river fishing, bike unlocks the valley trail, better tent unlocks overnight perks. One clear item → one clear new thing to do.
5. **Depth is data, not code.** Locations, activities, gear, quests, and NPCs ship as JSON catalogs — a new fishing spot or gear item is content, not a deploy.

---

## 2. World structure

| Location | Unlock | Activity (v1 scope) | Signature props |
|---|---|---|---|
| **Campsite (hub)** | Start | Decorate, cook, manage gear, day/night rest | tent, campfire, log seats, fairy lights, gear rack |
| **Forest** | Free | **Foraging trail** — walk a route, spot & tap mushrooms/berries before dusk | pines, ferns, mushrooms, log bridges |
| **River** | Cheap (500¢) or rod | **Fishing minigame** — cast, wait, tension-meter reel | river bend, pier, rocks, rod rack |
| **Valley** | Mid + bike | Bike trail run — steer/collect challenge (teaser in v1) | meadow, trail markers, barn |
| **Mountain** | High + boots | Climb challenge (teaser) | peaks, ropes, camp flags |
| **Sea** | High + boat ticket | Pier fishing+, photo spots (teaser) | lighthouse, boats, gulls |

v1 ships **Campsite + Forest + River** fully playable; Valley/Mountain/Sea appear on the map as locked teasers (greyed, "Coming soon — pack X to unlock").

---

## 3. Core loop

```
Campsite (rest/decorate/plan)
   └─ open Map → pick unlocked location → travel (wagon/car vignette)
        └─ Location scene: activity challenge → earn coins + items + rep
             └─ return → spend: gear shop / camp props / next unlock → repeat
```

**Sessions are short** (~3–8 min): arrive, do 2–4 challenges, head home. The map + campsite make every session resumable — matches Telegram interrupt-driven usage.

### Activity sketches (v1)

- **Fishing (river):** tap to cast → bobber lands → wait (1–4s, fish shadow circles) → **tap-hold tension minigame**: keep the tension bar in the green zone while the fish pulls; release to land. Rarity roll on catch. ~150 lines of game logic.
- **Foraging (forest):** a marked trail through the diorama; spotted forageables glow briefly — tap them before they "sink back" (soft timing window, generous). Combo streak = bonus. NPC ranger posts a daily list ("find 3 chanterelles") = quest hook.

### Campsite hub mechanics

- Decoration on the iso grid (reuses placement system), charm → visitors/gifts
- Campfire = "rest to next day" + cook caught fish for coins
- Gear rack = owned equipment display (diesgetic inventory)

---

## 4. Backend — what survives the pivot

| Keep (server-authoritative, unchanged) | Replace |
|---|---|
| Telegram initData HMAC auth + dev identity | Customers/patience/orders → **activity sessions** |
| Economy: coins, prices, purchases, anti-cheat validation | Brewing/recipes → **gear catalog + location catalog** |
| Placement validation (grid, bounds, collision) | Rush hour → **daily weather/event mods** |
| Progression: level, rep, daily quests, mastery | Story regulars → **camper NPC quest arcs** |
| Visits, tips, referrals, leaderboard, analytics, Stars stubs | Drink mastery → **activity skill levels** |

Net: ~65% of `server.py` carries over. The change is a **content + session-mechanics rewrite**, not an architecture change. Internal IDs stay numeric-friendly (catalog keys remap cleanly).

---

## 5. Cast (modern chibi, not fantasy)

- **You**: customizable camper (hoodie, cap) — palette swaps day one
- **NPCs**: park ranger (quests), van-lifer (shop), retired angler (river quests), streamer camper (social push), kid + dog regulars
- **Companions**: cat familiar stays. Cat always stays.

All single-direction idle + 4-8 dir walk sheets via the PixelLab character pipeline.

---

## 6. Art pipeline (proven, `prototype/`)

- **Generator**: PixelLab API — `generate-image-v2` + `style_image: example.png` (palette/outline/detail/shading lock) produced the witch-hat shop + chibi cast already in `prototype/assets/gen/`
- **Characters**: `create-character-v3` (8-direction rotations from a south-facing reference) → `animate-with-text-v3` (walk/idle/react) → `GET /characters/{id}/spritesheet`
- **Cheaper tier**: `create-image-pixen`/`pixflux` for props (~1 credit vs ~10 for Pro)
- **Compositor**: canvas/PixiJS — iso ground, depth-sort by feet-Y, prerendered static layer
- **Procedural motion** (validated in `animated-scene.html`): bob/squash walk, hop parabola, tilt-stir, particles (smoke, bubbles, fireflies, coin fountain), twinkle lights
- **Frames only where they pay**: humanoid customer/NPC walk+idle sheets; creatures and props stay procedural
- ⚠️ **Housekeeping**: the API token is hardcoded in `prototype/pixellab_gen.py` — move to env var (`PIXELLAB_TOKEN`) and gitignore the prototype assets before any commit.

---

## 7. Client stack (locked)

| Layer | Pick | Why |
|---|---|---|
| Build | Vite + TypeScript strict | — |
| App shell | React 19 + Zustand | UI + server-state mirror |
| Scene | **PixiJS v8** (or plain canvas for tiny builds) | crisp pixel sprites, depth-sorted containers, `roundPixels`, filter pipeline for day-dusk tinting |
| Iso engine | custom ~200-line compositor (proven) — no heavy iso lib needed at fixed view | traviso.js exists but adds little here |
| UI | DOM overlay (HUD pills, sheets, map screen, bubbles) | a11y + text + layout for free |
| Telegram | `@telegram-apps/sdk-react`, telegram-ui, haptics, MainButton | official |
| Motion | springs (motion) + in-scene procedural | — |
| Verify | vitest + Playwright screenshot (SwiftShader) | pixel-diff gate |

Scene layering per location: `ground/prerender → sorted props+characters → particles → weather overlay → DOM UI`.

---

## 8. Screens & UX

- **Main view**: full-bleed iso scene (~65% of portrait screen), floating HUD pills (coins · rep · day)
- **Bottom sheet**: contextual — location actions / challenge UI / camp catalog; 3 states (collapsed → primary action)
- **Map screen**: hand-drawn-style map panel, locations as nodes with lock states
- **Activity overlay**: fishing tension bar, forage streak — diegetic, inside scene bounds
- **NPC dialogue**: ailment-bubble pattern → quest/chat bubbles (proven in demo)

---

## 9. Phases

| # | Deliverable |
|---|---|
| 0 | `client/` Vite+React+TS scaffold; `/api` proxy; PixiJS boots; old game still served |
| 1 | Iso scene engine: prerender layer, depth-sort, sprite loader, particle system (port `animated-scene.html` into modules) |
| 2 | Campsite v0: tent, campfire, 2 props, player camper, decorate-mode ghost placement wired to existing placement API |
| 3 | Map screen + travel flow (location select → scene swap); Forest foraging challenge |
| 4 | River + fishing minigame; gear shop v0 (rod purchase gates river) |
| 5 | Day/rest cycle, campfire cook, quest board (ranger), NPC bubbles |
| 6 | Backend pivot: activity-session endpoints, gear/location catalogs (data-driven), keep all green tests |
| 7 | Telegram-native polish pass (theme, haptics, MainButton, skeleton boot) + juice layer |
| 8 | Locked teasers for Valley/Mountain/Sea; cutover `dist/` served at `/`; Playwright screenshot gate |

---

## 10. Risks (honest)

1. **Activity quality is the product.** Two polished minigames > six shallow ones. Forage+fish are deliberately simple-but-juicy; resist adding more until those feel good.
2. **Character frames cost money.** Full animated cast ≈ $15–40 PixelLab credits. Mitigation: procedural motion carried the demo at ~80%; buy frames only for the NPCs/customers that visibly walk.
3. **Backend pivot is real work.** Not scary — the test suite (108 tests) tells us exactly what breaks; but schedule it honestly (Phase 6).
4. **Scope discipline.** Locations are a content treadmill; the map's job in v1 is to *tease*, not to fill.

## 11. Open questions

- Multiplayer/social: visit-friends'-campsites is built into the backend — v1 keeps it, expand later?
- Seasonal packs (winter campsite) = retention lever, post-launch
- Name: "Trailbound" is a placeholder — worth a real naming pass
