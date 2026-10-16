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
| Catalog | `autoload/catalog.gd` | Loads `data/*.json` into `Catalog.data` (untyped Dictionary — callers must declare types; warnings-as-errors). `validate()` mirrors `tests/test_content.tscn` (§21.2) at load so bad refs fail fast. Adding data = drop a file in `data/` + keep both gates green |
| Econ | `autoload/econ.gd` | Pure economy functions (walk-ins, prices) — no state |
| Seating | `autoload/seating.gd` | Board generation, meal allocation, `resolve_guest` → stars/fee/tip |
| Save | `autoload/save.gd` | `user://save.json` + `.bak`; tmp-write → copy → rename (failure-checked, `report_nonfatal` on write/rename/corrupt paths); `SAVE_VERSION` migrations; `export_text`/`import_text` support seam. Budgets: <100 KB, <100 ms load (§22) |
| Audio | `autoload/audio.gd` | Buses Music/Ambience/SFX; `play_music` (crossfade), `play_sfx` (pool), `set_ambience_mix(mix)` — N named live layers, caller owns the full mix (absent keys keep their level), deadbanded start/stop |
| Analytics | `autoload/analytics.gd` | Event wrapper (Firebase when wired); `CATALOG` is the §25 registry — uncataloged names warn in debug builds |
| Ads | `autoload/ads.gd` | Mock ads/consent: real pacing gates (interstitial day/gap/skip-after-rewarded, rewarded floor), all §25 ad events emitted; constants read `Platform.remote()` so Remote Config slots in post-launch |
| Platform | `autoload/platform.gd` | OS seams behind mocks: `remote(key, fallback)` config map, `report_nonfatal` crash capture, launch attribution (`launch_source()` → `app_open`), review/notification gates, entitlement + `iap_restore`, Play Games (achievements, `cloud_save_push/pull` fed by `Save.commit`) |
| Transition | `autoload/transition.gd` | Scene veil: `reveal()` / `snap_reveal()` (QA) |

## 2. Systems layer — leaf subsystems (`scripts/systems/`)

`daily`, `dog`, `errands`, `gatherings`, `restore`, `build`,
`journal`, `crew`: each is a `RefCounted` owned by Game. **They hold no save
state** — the state dict stays on Game (so `state_dict()` stays the
one schema); the object reads `g.<state>` and mutates it; Game keeps
one-line delegate methods as the public API. New subsystem = same
pattern:
state field on Game, logic file here, no autoload. `build` owns the
purchase/footprint verbs + undo inverses + decor variants (§5.8/§6.1);
`journal` owns
letters, Field Notes and page/chapter progression + the unlock ladder
(§8/§6.7); `crew` owns the v1 restoration clock — tick/start/collect/
speedup/free-finish/readiness (§8.4/§6.10), tuning consts stay on Game
for `restore.gd`. `postcard` is
the exception — pure static codec (§33.5 Camp Postcards): packs
{version, site, seed, decor placements} into a Crockford-base32
code with an FNV checksum, ~15 chars for a typical camp; decode
rejects single-char typos and drops unplaceable items, so a typed
code can never inject illegal state. `Postcard.materialize(code)`
is the consumer half: code → sandbox site-state that `cast_night`
accepts unchanged — wanderers at the shared camp, weather and
rare beats seeded by the code.

`systems/sim/` is the casting layer: Game state → SimWorld entity
programs. Two casts: `cast_day` (morning/prep ambience — locals
drift the errand loop, dog patrols) and `cast_night` (guests at
pads, dog rounds, queue wanderers at the fire). Programs compose
op steps (`goto`/`anim`/`wait`/`emote`/`jump`/`select`/`if`/
`react`/`respond`/`emit`/`await`); the Director wraps every guest
with a storm select, claims `sockets` off placed decor into
sit-spot programs, and pairs couples under string_lights for the
duet (`await` rendezvous). Deterministic — seed-baked jitter,
labels resolve once at schedule build.

## 3. Data contracts (`game/data/`)

Catalog loads every `.json` by stem name. Key consumers:

