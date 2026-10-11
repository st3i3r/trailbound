# DEV WORKFLOW — Trailbound (Godot 4 / Android)

How we build, run, and debug. The one principle that drives everything:
**iterate on desktop, verify on phone.** GDScript is the same either way —
the phone is for touch + perf truth, not daily coding.

Design source of truth: `docs/GAME_DESIGN.md` ("GDD §N" below points there).

---

## 1. Environment checklist (Windows dev box)

| Tool | Why | Note |
|---|---|---|
| **Godot 4.7.2 stable** | the engine | portable zip, no install — pin the latest stable at Phase 0 for the team (GDD §20, D-13) |
| **OpenJDK 17 (Temurin)** | required by Godot's Android export (signing/dex) | set `Java SDK Path` in Editor Settings |
| **Android SDK** | platform-tools + build-tools 35.0.1 + platforms 35 and 36 + CMake 3.10.2 + NDK r28b | the Godot 4.7 export docs list platform 35; Play requires target API 36 since 2026-08-31 → set `gradle_build/target_sdk`; minSdk 24 (AdMob plugin) → `gradle_build/min_sdk`; the plugins need the Gradle build (verify on 4.7.2, GDD §20). Install via Android Studio OR `sdkmanager`; set `Android SDK Path` |
| **adb driver for your phone** | Windows needs the OEM USB driver for most phones | or skip cables entirely — see wireless debugging below |
| Git + Python | repo + tools/pixellab_gen.py + the economy sim (GDD Appendix C) | already in place |
| **fastlane** (later) | CI deploys to Play internal track | when release pipeline starts |
| Play Console acct ($25) | store, billing, closed test, Android vitals | create it **now**: personal accounts need a 12-tester × 14-day closed test before production (GDD §26, §29) |
| **AdMob account** | rewarded + interstitial ads, UMP consent messages | create it **now**; test ads only until release (GDD §24). Before production ads: link the app to the published listing and serve `app-ads.txt` from the developer website (GDD §26, §31) |
| **Firebase project** | Analytics, Crashlytics, Remote Config | create it **now** and link it to AdMob. No FCM push (GDD §20, §25, D-21) |

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
- **Device B — one cheap low-end** (used Snapdragon 4xx-class, 3 GB RAM, Android 10–11, ~$60) = the perf gate from GDD §23. Buy it before the Phase 0 renderer/lights spike — the Phase 0 gate runs on it
- **Device C — a 16:10 or 4:3 tablet** = the tablet layout pass (GDD §23, §30)
- **Emulator — optional**, only for screen-size layout checks (foldables, small screens) if we don't own them
- **Windows/Linux desktop build = the daily dev target** (see below)

### This host (provisioned 2026-10-11)

