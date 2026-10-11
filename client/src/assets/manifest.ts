// Asset manifest — the ONLY place sprite paths are named.
// PixelLab upgrades land by editing entries here; gameplay code never changes.
// Keys are stable; values point into public/assets/.

export const SPRITES = {
  // terrain — placeholder procedural/Kenney until P0 PixelLab batch lands
  "tile.grass": "tiles/grass.png",
  "tile.dirt": "tiles/dirt.png",
  "tile.water": "tiles/water.png",
  "tile.cliff.s": "tiles/cliff_s.png",
  "tile.cliff.e": "tiles/cliff_e.png",
  // camp props
  "prop.tent1": "props/tent1.png",
  "prop.campfire": "props/campfire.png",
  "prop.tripod": "props/tripod.png",
  "prop.stump": "props/stump.png",
  "prop.fence": "props/fence.png",
  "prop.fence.corner": "props/fence_corner.png",
  "prop.fence.gate": "props/fence_gate.png",
  "prop.lantern": "props/lantern.png",
  "prop.stringlights": "props/stringlights.png",
  "prop.noticeboard": "props/noticeboard.png",
  "prop.van": "props/outfitter_van.png",
  "prop.blanket": "props/picnic_blanket.png",
  "prop.table": "props/camp_table.png",
  "prop.planter": "props/planter.png",
  "prop.hammock": "props/hammock.png",
  // vegetation
  "tree.oak": "trees/oak.png",
  "tree.conifer": "trees/conifer.png",
  "tree.pine": "trees/pine.png",
  "bush.blob": "trees/bush.png",
  "clutter.mushroom": "trees/mushroom.png",
  "clutter.flowers": "trees/flowers.png",
  "clutter.grasstuft": "trees/grasstuft.png",
  // water props
  "water.shore": "water/shore.png",
  "water.waterfall": "water/waterfall.png",
  "water.dock": "water/dock.png",
  "water.swimring": "water/swimring.png",
  // characters — sheets are {dir}_{frame} grids resolved by loader
  "char.player": "chars/player_sheet.png",
  "char.ranger": "chars/ranger_sheet.png",
  "char.dog": "chars/dog_sheet.png",
  "char.traveler.hiker": "chars/hiker_sheet.png",
  "char.traveler.photo": "chars/photographer_sheet.png",
  "char.traveler.angler": "chars/angler_sheet.png",
  // activities
  "node.mushroom": "nodes/mushroom.png",
  "node.berries": "nodes/berries.png",
  "node.herb": "nodes/herb.png",
  "node.firewood": "nodes/firewood.png",
  "node.goldcap": "nodes/goldcap.png",
  "fish.minnow": "fish/minnow.png",
  "fish.trout": "fish/trout.png",
  "fish.koi": "fish/koi.png",
  // ui (generated sheet, sliced)
  "ui.sheet": "ui/widgets.png",
  "map.trail": "map/trail_map.png",
} as const;

export type SpriteKey = keyof typeof SPRITES;
