# DEV WORKFLOW — Trailbound (Godot 4.5+ / Android)

How we build, run, and debug. The one principle that drives everything:
**iterate on desktop, verify on phone.** GDScript is the same either way —
the phone is for touch + perf truth, not daily coding.

---

## 1. Environment checklist (Windows dev box)

| Tool | Why | Note |
|---|---|---|
| **Godot 4.5.1 stable** | the engine | portable zip, no install — pin version for the team |
| **OpenJDK 17 (Temurin)** | required by Godot's Android export (signing/dex) | set `Java SDK Path` in Editor Settings |
| **Android SDK** | adb + build-tools + platform 35 | install via Android Studio OR `cmdline-tools`; set `Android SDK Path`. NDK r28b only if we add native plugins later |
| **adb driver for your phone** | Windows needs the OEM USB driver for most phones | or skip cables entirely — see wireless debugging below |
| Git + Python | repo + tools/pixellab_gen.py | already in place |
| **fastlane** (later) | CI deploys to Play internal track | when release pipeline starts |
| Play Console acct ($25) + Firebase project | store + FCM/Analytics/Crashlytics | needed only at integration phase |

### The phone question — do we need an emulator?

**One real Android phone > any emulator**, and here's why for THIS game:

| Need | Emulator (AVD) | Real phone |
|---|---|---|
| Touch feel / tap accuracy | ❌ mouse ≠ thumb | ✅ |
| Pixel-art readability at real DPI | 🟡 approx | ✅ truth |
| Perf truth (60fps on the weakest target) | ❌ lies — runs on your PC's GPU | ✅ |
| Godot remote debug (1-click deploy + breakpoints) | 🟡 works | ✅ works great |
| Screen-size variety | ✅ many AVDs | ❌ |
| Cost | free | $0 (your phone) → ~$60 used Xiaomi for the low-end gate |

**Recommendation:**
- **Device A — your daily phone** = primary dev/deploy target
- **Device B — one cheap low-end** (used Snapdragon 4xx-class / 3-4GB RAM, ~$60) = the perf gate from §7.8. Buy it when the vertical slice exists, not before
- **Emulator — optional**, only for screen-size layout checks (foldables, small screens) if we don't own them
- **Windows/Linux desktop build = the daily dev target** (see below)

### Wireless debugging (no cables)

Android 11+: Developer Options → Wireless Debugging → pair. `adb pair` once,
then Godot deploys to the phone over WiFi — same speed, zero cables.

---

## 2. The iteration loop — how development actually feels

```
code/scene edit (Godot editor, Windows)
   │
   ├─ F5 → runs instantly as a DESKTOP build ← daily iteration lives here
   │        (same GDScript, same scene tree, mouse emulates touch)
   │
   └─ "Remote Deploy" → deploys + runs on the PHONE over WiFi
            with breakpoints, live scene inspector, profiler attached
            (~15-30s deploy) ← touch/perf verification, per feature
```

- **Prototype (`prototype/game.html`) stays the systems sandbox** — pure
  game-feel experiments (economy pacing, guest timing) before Godot port.
- **Godot live-edit**: the editor remote-inspector lets you tweak node
  properties ON THE RUNNING DEVICE — tune a guest's walk speed on the phone
  without redeploying.
- **Content-as-data**: all catalogs (items, recipes, guests, sites, letters,
  events) are JSON → balance iteration = edit file + F5, zero rebuild.

---

## 3. Debug toolchain

| Layer | Tool | Use |
|---|---|---|
| Script | **Godot debugger** — breakpoints, step, watch | works over remote deploy too — breakpoint on the phone |
| Scene | **Remote scene inspector** | live node tree of the running device — inspect a guest's actual state at runtime |
| Perf | **Profiler + Monitors** | frame time, draw calls, physics, script cost |
| Custom | **In-game debug menu** (build it day 1!) | give-coins, skip-to-dusk, spawn-guest, set-weather, day-jump — a sim game is untestable without time controls |
| Metrics | **Custom monitors** | coins/day, guests served, rating — watch the economy live |
| Logs | Godot console + `adb logcat` | native-layer issues (plugins, billing, Play Games) |
| Crashes | **Crashlytics** | from integration phase onward |
| Save | `user://save.json` is plain JSON | hand-edit + reload to test any game state instantly |
| Tests | **GUT** (Godot Unit Test) | unit-test the pure logic: capacity calc, satisfaction score, spoilage, economy |
| Scripted | **headless test scenes** | `godot --headless` in CI: run the day loop, assert economy invariants (e.g. "day-3 player can afford rod") |

**Debug-menu commands needed for THIS game specifically:** day/time jump ·
weather set · guest spawn/dismiss · inventory give · site teleport ·
rating set · letter trigger · save wipe/migrate-test.

---

## 4. Phase plan — what gets built in what order

| Phase | Goal | Exit criteria |
|---|---|---|
| **-1. Numbers** | balance sim spreadsheet (day 1-10 economy) | the sim says rod lands day-1, site-2 ~day-5 — before ANY code |
| **0. Scaffold** | `game/` Godot project: pixel-scaling settings, TileMapLayer+Y-sort test, save system (`save_version`), catalog loader (JSON+validation), **debug menu** | F5 boots a scene; debug menu works; save round-trips |
| **1. Vertical slice** | Site-1, placeholder art, ONE full day: morning → forage → dusk guests → serve → sleep | **the loop is fun in greybox** — the make-or-break gate before art spend |
| **2. Style lock + reskin** | BATCH 0 → approve → P0 art → slice wears real pixels | vibe check passed on the real phone |
| **3. Management depth** | booking board, menu, plot assignment, upkeep, supply chain | site-1 fully playable |
| **4. Sites + retention** | site-2/3, 10-day arc, letters, quests, collections | the 10-day arc playable end-to-end |
| **5. Platform** | Play Games, Billing, FCM, Crashlytics, Remote Config | test purchase + push + cloud save verified on device |
| **6. Store** | listing assets, AAB signing, closed test (20×14d), pre-launch report | production access granted |

**Gate discipline:** phase 1 is the risk kill — if the greybox loop isn't fun,
no art is generated. Art never leads gameplay.

---

## 5. Testing methodology

- **Per-commit:** typecheck-by-parse (GDScript errors at F5) + manual smoke of
  the touched system
- **Per-feature:** the day-loop checklist — does it survive a full simulated
  day? edge cases from §8G
- **Per-release device pass:** Device A (touch/UX) + Device B (60fps gate) +
  back-button stack + offline + save/cloud-conflict
- **Play pre-launch report** before every track promotion — free automated
  device matrix
- **Human playtests:** closed test group — recruit VN players deliberately;
  they double as the Easter-egg verification panel

---

## 6. Git/housekeeping for Godot

- `.tscn`/`.gd` are text → real diffs, same workflow as now
- `.gitignore`: `.godot/` (import cache), `export_presets.cfg` secrets
  (keystore passwords go in CI env, not the file), `*.keystore`
- Art pipeline unchanged: PixelLab → PNG → `game/assets/` → manifest maps it
- Save everything through `ResourceSaver`/JSON — never binary blobs in repo

---

## 7. First actions when we start coding

1. `winget install GodotEngine.Godot` (or portable zip) + Temurin JDK 17 + Android SDK
2. `game/` scaffold: project.godot, main scene, pixel-snap viewport settings, debug menu skeleton
3. Balance sim spreadsheet for day 1-10
4. THEN: vertical slice greybox