| Tool | Location / status |
|---|---|
| Godot 4.7.2 stable | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.2-stable_win64.exe`; `godot` shim in `WinGet\Links` (added to user PATH) |
| Temurin JDK 17.0.20.1 | `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot` (host also has Zulu 11/17; PATH still resolves `java`→Zulu 11, Godot uses the explicit path above) |
| Android SDK | **`D:\Android\Sdk`** (moved off C: — disk space). platform-tools 37.0.1 · build-tools 35.0.1 · platforms android-35 + android-36 · cmake 3.10.2.4988404 · ndk 28.2.13676358 (r28c, satisfies r28b pin). `ANDROID_HOME`/`ANDROID_SDK_ROOT` set; `platform-tools` on user PATH |
| Export templates 4.7.2 | `D:\Godot\export_templates\4.7.2.stable`, junctioned into `%APPDATA%\Godot\export_templates\4.7.2.stable` so the editor finds them at the standard path |
| Godot editor settings | `%APPDATA%\Godot\editor_settings-4.tres` seeded with `export/android/java_sdk_path` + `android_sdk_path` |
| Pixelorama 1.2 | installed (sprite cleanup, GDD §28) |
| Git 2.45 / Python 3.13 | already present; Appendix C sim output verified against GDD reference |
| fastlane | deferred — needed at Phase 5/6 release pipeline |

Disk note: C: ≈4 GB free, D: ≈3 GB free — keep `game/`, exports and caches lean.

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

- **Economy balance lives in the sim** (GDD Appendix C, run with and without
  ads) and the Phase -1 paper prototype; the phone is for feel.
- **Godot live-edit**: the editor remote-inspector lets you tweak node
  properties ON THE RUNNING DEVICE — tune a guest's walk speed on the phone
  without redeploying.
- **Content-as-data**: all catalogs (sites, layouts, decor, gear, upgrades,
  archetypes, traits, recipes, chapters, letters, vignettes — GDD §21.2) are
  JSON → balance iteration = edit file + F5, zero rebuild. CI re-runs the sim
  and the content lint on every data change.

---

## 3. Debug toolchain

| Layer | Tool | Use |
|---|---|---|
| Script | **Godot debugger** — breakpoints, step, watch | works over remote deploy too — breakpoint on the phone |
| Scene | **Remote scene inspector** | live node tree of the running device — inspect a guest's actual state at runtime |
| Perf | **Profiler + Monitors** | frame time, draw calls, physics, script cost |
| Custom | **In-game debug menu** (build it day 1!) | give-coins, jump-to-phase, spawn-booking, set-weather, day-jump — a day-based sim is untestable without phase/day controls |
| Metrics | **Custom monitors** | coins/day, guests served, rating — watch the economy live |
| Logs | Godot console + `adb logcat` | native-layer issues (AdMob, billing and Firebase plugins) |
| Crashes | **Crashlytics** + **Android vitals** | Crashlytics through the custom Firebase plugin, script errors as non-fatals via a custom `Logger` (verify on 4.7.2); vitals is what Play enforces (GDD §20, §23) |
| Analytics | **Firebase DebugView** | `adb shell setprop debug.firebase.analytics.app <package>` → events arrive live; check them against GDD §25 |
| Ads | **AdMob test ads** + **UMP debug settings** | debug builds use test ad units only — never tap live ads on your own device; force the EEA consent form with the debug geography (GDD §24) |
| Save | `user://save.json` is plain JSON | hand-edit + reload to test any game state instantly |
| Tests | **GUT** (Godot Unit Test) | unit-test the pure logic (Econ autoload): every star term, families, tips, rating window, walk-ins, meal allocation; recipe pairs; the 15 page conditions; save migrations (GDD §30) |
| Scripted | **headless test scenes** | `godot --headless` in CI: run the Appendix C bot on the real data files and assert the GDD §6.9 guardrails with and without ads (e.g. median Pinewatch chapter done on day 8–11); the Daily solver checks the next 400 seeds |

**Debug-menu commands needed for THIS game specifically:** phase/day jump ·
weather set · booking spawn/dismiss · inventory give · site switch ·
rating set · page complete · letter trigger · Daily seed override ·
Remove Ads toggle · ad test mode (fill / no fill) · ad pacing reset ·
consent reset (UMP debug geography) · save wipe/migrate-test.

---

## 4. Phase plan — what gets built in what order

Weeks and full deliverables: GDD §29.

