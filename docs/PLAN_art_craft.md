# Plan — Art craft pass (closing the Eastward gap)

Date: 2026-10-12. Status: **active**. Transient execution plan — the
durable rules it references live in `assets_src/prompts/style_lock.md`
(Craft spec section). Delete or archive when done.

## Forensic conclusion

Grade and ground are solved (pinewatch_v2 + tint-map recipe shipped).
Remaining gap vs `docs/reference/eastward-11.webp` is a craft-system
difference: they render "full craft", we render "icon style" — the
8-dimension rubric in style_lock records exactly where (value range,
ramps, outlines, shapes, embedding, shadow, composition, UI).

Root causes: generic prompts → cartoon icon; palette-snap compressed
color count; v1 grade lifted darks; tidy grid placement; sparse
composition; flat UI pieces.

## Phase 0 — zero-cost craft passes (code only)

1. **Embed pass** (`pinewatch_test.gd`, `scene_comp_v2.py`): decals/tufts
   overlap prop bases (y-sorted in front); ±2-4° lean on loose props.
2. **Form shading** (`tools/tb_form.py`): lower-right third darken
   ~12-18% + cool tint (bounce); deepen contact core; keep upper-left
   highlights. Dry-run on 5 props for review first.
3. **Cluster recomposition**: regroup existing staged assets into 4
   storytelling clusters — camp kitchen, outfitter camp, rest corner,
   work edge. Sub-cell jitter, some overlap, pads kept clear.
4. **UI enrichment** (`tools/tb_ui_enrich.py`): inner border + inner
   shadow + sparse paper-fiber specks + deeper shadows under raised
   elements (buttons, medallion, seal). Copies in `out/ui/pieces/`.
5. **Verify**: reshoot engine + comp. Success = embedded bases,
   warm/cool faces, fuller frame, textured UI.

## Phase 1 — targeted regen, hero props only (~80 gens) — DONE

Gated on Phase 0. Candidates ≤8: outfitter van, cabin, both tents,
fire ring, flamboyant tree, spirit house, signpost.
Tool: `create_image_pro_flash`/`create_object_pro_flash` at hero sizes
(van 128, cabin 128-160, tents 64-96). Style ref = graded comp via
`get_upload_url`; `style_options` palette+outline+shading, detail=false.
Craft-spec prompt block from style_lock.
Review gate: judge every candidate against the 8-dimension rubric;
failures keep the Phase-0 asset.

**Outcome (batch-6, 2026-10-12): 43 gens spent, balance ≈1633.**
7 of 8 approved swaps installed (van +2px top pad — roof was clipped;
cabin; both tents at 96 wide; flamboyant; spirit_house; signpost moved
to props_small). All graded `--site pinewatch_v2` + v3 palette-snap
(dE>30: only 3 px total — gens landed on-palette) + canonical contact
shadows baked via the tb_post rule. `fire_ring` NOT swapped: the A1b
flame loop is painted on the shipped ring — new gen staged as
`fire_ring_unlit_v2` and placed as a spare unlit pit by the rest corner.
Zero-gen reuse: shipped cabin copied to `cottage_shed` and placed as a
small second structure in the row-3 treeline gap, back-left of the
coop/spirit_house pair.

## Phase 2 — honest score

Engine shot + comp + 2× prop zoom. Score each rubric dimension vs
reference; report per-dimension delta. Human-pixel-artist decision
(hero props, the final ~15%) stays parked until Phase 1 data.

**Status after ground+dither+hero passes:** props/grade/ground now
pass. Two structural gaps remain, both decoded and spec'd in
`style_lock.md` → *Scene composition recipe*:

1. **Map grammar** — our scene is arranged, not designed: no spine,
   terrain doesn't read function, no envelope/exits. Fix = layout
   restructure (pure repositioning, 0 gens).
2. **L6 small-item layer** — the "more detailed" read = 60–80 objects
   with a thick functional smalls layer at 1–3% frame each. Deploy
   staged smalls (free) + one gen batch for missing types (fences,
   stepping stones, dishes/tools, signboards, ~25 gens).
   Characters also run ~15% frame height vs ref ≤12% — fix at next
   character regen, not by rescale.
3. **Deep-cut detail layer** (forensic pass 2, spec in style_lock):
   sky/mountain vista backdrop via `create_map` (~15), critters +
   signage + fence types + crop rows + tree species (~35), building
   inpaint touch-ups (~10), road wear + debris halos + characters-in-
   context placement (free).
4. **Production UI scope** (spec in style_lock → Production UI spec):
   the test HUD is ~15% of a production UI. Missing: 8-panel suite,
   diegetic open-from-object layer, need-bubbles/floaters, alert rail,
   time controls, modal stack, juice, designed states, i18n. ~0 gens —
   atlas+fonts already cover it; code work only. *Superseded by
   `docs/UI_PRODUCTION.md` (audit 2026-10-12): time controls and the
   alert rail are withdrawn, the fonts do not cover Vietnamese, and the
   flagship is the Evening tray.*

