// Steep 3/4 iso projection — matches docs/reference/example.png (~35° pitch,
// ~1.55:1 ground diamond, tall side faces). Source of truth for all scene math.
export const GW = 66;   // half-width of a tile's ground diamond
export const GH = 42;   // half-height — steeper than classic 2:1 iso
export const TOPH = 84; // raised-block top face height
export const SIDEH = 43; // raised-block side face height (the chunky look)

export const iso = (i: number, j: number, ox: number, oy: number) => ({
  x: ox + (i - j) * GW,
  y: oy + (i + j) * GH,
});

export const depth = (i: number, j: number, yOff = 0) => i + j + yOff / 1000;
