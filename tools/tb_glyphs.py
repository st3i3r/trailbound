#!/usr/bin/env python3
## tb_glyphs — UI-066 chrome glyph pipeline.
##
## Two sources, one output format (24px white masks -> game/assets/
## pinewatch/icons/G_<name>.png):
##
##   IMPORT — pixelarticons (MIT, assets_src/thirdparty/pixelarticons/svg).
##            Their paths are integer M/H/V/Z rect unions: rasterized
##            exactly, no AA, by walking the path into PIL polygons.
##   DRAW   — Trailbound objects authored here as string art ('#'=ink).
##            Sections, values the library lacks, trait-specific marks.
##
## Glyphs are WHITE MASKS: fill 255,255,255 on the shape's alpha.
## Colour is a UI concern — call sites modulate (theme icon colors).
##
## Usage:
##   python tools/tb_glyphs.py            # emit all masks + contact sheet
##   python tools/tb_glyphs.py --sheet    # contact sheet only
##
## Registry ids printed at the end for icons.json.

import json
import os
import re
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_DIR = os.path.join(ROOT, "assets_src", "thirdparty", "pixelarticons", "svg")
OUT_DIR = os.path.join(ROOT, "game", "assets", "pinewatch", "icons")
SHEET = os.path.join(ROOT, "assets_src", "cleanup", "glyphs_sheet.png")

INK = "#"   # string-art mark for a lit pixel


# --------------------------------------------------------------- import set
# semantic name -> pixelarticons svg.  Chosen for silhouette legibility
# at 24px and Trailbound vocabulary (MIT licence — see registry _sources).
IMPORT = {
    # system / chrome
    "close": "close", "back": "arrow-left", "check": "check",
    "plus": "plus", "minus": "minus", "lock": "lock", "unlock": "unlock",
    "gear": "gear", "sliders": "sliders", "info": "circle-info",
    "alert": "square-alert", "question": "circle-question",
    "undo": "undo", "play": "play", "pause": "pause",
    "volume": "volume-2", "volume_x": "volume-x",
    "music": "music", "note": "note", "bell": "bell",
    "hourglass": "hourglass", "hand": "hand", "sparkle": "sparkle",
    "radio": "radio", "megaphone": "megaphone", "search": "search",
    "filter": "filter", "share": "share", "trash": "trash",
    "edit": "pencil", "checkbox": "checkbox", "spinner": "spinner",
    "eye": "eye", "eye_off": "eye-off", "zap": "zap",
    "arrow_up": "arrow-up", "arrow_down": "arrow-down",
    "arrow_right": "arrow-right",
    "plus_box": "plus-box", "minus_box": "minus-box",
    "map": "map", "map_pin": "map-pin", "compass": "compass",
    "notebook": "notebook", "book_open": "book-open",
    "mail": "mail", "mailbox": "mailbox", "calendar": "calendar",
    "image": "image", "bookmark": "bookmark", "inbox": "inbox",
    "card": "card", "credit_card": "credit-card",
    "users": "users", "user": "user", "user_plus": "user-plus",
    "human": "human", "backpack": "backpack", "tools": "tools",
    "tool_case": "tool-case", "store": "store", "box": "box",
    "scroll": "scroll-horizontal", "lightbulb": "lightbulb",
    "bed": "bed", "pen_square": "pen-square", "flag": "flag",
    # objects that double as chrome (pads chip etc.)
    "tent": "tent", "camera": "camera", "fish": "fish", "dog": "dog",
    "fire": "fire", "leaf": "leaf", "tree_pine": "tree-pine",
    "snowflake": "snowflake", "wind": "wind",
    "thermometer": "thermometer", "snail": "snail", "car": "car",
    "bus": "bus", "truck": "truck", "potion": "potion",
    "heart": "heart", "coins": "coins",
    "sun": "sun", "moon": "moon", "cloud": "cloud",
}


