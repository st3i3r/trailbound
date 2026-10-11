# Trailbound

A cozy campsite puzzle-management game for **Android on Google Play**. Each
evening, decide which guest sleeps where; each morning, reshape the camp with
what you earned. Reopen grandpa's chain of forgotten trail campsites, one
journal page at a time.

- Game design document (source of truth): `docs/GAME_DESIGN.md`
- Dev workflow: `docs/DEV_WORKFLOW.md`
- Visual target: `docs/reference/eastward.jpg` (3/4 tilted top-down, painterly
  pixel); `docs/reference/example.png` = prop-density + dusk-mood secondary ref

## Stack (locked)

**Godot 4 (typed GDScript, Compatibility renderer)** → AAB for Play Store.
TileMapLayer terrain, Y-sort depth, AnimatedSprite2D, Control-UI, 2D lights
(CanvasModulate + PointLight2D), CPUParticles2D. No backend: the whole game
plays offline.
Free and ad-supported: opt-in rewarded ads and a capped interstitial between
days (AdMob, UMP consent), plus a one-time Remove Ads purchase (Play Billing).
Firebase Analytics, Crashlytics and Remote Config; Play Games in v1.1.
See GDD §20 and §24.

## Layout

```
game/         Godot project (lands in Phase 0 — the production app)
tools/        pixellab_gen.py (PixelLab REST); the sim, content lint and Daily solver join later
assets_src/   source art from the tools, before import — never shipped
docs/         GDD, dev workflow, reference/ (style targets)
LEGAL/        PRIVACY.md, TERMS.md drafts (needed for the Play listing)
```

Earlier prototypes, the café-era code and plans, and the 2.x design were
removed in the v3.0 hard break (GDD D-22); they live in git history.

## Develop

Godot project: not yet scaffolded — `game/` lands in Phase 0
(`docs/DEV_WORKFLOW.md` §4).

Economy sim: Python 3, standard library only — the code and its reference
output live in GDD Appendix C.

## Asset pipeline

PixelLab is the art source. Two ways in:

- MCP server (configured under `.devin/`, remote HTTP endpoint)
- `tools/pixellab_gen.py` for scripted batches — needs `PIXELLAB_TOKEN` env
  (see `.env.example`):
  `python tools/pixellab_gen.py "<description>" <width> <height> <prefix>`
  (`--help` for options). Files land in `assets_src/gen/` by default
  (`GEN_OUT_DIR` overrides). Download immediately — objects expire ~8h.

Style lock: `docs/reference/eastward.jpg` on every call. Sprites are plain
PNGs — engine-agnostic; the manifest maps them into the game.