| File(s) | Feeds |
|---|---|
| `archetypes`, `traits`, `reviews`, `regulars` | board rolls, resolve_guest, guest personas |
| `sites`, `layouts/*.json` | world geometry, pad/economy rows (three sites defined; pinewatch built); `nav.blocked` impassable, `nav.road`/`road_cost` discounted lanes, `nav.pad_cost` soft pad penalty |
| `crew` | structures, stages, UTC durations |
| `letters` | journal mail — `trigger.morning` (day-gate + `guests_welcomed>=1`, D-UI-8) or `trigger.event`; `site:"any"` = the wandering mailbag, deduped via `Game.letters_delivered_any` |
| `dialogue` | world bubbles keyed site + *site-relative* `day` or a `when` gate (`last_stars_min`, `last_weather`, `served_favourite`, `regular_visit`, `first_night`, `last_event`, `returning_min`, `wishes_met_min`, `weather_streak`), once-ever via `Game.dialogue_seen` |
| `recipes`, `ingredients`, `fusion` | pantry/cooking — `fusion` rows match ingredient *kind* pairs, the tier between exact recipe and `camp_mash` |
| `decor`, `gear`, `upgrades` | outfitter/build; `decor.variants` = cosmetic re-skins (`buy_decor_variant`), `unlock:"E:<event>"` = journal-event-gated rows (fund grants) |
| `fund` | Grandpa's Fund tiers — coins → `journal_event` + grant decor into `stored` + wandering-mail letters; the post-arc sink |
| `photos` | LV Field Camera shots — `take_photo` once/site-day, print coins, 5 shots → `photo_wall` event |
| `wishes` | board-card wish labels — `Seating.board` deals a `wish` kind (trait/arch/generic ~50%); `WISH_CAP_KINDS` kinds are dealt only where `Game._wish_kinds` says tonight's pads can grant them (tags, fire-ring, light, sky, adjacent pair); `wish_label` baked on the card; `wish_met` scores +1 star, `days_log.wishes_met` |
| `margins` | Pinewatch's signature — `read_margin` once/site-day, sequential; `hint.weather` peeks tomorrow's roll, `hint.recipe` writes `pairs_tried` |
| `chapters` | journal pages + gifts |
| `birds`, `fish`, `vignettes` | Field Notes catalogs (birds+fish+forage `note` rows), errands, night vignettes; `layouts.errand_spots.fish_tables` = weighted per-bank catches |
| `festivals` | §13.5 arc-date events: `st["event"]` rolls at morning; `archetype_boost` leans the board, `dish` unlocks a one-night recipe, vignettes trigger on `event` |
| `gatherings` | Vol II night offers |
| `daily_seeds` | Trail Daily puzzles |
| `strings/strings.csv` → `.translation` | EN/VI; regenerate via `godot --import` after edits |
| `icons`, `icons_sources` | glyph registry + provenance |

## 4. Save pipeline

`Save.default_state()` is the §22 skeleton — **migrations fill keys,
never remove them**; `_migrate` walks `save_version` up (v2: day
spines + ads pacing + dog flags), stamps the version, then
back-fills — top-level keys *and* missing or **type-drifted**
sub-keys inside the dict-shaped blocks (`ads`, `settings`, `dog`,
`crew`, `journal`).
`Game.state_dict()` / `load_state()` own the payload: per-site
dicts, pantry/meals/recipes, journal, letters/dialogue, settings,
crew, the day spines (`actions` undo log + `day_log` event stream),
and `ads` pacing/entitlement state. `Vector2i` isn't JSON-safe —
`campfire.cell` and `decor[].cells` flatten to `[x,y]` pairs on
write, rebuild on load. `load_state` ends with `crew_tick()` →
offline progress applies (§8.4). Settings apply at boot so prefs
hold on the title screen. Frozen-fixture + round-trip +
golden-replay + <100KB/<100ms budget checks: `tests/test_save.tscn`
+ `tests/fixtures/save_v1.json`. Seeded verb-fuzz (random public-API
sequences vs invariants, **undo-inverse round-trips**, same-seed
replay equality): `tests/test_fuzz.tscn`. A 200-day completionist
save is asserted under the 100 KB budget in `test_save`.

