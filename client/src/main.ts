import { Application } from "pixi.js";
import { initTelegram } from "./tg";
import { Hud } from "./ui/hud";
import { loadState } from "./game/state";
import { mountScene } from "./scenes";
import { IsoStage } from "./render/stage";

async function boot() {
  const app = new Application();
  await app.init({
    background: 0x1a1420,
    resizeTo: document.getElementById("app")!,
    antialias: false, // pixel art
  });

  document.getElementById("app")!.appendChild(app.canvas);

  initTelegram();
  const state = loadState();
  const hud = new Hud(state);
  const stage = new IsoStage(app.stage);

  mountScene(stage, state, hud);
}

boot();
