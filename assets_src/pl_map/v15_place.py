#!/usr/bin/env python3
"""v15 object dressing pass — sequential place_map_object calls.
Placements mirror PROPS_PINEWATCH clusters on the new terrain.
Usage: python assets_src/pl_map/v15_place.py [--dry]"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))
import pixellab_mcp as plm

MAP = "819843d7-50f6-4883-a357-421c66027a59"

# [object_id | "char:"+character_id, x, y, layer, direction?]
# layer = draw order; higher paints on top (southward later)
P = [
    # ---- treeline canopy wall on the dirt band (bases y1-3) ----
    ("e7ca2632-2e50-4e80-80d3-be89d2bf34a5", 0, 3, 30),    # pine A west edge
    ("36dcc133-b25b-4f61-9e18-4012b1eed41d", 11, 2, 20),   # pine B
    ("d4a77616-cc87-48f9-bce1-a05fcea6a87b", 14, 2, 20),   # flame tree accent
    ("ccae7b55-4488-4561-9ec2-7065ac9858c2", 17, 2, 20),   # pine C
    ("e7ca2632-2e50-4e80-80d3-be89d2bf34a5", 20, 2, 20),   # pine A
    ("36dcc133-b25b-4f61-9e18-4012b1eed41d", 23, 3, 30),   # pine B east edge
    ("ccae7b55-4488-4561-9ec2-7065ac9858c2", 7, 1, 10),    # pine C flanking vale
    ("d79ebcde-cf76-411a-8b00-2e6cf930de92", 4, 1, 10),    # flame tree vale W
    # ---- hut yard NE ----
    ("95ab3885-047a-46a8-b0d8-f40014d68d9f", 21, 4, 40),   # warden cabin
    ("89c7cef0-b320-49db-9c71-406a6a48dff6", 19, 4, 45),   # bird_feeder
    ("929a352d-aa7f-4c11-b388-900ac5cbdae0", 20, 5, 50),   # clothesline
    ("eb2bf0ff-3aca-4b11-9c8d-bbccc2287cc5", 22, 5, 50),   # rain_barrel
    ("e80acae6-2bac-41f3-a34b-e0f673b24dd8", 23, 5, 50),   # water_jar
    ("4f40354b-9903-4920-a203-924f09626a76", 22, 6, 60),   # chicken_coop
    # ---- gate apron / road east ----
    ("222b1d77-126f-44ab-8a52-2802b2d022a7", 22, 7, 70),   # flower_arch
    ("338cde64-3079-4c0f-bfc2-48070e340493", 19, 6, 60),   # moped_cub
    ("2a1d4712-015f-4eb1-a08f-d8c10401abb8", 20, 8, 80),   # outfitter_bus
    ("8d32b54c-3939-470c-81ba-e1a8934ec8c1", 18, 8, 80),   # reception_board
    ("9cbd19f4-dc24-4183-acc7-a6ae4f58e0ee", 21, 9, 90),   # basket mushrooms
    ("086e3ef4-c5bc-4bd4-9210-4ea590b1ab33", 20, 9, 90),   # basket red
    # ---- fire court plaza ----
    ("f91277ee-0b83-44de-a74f-221b5441504a", 14, 9, 90),   # lantern_post NW
    ("9aa2a8f3-3595-428f-9ca0-a14022d8862a", 13, 8, 80),   # trail signpost
    ("62c50b04-5e86-4165-af81-f35152724059", 16, 11, 110), # fire ring
    ("8ae7ba3e-7c4d-4753-9d76-fc3fd3f96f01", 15, 10, 100), # tripod pot
    ("729c6727-87bd-43df-ba69-c79ffb58fc04", 15, 12, 120), # log bench
    ("be2e9fce-9686-491f-a83f-c482971b9745", 17, 11, 110), # log stool
    ("be2e9fce-9686-491f-a83f-c482971b9745", 17, 12, 120), # log stool 2
    ("6a4b5b8b-09dd-4ff8-b878-6e159925cf6c", 14, 12, 120), # woodpile
    ("5962f453-ddff-40f7-b716-cbe81270bf46", 16, 13, 130), # dog bed
    # ---- pads: 2 open + platform, 5 overgrown ----
    ("ba2fc2cc-dd53-4799-b826-f532a6a78bb0", 9, 7, 70),    # pad_cleared p1
    ("ffc2d52b-4ec4-4912-9c90-f60263d45870", 13, 7, 70),   # tent platform p2
    ("118a6055-e7e1-4646-b527-b20a8c16d3fa", 9, 9, 90),    # pad_overgrown_a p3
    ("3fd700ea-6279-47bf-b3a9-1e94e20497fa", 13, 11, 110), # pad_overgrown_b p4
    ("118a6055-e7e1-4646-b527-b20a8c16d3fa", 19, 11, 110), # pad_overgrown_a p5
    ("3fd700ea-6279-47bf-b3a9-1e94e20497fa", 19, 13, 130), # pad_overgrown_b p6
    ("118a6055-e7e1-4646-b527-b20a8c16d3fa", 11, 13, 130), # pad_overgrown_a p7
    ("3fd700ea-6279-47bf-b3a9-1e94e20497fa", 7, 11, 110),  # pad_overgrown_b p8
    # ---- pond west + bank ----
    ("5d0ca814-2f06-47a3-a6fa-836814c62f62", 9, 5, 50),    # shore reeds N
    ("f754187e-78cf-4006-95eb-46b2e58cf8da", 3, 4, 40),    # mossy rock inlet
    ("f754187e-78cf-4006-95eb-46b2e58cf8da", 6, 4, 40),    # mossy rock shore
    ("f754187e-78cf-4006-95eb-46b2e58cf8da", 9, 8, 80),    # mossy rock bank
    ("5d0ca814-2f06-47a3-a6fa-836814c62f62", 8, 11, 110),  # reeds S arm
    ("24bf3073-2a1b-4259-aaf9-748a193eaae6", 9, 10, 100),  # fishing stool
    ("71c6c441-dca6-4fd0-92e8-701599f92cc4", 8, 10, 100),  # heron wading
    ("8a0700fa-4902-44da-b7b4-d50fce0e5254", 6, 5, 50),    # kingfisher
    ("56212a17-9410-47af-b418-8ea248a9207c", 7, 12, 120),  # forage bush
    # ---- field vignettes ----
    ("b4e03d16-41ba-4647-b61a-c46b4e98ab33", 10, 4, 40),   # hammock by pond
    ("6a854c29-e5aa-427c-82e5-891d07877e12", 12, 5, 50),   # kite stake
    ("32fa8627-2dc3-4968-a1e8-b67cc319d8e0", 12, 6, 60),   # picnic table
    ("119db57e-49b8-49d9-a832-ceab8ef3f18f", 19, 10, 100), # tea table
    ("0b40b3de-9004-41e5-98ae-7fe5a3457660", 10, 3, 30),   # fern bank at finger
    ("d29b2ede-f5fb-4ed6-a057-aed6cc813b5c", 12, 13, 130), # pink wildflowers
    ("21d69e8b-41ba-477e-8992-6d7a02ef5394", 20, 10, 100), # white wildflowers
    ("14d2eb27-bf5c-4716-bee7-f846342921b4", 9, 2, 20),    # pinecone on dirt
    ("0655b192-803a-49be-a94f-d299313cdf76", 15, 3, 30),   # needle scatter
    ("45b77774-b4c4-4a3f-8ca6-5784d0c42c41", 11, 12, 120), # grass tuft
    ("7a9292b3-fd1e-4785-8d48-41dbd41bcac5", 6, 13, 130),  # tall tuft S
    # ---- cast ----
    ("char:5c46829b-6f6b-4028-a496-3159425bc5f8", 15, 11, 115, "south"), # warden
    ("char:63f02b24-de59-40f6-9985-06d5569dd455", 18, 10, 100, "west"),  # mai
    ("char:11c5c011-bd93-4545-baa1-09b28508d454", 10, 10, 105, "west"),  # angler
    ("char:0ec5d5b2-f18e-4f8c-b77f-0c2f7e81d19f", 16, 12, 125, "east"),  # collie
    ("char:61e5900e-144a-4857-a992-b903890d2976", 22, 9, 95, "west"),    # backpacker m
    ("char:4a938bba-bcaf-462e-adf8-018f565bba18", 21, 10, 100, "west"),  # backpacker f
]

def main():
    dry = "--dry" in sys.argv
    plm.session_init()
    n = 0
    for row in P:
        oid, x, y, layer = row[0], row[1], row[2], row[3]
        args = {"map_id": MAP, "x": x, "y": y, "layer": layer, "show": False}
        if oid.startswith("char:"):
            args["character_id"] = oid[5:]
            if len(row) > 4:
                args["direction"] = row[4]
        else:
            args["object_id"] = oid
        if dry:
            print(" ", oid[:14], "->", x, y, "L", layer)
            continue
        try:
            res = plm.tool_call("place_map_object", args)
            txt = plm.res_text(res).splitlines()
            print(" ", txt[0] if txt else "ok", flush=True)
        except SystemExit as e:
            print(f"  FAIL {oid[:8]} at {x},{y}: {e}", flush=True)
        n += 1
    print(f"done: {n}/{len(P)} placements")

if __name__ == "__main__":
    main()
