// Save model — mirrors the proven prototype shape (prototype/game.html).
export interface GameState {
  coins: number;
  day: number;
  energy: number;
  energyMax: number;
  charm: number;
  scene: SceneId;
  inv: Record<string, number>;
  gear: Record<string, boolean>;
  unlocked: Record<SceneId, boolean>;
  found: Record<string, number>;
  caught: Record<string, number>;
  bestFish: number;
}

export type SceneId = "camp" | "map" | "forest" | "river" | "valley" | "coast";

const KEY = "trailbound_v1";

export const defaultState = (): GameState => ({
  coins: 80,
  day: 1,
  energy: 10,
  energyMax: 10,
  charm: 1,
  scene: "camp",
  inv: { firewood: 1 },
  gear: {},
  unlocked: { camp: true, map: true, forest: true, river: true, valley: false, coast: false },
  found: {},
  caught: {},
  bestFish: 0,
});

export function loadState(): GameState {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return { ...defaultState(), ...JSON.parse(raw) };
  } catch { /* corrupted save -> fresh */ }
  return defaultState();
}

export function saveState(s: GameState) {
  localStorage.setItem(KEY, JSON.stringify(s));
}