**Write cadence — commit-on-beat** (D-UI-8): sleep is never the only
checkpoint; a player who never presses Goodnight still keeps
everything. Mutating verbs call `Game.touch()` (dirty flag — the 1 s
`_process` tick coalesces a burst into ≤1 write/s); day boundaries
(`goodnight`, `advance_day`, `travel_to`), `setting()`,
`NOTIFICATION_APPLICATION_FOCUS_OUT` (Android background = OS may
reclaim), the desktop close path, and the quit dialog's Leave call
`Game.commit()` — an immediate write. `bought_today` is a cache
derived from the action log (`_refresh_bought()`): buy adds,
return removes, undo replays — one truth, no parallel bookkeeping.
v1 saves without an `actions` spine keep their stored list so a
same-day return still works.

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
| `--smoke` | pinewatch | ~30 runtime asserts via `scripts/qa_smoke.gd`, prints `SMOKE name:result`, quits |
| `--lint` | ui_gallery | `LINT name:PASS` — touch targets, icon registry, strings, contrast 4.5, dynamic names, VI width (advisory) |
| `--shot[=path]` | pinewatch/gallery | rendered PNG — needs a real renderer (windowed); headless dummy can't capture |
| `--bare/--pose/--night/--morning/--board/--settings/--journal[=<tab>]` | pinewatch | shot staging |
| `--weather=<p>`, `--storm` | pinewatch | weather QA lock |
| `--reduced-motion` | pinewatch | exercises the UIFeel policy |
| `--bench` | title/pinewatch | `BENCH boot_ms=N` — engine boot cost |

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
| D-ARCH-8 | Viewport fixed at 640×360 (`scale_mode=integer`, `aspect=expand`); maps may exceed it — `stage` pans by `_cam` (touch drag; mid/right mouse drag on desktop). Gestures obey release-under-slop law: a press arms a candidate tap, `TAP_SLOP` (7px ≈ Android scaledTouchSlop) travel turns it into a pan/card-drag, release inside commits via `_commit_map_tap` — the emulated-mouse press lands before the first drag event, so deferral is the only honest tap-vs-pan test. Card/guest gestures own their finger first; `focus_cell(c)` is the UI seam for scripted pans. `import_map --crop` = the full playable map | Landed 2026-10-19 — supersedes the no-pan interim call from the same day |
| D-ARCH-9 | Presenter/test split: `--smoke` choreography lives in `scripts/qa_smoke.gd` (static `run(s)` + `frames_until`, scene passed untyped), the scene keeps a 13-line entry + preload — prod never imports test code, test drives prod only through tap APIs + typed reads. Same rule applies forward: world builders, input/HUD/FX/cast presenters extract with the scene owning `stage/pad_cells/panel_mgr/hud`, helpers taking it as constructor/dispatched arg | Landed 2026-10-15 — `pinewatch_test.gd` 4493→4005, `--smoke` output identical, suite green |
| D-ARCH-10 | World-build passes live in `scripts/world_builder.gd` (`build_ground/backdrop/scatter/pads/objects/props` + `open_cell/add_shadow/embed_base`, `GroundPaint` class) — same D-ARCH-9 helper-with-scene-ref shape; the scene keeps texture primitives (`_tex/_anchored/_cell_mask/_painted_map/_shadow_texture`), node ownership, and 2-line delegates. Values flowing through the untyped scene ref take explicit types (`var x: T = s.…` — `:=` can't infer through it) | Landed 2026-10-15 — `pinewatch_test.gd` 4005→3723, ground/scatter/smoke output identical, suite green |
| D-ARCH-11 | Gesture + tap routing lives in `scripts/input_presenter.gd` (35 verbs: card/seat/serve/drag/previews, prep/build/hut taps, pad/guest hit-tests, `unhandled` router + `commit_map_tap`) — same helper shape; the scene keeps the `_unhandled_input` entry, camera (`_cam`), selection UI state (`selected`, `_meal_sel`), nodes, and delegates. Gesture state (tap-arm, card-press/drag ghost, build ghost) moved WITH the code; scene-side readers became accessor calls (`build_armed/build_active/reset_gesture`). Node APIs route via `s` (`tr`, `create_tween`); fellow-mover calls use new names, staying code keeps `s._old` | Landed 2026-10-15 — `pinewatch_test.gd` 3723→3132, full `--smoke` incl. all tap/drag/build paths green, 9 suites green |
| D-ARCH-12 | Seating visuals + trait bubbles live in `scripts/guest_presenter.gd` (`seat/unseat_visual`, `bubble_state`, `refresh/fill/clear_bubbles`, `sync_marks`) — same helper shape; the scene keeps guest/tent/bubble nodes, tray/markers, and delegates. All guest state stays on the scene (smoke reads `guest_bubbles`); pad occupancy reads the existing `s._pad_occupied` delegate, so helpers never call each other | Landed 2026-10-16 — `pinewatch_test.gd` 3132→3017, `--smoke` identical, 14 suites green |
| D-ARCH-13 | Sheets, context menus + chips live in `scripts/sheet_presenter.gd` (outfitter/booking/crew/adopt opens, piece/pad menus, clear/finish transforms, pad visual/chip sync, float/hud chips, name/text lookups) — same helper shape; the scene keeps `panel_mgr`, nodes and menu-token state (`_pad_menu_tok/_pid` stay — shared UI like `selected`). Only `_build_menu_tok` moved (piece menus own it). Sheet locals renamed (`s`→`sheet`); `tr`/`create_tween`/`get_tree`/`call_deferred` route via `s`; bare method refs (`connect`, `.bind`) renamed like calls | Landed 2026-10-16 — `pinewatch_test.gd` 3017→2729, `--smoke` identical, 14 suites green |
| D-ARCH-14 | Day flow + celebrations live in `scripts/flow_presenter.gd` (status readout, goodnight/sleep, phase advance, morning/prep/evening starts, travel, dialogue queue, crew/page handlers, ceremony queue/drain, keepsake labels, `CEREMONY_CUE`) — same helper shape; the scene keeps nodes, camera, evening/board/selection UI state and the three signal connects (rewired to `_flow.*`). Moved state (`night_rating`, fivestar flag, ceremony + dialogue queues) travels with the code; loop var shadowing the scene param renamed. Multi-line signatures joined in delegates | Landed 2026-10-16 — `pinewatch_test.gd` 2729→2525, `--smoke` incl. ceremony/dialogue paths green, 14 suites green |
| D-ARCH-15 | Weather/FX config + response live in `scripts/fx_presenter.gd` (profile application, overlay crossfades, procedural textures, sway assignment, chrome fades, light-cue track/untrack) — same helper shape; the scene keeps the frame tick, all FX nodes and data tables (`WEATHER_PROFILES`), plus delegates. Scene-const classes need their own preload in helpers (`AmbientFX`). Delegates callable pre-ready stay null-safe (`_wake_chrome` guards `_fxp` — mouse-enter can fire mid-boot). Tooling note: this env's `re` drops `)` after `.*`, so extractor tooling must not put literal parens in `.*`-patterns — parse defs with explicit `chr(0x28/0x29)` walks | Landed 2026-10-16 — `pinewatch_test.gd` 2525→2294, `--smoke` identical, 14 suites green |
| D-ARCH-16 | Sim cast + errands + dog rounds live in `scripts/cast_presenter.gd` (cast build/configure day + evening, seat-actor sync, emote chips, errand spawn/sync/free, dog rounds + direction names) — same helper shape; the scene keeps the frame tick, all nodes and sim/view state. Bare method refs (`configure()` emote args) rename like calls; node `add_child` routes via `s`; scene inner classes stay put (`s.BuildGrid` resolves); `_anchored` vs `_anchored_frames` return different types (Sprite2D vs AnimatedSprite2D — annotate from the callee, not the shape) | Landed 2026-10-16 — `pinewatch_test.gd` 2294→2020, `--smoke` incl. cast/errand/dog paths green, 14 suites green |
| D-ARCH-17 | Crew structure + hut visuals live in `scripts/crew_presenter.gd` (queries `crew_sid` / `crew_rows` / `crew_stage`, `hut_px` / `hut_engaged`, the state->view pass `sync_crew_hut`, plus the hut stage-art table) — same helper shape; the scene keeps the `CrewDress`/`_hut` node ownership and the `_hut_tok` / `_hut_ready` token state so the smoke harness reads them directly (D-ARCH-12 precedent), plus the `_sync_crew_hut` / `_crew_sid` / `_crew_stage` / `_hut_px` / `_hut_engaged` delegates. Note `_hut_rect` is deliberately NOT part of this slice — it belongs to the already-extracted `input_presenter`, with a `hut_px` in both (input from the tap layout, crew from the structure plots) so presenters never reach into each other's logic | Landed 2026-10-16 — `pinewatch_test.gd` 2020→1920, `--smoke` incl. crew hut paths green, 14 suites green |

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
- `game.gd` ~2.4k lines post-split — state hub + delegate surface;
  purchase/journal/crew verb layers moved to `systems/build.gd`,
  `systems/journal.gd` and `systems/crew.gd` (leaf pattern,
  suite-guarded). Next: hosting, night, kitchen leaves.
- `pinewatch_test.gd` 4493→1920 lines — the `--smoke` drive moved to
  `scripts/qa_smoke.gd` (D-ARCH-9), the six world-build passes to
  `scripts/world_builder.gd` (D-ARCH-10), gesture + tap routing to
  `scripts/input_presenter.gd` (D-ARCH-11), seating visuals + bubbles
  to `scripts/guest_presenter.gd` (D-ARCH-12), sheets + menus + chips
  to `scripts/sheet_presenter.gd` (D-ARCH-13), day flow + celebrations
  to `scripts/flow_presenter.gd` (D-ARCH-14), weather/FX config to
  `scripts/fx_presenter.gd` (D-ARCH-15), sim cast + errands + dog to
  `scripts/cast_presenter.gd` (D-ARCH-16), crew structure + hut to
  `scripts/crew_presenter.gd` (D-ARCH-17); remaining shared world
  primitives (texture anchors, shadow mounts, `BuildGrid`) stay per
  D-ARCH-10, then `game.gd` leaves (hosting/night/kitchen).
- `SAVE_VERSION=2` — real migration path exercised: frozen v1 blob at
  `tests/fixtures/save_v1.json` drives `test_save`'s fill + stability
  + *load* checks (the fill also coerces type drift — v1
  `personas_met` was an Array, now a Dictionary).
- Sim `t` is float — fine for same-build replay; fixed-point is only
  needed for cross-platform lockstep (not our problem).