# ----------------------------------------------------------------- drawn set
# Trailbound objects + shapes the library lacks.  24 rows of 24 chars,
# >=2px strokes, live area ~20x20.  Kept chunky: these tint down to
# 12-16px on chips, so detail must survive.
DRAW = {

# single coin disc — library "coins" is a stack, we need the solo unit
"coin": [
"                        ",
"                        ",
"                        ",
"                        ",
"        ########        ",
"      ####    ####      ",
"     ###        ###     ",
"    ##            ##    ",
"   ##     ####     ##   ",
"   ##    ######    ##   ",
"  ##     ######     ##  ",
"  ##     ######     ##  ",
"  ##     ######     ##  ",
"  ##     ######     ##  ",
"   ##    ######    ##   ",
"   ##     ####    ##    ",
"    ##           ##     ",
"     ###       ###      ",
"      ####   ####       ",
"        ########        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# 5-point star MASTER — star_empty/star_half are DERIVED in code
# (outline = fill minus erosion; half = left fill + right outline),
# never drawn separately.  The library's `star` is a 4-point
# sparkle, not a rating star — hence bespoke.
"star": [
"                        ",
"                        ",
"                        ",
"          ####          ",
"          ####          ",
"         ######         ",
"         ######         ",
"        ########        ",
"  ####################  ",
"  ####################  ",
"   ##################   ",
"    ################    ",
"     ##############     ",
"      ############      ",
"      ############      ",
"     ######  ######     ",
"     #####    #####     ",
"    #####      #####    ",
"    ####        ####    ",
"   ####          ####   ",
"   ###            ###   ",
"                        ",
"                        ",
"                        ",
],

# hollow star — outline only (empty rating slot)
"star_empty": [
"                        ",
"                        ",
"          ##            ",
"         ####           ",
"         ####           ",
"        ##  ##          ",
"        ##  ##          ",
"  #######    #######    ",
"  ##              ##    ",
"   ##            ##     ",
"    ##          ##      ",
"     ##        ##       ",
"     ##       ###       ",
"    ###      ## ##      ",
"    ##      ##   ##     ",
"   ##       ##   ##     ",
"   ##      ##    ##     ",
"  ##      ##      ##    ",
"  ##    ###        ##   ",
"  ##   ##          ##   ",
"   ####            ##   ",
"                        ",
"                        ",
"                        ",
],

# half-filled star — left solid, right outline (rating 4.5)
"star_half": [
"                        ",
"                        ",
"          ##            ",
"         ## #           ",
"        ##  #           ",
"        ##  ##          ",
"        ##  ##          ",
"  ####### # #######     ",
"  #######        ##     ",
"   #####        ##      ",
"    ####       ##       ",
"     ##       ##        ",
"     ##      ###        ",
"    ##      ## ##       ",
"    ##     ##   ##      ",
"   ##     ##    ##      ",
"   ##    ##     ##      ",
"  ##    ##       ##     ",
"  ##   ##        ##     ",
"  ##  ##          ##    ",
"   ####           ##    ",
"                        ",
"                        ",
"                        ",
],

# rain cloud — library has no cloud-rain
"rain": [
"                        ",
"                        ",
"      #########         ",
"    #############       ",
"   ###############      ",
"  #################     ",
"  ##################    ",
"  ##################    ",
"   ################     ",
"    ##############      ",
"     ##########         ",
"                        ",
"    ##    ##    ##      ",
"    ##    ##    ##      ",
"     ##    ##    ##     ",
"     ##    ##    ##     ",
"      ##    ##    ##    ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# sunrise — half sun over a horizon line (Morning phase)
"sunrise": [
"                        ",
"                        ",
"                        ",
"           ##           ",
"           ####         ",
"   ###    ####    ###   ",
"    ###   ##    ###     ",
"           ####         ",
"       ##########       ",
"      ############      ",
"     ##############     ",
"     ##############     ",
"      ############      ",
"   ####          ####   ",
"                        ",
"  ####################  ",
"  ####################  ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# paper lantern — Vietnamese silk lantern, ribs + tassel (Evening phase)
"lantern": [
"                        ",
"           ##           ",
"           ##           ",
"          ####          ",
"        ########        ",
"      ############      ",
"     ####  ##  ####     ",
"    ####  ##   ####     ",
"   ####   ##    ####    ",
"   ####   ##    ####    ",
"   ####   ##    ####    ",
"   ####   ##    ####    ",
"   ####   ##    ####    ",
"    ####  ##   ####     ",
"     #### ##  ####      ",
"      ############      ",
"        ########        ",
"          ####          ",
"           ##           ",
"          ##            ",
"          ###           ",
"         ## ##          ",
"                        ",
"                        ",
],

# kite — diamond + spine + tail (kids trait)
"kite": [
"                        ",
"           ##           ",
"          ####          ",
"         ##  ##         ",
"        ##    ##        ",
"       ##      ##       ",
"      ##        ##      ",
"     ##   ##     ##     ",
"    ##    ##      ##    ",
"     ##   ##     ##     ",
"      ##  ##   ##       ",
"       ## ##  ##        ",
"        ### ##          ",
"         ####           ",
"          ##            ",
"          ##            ",
"           ##           ",
"           ###          ",
"          ## ##         ",
"         ##   ###       ",
"        ##     ##       ",
"                        ",
"                        ",
"                        ",
],

# cooking pot + ladle — recipes section
"pot": [
"                        ",
"                        ",
"                   ##   ",
"                  ####  ",
"                  ##    ",
"     ##           ##    ",
"   ######        ##     ",
"  ########      ##      ",
" #############  ##      ",
" ############# ###      ",
" ##          #####      ",
" ##          ####       ",
" ##           ##        ",
" ##           ##        ",
" ##           ##        ",
"  ##         ##         ",
"  #############         ",
"   ###########          ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# phở bowl + chopsticks + steam — pantry section
"bowl_pho": [
"                        ",
"    ##     ##     ##    ",
"    ##     ##     ##    ",
"     ##     ##   ##     ",
"     ##     ##   ##     ",
"                        ",
"                #####   ",
"   ##################   ",
"   ##################   ",
"    ##            ##    ",
"    ##          ##      ",
"     ##        ##       ",
"     ##        ##       ",
"      ##      ##        ",
"       ##    ##         ",
"        ######          ",
"         ####           ",
"        ######          ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# Mai's van — outfitter section
"van": [
"                        ",
"                        ",
"                        ",
"                        ",
"    #################   ",
"   ###################  ",
"   ##   ###    ###   ## ",
"   ##   ###    ###   ## ",
"   ##   ###    ###   ## ",
"   ################# ## ",
"   ################# ## ",
"   ################# ## ",
"   ################# ## ",
"   ####  ########  #### ",
"   ###    ######    ### ",
"    ##    ##  ##   ##   ",
"          ##  ##        ",
"          ######        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# hammer + tent — build section
"build": [
"                        ",
"             ######     ",
"            ########    ",
"            ##  ##      ",
"            ##  ##      ",
"           ##   ##      ",
"     ##   ##    ##      ",
"    #######     ##      ",
"   #########    ##      ",
"   ##     ########      ",
"  ##        ######      ",
"  ##          ##        ",
" ##           ##        ",
" ##           ##        ",
" ##         ## ##       ",
"  ##       ##   ##      ",
"  ###############       ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# envelope — letters section
"letters": [
"                        ",
"                        ",
"                        ",
"                        ",
"  ####################  ",
"  ## ##            ###  ",
"  ##   ##        #  ##  ",
"  ##    ###    ##   ##  ",
"  ##      ######    ##  ",
"  ##       ####     ##  ",
"  ##      ##  ##    ##  ",
"  ##     ##    ##   ##  ",
"  ##    ##      ##  ##  ",
"  ##   ##        ## ##  ",
"  ##                ##  ",
"  ####################  ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# calendar + star — Trail Daily
"daily": [
"                        ",
"                        ",
"   ##    ##    ##       ",
"   ##    ##    ##       ",
"  ####################  ",
"  ####################  ",
"  ##                ##  ",
"  ##      ##      ###   ",
"  ##     ####     ###   ",
"  ##     ####     ###   ",
"  ##    ##  ##    ###   ",
"  ##   ##    ##   ##    ",
"  ##    ##  ##    ##    ",
"  ##     ####     ##    ",
"  ##      ##      ##    ",
"  ##                ##  ",
"  ####################  ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# open book + paw — guestbook section
"guestbook": [
"                        ",
"                        ",
"                        ",
"                        ",
"   #######    #######   ",
"  #########  #########  ",
"  ##  ### ####  ##  ##  ",
"  ##  ## ###### ##  ##  ",
"  ##  ## ##  ## ##  ##  ",
"  ##  ## ##  ## ##  ##  ",
"  ##  ## ##  ## ## ###  ",
"  ## ### ##  ## ######  ",
"  ##  ## ##  ## ######  ",
"  ##  ## ##  ## ## ###  ",
"  ##  ## ##  ## ##  ##  ",
"   ##################   ",
"    ################    ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# leaf + pencil — field notes section
"field_notes": [
"                        ",
"                        ",
"                      ##",
"                    ####",
"              ##   #####",
"             ##   ##### ",
"            ##   ####   ",
"     ####  ##   ####    ",
"   ####### ##  ####     ",
"  ####### ## #####      ",
"  ###### ## #####       ",
"  ##### ## ####   ##    ",
"  #### ## ####    ##    ",
"  ### ## ####     ###   ",
"  ## ## ####       ##   ",
"  ## ##  ##        ##   ",
"   ##            ###    ",
"   ##            ##     ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# paw — dog traits (library dog is a full body; chips need the mark)
"paw": [
"                        ",
"                        ",
"                        ",
"    ####   ##   ####    ",
"   ###### #### ######   ",
"   ###### #### ######   ",
"   ###### #### ######   ",
"    ####   ##   ###     ",
"                        ",
"      ############      ",
"     ##############     ",
"    ################    ",
"    ################    ",
"    ################    ",
"     ##############     ",
"     ############       ",
"      ##########        ",
"        ######          ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# dog + alert — dog_wary (likes space FROM the dog)
"dog_wary": [
"                        ",
"                 ###    ",
"                #####   ",
"                #####   ",
"                 ###    ",
"                        ",
"                 ###    ",
"                ####    ",
"   ####        ####     ",
"  ######      ##        ",
"  ######     ##         ",
"  ####################  ",
"   ##    ##  ##   ###   ",
"   ##    ##  ##   ###   ",
"   ##    ##  ##    #    ",
"   ##    ##  ##         ",
"  ###   ###  ##         ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# telescope + star — stargazer trait
"stargazer": [
"                        ",
"                    ##  ",
"                  ##### ",
"                 #####  ",
"                   ##   ",
"      ###         ##    ",
"    #######      ##     ",
"   #########    ##      ",
"   #########   ##       ",
"    #######   ##        ",
"     #####   ##         ",
"      ###   ##          ",
"        ## ##           ",
"       ## ##            ",
"      ##  ##            ",
"      ##  ##            ",
"     ##   ##            ",
"    ##                  ",
"   ##                   ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# elder — person with cane (Old Ba archetype chip)
"elder": [
"                        ",
"                        ",
"         #####          ",
"        #######         ",
"        #######         ",
"         #####          ",
"          ###           ",
"       #########        ",
"      ###########       ",
"     ##### #####  #     ",
"     ##    ###    ##    ",
"     ##    ###    ##    ",
"           ###    ##    ",
"           ###    ##    ",
"          ## ##   ##    ",
"          ## ##   ##    ",
"         ##   ##  ##    ",
"         ##   ## ##     ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# guitar — music-night content glyph (chrome-side; art icon stays I1)
"guitar": [
"                        ",
"                    ##  ",
"                  ##### ",
"                 ###### ",
"                #####   ",
"              #####     ",
"            #####       ",
"          ######        ",
"        ######          ",
"       ####  ####       ",
"      #### ## ####      ",
"     ####  ##  ####     ",
"     ###   ##    ###    ",
"    ###   ####    ###   ",
"    ##     ##     ##    ",
"    ##    ####    ##    ",
"     ##          ##     ",
"     ###        ###     ",
"      #####  #####      ",
"        ########        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# keepsake box — ribbon + lid (keepsakes section)
"keepsakes": [
"                        ",
"                        ",
"                        ",
"        ##    ##        ",
"       ###  ###         ",
"      ###    ###        ",
"       ##    ##         ",
"        ##  ##          ",
"   #######  #########   ",
"   ######    ########   ",
"   #######  #########   ",
"   ##   ##  ##     ##   ",
"   ##   ##  ##     ##   ",
"   ##   ##  ##     ##   ",
"   ##   ##  ##     ##   ",
"   ##   ##  ##     ##   ",
"   ##   ##  ##     ##   ",
"   ##################   ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],

# person + lantern — crew section
"crew": [
"                        ",
"           ##           ",
"      ##  ####          ",
"     ##   ####          ",
"         ##  ##         ",
"        ########        ",
"       ### ## ###       ",
"       ### ## ###       ",
"       #########        ",
"        #######         ",
"     ##                 ",
"    ####    #####       ",
"   ####    #######      ",
"   ####   #########     ",
"   ###    ###  ####     ",
"   ##     ##    ###     ",
"          #########     ",
"           ######       ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
],
}


# --------------------------------------------------------------- 16px set
# hand-drawn at 16 with ~14px live area — NEVER auto-scaled from 24:
# coordinate-floored scaling collapses strokes and closes gaps, which
# is exactly the "blob" failure.  Every glyph the dense slots render
# (pills, card traits, bubbles, breakdown strip) gets a drawn 16.
DRAW16 = {

"coin": [
"                ",
"                ",
"                ",
"     ######     ",
"    ##    ##    ",
"   ##      ##   ",
"   #  ####  #   ",
"  #   ####   #  ",
"  #   ####   #  ",
"  #   ####   #  ",
"   #  ####  #   ",
"   ##      ##   ",
"    ##    ##    ",
"     ######     ",
"                ",
"                ",
],

# star master at 16 — full/half/empty derived in code
"star": [
"                ",
"                ",
"       ##       ",
"       ##       ",
"      ####      ",
"  ############  ",
"  ############  ",
"   ##########   ",
"    ########    ",
"    ########    ",
"   ####  ####   ",
"   ###    ###   ",
"  ###      ###  ",
"  ##        ##  ",
"                ",
"                ",
],

"heart": [
"                ",
"                ",
"  ###   ###     ",
" ##### #####    ",
"#############   ",
"#############   ",
" ###########    ",
"  #########     ",
"   #######      ",
"    #####       ",
"     ###        ",
"      #         ",
"                ",
"                ",
"                ",
"                ",
],

"check": [
"                ",
"                ",
"            ##  ",
"           ###  ",
"          ###   ",
"  ##     ###    ",
"  ###   ###     ",
"   ### ###      ",
"    #####       ",
"     ###        ",
"      #         ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"alert": [
"                ",
"      ##        ",
"      ##        ",
"     ####       ",
"     ####       ",
"     ####       ",
"     ####       ",
"      ##        ",
"                ",
"      ##        ",
"     ####       ",
"     ####       ",
"                ",
"                ",
"                ",
"                ",
],

"question": [
"                ",
"    ######      ",
"   ##    ##     ",
"   #      ##    ",
"          ##    ",
"         ##     ",
"        ##      ",
"       ##       ",
"       ##       ",
"                ",
"       ##       ",
"       ##       ",
"                ",
"                ",
"                ",
"                ",
],

"sun": [
"                ",
"    #    #      ",
"     #  #       ",
"      ##        ",
"   # #### #     ",
"   ########     ",
"   ########     ",
"  ###########   ",
"   ########     ",
"   ########     ",
"     ####       ",
"      ##        ",
"     #  #       ",
"    #    #      ",
"                ",
"                ",
],

"moon": [
"                ",
"      ####      ",
"     ######     ",
"    ######      ",
"    #####       ",
"   #####        ",
"   #####        ",
"   #####        ",
"   #####        ",
"    #####       ",
"    ######      ",
"     ########   ",
"      ######    ",
"                ",
"                ",
"                ",
],

"cloud": [
"                ",
"                ",
"     #####      ",
"   #########    ",
"  ##########    ",
" ############   ",
"##############  ",
"##############  ",
" ############   ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"rain": [
"                ",
"     #####      ",
"   #########    ",
"  ###########   ",
" ###########    ",
" ###########    ",
"                ",
"  ##   ##   ##  ",
"  ##   ##   ##  ",
"   ##   ##   ## ",
"   ##   ##   ## ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"sunrise": [
"                ",
"                ",
"       ##       ",
"   ##  ##  ##   ",
"    ## ## ##    ",
"      ####      ",
"     ######     ",
"    ########    ",
"    ########    ",
"     ######     ",
" ###        ### ",
"                ",
"##############  ",
"##############  ",
"                ",
"                ",
],

"fire": [
"                ",
"       ##       ",
"      ###       ",
"      ####      ",
"     #####      ",
"     ######     ",
"    ###  ###    ",
"    ##    ##    ",
"   ###    ###   ",
"   ##  ##  ##   ",
"   ##  ##  ##   ",
"   ### #### ##  ",
"    ########    ",
"     ######     ",
"                ",
"                ",
],

"users": [
"                ",
"   ###          ",
"  #####    ###  ",
"  #####   ##### ",
"   ###    ##### ",
"  #####    ###  ",
" ####### #####  ",
"############### ",
"############### ",
" ###### ######  ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"tent": [
"                ",
"       ##       ",
"      ####      ",
"     ######     ",
"     ##  ##     ",
"    ##    ##    ",
"    ## ## ##    ",
"   ##  ###  #   ",
"  ##   ##    #  ",
"  ##  # ##   #  ",
" ##  ##  ##  ## ",
" ## ##    ## ## ",
" ############## ",
" ############## ",
"                ",
"                ",
],

"leaf": [
"                ",
"          ##    ",
"        ####    ",
"      ######    ",
"     ########   ",
"    #########   ",
"   ### ######   ",
"   ##   ####    ",
"  ##    ###     ",
"  ##   ##       ",
"  #   ##        ",
"   # ##         ",
"    ##          ",
"                ",
"                ",
"                ",
],

"note": [
"                ",
"       #####    ",
"       ##  ##   ",
"       ##  ##   ",
"       ##       ",
"       ##       ",
"       ##       ",
"       ##       ",
"    ## ##       ",
"   ######       ",
"   ######       ",
"    ####        ",
"                ",
"                ",
"                ",
"                ",
],

"bell": [
"                ",
"      ##        ",
"     ####       ",
"    ######      ",
"    ######      ",
"    ######      ",
"    ######      ",
"   ########     ",
"   ########     ",
"  ##########    ",
" #############  ",
"      ###       ",
"       #        ",
"                ",
"                ",
"                ",
],

"paw": [
"                ",
"  ##  ##  ##    ",
" #### ## ####   ",
" #### ## ####   ",
"  ##  ##  ##    ",
"                ",
"   ########     ",
"  ##########    ",
"  ##########    ",
"  ##########    ",
"   ########     ",
"    ######      ",
"                ",
"                ",
"                ",
"                ",
],

"dog_wary": [
"                ",
"            ##  ",
"           ###  ",
"            #   ",
"                ",
"            #   ",
"  ###        #  ",
" #####      #   ",
"##### ######    ",
"  ##   ##  ##   ",
"  ##   ##  ##   ",
" ###  ###  ##   ",
"                ",
"                ",
"                ",
"                ",
],

"kite": [
"                ",
"      ##        ",
"     ####       ",
"    ##  ##      ",
"   ##    ##     ",
"  ##  ##   ##   ",
"  ##  ##   #    ",
"   ## ##  ##    ",
"    ### ##      ",
"     ####       ",
"      ##        ",
"      ##        ",
"       ##       ",
"      # ##      ",
"     #   #      ",
"                ",
],

"fish": [
"                ",
"                ",
"    ######      ",
"  ##########    ",
" ##  ##     ####",
" ##  ##       ##",
" ##  ##       ##",
" ##  ##     ####",
"  ##########    ",
"    ######      ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"camera": [
"                ",
"                ",
"   ##########   ",
"  ####  ######  ",
" ##    ##    ## ",
" ##   ####   ## ",
" ##  ######  ## ",
" ##  ######  ## ",
" ##   ####   ## ",
" ##    ##    ## ",
"  ############  ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"stargazer": [
"                ",
"           ##   ",
"          ####  ",
"           ##   ",
"    ###    ##   ",
"   #####  ##    ",
"   ##### ##     ",
"    ###  ##     ",
"     # ##       ",
"    ## ##       ",
"   ##   ##      ",
"  ##    ##      ",
" ##             ",
"                ",
"                ",
"                ",
],

"sparkle": [
"                ",
"      ##        ",
"      ##        ",
"     ####       ",
" ###########    ",
"##############  ",
" ###########    ",
"     ####       ",
"      ##        ",
"      ##        ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"megaphone": [
"                ",
"                ",
" ##             ",
" #####   ##     ",
" #######  ###   ",
"############### ",
"############### ",
"############### ",
" #######  ###   ",
" #####   ##     ",
"  ####          ",
"   ##           ",
"                ",
"                ",
"                ",
"                ",
],

"cook": [
"                ",
"             ## ",
"   ##       ##  ",
" ######    ##   ",
" ########### #  ",
" ##        ##   ",
" ##         #   ",
" ##         #   ",
" ##        ##   ",
" ###########    ",
"  #########     ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"notebook": [
"                ",
" ############   ",
"##   #########  ",
"##   #########  ",
"##   ##    ##   ",
"##   ##    ##   ",
"##   ##    ##   ",
"##   ##    ##   ",
"##   ##    ##   ",
"##   ##    ##   ",
"##   ########   ",
"##   ########   ",
" #############  ",
"                ",
"                ",
"                ",
],

"plus": [
"                ",
"                ",
"      ##        ",
"      ##        ",
"      ##        ",
"  ##########    ",
"  ##########    ",
"      ##        ",
"      ##        ",
"      ##        ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"minus": [
"                ",
"                ",
"                ",
"                ",
"                ",
"  ##########    ",
"  ##########    ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
"                ",
],

"lantern": [
"                ",
"      ##        ",
"     ####       ",
"    ######      ",
"   ###  ###     ",
"   ##    ##     ",
"   ##    ##     ",
"   ##    ##     ",
"   ##    ##     ",
"    ######      ",
"     ####       ",
"      ##        ",
"     # ##       ",
"                ",
"                ",
"                ",
],

}


# --------------------------------------------------------------- 12px set
# hand-drawn at 12 — never downscaled from 24 (AA smear).  Chips and
# inline-text badges only.
DRAW12 = {
"coin": [
"            ",
"   ######   ",
"  ##    ##  ",
" ##  ##  ## ",
" ## ##   ## ",
" ## ##   ## ",
" ##  ## ##  ",
"  ##    ##  ",
"   ######   ",
"            ",
"            ",
"            ",
],
"star_full": [
"            ",
"    ##      ",
"   ####     ",
" ###### ##  ",
"  ######    ",
"   ####     ",
"  ######    ",
" ##    ##   ",
" ##    ##   ",
"            ",
"            ",
"            ",
],
"check": [
"            ",
"            ",
"        ##  ",
"       ###  ",
"  ##   ##   ",
"  ###  ##   ",
"   ## ##    ",
"    ###     ",
"     #      ",
"            ",
"            ",
"            ",
],
"plus": [
"            ",
"            ",
"    ##      ",
"    ##      ",
"  ######    ",
"  ######    ",
"    ##      ",
"    ##      ",
"            ",
"            ",
"            ",
"            ",
],
"minus": [
"            ",
"            ",
"            ",
"            ",
"  ######    ",
"  ######    ",
"            ",
"            ",
"            ",
"            ",
"            ",
"            ",
],
"heart": [
"            ",
"  ##  ##    ",
" #########  ",
" #########  ",
" #########  ",
"  #######   ",
"   #####    ",
"    ###     ",
"     #      ",
"            ",
"            ",
"            ",
],
"alert": [
"            ",
"    ##      ",
"   ####     ",
"   ####     ",
"   ####     ",
"    ##      ",
"            ",
"    ##      ",
"   ####     ",
"            ",
"            ",
"            ",
],
}


# ------------------------------------------------------------ rasterizer
def raster_svg(path: str, size: int = 24) -> Image.Image:
    """pixelarticons path -> size x size white mask.  Paths are integer
    rect-unions (M/H/V/L/Z, some relative) — walk them into PIL
    polygons; no AA.  For size != 24 every coordinate scales then
    floors to the grid — each rect stays integer so 16px variants
    remain grid-exact (slightly denser, never smeared)."""
    scale = size / 24.0
    txt = open(path, encoding="utf-8").read()
    # an svg can carry several <path> elements (pole + flag, ground +
    # tent) — rasterize them all into the same mask
    toks = []
    for d in re.findall(r'\bd="([^"]+)"', txt):
        toks += re.findall(r'[MmHhVvLlZz]|-?\d+(?:\.\d+)?', d) + ["Z"]
    img = Image.new("L", (size, size), 0)
    dr = ImageDraw.Draw(img)
    i, x, y, sx, sy, poly = 0, 0.0, 0.0, 0.0, 0.0, []
    while i < len(toks):
        t = toks[i]
        if t in "Mm":
            x, y = float(toks[i+1]), float(toks[i+2]); i += 3
            if t == "m": x, y = sx + x, sy + y
            sx, sy = x, y
            poly = [(int(x * scale), int(y * scale))]
        elif t in "Hh":
            v = float(toks[i+1]); i += 2
            x = v if t == "H" else x + v
            poly.append((int(x * scale), int(y * scale)))
        elif t in "Vv":
            v = float(toks[i+1]); i += 2
            y = v if t == "V" else y + v
            poly.append((int(x * scale), int(y * scale)))
        elif t in "Ll":
            nx, ny = float(toks[i+1]), float(toks[i+2]); i += 3
            if t == "l": nx, ny = x + nx, y + ny
            x, y = nx, ny
            poly.append((int(x * scale), int(y * scale)))
        elif t in "Zz":
            i += 1
            if len(poly) >= 3:
                dr.polygon(poly, fill=255)
            poly = []
        else:
            raise ValueError("unhandled token %r in %s" % (t, path))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.putalpha(img)
    px = out.load()
    for yy in range(size):
        for xx in range(size):
            if px[xx, yy][3]:
                px[xx, yy] = (255, 255, 255, 255)
    return out


def raster_art(rows, size) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for yy, row in enumerate(rows):
        assert len(row) == size, "row %d: %d chars != %d" % (yy, len(row), size)
        for xx, ch in enumerate(row):
            if ch == INK:
                dr.point((xx, yy), fill=(255, 255, 255, 255))
    assert len(rows) == size
    return img


def resample_art(rows, size) -> Image.Image:
    """drawn 24-grid -> `size` by nearest sampling (x' = x*24/size).
    Chunky shapes keep their weight; used for the _16 variants."""
    out_rows = []
    step = 24.0 / size
    for yy in range(size):
        src_y = min(int(yy * step), 23)
        row = ""
        for xx in range(size):
            row += rows[src_y][min(int(xx * step), 23)]
        out_rows.append(row)
    return raster_art(out_rows, size)


def emit(name: str, img: Image.Image) -> None:
    img.save(os.path.join(OUT_DIR, "G_%s.png" % name))


def erode(img: Image.Image) -> Image.Image:
    """1px morphological erosion (8-neighbour)."""
    px = img.load()
    w, h = img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            ok = True
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h \
                            or px[nx, ny][3] == 0:
                        ok = False
                        break
                if not ok:
                    break
            if ok:
                po[x, y] = (255, 255, 255, 255)
    return out


def outline_of(img: Image.Image, depth: int) -> Image.Image:
    """Perimeter ring of a filled mask.  'Empty' variants must share
    the master's exact silhouette — derive by boolean op, never
    redraw by hand (that's what produced the comet-looking stars)."""
    core = img.copy()
    for _ in range(depth):
        core = erode(core)
    px, pc = img.load(), core.load()
    w, h = img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0 and pc[x, y][3] == 0:
                po[x, y] = (255, 255, 255, 255)
    return out


def half_of(full: Image.Image, outline: Image.Image) -> Image.Image:
    """Left half fill + right half outline, split at the canvas centre."""
    w, h = full.size
    cx = w // 2
    pf, po = full.load(), outline.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pd = out.load()
    for y in range(h):
        for x in range(w):
            a = pf[x, y][3] if x < cx else po[x, y][3]
            if a:
                pd[x, y] = (255, 255, 255, 255)
    return out


def lint_mask(name: str, img: Image.Image, strict: bool) -> list:
    """Per-glyph quality gate.  strict=True for Trailbound-drawn glyphs
    (our own craft is what needs policing); imported library art is
    vetted upstream — it only gets an empty-file sanity check, since
    its conventions (full-bleed live area, multi-part marks) differ
    from ours deliberately."""
    px = img.load()
    w, h = img.size
    lit = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                lit.add((x, y))
    if not lit:
        return ["%s: EMPTY" % name]
    if not strict:
        return []
    out = []
    seen = set()
    comps = []
    # 8-connectivity — pixel-art strokes join diagonally legitimately
    for s in lit:
        if s in seen:
            continue
        q, comp = [s], set()
        while q:
            p = q.pop()
            if p in comp:
                continue
            comp.add(p)
            seen.add(p)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    np_ = (p[0]+dx, p[1]+dy)
                    if np_ in lit and np_ not in comp:
                        q.append(np_)
        comps.append(comp)
    # a ≤2px isolated speck is noise, not a design element — real
    # multi-part marks (rain drops, steam, ?-dot) are bigger clusters
    specks = [c for c in comps if len(c) <= 2]
    if specks:
        out.append("%s: %d speck cluster(s)" % (name, len(specks)))
    if len(comps) > 6 and w >= 16:
        out.append("%s: %d components — scattered?" % (name, len(comps)))
    # touching 2+ edges means the glyph is oversized for its canvas;
    # one edge is fine (ground/base lines legitimately span it)
    xs = [p[0] for p in lit]; ys = [p[1] for p in lit]
    edges = (min(xs) == 0) + (min(ys) == 0) + (max(xs) == w-1) \
        + (max(ys) == h-1)
    if edges >= 2:
        out.append("%s: touches %d edges — oversized" % (name, edges))
    return out


def lint_all(items) -> int:
    fails = 0
    for name, img, strict in items:
        for f in lint_mask(name, img, strict):
            print("  LINT", f)
            fails += 1
    print("glyph lint: %s" % ("PASS" if fails == 0 else "%d findings"
          % fails))
    return fails


def contact_sheet(items, small=()) -> None:
    """items: [(name, img)] at 24, small: [(name,img)] at 16 — two
    stacked sheets so both sizes get reviewed."""
    def render(entries, cell):
        cols = 8
        rows = (len(entries) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cell, rows * cell + 8),
                          (26, 32, 28, 255))
        for n, entry in enumerate(entries):
            name, img = entry[0], entry[1]
            cx = (n % cols) * cell + (cell - img.width) // 2
            cy = (n // cols) * cell + (cell - img.height) // 2
            chip = Image.new("RGBA", img.size, (20, 29, 26, 255))
            chip.alpha_composite(img)
            sheet.paste(chip, (cx, cy))
        return sheet
    top = render(items, 40)
    bottom = render(small, 28) if small else Image.new(
        "RGBA", (1, 1), (0, 0, 0, 0))
    full = Image.new("RGBA", (max(top.width, bottom.width),
        top.height + 16 + bottom.height), (18, 23, 19, 255))
    full.paste(top, (0, 0))
    full.paste(bottom, (0, top.height + 16))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    full.resize((full.width * 3, full.height * 3),
                Image.NEAREST).save(SHEET)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    items = []
    missing = []
    for name, svg in IMPORT.items():
        p = os.path.join(SVG_DIR, svg + ".svg")
        if not os.path.exists(p):
            missing.append(svg)
            continue
        img = raster_svg(p)
        emit(name, img)
        items.append((name, img, False))
    for name, rows in DRAW.items():
        if name == "star":
            continue  # master — emitted as the star_full/half/empty trio below
        img = raster_art(rows, 24)
        emit(name, img)
        items.append((name, img, True))
    # derived star family: ONE drawn master per size -> full, empty
    # (outline ring), half (left fill + right ring).  Variants share
    # the silhouette by construction — never draw them separately.
    star24 = raster_art(DRAW["star"], 24)
    for nm, img in (("star_full", star24),
                    ("star_empty", outline_of(star24, 2)),
                    ("star_half", half_of(star24, outline_of(star24, 2)))):
        emit(nm, img)
        items.append((nm, img, True))
    for name, rows in DRAW16.items():
        if name == "star":
            continue
        img = raster_art(rows, 16)
        emit(name + "_16", img)
        items.append((name + "_16", img, True))
    star16 = raster_art(DRAW16["star"], 16)
    for nm, img in (("star_full_16", star16),
                    ("star_empty_16", outline_of(star16, 1)),
                    ("star_half_16", half_of(star16, outline_of(star16, 1)))):
        emit(nm, img)
        items.append((nm, img, True))
    for name, rows in DRAW12.items():
        img = raster_art(rows, 12)
        emit(name + "_12", img)
        items.append((name + "_12", img, True))
    contact_sheet(items)
    lint_all(items)
    if missing:
        print("MISSING svgs:", ", ".join(missing))
    print("glyphs: %d imported + %d drawn + %d @16 + %d @12 -> %s"
          % (len(IMPORT) - len(missing), len(DRAW), len(DRAW16),
             len(DRAW12), OUT_DIR))
    print("sheet ->", SHEET)
    # per-glyph provenance — generated, never hand-edited.  icons.json
    # stays curated (semantic names); this records WHERE every mask
    # came from for credits + licencing review (UI-066).
    prov = {"comment": "GENERATED by tools/tb_glyphs.py — do not edit.",
            "glyphs": {}}
    for name, img, strict in items:
        if not strict:
            prov["glyphs"][name] = {
                "source": "pixelarticons",
                "file": "assets_src/thirdparty/pixelarticons/svg/%s.svg"
                        % IMPORT.get(name, name),
                "licence": "MIT", "size": img.width}
        else:
            prov["glyphs"][name] = {"source": "trailbound-drawn",
                                    "tool": "tools/tb_glyphs.py",
                                    "licence": "proprietary",
                                    "size": img.width}
    with open(os.path.join(ROOT, "game/data/icons_sources.json"),
              "w", encoding="utf8") as f:
        json.dump(prov, f, indent=1, sort_keys=True)
    print("provenance -> game/data/icons_sources.json")

    print("\nregistry ids:")
    for name, _, _strict in items:
        print('  "%s": "G_%s",' % (name, name))


if __name__ == "__main__":
    main()
