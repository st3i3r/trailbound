# Trailbound

A cozy campsite-management game for **Android on Google Play**. Reopen the
trail's chain of forgotten rest stops: run each campsite (host guests, cook,
decorate), hit milestones, unlock the next site — complete the trail journal.

- Design bible: `docs/GAME_DESIGN.md`
- Concept plan: `docs/CAMPING_PLAN.md`
- Visual target: `docs/reference/eastward.jpg` (3/4 tilted top-down, painterly
  pixel); `docs/reference/example.png` = prop-density + dusk-mood secondary ref

## Stack (locked)

**Godot 4.5+ (GDScript)** → AAB for Play Store. TileMapLayer terrain, Y-sort
depth, AnimatedSprite2D, Control-UI, CanvasItem shaders (day/dusk), GPUParticles.
Platform: Play Games Services · Play Billing · FCM · Firebase. See §7.8.

## Layout

```
game/         Godot project (to be created — the production app)
prototype/    playable HTML prototypes — the current sandbox lives here
  game.html     playable loop: map → forage → fish → cook → serve → shop
  assets/       runtime sprites (Kenney terrain, CC0 props, generated art)
client/       SUPERSEDED Vite/PixiJS scaffold — kept as reference only
tools/        asset pipeline: pixellab_gen.py (PixelLab REST), extract, compose
assets_src/   raw packs/sheets/debug — never shipped
server/       Python backend (save/visits APIs later), tests
docs/         design + reference; archive/ holds the café-era plans
legacy/       original café-builder client (index.html) + three.js vendor
LEGAL/        PRIVACY.md, TERMS.md (needed for Play listing)
```

## Develop

Prototype demo (no build): `python -m http.server 8082` from repo root →
`http://localhost:8082/prototype/game.html?reset=1`

Godot project: not yet scaffolded — `game/` lands when implementation starts.

## Asset pipeline

PixelLab is the art source. Two ways in:

- MCP server (already configured in `.devin/config.json`, remote HTTP endpoint)
- `tools/pixellab_gen.py` for scripted batches — needs `PIXELLAB_TOKEN` env
  (see `.env.example`); generated files land in `prototype/assets/gen/` by
  default (`GEN_OUT_DIR` overrides). Download immediately — objects expire ~8h.

Style lock: `docs/reference/eastward.jpg` on every call. Sprites are plain
PNGs — engine-agnostic; the manifest maps them into the game.
