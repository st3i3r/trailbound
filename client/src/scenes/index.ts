import { Graphics } from "pixi.js";
import type { IsoStage } from "../render/stage";
import { iso, depth } from "../render/iso";
import type { GameState } from "../game/state";
import type { Hud } from "../ui/hud";

/** Scene mounting. Real scenes (camp/forest/river/map) port from
 *  prototype/game.html in Phase 0 — this placeholder proves the boot path. */
export function mountScene(stage: IsoStage, state: GameState, _hud: Hud) {
  const W = 400, OX = W / 2, OY = 60;
  // placeholder diamond so `vite dev` shows the camera works
  for (let i = 0; i < 8; i++) {
    for (let j = 0; j < 8; j++) {
      const p = iso(i, j, OX, OY);
      const g = new Graphics();
      g.poly([-66, 0, 0, 42, 66, 0, 0, -42], true).fill(0x5da944).stroke({ width: 1, color: 0x3d7a2c });
      g.position.set(p.x, p.y);
      g.zIndex = depth(i, j);
      stage.world.addChild(g);
    }
  }
  stage.world.position.set(0, 20);
}
