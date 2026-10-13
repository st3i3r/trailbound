# Architecture — Trailbound (technical design)

System map, contracts and conventions. **GAME_DESIGN.md owns the
rules; this file owns the machinery.** Written 2026-10-13. When a
system, autoload, data contract or harness flag changes, change it
here in the same commit — this is also the onboarding doc.

## 1. Runtime map — autoloads (`project.godot`)

One responsibility each; scenes never reach across boundaries.

| Name | File | Owns |
|---|---|---|
| Game | `scripts/autoload/game.gd` | The whole sim: `day`, `phase` (enum BOOT/MORNING/PREP/EVENING/NIGHT), `coins`, per-site state dict, crew, journal, settings, and the public API other nodes call. `_process` ticks only `crew_tick` + `restore.tick` (1s accumulators) — **phases never tick on a clock** (D-UI-8) |
| Catalog | `autoload/catalog.gd` | Loads `data/*.json` into `Catalog.data` (untyped Dictionary — callers must declare types; warnings-as-errors). Adding data = drop a file in `data/` |
| Econ | `autoload/econ.gd` | Pure economy functions (walk-ins, prices) — no state |
| Seating | `autoload/seating.gd` | Board generation, meal allocation, `resolve_guest` → stars/fee/tip |
| Save | `autoload/save.gd` | `user://save.json` + `.bak`; tmp-write → copy → rename; `SAVE_VERSION` migrations. Budgets: <100 KB, <100 ms load (§22) |
| Audio | `autoload/audio.gd` | Buses Music/Ambience/SFX; `play_music` (crossfade), `play_sfx` (pool), `set_ambience_mix(mix)` — N named live layers, caller owns the full mix (absent keys keep their level), deadbanded start/stop |
| Analytics | `autoload/analytics.gd` | Event wrapper (Firebase when wired) |
| Ads | `autoload/ads.gd` | Mock ads/consent — console-side work pending (§20) |
| Platform | `autoload/platform.gd` | OS integration: `WM_CLOSE_REQUEST` → `close_requested` (camp saves then quits) |
| Transition | `autoload/transition.gd` | Scene veil: `reveal()` / `snap_reveal()` (QA) |

## 2. Systems layer — leaf subsystems (`scripts/systems/`)

`daily`, `dog`, `errands`, `gatherings`, `restore`: each is a
`RefCounted` owned by Game. **They hold no save state** — the state
dict stays on Game (so `state_dict()` stays the one schema); the
object reads `g.<state>` and mutates it; Game keeps one-line
delegate methods as the public API. New subsystem = same pattern:
state field on Game, logic file here, no autoload.

`systems/sim/` is the casting layer: Game state → SimWorld entity
programs (guest idle-at-pad, dog patrol, angler bank-walk). Minimal
in-code table today; becomes JSON when real scenarios land.

## 3. Data contracts (`game/data/`)

Catalog loads every `.json` by stem name. Key consumers:

| File(s) | Feeds |
|---|---|
| `archetypes`, `traits`, `reviews`, `regulars` | board rolls, resolve_guest, guest personas |
| `sites`, `layouts/*.json` | world geometry, pad/economy rows (three sites defined; pinewatch built) |
| `crew` | structures, stages, UTC durations |
| `letters` | journal mail — `trigger.morning` (day-gate + `guests_welcomed>=1`, D-UI-8) or `trigger.event` |
| `dialogue` | world bubbles keyed site+day, once-ever via `Game.dialogue_seen` |
| `recipes`, `ingredients`, `fusion` | pantry/cooking — `fusion` rows match ingredient *kind* pairs, the tier between exact recipe and `camp_mash` |
| `decor`, `gear`, `upgrades` | outfitter/build (pending decisions) |
| `chapters` | journal pages + gifts |
| `birds`, `fish`, `vignettes` | field notes, errands, night vignettes |
| `gatherings` | Vol II night offers |
| `daily_seeds` | Trail Daily puzzles |
| `strings/strings.csv` → `.translation` | EN/VI; regenerate via `godot --import` after edits |
| `icons`, `icons_sources` | glyph registry + provenance |

## 4. Save pipeline

`Save.default_state()` is the §22 skeleton — **migrations fill keys,
never remove them**; `_migrate` walks `save_version` up then
back-fills. `Game.state_dict()` / `load_state()` own the payload:
per-site dicts, pantry/meals/recipes, journal, letters/dialogue,
settings, crew. `Vector2i` isn't JSON-safe — `campfire.cell` and
`decor[].cells` flatten to `[x,y]` pairs on write, rebuild on load.
`load_state` ends with `crew_tick()` → offline progress applies
(§8.4). Settings apply at boot so prefs hold on the title screen.