## Phase 4 — character/life pass (re-ranked after RPS review)

External evidence (RPS review): Eastward is praised for its CAST and
bespoke per-character animation — the soul axis. Runs right after
Phase 3, before more prop polish:

1. Regen warden/Mai/dog + first guest types via
   `create_character_pro_flash` with craft spec, ≤12% frame height
   (~30-50 gens)
2. Idle-quirk + in-context poses (sit/read/fish/cook/pet) — bespoke
   anim sets, not just walks
3. Need-bubbles over guests (food/rest/social) + floaters
   (coins/hearts/stars) — the living-feedback layer
4. Living world: arrivals/departures, pad occupation, phase redress —
   scene visibly changes per game state
5. Pacing guard: day-1 loop must show arrive→need→satisfy→paid→report
   immediately (the slow-burn failure Eastward was dinged for)

Budget: ~40-60 gens. The prop/ground/grade axes are done — this is
the axis that decides whether the game FEELS Eastward.

## Out of scope

Whisper River/Lantern Valley sites, new animation batches, gameplay
features — until Pinewatch passes Phase 2.

## Asset manifest (v2 — 2026-10-12, derived from GAME_DESIGN systems)

Cast is derived from the GDD's actual rosters (Guestbook 13,
Field Notes 22, Recipes 21, Keepsakes 9), not visual guesswork.

**Batch A — world/props (Phase 3, ~110):** L6 smalls + fences x3
(~25), tree species x4-5 (~20), trailhead gate (~8), pho stall +
merchandise (~12), water dressing + dock (~8), critters (~8),
building inpaint (~10), repoussoir foliage (~5), vista backdrop +
trail-map art + direction frames (~35).

**Batch B — the cast (Phase 4, ~160-180):**
- Named: warden regen + Mai + crew x2-3 + Bean/Bo dog (~25);
  grandpa sepia portrait (~3)
- Regulars x4 w/ story poses: Hung (scout leader), Minh family
  (own kid sprite), Old Ba (angler + koi vignette), Lan
  (photographer + exhibition) (~20)
- PERSONA LAYER (not class uniforms — archetype is hidden
  metadata, persona is what renders; map at spawn): ao dai photo
  couple, phuot thu (motorbike tripper), sundress city girl,
  karaoke family (Loud), co tuong elders, tiktok teen, bird-uncle
  w/ telephoto, wedding-shoot couple, art student, temple granny,
  office escapee, kid swarm (~60 bases) + costume variants via
  transfer_outfit (~25)
- Guest PETS (approved 2026-10-12, cosmetic only): border collie,
  corgi, cat-in-basket (~8)
- Portraits for named chars + persona faces (~15-20)

**Batch C — fauna (Field Notes, ~30):** 12 bird species (bulbul,
kingfisher, egret, woodpecker, swift...), 5 fish incl. Golden Koi,
chickens x2-3, ambient frog/butterfly/dragonfly.

**Batch D — food/pantry (~30):** 21 dish sprites (com nam, goi
cuon, mi quang, che, ca kho, sinh to, ca phe trung...) + ~10
ingredient sprites.

**Batch E — equipment/decor/story (~45):** Fishing Rod, Binoculars,
Camp Oven; decor catalog gaps (lanterns x3, tarp, hedge, platform,
bench, guitar stump, planter, woodpile, clothesline, bird feeder,
koi pond — audit first); keepsakes x9; vignette art (koi release,
pennant ceremony, photo-wall unveiling).

**Batch F — UI (~20):** need+mood+alert+speed icons, missing atlas
ornaments. *Re-aimed (D-UI-4/D-UI-5, `docs/UI_PRODUCTION.md`): chrome,
value and trait icons become flat glyphs drawn by us (0 gens); Batch F =
~10–12 gens of cooking cut-in close-up art. Speed icons dropped.*

**Batch G — animation sets (~70):** Bean personality set (dig,
curl-by-fire, excited-wag, follow, eat-leftovers), warden quirks,
guest in-context set (sit/fish/eat/photo/chat/kids-run), crew work
anims (hammer/carry/saw), critter loops, prop loops.

**Zero-gen (code):** particles (fireflies, petals, smoke,
confetti), ALL transitions, 2.5D lighting, juice.

**Totals: ~110+170+30+30+45+20+70 = ~475 gens (~29% of ~1633) —
leaves ~1160 for future sites.** The cast is the biggest line
item, as the RPS review predicted: the game lives on its people.

## Budget

Phase 0: 0 gens. Phase 1: ≤8 × ~10 = ~80 of ~1640 remaining.
Phase 3 (map restructure + L6 + deep-cut details): ~100-110 gens —
map restructure itself is free; spend goes to L6 smalls, vista
backdrop (create_map, approved uses per policy), trail-map art,
1-2 direction frames, tree species (4-6 for forest wall), trailhead
gate, pho stall w/ merchandise, signage, water dressing, critters,
building inpaint. Spec: style_lock Scene composition recipe (all
four specs) + create_map usage policy.