| Phase | Goal | Exit criteria |
|---|---|---|
| **-1. Paper & numbers** | paper prototype (guest cards, pad grid, decor tiles; 10 nights by hand) + extend the economy sim (GDD Appendix C) with unlock gating and per-guest traits | 5 paper sessions show real trade-offs; GDD §6.9 guardrails hold — before ANY code |
| **0. Scaffold** | `game/` Godot project: display settings (640×360, `canvas_items`, integer scaling), TileMapLayer+Y-sort test, autoloads, save system (`save_version`), catalog loader (JSON+validation), **debug menu**, Android export (Gradle build) to the internal track; spikes: renderer/2D lights, Vietnamese font, AdMob plugin (pin a release), custom Firebase plugin | F5 boots a scene; debug menu works; save round-trips; the AAB installs from the internal track; 20 lights at 60 fps on Device B; a Vietnamese pangram renders; a test ad and a test analytics event come through on Device A |
| **1. Greybox** | Pinewatch days 1–5, placeholder art: Morning → Prep (forage, cook, build) → Evening seating with star preview → Night | **≥3 of 5 testers want to continue; median day 4–6 min; testers can explain their stars** — the make-or-break gate before art spend |
| **2. Style lock** | Batch 0 (GDD §28) → approve → one production Pinewatch dusk screen; time every asset | look approved on the real phone; art hours re-estimated |
| **3. Pinewatch complete** | all Pinewatch content, onboarding, letters 1–10, the dog, journal, settings, EN+VI, audio | 5 testers finish the chapter; median completion on day 8–11 |
| **4. River, Valley, Daily** | sites 2–3, regulars, finale, Trail Daily | arc completable; guardrails hold on real data; Daily deterministic + solver-checked |
| **5. Platform** | ad placements + pacing, UMP consent + privacy options, Remove Ads (Play Billing) + restore, Firebase Analytics/Crashlytics/Remote Config, Daily reminder notification, privacy policy + data safety | ads verified with test units incl. no fill; consent verified with the EEA debug geography; Remove Ads purchase incl. pending + refund verified with license testers; GDD §23 budgets met with ads on |
| **6. Store** | listing assets (EN+VI), AAB signing, closed test (12 testers × 14 days), pre-launch report, staged rollout | closed test complete; crash-free ≥ 99.5%; production access granted |

**Gate discipline:** phase 1 is the risk kill — if the greybox loop isn't fun,
no art is generated. Art never leads gameplay.

---

## 5. Testing methodology

- **Per-commit:** typecheck-by-parse (GDScript errors at F5) + manual smoke of
  the touched system
- **Per-feature:** the day-loop checklist — does it survive a full simulated
  day? edge cases from GDD §17.7
- **Per-release device pass:** Device A (touch/UX) + Device B (60fps gate) +
  Device C (tablet layout) + back-button stack + offline + kill-and-resume in
  every phase + ads: with and without Remove Ads, no fill, airplane mode,
  consent declined, backgrounded mid-ad (GDD §17.7, §30)
- **Play pre-launch report** before every track promotion — free automated
  device matrix
- **Human playtests:** closed test group — recruit VN players deliberately;
  they double as the Easter-egg verification panel

---

## 6. Git/housekeeping for Godot

- `.tscn`/`.gd` are text → real diffs, same workflow as now
- `.gitignore`: `.godot/` (import cache; it also holds `export_credentials.cfg`
  with keystore passwords and other export secrets), `*.keystore`, `*.jks`.
  `export_presets.cfg` holds no secrets and is committed. CI injects signing via
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD` (keystore and
  key passwords must match)
- `game/android/` (the Gradle build template, reinstallable from the editor):
  decide at Phase 0 — commit it if the Firebase spike has to edit it,
  otherwise ignore it
- AdMob app and ad unit IDs and the Firebase config are identifiers, not
  secrets: committed. Debug builds use test ad units; production IDs only in
  release exports
- Art pipeline: PixelLab → `assets_src/` → QA gates (GDD §16.4) → `game/assets/` → manifest maps it
- Save everything through `ResourceSaver`/JSON — never binary blobs in repo

---

## 7. First actions when we start coding

Do now, before any code: create the Play developer account, the AdMob
account and the Firebase project, and start recruiting closed-test testers,
including Vietnamese players (GDD §29).

1. Phase -1: paper prototype + extend the economy sim (GDD Appendix C)
2. `winget install GodotEngine.Godot` (or the 4.7.2 portable zip) + Temurin JDK 17 + Android SDK
3. `game/` scaffold: project.godot, main scene, pixel-snap viewport settings, debug menu skeleton, Android build template
4. Phase 0 spikes: 20 lights on Device B, Vietnamese font, a test ad and a test analytics event on Device A
5. THEN: Pinewatch greybox (Phase 1)
