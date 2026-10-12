# UI production — audit, Eastward DNA, tooling, backlog

Single source for getting Trailbound's UI to shipping grade. Written
2026-10-12 from a code + screenshot + reference audit. Authority split:
**GDD §17 owns screens and behaviour; `assets_src/prompts/style_lock.md`
owns the look; this file owns the gap, the tooling and the backlog.**

## 1. Verdict

Style direction is strong; the build is a prototype. The UI spec we were
about to build from had drifted from the GDD, our panels do not match
Eastward's real menu language (we had no Eastward *menu* references until
this audit — only world shots), and the HUD has shipping bugs. Every
Eastward UI trait is reachable in Godot 4.7 with our stack; none of it is
built yet.

| Axis | Today | Eastward grade reachable? | Path |
|---|---|---|---|
| Visual language | Opaque cream-paper kit, heavy wood frames | Yes | D-UI-1 → D-UI-6 (§8): silver-sheet chrome is code, not textures |
| Typography | F1 pixel font, antialiased, ASCII-only | Yes | Hi-res text via font oversampling (§5.3), D-UI-2 |
| Iconography | 4 of 5 HUD icons semantically wrong; flat, no outline | Yes | Icon registry + scripted sticker outline |
| Layout/systems | Hand-placed controls, no Theme, Panel-as-button | Yes | Theme + containers + phase layouts |
| Motion/juice | None | Yes | Tokens + Tween + `vfx_workbench` |
| Spectacle | None (cut-ins, letterbox, ceremonies) | Yes | Code + a little art |
| Characters in UI | No guest art, no portraits | Yes | Batch B + portrait pipeline |
| QA | Manual screenshots | Yes | UI gallery + lints (§5.4) |

## 2. Eastward UI DNA (measured from real menu captures)

References: `docs/reference/ui/` — shop menu, result card, speech bubble,
cooking cut-in, inventory menu (sources in §9). Eastward runs a 360p art
base (Steam forum, 2021) — the same as ours — with UI text drawn at output
resolution. Measured colours are regional medians/brights from 720p
captures; sizes are converted to our 360p base.

| # | Trait | Eastward (measured) | Ours today |
|---|---|---|---|
| 1 | World stays visible | Menus are translucent glass over a dimmed scene with a fine halftone dot screen (pitch ≈2–3 px @360p) | Panel mock is opaque paper over ~70% of the screen |
| 2 | Thin line frames | 1 px pale-khaki line `#c2c397` (dim variant `#57574d`), small corner notches; buttons double-lined | 6–10 px wood/bamboo frames |
| 3 | Hierarchy by bands | Lighter title band `#2f3934` across the card; section headers as dark bands `#2f2f27` with muted text `#989586` | Boxes inside frames inside frames |
| 4 | Glass tint per context | Card `#161c17`→`#1f332f` (green-teal); shop near-black `#050502`; inventory navy `#1a3f70` | — |
| 5 | Hi-res type in menus | Smooth sans, bold titles `#fefec9`, body `#fefec7`, rendered at output res over 360p art | F1 pixel font at 8–9 px, antialiased |
| 6 | Semantic value colours | Qty blue `#69bffd`, category green `#49a60f`, stat chips red/yellow, ×N muted `#ada684` | INK/PAPER only |
| 7 | Sticker icons | ~16–18 px @360p item art with a cream/white outer outline; ×N beside | Flat 16 px icons, no outline |
| 8 | Hero art breaks the frame | Dish plate overlaps the card's top edge; large item art in the detail pane | None |
| 9 | Selection = glow line | Amber `#cc9b3f` rounded outline on a grid cell; selected OK button glows `#e7e54b`; inventory uses corner brackets | No states at all |
| 10 | Watermark typography | Shop's Chinese name ghosted large behind the detail pane | None (ours: Vietnamese name or seal ghost) |
| 11 | Minimal chrome | One counter cluster top-right; digits with dimmed leading zeros (`0324`) | 4 pills + medallion + toolbar + debug lines |
| 12 | Speech bubble | Cream `#f5f1d8` (≈ our PAPER `#f5e9c8`), body slate-blue `#537a93` (never black), small muted speaker name, ▼ advance glyph `#7c809d`, tail to speaker, world not dimmed; ≈157×57 px @360p | `bubble_speech` exists — our closest match; text is dark brown INK |
| 13 | Spectacle cut-ins | Cooking: stove drawn huge in the foreground, blue spotlight vignette, world dimmed, then the result card | None |
| 14 | Cinematic letterbox | Black bars during story scenes | None |

**Key read:** Eastward is two-layered — *light paper* for things spoken in
the world (bubbles, dialogue boxes), *dark glass + thin lines* for its
controller menus. Our kit applied paper to everything and added heavy
frames. Eastward's grade comes from restraint, layering, typography and
motion, not ornament.

