# Site briefs — Trailbound

One page per site. Everything here conforms to `assets_src/prompts/
style_lock.md` (scene composition recipe, lighting spec, character
spec). A brief is the design contract BEFORE any generation: terrain
trio, spine, vista, signatures, fauna, food, mood preset, asset list.

Template fields: Geography inspiration · Three-zone grammar · Spine ·
Signature elements · Fauna roster · Food/stall · Mood preset ·
Asset needs · Reuse.

---

## SB-1 · Pinewatch Forest (SITE 1 — built, reference implementation)

Mixed pine highland clearing. Grammar: canopy wall → grass field +
pond + dirt yard → treeline. Spine: bottom trailhead → road → fire hub.
Signatures: flamboyant (phuong) tree, spirit house, outfitter van,
phin coffee. Fauna: bulbul + forest birds. Food: pho stall. Mood:
warm sunny forest (pinewatch_v2 preset). Status: integrated.

## SB-2 · Sơn Trà Shorecamp (SITE 2/3 candidate — coastal Danang)

**Inspiration:** Son Tra peninsula — jungle foothill dropping to the
sea, Hai Van motorbike pass, coracle (thuyen thung) fishing boats,
My Khe east-facing shore, whale-shrine fishing culture, Marble
Mountains karst DNA. Central-coast Vietnam, not generic beach.

**Three-zone grammar:**
JUNGLE WALL (Sơn Trà foothill: banyan, palms, casuarina, vines —
tropical canopy, denser+looser than pine wall) → CAMP CLEARING
(grass-to-sand transition, fire hub, pads) → SEA (sand band, working
shore, open horizon vista).

**Spine:** the HẢI VÂN ROAD itself — coastal road crosses the frame,
trailhead gate + moped parking row (4-5 mopeds = phuot culture),
road visibly continues toward the pass = exit cue. Branches: road →
fire hub → pads → shore/jetty.

**Signature elements:**
- Coracle boats x3-4 on the sand + one afloat at stone jetty —
  THE icon
- Whale shrine (dinh ca ong — fishermen's guardian-whale shrine) in
  the spirit-house role
- Douc langur perched in jungle canopy — Field Notes celebrity,
  occasional position shifts
- Seafood stall = pho-stall grammar Danang form: banh xeo griddle,
  hanging fish, crab baskets, price board
- Casuarina fringe lining the sand edge
- Net-mending chair, drying racks (reuse fish_rack), basket stacks

**Vista:** OPEN SEA HORIZON — the inverse of Pinewatch's mountain
backdrop: sky + sea + distant headland silhouette + coracle dots.
Sunrise gold on water. Via create_map.

**Fauna roster:** douc langur (hero), kingfisher + egret + terns at
shore, crabs at tideline, koi→sea fish species, butterfly. Fishing:
jetty spot + coracle spot.

**Mood preset:** BRIGHT MARINE — teal sea, white sand, deep jungle
green, coral/orange accents; east-facing = sunrise scene as the
signature phase. Hue-shifted pinewatch_v2 toward cyan/sand.

**Asset needs (~80-100 gens):** sea+shore+sand terrain sheet,
coracles x3-4, whale shrine, casuarina/palm/banyan species, langur,
seafood stall + goods, moped row, wave-edge loop, sunrise vista,
jetty/dock, karst outcrop accents.

**Reuse:** tile pipeline + all post systems (grade/dither/tint/
embed/variants), fire hub, tents, stall grammar, gate, crew, UI.

**Note:** distinct enough to stand as Site 2 or 3 on its own —
compare against canon Whisper River before assigning (coastal camp
is more differentiated from Pinewatch than a second forest site).

## SB-3 · Lantern Valley (canon site 3 — brief TBD)

Valley-of-lanterns concept exists in GDD; brief to be written when
SB-2 lands (contrast target: evening/warm-lantern mood vs SB-2's
bright marine).
