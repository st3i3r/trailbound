// Data catalogs — gameplay is data-driven; everything here is a stub until the
// P0 JSON catalogs land (items, gear, recipes, visitors, locations).

export interface ItemDef { id: string; name: string; sell: number; tags: string[] }
export interface GearDef { id: string; name: string; cost: number; unlocks: string }
export interface LocationDef {
  id: string; name: string; cost: number; activity: "forage" | "fish" | "none";
}

export const ITEMS: ItemDef[] = [
  { id: "mushroom", name: "Mushroom", sell: 4, tags: ["ingredient"] },
  { id: "berries", name: "Berries", sell: 5, tags: ["ingredient"] },
  { id: "herb", name: "Trail Herb", sell: 6, tags: ["ingredient"] },
  { id: "firewood", name: "Firewood", sell: 2, tags: ["fuel"] },
  { id: "goldcap", name: "Goldcap", sell: 25, tags: ["ingredient", "rare"] },
  { id: "minnow", name: "Minnow", sell: 6, tags: ["fish"] },
  { id: "trout", name: "Trout", sell: 14, tags: ["fish"] },
  { id: "golden_koi", name: "Golden Koi", sell: 40, tags: ["fish", "rare"] },
];

export const GEAR: GearDef[] = [
  { id: "rod", name: "Fishing Rod", cost: 60, unlocks: "river fishing" },
  { id: "net", name: "Forage Net", cost: 90, unlocks: "+1 forage yield" },
  { id: "lantern", name: "Lantern", cost: 120, unlocks: "+4 max energy" },
  { id: "tent2", name: "Big Tent", cost: 200, unlocks: "more visitors" },
];

export const LOCATIONS: LocationDef[] = [
  { id: "forest", name: "Pinewatch Forest", cost: 0, activity: "forage" },
  { id: "river", name: "Whisper River", cost: 0, activity: "fish" },
  { id: "valley", name: "Lantern Valley", cost: 500, activity: "forage" },
  { id: "coast", name: "Glasscoast", cost: 1500, activity: "fish" },
];