**Amended 2026-10-13 (D-UI-6):** the player-facing sheet surface is the
**silver panel** — a light translucent fill (`GLASS #e8e5d8 @80%`) with a
graphite hairline and a soft offset shadow, over the halftone dimmer —
Eastward's *dialogue-box* read taken across every sheet, not its dark
menu glass. Ink text (`PAPER #332e22`), deep-tuned accents ≥4.5 on the
composited surface (`GOLD #644508`, `GREEN #2f5218`, `RED #7c2e1e`,
`DIM #514a3a`, `BLUE #234a6e`); vermilion stays the primary accent.
HUD pills/cards share the same silver chips — light chrome floating on
the dark world. Lacquer tokens (§8.1) are retired.

### 2.1 Chrome icon system — modern flat glyphs (D-UI-5)

The I1 control icons (painterly, dark-outlined, shaded: red book, parchment
map, gold padlock, hourglass) read as an old journal/RPG kit on glass.
Eastward's tab bar uses **flat one-colour filled glyphs** — silhouettes
with negative-space detail, muted when idle, bright when active — and its
tabs depict objects from its own world (cassette, jacket, fridge), not
generic UI symbols. Studies: `assets_src/cleanup/ui_icon_study.png`
(current vs two sets) and `ui_icon_system_v2.png` (proposed system on
lacquer glass).

