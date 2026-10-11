# Trailbound

A cozy isometric camping/travel game for **Telegram Mini Apps** (mobile + desktop +
standalone browser). Restore the trail's forgotten rest stop: hike out by day
(forage, fish), host travelers by night, and complete the trail journal.

- Design bible: `docs/GAME_DESIGN.md`
- Concept plan: `docs/CAMPING_PLAN.md`
- Visual target: `docs/reference/example.png` (steep 3/4 iso, chunky diorama)

## Layout

```
client/       production app — Vite + TypeScript + PixiJS v8 + @twa-dev/sdk
  src/game/     engine-agnostic state, catalogs (items/gear/locations)
  src/render/   iso math + PixiJS stage adapter (depth-sorted world)
  src/assets/   manifest.ts — every sprite path lives here, nothing else
  src/scenes/   camp / forest / river / map
  src/ui/       DOM HUD (floating pills) + sheets
  src/tg/       Telegram SDK wrapper (no-op outside Telegram)
  src/audio/    procedural WebAudio SFX
  public/assets/ shipped sprites (atlas-packed later)
prototype/    playable HTML prototypes — the current demo lives here
  game.html     playable loop: map → forage → fish → cook → serve → shop
  assets/       runtime sprites (Kenney terrain, CC0 props, generated art)
tools/        asset pipeline: pixellab_gen.py (PixelLab REST), extract, compose
assets_src/   raw packs/sheets/debug — never shipped
server/       Python backend (save/visits APIs later), tests
docs/         design + reference; archive/ holds the café-era plans
legacy/       original café-builder client (index.html) + three.js vendor
LEGAL/        PRIVACY.md, TERMS.md (needed for Telegram apps)
```

## Develop

```sh
cd client && npm install && npm run dev     # http://localhost:5173
npm run build                               # typecheck + bundle -> dist/
```

Prototype demo (no build): `python -m http.server 8082` from repo root →
`http://localhost:8082/prototype/game.html?reset=1`

## Asset pipeline

PixelLab is the art source. Two ways in:

- MCP server (already configured in `.devin/config.json`, remote HTTP endpoint)
- `tools/pixellab_gen.py` for scripted batches — needs `PIXELLAB_TOKEN` env
  (see `.env.example`); generated files land in `prototype/assets/gen/` by
  default (`GEN_OUT_DIR` overrides). Download immediately — objects expire ~8h.

Swap placeholders → generated art by editing `client/src/assets/manifest.ts` only.