**Write cadence — commit-on-beat** (D-UI-8): sleep is never the only
checkpoint; a player who never presses Goodnight still keeps
everything. Mutating verbs call `Game.touch()` (dirty flag — the 1 s
`_process` tick coalesces a burst into ≤1 write/s); day boundaries
(`goodnight`, `advance_day`, `travel_to`), `setting()`,
`NOTIFICATION_APPLICATION_FOCUS_OUT` (Android background = OS may
reclaim), the desktop close path, and the quit dialog's Leave call
`Game.commit()` — an immediate write. `bought_today` serializes so a
mid-day resume keeps same-day return eligibility.

## 5. Scene flow

`run/main_scene` = `scenes/title.tscn` → cold open or Continue →
`scenes/pinewatch_test.tscn` (the camp: world presenter + HUD +
sheets + WorldFX). `scenes/ui_gallery.tscn` is the kit-QA scene
(`--lint`/`--shot`/`--lang=`/`--big`). `Transition` carries the
reveal veil between boots. There is no `main.gd`.

## 6. Presentation layers

**WorldFX** (`scripts/world_fx.gd`) — scalar-driven environment:
`front` (weather severity 0→1), `dusk` (nightfall 0→1), `flash`
(lightning impulse). Every channel is a response curve read in
`_apply()`: rain/leaf emitters (hysteresis gates), wind global param,
3-layer ambience mix, tracked overlays (`resp`: `front` /
`front_lift` / `dusk`). Grade = `time(dusk) × absorb(base_color) +
Σ emit×w` — Beer–Lambert split (>1 channel = in-scatter, daylight-
weighted; "no sunny at night" is structural) plus an **emit
registry** (`track_emit`: grade rows or node-property rows; curves
`flat/ember/daylight/dusk/front/flash`). Lightning: settled +
`front>0.8` + `UIFeel.can_pulse()`. `WEATHER_PROFILES` in
pinewatch_test.gd selects shader slots + `front` target + tint;
`SIM_TO_FX` maps sim weather. Interrupts retarget from the current
scalar — never snap. **Authored light cues** (spec 005) are
moment-bound registry terms: vignettes/ceremonies/letters track a
`{col, w}` row on play and `untrack_emit` on dismiss — the Eastward
"systems serve authored moments" pattern, no new curve kinds.

**UI kit** (`game/ui/`): `ui_tokens` (palette/type/motion/touch
tokens) → `ui_kit` (builders: `panel`, `btn`, `icon_btn`, `empty`,
labels) → `ui_feel` (`dur`/`apply` tween routing, `sfx`, `nav_input`,
`typewriter`, `reduced_motion`/`reduced_flashing`/`can_pulse`) →
`panel_manager` (modal stack, focus: nav-armed grabs `[ui_primary]`,
pointer presses never leave focus). `markers.gd` = world-anchored UI
tokens. Sheets: booking_board, evening_tray, night_summary, journal,
settings_sheet, crew_sheet, pantry_sheet, ceremony,
dialogue_bubble.

## 7. Audio layout

Three buses. Music crossfades (`title`, `camp`). Ambience is a live
mix — `day`/`night`/`storm` layer players volume-driven by WorldFX
curves (wildlife ducks under storm). SFX pool is semantic
(`press/confirm/warn/pay/open/close/coin/pop/stamp/tick/thunder`).
**Generated WAVs have no `.import`** — load via
`AudioStreamWAV.load_from_file()` + `FileAccess.file_exists()`;
`ResourceLoader.exists()` can't see them (D-ARCH-4).

## 8. QA & tooling harness

**Flags are engine args — never use the `--` separator.**
`godot --headless --path . res://scenes/pinewatch_test.tscn --smoke`
— everything after `--` is invisible to `OS.get_cmdline_args()` on
4.7 (D-ARCH-5; a `-- --smoke` run just plays the game forever).

| Flag | Scene | Does |
|---|---|---|
| `--smoke` | pinewatch | ~30 runtime asserts, prints `SMOKE name:result`, quits |
| `--lint` | ui_gallery | `LINT name:PASS` — touch targets, icon registry, strings, contrast 4.5, dynamic names, VI width (advisory) |
| `--shot[=path]` | pinewatch/gallery | rendered PNG — needs a real renderer (windowed); headless dummy can't capture |
| `--bare/--pose/--night/--morning/--board/--settings/--journal[=<tab>]` | pinewatch | shot staging |
| `--weather=<p>`, `--storm` | pinewatch | weather QA lock |
| `--reduced-motion` | pinewatch | exercises the UIFeel policy |

`--check-only` can't resolve autoloads (`Audio`, `Catalog` errors
are artifacts — real compile check is a scene run). Generated wavs:
`python ../tools/tb_sfx.py`. Economy sim: `python ../tools/sim.py`.

## 9. Conventions

- Strict typed GDScript: declare types on every `Dictionary`/Variant
  source — inference warnings are errors here.
- `§x.y` comments cite GAME_DESIGN.md — keep them accurate when
  moving logic.
- Comments say *why*, not what; compact code, shared abstractions.
- Pixel-safe: integer world scale, `default_texture_filter=0`,
  GL Compatibility renderer. Touch targets ≥40 px, contrast ≥4.5 —
  both linted.