| Family | Use | Style | Source |
|---|---|---|---|
| System glyphs | close, back, check, +/−, lock, settings, info, alert, undo, play/pause/skip, sound, music, vibrate, language, search, filter, share, trash, edit | Filled, one colour, state-tinted | HackerNoon Pixel Icon Library *solid* (MIT, 248 icons, pixel-clean at 24 px); gaps from pixelarticons (MIT, 1036 icons, 24 grid) redrawn filled |
| Section/tab glyphs | Journal, Trail map, Pantry, Outfitter, Build, Crew, Daily, Guestbook, Field Notes, Recipes, Keepsakes, Letters, Settings (~14) | Same filled style, but **Trailbound objects** (strapped notebook, folded trail map, phở bowl, Mai's van, hammer + tent, lantern…) | Drawn by us (`pixelart_workbench` draw/edit, free; or Aseprite), silhouettes traced from our I1 art as reference |
| Value/trait glyphs | coin, star full/half/empty, heart, 13 traits, weather ×4, phase | Same grid, one **semantic** colour (gold, red, blue, green) | Drawn/adapted to match |
| Content icons | items, dishes, ingredients, fauna, keepsakes | Full-colour pixel art + cream sticker outline (Eastward items) | Existing I1 content icons + Batch C/D/E |

Rules:
- 24 px native glyphs on a 24 grid, ≥2 px strokes/gaps, live area
  ≈20×20; a 24 px glyph in a 40 px button is Material's 24-in-48 ratio.
- A hand-drawn 12 px set for chips and inline text only — never reduced
  from 24 (exact 2× reduction breaks gear/hourglass/tools; HackerNoon's
  12/16 px PNGs are smoothed downscales, 4–9 alpha levels — rejected).
- Glyphs ship as white alpha masks; colour comes from the Theme: Godot
  `Button` icon colour items (`icon_normal_color`, `icon_hover_color`,
  `icon_pressed_color`, `icon_disabled_color`, `icon_focus_color`) —
  one asset serves every state.
- No outlines, shading or gradients on glyphs; content icons keep colour.
- `icons.json` registry records family, size, semantic name, source and
  licence; MIT notices go in the credits (GDD §18).
- 0 gens: AI output isn't grid-exact monochrome; draw and clean with the
  free workbench.

Mobile adaptation (Eastward is controller-first): bracket/glow selection
stays as the *pressed/selected* state; grid cells must grow — Eastward's
shop grid cell is ≈40×27 px @360p, under our 40 px touch height — so
fewer items per page, paging or scroll, bottom sheets for detail.

## 3. Spec drift — GDD vs style_lock

The style_lock "Production UI spec" imported management-sim patterns
(Two Point, Bear & Breakfast) that contradict the GDD:

| style_lock said | GDD | Action |
|---|---|---|
| Time controls pause/1x/2x | "Nothing in a day runs on a clock" (§4), Pillar 3 | Remove |
| Need-bubbles food/rest/social | Traits are binary checks resolved at placement (§5.3) | Replace with trait-state bubbles (met/unmet icons) |
| Booking Board as arrivals/departures calendar | Tonight's requests only (§5.2) | Remove calendar |
| Guest Inspector: stay length, mood | Neither exists | Drop fields; inspector = card detail |
| Alert rail of queued problems | Only crew-ready and "no meals" are live | Collapse to two contextual cues |
| "48dp+ everywhere (already met)" | Phase button ≈28 dp on a phone | Claim was false (UI-005) |
| Missing: star row, close X, back, settings icon | Icon set already has them (I1_1–3, 13, 15, 12) | Correct the inventory |

Screen reconciliation — GDD §17.2 is the list; style_lock covered 6 of 14
and added 2 not in the GDD:

| Screen | GDD | style_lock | Notes |
|---|---|---|---|
| Title | ✓ | — | Skipped on first launch |
| Camp | ✓ | — | Phase-aware HUD (UI-014) |
| Booking board | ✓ | ✓ | Opens from the notice board |
| Build mode | ✓ | ✓ | |
| **Evening tray** | ✓ | **—** | **The core moment loop** — flagship |
| Pantry and cooking | ✓ | ✓ | Cooking cut-in (DNA #13) |
| Outfitter | ✓ | — | Tabs; Remove Ads offer last |
| Night summary | ✓ | ✓ (Day-end report) | Reward screen |
| Journal | ✓ | — | 8 sections incl. Then/Now |
| Trail map | ✓ | ✓ | `create_map` art approved |
| Crew sheet | ✓ | — | |
| Remove Ads | ✓ | — | |
| Trail Daily | ✓ | — | |
| Settings | ✓ | ✓ | Full §17.4 list |
| Guest/Pad Inspector | — | ✓ | Fold into card detail / pad tap |

Surfaces added this session with no UI spec yet: Clear action (hold
ring + debris pull, §5.1), Music Night purchase with star-delta preview
(§13.5), trailhead queue (§5.6), Then/Now (§8.3), tier-up ceremonies.

## 4. Backlog

IDs are stable; priorities P0 (fix now) → P4 (platform phase). "Done
when" is the acceptance check.

### P0 — fix now (0 gens)

*✓ = landed 2026-10-12 step-0 pass (verified by `--smoke` + shots at
1920×1080 and 2400×1080). Open inside those rows: hit-area lint
(UI-005), `content` rects in atlas meta (UI-002, superseded by pill
auto-grow).*

| ID | Item | Evidence | Done when |
|---|---|---|---|
| UI-001 ✓ | Semantic icon registry (`icons.json`: name → file + meaning) and HUD fix: coins→`I1_0`, rating and star preview→`I1_1`, day/weather→`I1_4..7` by weather/phase, journal→`I1_10` | `hud.gd:53-81` uses sun/sparkle/undo/radio; `pinewatch_test.gd:27` STAR_ICON = sun; DEV_WORKFLOW calls `I1_4` a star | No `I1_` literals in `.gd`; registry lint passes; shot shows correct icons |
| UI-002 ✓ | Pixel-font rendering: antialiasing off, no 1 px shadow on dark-on-light text, sizes at native multiples; add a `content` rect per piece in `ui_atlas_meta.json` so text never crosses end caps | 36 colours in a 2-colour text strip; "DAY 1 · CLEAR" runs onto the cap | Text strips are 2-colour; no overflow at EN/VI/pseudo |
| UI-003 ✓ | Debug chrome behind an explicit flag/cmdline arg (`--dev-ui`), not a `true` const | `ui_tokens.gd:53` `DEBUG_UI := true` | `--shot` output has no debug text |
| UI-004 ✓ | Android Back: `application/config/quit_on_go_back=false`; `Platform` routes `NOTIFICATION_WM_GO_BACK_REQUEST` → `PanelManager.close()`, or the Camp confirm-quit sheet (§17.6); one handler | `platform.gd:11` is `pass`; `panel_manager.gd:63` listens for `ui_cancel`, which Back doesn't send | Device: Back closes the top sheet; on Camp it asks |
| UI-005 ✓ | Touch targets ≥40 virtual px (≈48 dp at our 360p base) via invisible hit padding; correct style_lock's "already met" | Phase button 74×24 px ≈28 dp | Touch-target lint passes |
| UI-006 ~ | Aspect + safe area: Camera2D limits + world bleed for 20:9 (800×360) and 4:3 (640×480); HUD inside `DisplayServer.get_display_safe_area()` | `stretch/aspect=expand`, world 640 wide; grey void in the 651-px shot; zero safe-area/Camera2D code | Shots at 800×360 and 640×480 have no void |
| UI-007 ✓ | Remove the persistent centre FIRE banner (proximity prompts appear on approach/selection only); remove or repurpose the dead medallion + toolbar | `hud.gd:125` 122×41 banner over the hero prop; "centre = never persistent" rule | Idle camp frame shows world only |

### P1 — foundations (0 gens)

| ID | Item | Done when |
|---|---|---|
| UI-010 | Rewrite style_lock "Production UI spec" from GDD §17.2 + §3 above; look per D-UI-1 | style_lock lists the 14 GDD screens + new surfaces; removed items gone |
| UI-011 ✓ | `trailbound_theme.tres` generated from tokens, with type variations (PaperPanel, GlassPanel, PillButton, IconButton, TabButton, ListRow, Chip); real `Button`/`TextureButton` states normal/hover/pressed/disabled/focus | No `Panel`+`gui_input` buttons; no per-control style overrides |
| UI-012 ~ | i18n: every string via `tr()` keys in `en.csv`/`vi.csv`, translations registered, `tr_n` plurals, locale number format; Godot's built-in pseudolocalization on in QA | Content lint: zero hardcoded UI strings; pseudo-locale shots clean |
| UI-013 ~ | Font path per D-UI-2; a VI pangram renders in every type role | Pangram shot at 1×/2×/3× scale |
| UI-014 ~ | Phase-aware HUD: Morning / Prep / Evening / Night each own the bottom band (Evening = guest tray) | Four layouts, one per phase |
| UI-015 ✓ | App shell: boot → cold open (first launch) or live camp → title; scene router with mist/smoke wipe; replace the Phase-0 `main.tscn` | `run/main_scene` boots the real flow |
| UI-016 ✓ | PanelManager v2: in/out transitions, tap-dimmer-to-dismiss for sheets, HUD fades on `stack_changed`, focus order; free only after the out-animation | Stack test: open/close/back/animate |
| UI-017 ✓ | Motion + haptics tokens: `UITokens.MOTION` (duration/easing/`kind` per component) + `UIFeel` (`dur()`/`apply()` route every tween — panel pop, dimmer, chrome/fire fades, count-ups, marker bob). Haptics: `UIFeel.haptic()` semantic events — `press` auto-wired in `UIKit.btn`, `confirm` on seat/sleep/head-out, `pay` on double-tips, `warn` on refused seat — Android-gated `Input.vibrate_handheld`, 8-30 ms. Reduced-motion: `UIFeel.reduced_motion` collapses scale/motion to ~0, keeps 60 ms fades; `--reduced-motion` QA flag + `settings.reduced_motion` save slot ready for the P3 settings sheet | `--smoke` green under both policies; no bare `create_tween()` + magic duration left in UI |
| UI-018 ✓ | QA harness (§5.4): `scenes/ui_gallery.tscn` storybook (type roles on dark/paper, nine pieces, pills, buttons + state swatches, full icon registry, sign vocabulary) + `--shot` golden path + `--lint`: touch ≥40 both axes, icon registry, literal+prefix tr() keys in strings.csv, WCAG-4.5 token-on-surface contrast (caught 6 under-ratio tokens — fixed in tokens.gd), advisory VI-width drift list | `--lint` headless, exits non-zero on fail; shots need a real window (no `--headless` — no framebuffer) |
| UI-019 ✓ | Chrome kit — **flat chrome is code, not textures**: `UIKit.flat()` draws sheets/panels/chips/pills/buttons as `StyleBoxFlat` from UITokens (rounded corners, 1 px hairline, consistent by construction — no PNGs, no import cache, no nine-slice insets; the "stacked borders" debug round traced to a stale `.ctex`). Sheets use the `"sheet"` piece — silver fill + soft offset shadow (D-UI-6). `tools/tb_glass_kit.py` now generates only what StyleBoxFlat can't: `sel_glow` halo, `seal_lacquer`, `halftone` (`glass_band` retired with the dark kit). Sheet layouts are MarginContainer+VBox (content can't reach the frame zone by construction). Left: sticker-outline pass on content icons | Every component renders in the gallery; no parchment/rope art on shipped screens; contrast lint measures the real composited surface |

*P1 landed 2026-10-12 (foundations pass): **UI-011** shipped as a
code-built `UITheme` — not a `.tres` — so tokens stay the source of
truth; `UIKit.btn()` returns real Buttons with normal/hover/pressed/
disabled/focus states (atlas art + modulate dips; named type-variation
classes still TODO as panels arrive). **UI-015** shipped as
`title.tscn` + `Transition` autoload (dark-forest veil, not mist);
Continue gates on `Save.has_save()`; the vista is a `--bare` capture.
**UI-016** adds tap-dimmer-dismiss + focus grab/restore on push/pop.
Partial: **UI-013** weights landed (DISPLAY→SemiBold, HEAD→Medium);
pangram QA open. **UI-014** `Game.set_phase` is now real (EVENING on
board, NIGHT on Goodnight); per-phase bottom-band layouts still
scaffold. **UI-012** 18 keys registered EN/VI; `tr_n`, pseudo-locale
QA and the content lint remain open.*

### P2 — flagship: the core loop

| ID | Item | Done when |
|---|---|---|
| UI-020 ✓ | **Evening tray** — landed 2026-10-12: guest cards (sprite portrait crop, name, fee, trait icons, elite/loud badges, favourite `?`), tap-tap *and* hold-drag seating, per-pad star badges, live breakdown strip listing every +/− term with its icon (needs/aversions/comfort/rain → star total), tap seated guest or card to undo until Goodnight | Phase 1 gate: testers explain their stars — strip is live; portrait art + trait-state bubbles still placeholders |
| UI-021 ✓ | Trait-state bubbles over seated guests — landed 2026-10-12: per-guest chip tag at the head, trait icon + state glyph (+/−/·, same vocabulary as the UI-020 strip), all seated guests re-evaluated on every seat/unseat so neighbour effects propagate live | Every trait shows a state icon, never colour alone |
| UI-022 ✓ | Night summary — landed 2026-10-12 (`night_summary.gd`): review blocks (name, star icons, fee+tip, +/− term chips, quote), fees/tips/walk-in/gathering totals, journal-page lines, real forecast via `Game.forecast()`, coin count-up, Double-tips offer (`Ads.can_double_tips`, night ≥3, once/day, mock reward), Sleep → next morning | §17.2 contents present — vignette display + Remove-Ads purchase still open (art/system, not this sheet) |
| UI-023 ~ | **Booking board** — landed 2026-10-12 (`booking_board.gd`): minimal Morning phase (Sleep → MORNING, no tray; "!" chip over the signpost as the notice-board stand-in; HEAD OUT → Evening). Sheet lists tonight's requests — portrait crop, name (+ ×2 party), fee, trait icons, favourite `?`, regular ribbon — plus the always-right morning forecast and the §5.6 demand line (requests vs open pads, overflow waits at the trailhead). Dimmer-close | Tap the board → sheet — honest gaps: signpost is the stand-in prop (real `reception_board` decor is batch E1); letters (§4 Morning) and the Prep phase are still skipped |

### P3 — suite and signature craft

| ID | Item |
|---|---|
| UI-030 ✓ | Journal (`game/ui/journal.gd`, §8.3): 8 icon-tab sections on the silver sheet — **chapters** (page goals per site, stamped/locked/vol-II dimmed, coin gifts), **guestbook** (personas by archetype + regulars × visits — `Game.personas_met` written at first stay, `regular_visits` counters), **field notes** (birds found/unknown; fish join when `fish.json` fills), **recipes** (cooked vs undiscovered), **keepsakes** (crew-stage keepsakes + notes + the Vol II book), **letters** (delivered mail; unread marked; tap → in-sheet reading view + `read_letter`), **days log** (`Game.days_log` — one line per `goodnight()`, newest first, weather glyph + best-star), **then/now** (per-site day-1→today card; photo pair is honest text until the capture pass). Cover completion `Game.journal_completion()` = collected/total over the five fill-in sections (15 v1 pages + personas&regulars + field notes + recipes + 9 keepsakes). Entry: HUD journal `icon_btn` + unread-letter count badge (`hud.set_journal_badge`, refreshed on `letter_delivered` + `stack_changed`). QA: `--journal[=<tab>]` staging flag; smoke asserts open/tab/badge/read |
| UI-031 | Pantry and cooking, with an Eastward-style cooking cut-in and result card |
| UI-032 | Outfitter with tabs (decor, pads/upgrades, gear, staples, cosmetics) |
| UI-033 | Build mode: ghost, radius rings, star-change preview, store/return |
| UI-034 | Trail map (`create_map` art), crew bubbles per site |
| UI-035 | Crew sheet (stage, time left, Collect, speed-up offer) |
| UI-036 ✓ | Settings sheet (`game/ui/settings_sheet.gd`, §17.4): SOUND (Music/Ambience/SFX −/+ steppers → real `AudioServer` buses created lazily, mute at step 0), FEEL (haptics → `UIFeel.haptics_enabled`, reduced motion → `UIFeel.reduced_motion`, reduced flashing stored), DISPLAY (text size choice → `UIKit.text_scale` pixel-safe +2 px on text roles; left-handed → `hud.apply_handedness()` mirrors phase button + tray live), GAME (language EN/VI choice → `TranslationServer.set_locale`, ranger's tips + assist mode stored), ALERTS (daily reminder + crew notification stored for the scheduling pass), PURCHASES (Remove Ads + Restore shown disabled — billing P3), ABOUT (credits & licences in-sheet page incl. pixelarticons MIT, privacy options → `Ads.request_consent()`, offline-only note). One setter `Game.setting()` = store + `apply_settings()` + `Save.save_state(state_dict())`; `Game.settings` loads at boot so prefs apply on the title screen. Entry: title menu button + HUD gear `icon_btn` (top-right, full 40 px target). New kit piece `UIKit.icon_btn` — 40 px chip button, centered registry glyph | `--smoke` asserts sheet opens + reduced_motion applies and persists; green under both motion policies; lint all PASS |
| UI-037 | Trail Daily: puzzle, result, share |
| UI-038 | Dialogue and letters: typewriter reveal, ▼ advance glyph, portraits for named characters; optional engine lip-sync via `get_lip_sync` |
| UI-039 | Ceremonies (page stamp, chapter, site unlock, all-5★, crew stage) with `vfx_workbench` effects |
| UI-040 | New-mechanic surfaces: Clear hold-ring + debris pull, Music Night sheet with star-delta preview, trailhead queue cue, tier-up reveal |
| UI-041 | Designed empty / loading / error / first-run states for every panel |
| UI-042 | Cinematic letterbox for night vignettes and story beats |
| UI-043 | Display/world zoom — the one SOTA gap vs mobile peers (Stardew pinch, Terraria ± buttons, Kairosoft pinch all ship a zoom control). A fixed one-screen board can't zoom in without cropping the puzzle, so the honest form is: **(a)** UI/text-scale steps in Settings (§17.4 already has text size), **(b)** pinch-zoom + camera pan reserved for any future site larger than the viewport (the pan-capable-site option). Done when: Settings exposes only pixel-safe scale steps; no fractional world scale ever ships |

### P4 — platform (GDD Phase 5)

| ID | Item |
|---|---|
| UI-050 | UMP consent surfaces, Remove Ads + restore, rewarded-offer slots that hide on no fill/offline, notification opt-in explainer, in-app review timing (§17.6, §24) |

### Character and asset dependencies

| ID | Item |
|---|---|
| UI-060 | Lock the character canvas/figure size (≤12% ≈ 43 px figure) **before** card slots, inspector, guestbook or dialogue frames are sized. Today: warden 57 px (15.8%), Mai 61 px (16.9%), dog 34 px |
| UI-061 | Guestbook = persona entries (D-UI-3): Guestbook page lists personas with which archetypes each can play; count follows the Batch B roster |
| UI-062 | Portraits for named characters only (Mai, Hùng, Old Ba, Lan, Minh mother, crew foreman, phở vendor; Grandpa as a sepia photo); guest cards reuse the in-world sprite. `create_portrait_character` costs 10 gens each → ≈70 + 10 (PROMPT_PACK Batch B) |
| UI-063 | Batch F rescope: chrome, value and trait icons are now flat glyphs drawn by us (§2.1, UI-066) — the missing ones (Light Sleeper, Dog-wary, Stargazer, "??" favourite, Clear, Music Night) cost 0 gens. Batch F = spectacle close-up art only (≈27: 3 seeds × 9 gens at 256×128, verified price). Sticker outlines on content icons are a script. Speed icons dropped |
| UI-066 ✓ | Chrome glyph set (§2.1) via `tools/tb_glyphs.py`: 87 pixelarticons SVGs rasterised to 24 px masks (integer M/H/V paths — exact, no AA; multi-path SVGs merged) + 23 drawn 24 px + 30 hand-drawn 16 px + 7 drawn 12 px masters — **per-size masters only, never scaled** (24→16 coordinate-scaling was the blob root cause). Star family derived by same-size boolean ops from one master (full/half/empty share a silhouette). Quality gate: `lint_mask()` — speck clusters, component scatter, 2+-edge overflow; imports sanity-checked, drawn glyphs strict. Registry: `icons.json` semantic families + `icons_sources.json` generated provenance (source/licence per glyph); MIT notice in `assets_src/README.md`. Call sites via `UIKit.icon_rect(size)` (auto `_16`/`_12` variants) with semantic tints; I1_* remains for content art only | Every gallery surface uses registry glyphs; no I1 control icon in chrome; glyph lint PASS; `--lint`/`--smoke` green |
| UI-064 | Batch D sizing: dish art sized so one sprite serves grid and result card at integer scale (no mixed pixel density) |

## 5. Tooling

### 5.1 PixelLab — verified for UI (account: Tier 1, 1633/2000 gens left, resets 2026-11-11)

Access note: the in-session MCP connector returns 401 (no auth header);
`tools/pixellab_mcp.py` (token from the repo `.env`) works — use it.

| Tool | Cost | What it does for UI | Limits (verified) |
|---|---|---|---|
| `create_ui_asset` | 10–25 | One panel image from description + optional style image; scaffold `elements` (button, icon_button, toolbar, tab, panel, window, health_bar, avatar, polygons) or custom `pieces` | Returns **one flat PNG** (192–688 px, aspect-gated). No per-element files, no states, no nine-slice data — checked on our 6 existing UI assets and the docs. Use for mood/ornament harvesting; slicing + states stay in our tools |
| `create_image_pro_flash` + `style_image` | by size | Ornaments, icons, frame-breaking hero art; palette/outline/detail/shading copied independently | 16–256 px, multiples of 4 |
| `inpaint_image(_pro_flash)` / `edit_image_pro_flash` | 10–25 | Fix one region of a piece without drift | 32–512 px |
| `create_portrait_character` | 10 (≤64 px) / 15 (128–160) | Bust portrait from a character sprite (or reverse) | Views: low/high top-down, side |
| `set_character_portrait` | free | Attach a portrait to a character | — |
| `create_vocal_animation` | gens once | Talking mouth set (3/5/7/12 visemes, 5 moods) | Tier 1+ ✓; needs a portrait |
| `get_lip_sync` | free | Frame plan (column + hold ms) for engine-driven mouths | Character-only |
| `create_font` | 15 | Pixel TTF + atlas | **Fixed 80-glyph ASCII set** (A–Z a–z 0–9 + 18 punctuation); no Vietnamese, no ·—★. F1 came from here. Not usable for VI text |
| `vfx_workbench` | free | UI juice: stamp burst, coin sparkle, star twinkle, confetti; exports spritesheet + JSON / game pack | — |
| `pixelart_workbench` | free | `lint` (outline gaps, orphan pixels), `score` 0–100, `inspect`, exact `edit`, `selout`, `repair` — a deterministic QA gate for every UI piece | — |
| `reduce_colors` / `correct_pixelart` | 0.1 | Lock pieces onto one palette; clean strays | 512² total / 1024² per frame |
| `create_map` | — | Trail map screen art (approved use) | Flat image only |

### 5.2 Authoring

- **Aseprite** — Pixpil's own tool (Road to the IGF interview). Slices
  with nine-slice centre + pivot export as JSON, which maps directly onto
  `ui_atlas_meta.json` (`nine_slice` + the new `content` rect).
  Recommended purchase. Pixelorama (installed) covers simple edits.
- **Our composers** — `tools/tb_ui_kit.py` / `tb_ui_enrich.py` stay the
  deterministic kit builders: glass fill, 1 px line frames, corner
  notches, halftone tile, sticker outline pass, state variants.
- **Reference boards** — Game UI Database and Interface In Game, filtered
  by screen type (inventory, shop, dialogue, result, map, settings), for
  Eastward plus cozy-management peers.

### 5.3 Engine built-ins (Godot 4.7 — no plugins needed)

- **Font oversampling is on by default** (Godot docs, Multiple
  resolutions): text re-renders at the viewport scale, so our 640×360
  `canvas_items` setup already draws text at device resolution over the
  360p art — Eastward's mixed-resolution UI for free. Same mechanism
  means a pixel font must run antialias-off at native-multiple sizes.
- **Theme + type variations**, project default via `gui/theme/custom`.
- **Pseudolocalization** built in (accents, double vowels for expansion,
  fake BiDi) — free QA for VI's longer strings.
- **Shaders**: dim + desaturate + halftone backdrop via a tile or a
  screen-reading shader (`BackBufferCopy`). Mipmapped screen blur in the
  Compatibility renderer is unverified — spike before relying on it;
  Eastward's look needs no blur.
- `Input.vibrate_handheld`, `DisplayServer.get_display_safe_area()` /
  `get_display_cutouts()`, Tween/AnimationPlayer for motion.
- AccessKit screen-reader support is documented in 4.x — GDD keeps it
  out of v1; cheap to revisit.

### 5.4 QA harness (to build — UI-018)

- **UI gallery scene** ("storybook"): every component × state × locale
  (EN / VI / pseudo) × aspect (16:9, 20:9, 4:3), rendered headless via the
  existing `--shot` path → golden PNGs + diff.
- **Lints**: interactive rect ≥40 px incl. padding; Label overflow under
  pseudo-locale; contrast (WCAG ≥4.5 body text on its surface); every
  icon id in the registry; every `tr()` key present in both CSVs.
- **Art gate**: `pixelart_workbench lint` + `score` on every new piece.
- **Devices**: Android "Pointer location"/"Show taps", remote debug, and
  the Play pre-launch report as a free aspect/safe-area device matrix.

## 6. Fonts (coverage verified 2026-10-12)

Vietnamese letters checked against a 102-character sample (all stacked
forms + ă â đ ê ô ơ ư ĩ ũ) via cmap; Google Fonts via served subsets.

| Font | Vietnamese | Notes |
|---|---|---|
| F1_1 (PixelLab) | 0/102 | 81 glyphs, ASCII only |
| Be Vietnam Pro | 102/102 | Have; no ★ |
| Fusion Pixel 8/10/12 (OFL) | 12/102 | Has ·—…“”★, not stacked VI |
| Silkscreen, Pixelify Sans, Tiny5 (GDD §19 candidates) | no VI subset | Fail §19 |
| VT323 | VI subset ✓ | Thin terminal look — style mismatch |
| Handjet | VI subset ✓ | Dot-matrix display face |
| Baloo 2, Nunito, M PLUS Rounded 1c, Quicksand, Lexend | VI subset ✓ | Smooth rounded candidates for hi-res UI |

## 7. Flow

0. P0 fixes (visible bugs, Back, aspect, targets).
1. Rewrite the style_lock UI spec for glass (UI-010); approve the
   lacquer tint (§8.1).
2. Foundations P1 + QA harness.
3. **Evening tray greybox → playtest** (Phase 1 gate "testers can explain
   their stars" is a UI test).
4. Lock character size → Batch B → named portraits → dialogue.
5. Suite, craft, states, ceremonies.
6. Platform surfaces.

Batch A world art does not block any step and can run alongside.

## 8. Decisions

| ID | Decision | Status |
|---|---|---|
| D-UI-1 | **Visual language: Eastward glass.** The cream-paper kit retires. We follow Eastward's whole system, which includes its *light cream speech bubbles* (DNA #12) — glass for every interface surface, cream only for words spoken in the world. Tint: Vietnamese lacquer (§8.1) | Decided 2026-10-12 (user); lacquer tint approved; **tint superseded by D-UI-6** — sheets are silver |
| D-UI-2 | **Fonts: Be Vietnam Pro family, hi-res, for all UI text** (bubbles included). Free (OFL), already in the repo, 102/102 Vietnamese; add the Medium/Bold weights from the same family. The pixel font retires from text. Not urgent — lands with UI-013 | Decided 2026-10-12 (user: free + ready) |
| D-UI-3 | **Guestbook collects personas**, not archetypes: one entry per persona + the 4 regulars (GDD §8.3). Roster is final with Batch B; personas pick deterministically (§21.3) with an unseen-first bias; content lint proves every persona is reachable in the arc | Decided 2026-10-12 (user) |
| D-UI-4 | **Batch F re-aimed at what reads as Eastward grade** — ≈27 gens (3 seeds × 9 at 256×128) for spectacle close-up art (cooking cut-in at the campfire: fire pit, pot/wok, steam — DNA #13). Icons cost 0 since D-UI-5 (glyphs drawn by us); sticker outlines on content icons by script; glass kit pieces procedural (UI-019); old paper ornaments dropped | Approved 2026-10-12 (user); icon share → 0 after D-UI-5 |
| D-UI-5 | **Modern chrome icons: flat one-colour filled glyphs** (§2.1) — system glyphs from HackerNoon solid (MIT) + pixelarticons (MIT), Trailbound-object section glyphs drawn to match, state colour from the Theme; I1 painterly icons stay only as content icons | Decided 2026-10-12 (user request: modern, not journal style) |
| D-UI-6 | **Sheet surface: silver panel, not dark glass.** Every player sheet, HUD pill, card and chip draws `GLASS #e8e5d8 @80%` translucent silver + graphite hairline + soft offset shadow — Eastward's dialogue-box read over the dimmed world. Text = warm ink (`PAPER #332e22`), accents deep-tuned ≥4.5 on the composited surface; vermilion stays primary. The lacquer spec (§8.1) and `glass_band` retire | Decided 2026-10-13 (user, ref: Eastward dialogue panel; "don't keep the original theme") |
| D-UI-7 | **Type scale & shadow policy** — `TYPE` = DISPLAY 18 SemiBold (sheet titles) / HEAD 12 Medium (rows, buttons, pills) / BODY·CAPTION 9 Regular; ratio ≥1.3× between levels (Eastward ~2×). **No text shadow on surfaces** — the theme's global 1px offset was tuned for the retired dark glass and smeared ink on silver; `UIKit.label()` keeps a 1px lift only for light text over world art. The logotype gets a silver card, not a shadow | Decided 2026-10-13 (user: "the text shadow makes it very bad UI") |

Retired by D-UI-1: the paper atlas pieces except `bubble_speech`,
`bubble_tail` and `seal_red` (kept as the lacquer seal accent);
`docs/paper-kit.html`; the U1–U5 `create_ui_asset` outputs; the panel
mock (kept in `reference/ui/` only as a before image).
Retired by D-UI-6: the lacquer dark-glass palette (§8.1 table kept as
history), `glass_band` (banded sheet texture — the flat `"sheet"`
piece draws its surface now), and the global Label text shadow —
the theme shipped `font_shadow_color` + 1px offsets on every label,
which smeared dark-ink-on-silver text once D-UI-6 landed. Hierarchy
now comes from the type scale (D-UI-7): DISPLAY 18 SemiBold /
HEAD 12 Medium / BODY·CAPTION 9 Regular; CAPTION stays 9 (VI
diacritics floor) and differentiates by `DIM` colour, not size.
Text shadows exist only inside `UIKit.label()` for light text
floating over world art — never on surfaces. The title-screen
logotype rides a `"sheet"` card (24px inline), not a glyph shadow.

### 8.1 Lacquer spec v0 — **superseded by D-UI-6** (kept as history)

*The shipped palette is the silver set in `ui_tokens.gd` (§2 amended
note). This table documented the dark-glass direction before the user
picked the silver read.*

| Token | Eastward (measured) | Trailbound proposal — lacquer (sơn mài) tint |
|---|---|---|
| Glass fill | `#161c17`→`#1f332f` card, `#050502` shop | Lacquer black-brown `#1a120d` → oxblood `#2e1612`, 80–92% opacity over a dimmed world |
| Backdrop | Dim + halftone dots, pitch ≈2–3 px | Same; dot tile 3 px |
| Line frame | 1 px `#c2c397`, corner notches | 1 px gold leaf `#c9a45c`, corner notches |
| Band | `#2f3934` | `#3a221b` |
| Title / body text | `#fefec9` / `#fefec7` | Eggshell (vỏ trứng) `#f3ead2` |
| Muted text | `#989586` | `#a8957a` |
| Selection | Amber outline `#cc9b3f`, button glow `#e7e54b` | Gold glow `#e8c46a` |
| Primary / confirm | — | Vermilion seal `#b8322a` |
| Semantic values | Blue `#69bffd`, green `#49a60f`, red/yellow stats | Keep Eastward's semantics |
| Speech bubble | Cream `#f5f1d8`, slate-blue text `#537a93` | Keep (our PAPER is close) |

Why lacquer: Vietnamese lacquerware (sơn mài) is literally dark glossy
panels inlaid with gold leaf and eggshell — Eastward's grammar in a
Vietnamese material, and the red seal we already own fits it. Other
families considered: Sea of Stars (dark navy + gold — same family,
heavier frames), Octopath Traveler (ornate dark frames — less restrained),
Spiritfarer / Cozy Grove / A Short Hike (light hand-drawn or scrapbook —
the paper family being retired), CrossCode (sci-fi glass — off-tone),
Dredge (dark minimal diegetic — too moody for a cozy camp).

## 9. Reference sources

- `eastward_shop_menu.jpg`, `eastward_result_card.jpg`,
  `eastward_speech_bubble.jpg`, `eastward_cooking_cutin.jpg` —
  Chucklefish dev blog "FEASTWARD" (chucklefish.org/blog/feastward, 2021).
- `eastward_inventory_menu.png` — Eastward Wiki, File:Ingredients_Menu.png
  (CC BY-NC-SA).
- `ours_panel_mock_2026-10-12.png` — our panel mock at audit time.
- Eastward 360p base resolution — Steam community thread "Devs, please fix
  the resolution scaling" (2021).
