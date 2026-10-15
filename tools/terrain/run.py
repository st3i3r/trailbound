"""Terrain pipeline orchestrator.

  python -m tools.terrain.run            full pipeline
  python -m tools.terrain.run --zones    stage A only (inspect zones.png first)

Stages: A zones -> B fields -> C quilt -> D transitions -> E scatter -> F validate.
Deterministic: seed fixed per run. All intermediate layers land in
assets_src/layers/ as inspectable PNG/npz/json.
"""
import sys
import numpy as np
from . import lib, zones, fields, synth, transitions, scatter, validate, exemplars as exb


def main():
    only_zones = '--zones' in sys.argv
    seed = 11
    for a in sys.argv[1:]:
        if a.startswith('--seed='):
            seed = int(a.split('=')[1])
    rng = np.random.default_rng(seed)

    print('A zones')
    bare = '--bare' in sys.argv          # no struct inheritance from old render
    zmap, masks = zones.run(bare=bare)
    if only_zones:
        return
    print('B fields')
    dist, pairs, edge = fields.run(zmap, masks)
    print('C0 exemplars')
    base = lib.load_rgb(lib.GROUND)
    ex = exb.gen_all(rng)
    print('C quilt')
    out, cover = synth.run(zmap, masks, ex, base, rng)
    # untouched terrain falls back to base (e.g. zone eroded away entirely)
    terrain_any = ~masks['struct']
    out[terrain_any & ~cover] = base[terrain_any & ~cover]
    lib.save_rgb(out, f'{lib.LAYERS}/after_synth.png')
    print('D transitions')
    out = transitions.run(out, base, zmap, masks, dist, rng)
    lib.save_rgb(out, f'{lib.LAYERS}/after_trans.png')
    print('E scatter')
    out = scatter.run(out, zmap, masks, rng)
    out[masks['struct']] = base[masks['struct']]
    lib.save_rgb(out, lib.OUT)
    print('F validate')
    validate.run(out, masks)
    print('saved', lib.OUT)


if __name__ == '__main__':
    main()
