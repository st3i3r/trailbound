import { Container, Sprite, Texture } from "pixi.js";

/** Depth-sorted iso stage. Thin PixiJS adapter — game code never touches
 *  Pixi objects directly, so a Canvas-2D fallback remains possible. */
export class IsoStage {
  readonly world: Container;

  constructor(root: Container) {
    this.world = new Container({ sortableChildren: true });
    root.addChild(this.world);
  }

  add(tex: Texture | undefined, x: number, y: number, z: number, anchorY = 1): Sprite {
    const s = new Sprite(tex ?? Texture.WHITE);
    s.anchor.set(0.5, anchorY);
    s.position.set(x, y);
    s.zIndex = z;
    this.world.addChild(s);
    return s;
  }

  resort() {
    this.world.sortChildren();
  }
}