- Accessibility is behavior, not storage: `UIFeel.reduced_motion`,
  `reduced_flashing`, `can_pulse()` gate real consumers.
- Un-imported generated assets use direct file APIs (§7).

## 10. Decisions (D-ARCH — engineering; D-UI-x in UI_PRODUCTION)

| ID | Decision | Status |
|---|---|---|
| D-ARCH-1 | Scalar world-FX (`front`/`dusk` + response curves) replaces timeline-style weather; profiles own discrete shader selection | Landed 2026-10-13 (spec `specs/001`, row UI-046) |
| D-ARCH-2 | Leaf-subsystem pattern: systems hold no save state; Game owns the dict; delegates are the API | Established |
| D-ARCH-3 | Light model `time×absorb + Σemit×w` with emit registry — brightening tints can't lift night; node rows drive light props | Landed 2026-10-13 |
| D-ARCH-4 | Generated WAVs/PNGs without `.import` load via `AudioStreamWAV.load_from_file`/`FileAccess`, never `ResourceLoader.exists` | Landed 2026-10-13 |
| D-ARCH-5 | QA flags are engine args (no `--` separator) — user args are invisible to `get_cmdline_args()` on 4.7 | Landed 2026-10-13 |
| D-ARCH-6 | Commit-on-beat persistence: `touch()` on verbs (1 s tick coalesces to ≤1 write/s), `commit()` on day boundaries, focus-loss and quit paths — sleep is never a checkpoint (§4) | Landed 2026-10-13 |
| D-ARCH-7 | Actor-presenter determinism contract: `SimWorld` ticks at **fixed dt via an accumulator** (never render delta), RNG only through `_rng_for` streams, iteration order = cast order — no `randf()`/wall-clock/dict-shuffle in sim code. Test ticks are already fixed-step; the live tick must match or replays drift | Contract 2026-10-13 — binds when the presenter lands (spec `specs/003` Dependency) |

## 11. External design audits

Third-party architecture/UI guides audited against this codebase.
Each verdict lists adopted deltas and where the full record lives.

| Source | Date | Verdict | Record |
|---|---|---|---|
| `tmp.txt` + `pixel.txt` (pixel-UI guides) | 2026-10-13 | ~30% applicable; adopted texel-phase snapping | `PLAN_art_craft.md` §5.9 |
| `mobile.txt` (viewport/touch/campfire) | 2026-10-13 | One adoption — emit-row `jitter` (hearth flicker, storm sputter); rest not applicable to a fixed board | `PLAN_art_craft.md` §5.10 |
| `design.txt` (production-blueprint claim) | 2026-10-13 | Same shape as ours, details superseded — see below | this section |

### design.txt audit notes

The blueprint maps onto our real layers, but each detail was already
decided differently for better reasons:

| Blueprint layer | Our equivalent | Read |
|---|---|---|
| `CozyClock` master clock | None — action-driven phases (spec `specs/002`) | A heartbeat clock is a design *regression*, not a gap |
| `EventManager` async bus | Direct signals (`phase_changed`, `letter_delivered`, `light_cue_changed`) — call-down/signal-up | An event bus is premature at our subscriber count |
| Camper matrix (weighted rolls, fixed tracks, "smart object bench") | `SimWorld` ECS-lite + `SimDirector` cast programs; sit-spots = the real Sims affordance pattern (spec `specs/003`) | Their "smart objects" name is the actual Sims pattern — we already implement its honest form |
| Weather & demand ledger (rent multipliers, revenue tallies) | `seating.gd` scoring + `econ.gd` + one-currency design (§6.1) | Dynamic pricing would fight the cozy contract — deliberate |
| GPU post-processing layer | Scalar WorldFX + emit registry (D-ARCH-1/3) | Ours is one matrix of response curves, not ad-hoc effects |
| Flat JSON saves | `save.gd` atomic tmp+rename + `save_version` migrations | Equivalent; migrations beat their "schema freeze" |
| `TouchInputManager` | None — no Camera2D (fixed board, UI-043) | Rejected §5.10 |

**Verified strengths (kept honest by the audit):** stateless
per-stream RNG (`_rng_for` reseeds `seed|site|day|stream` per call —
no generator state to corrupt, streams can't cross-contaminate);
sim/view split with ephemeral cast actors; engine/sim parity
(`tools/sim.py` mirrors `seating.gd` for headless solving);
commit-on-beat persistence; facade + leaf subsystems (D-ARCH-2).

**Watch list (not defects today):**
- `game.gd` ~1.9k lines — state hub, not god-object yet; the
  leaf-delegate pattern is the pressure valve. Watch ~2.5k.
- `pinewatch_test.gd` ~2.3k lines — world-build + input + smoke +
  cue plumbing in one presenter; the actor-presenter work is the
  planned split (the smoke harness living in-scene is the smell).
- `SAVE_VERSION=1` — migration machinery has never run for real;
  the first bump is when §22's promise gets tested.
- Sim `t` is float — fine for same-build replay; fixed-point is only
  needed for cross-platform lockstep (not our problem).
