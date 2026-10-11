import type { GameState } from "../game/state";

/** DOM HUD — floating pills only, nothing persistent (matches the
 *  no-HUD reference). Sheets/dialogs slide up on demand. */
export class Hud {
  private root: HTMLDivElement;

  constructor(private state: GameState) {
    this.root = document.createElement("div");
    this.root.style.cssText =
      "position:fixed;top:0;left:0;right:0;display:flex;gap:8px;" +
      "justify-content:center;padding:10px;font-family:Silkscreen,monospace;" +
      "font-size:12px;pointer-events:none;z-index:10";
    document.body.appendChild(this.root);
    this.refresh();
  }

  refresh() {
    const s = this.state;
    this.root.innerHTML = "";
    for (const [icon, val] of [
      ["🪙", s.coins], ["⚡", `${s.energy}/${s.energyMax}`], ["📅", `Day ${s.day}`],
    ] as const) {
      const pill = document.createElement("div");
      pill.style.cssText =
        "background:#fff8e7;border:2px solid #4a3728;border-radius:999px;" +
        "padding:4px 10px;color:#4a3728";
      pill.textContent = `${icon} ${val}`;
      this.root.appendChild(pill);
    }
  }
}
