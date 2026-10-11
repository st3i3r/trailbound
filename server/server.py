#!/usr/bin/env python3
"""
Cafe Builder — Telegram Mini App shop-builder + drink-crafting sim backend.
Python standard library only (no pip install needed).

SERVER-AUTHORITATIVE ECONOMY: the client never decides coins, recipes,
placements, or customer outcomes. Every timestamp comes from the server
clock; all recipes are validated server-side; decor placement is
re-priced and collision-checked here.

Floor data model is rooms-based from day one:
  rooms = [{id, name, cols, rows, unlocked, locked_reason, grid:[placements]}]
so adding "Sunny Terrace" / "Upstairs Lounge" later is data, not a rewrite.

Run:  BOT_TOKEN=... WEBAPP_URL=https://... python3 server.py
"""
import hashlib
import hmac
import json
import os
import random
import sqlite3
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BOT_TOKEN = os.environ.get("BOT_TOKEN", "TODO_PASTE_BOT_TOKEN")
BOT_USERNAME = os.environ.get("BOT_USERNAME", "TODO_PASTE_BOT_USERNAME")
WEBAPP_URL = os.environ.get("WEBAPP_URL", "TODO_PASTE_HTTPS_WEBAPP_URL")
PORT = int(os.environ.get("PORT", "8080"))
DB_PATH = os.environ.get("CAFE_DB", os.path.join(BASE_DIR, "cafe.db"))
# Local-dev identity: when BOT_TOKEN is unset (TODO placeholder), empty
# init_data is accepted as a fixed local player. The game runs against the
# same server rules and a local SQLite DB — no Telegram needed. Production
# (real token configured) always requires valid initData.
DEV_USER_ID = 777001

# ------------------------------------------------------------ tuning
RATE_LIMIT_S = 2            # min seconds between mutating calls per user
INITDATA_TTL_S = 86400      # initData older than this is rejected
DAY_LEN_S = 180             # 3-minute demo days
BASE_SPAWN_S = 25.0         # base seconds between customers (scaled by rep)
MAX_CUSTOMERS = 4           # concurrent customers cap (prototype)
PATIENCE_BASE_S = 60.0      # customer patience before coziness multiplier
AD_REWARD_COOLDOWN_S = 120
RUSH_HOUR_S = 300           # 5 minutes of 2x spawns from a rewarded ad
# Organic telegraphed rushes (workstream D): every RUSH_CYCLE_S of wall
# clock the server telegraphs a rush RUSH_TELEGRAPH_LEAD_S early, then the
# rush is active for RUSH_ACTIVE_S (spawns 2x). Independent of ad rushes.
RUSH_CYCLE_S = 360.0
RUSH_TELEGRAPH_LEAD_S = 60.0
RUSH_ACTIVE_S = 180.0
CRITIC_PATIENCE_S = 45.0    # Elena Voss's strict deadline
CRITIC_SURGE_S = 540.0      # customer surge after a 4-5 star review
CRITIC_COZY_BAR = 40        # effective coziness earning the critic's cozy point
# Daily quests (workstream E): 3 sampled per day, seeded by day number.
QUEST_DEFS = [
    {"id": "serve_8", "desc": "Serve 8 customers", "target": 8, "reward": 40},
    {"id": "tips_60", "desc": "Earn 60 coins in tips", "target": 60,
     "reward": 50},
    {"id": "place_3", "desc": "Place 3 decorations", "target": 3, "reward": 45},
    {"id": "discover_1", "desc": "Discover a new recipe", "target": 1,
     "reward": 60},
    {"id": "rep_35", "desc": "Reach 3.5\u2605 reputation", "target": 35,
     "reward": 70},
    {"id": "earn_300", "desc": "Earn 300 coins", "target": 300, "reward": 55},
]
REP_UP = 0.08               # rep gain per perfect serve
REP_DOWN_WALKOUT = 0.15     # rep loss on timeout walkout
REP_DOWN_WRONG = 0.05       # rep loss serving the wrong (valid) drink
REP_DOWN_SLUDGE = 0.10      # rep loss serving sludge
REP_DOWN_NOSEAT = 0.05      # rep loss when a customer finds no free seat
SELL_REFUND = 0.5           # decor resale fraction
EXPANSION_COST = 500        # main hall 8x6 -> 10x8
RESTOCK_COST = 20          # coins to refill every ingredient to full stock
BREW_BASE_S = 4.0           # base brew time (seconds)
EVENING_REP = 4.0           # rep threshold unlocking the evening crowd
MAYA_PATIENCE_S = 3600      # Maya (FTUE regular) waits up to 1h — she never
                            # walks out mid-tutorial; re-seeded if needed
# ------------------------------------------------- Wave 2: progression
LEVEL_MAX = 30              # café levels
SET_BONUS_MULT = 1.15       # completed decor set: +15% cozy (multiplicative)
SPONSOR_DAYS = 3            # Zoe brand-deal patience penalty duration (days)
CHEN_FAST_S = 20.0          # Chen beat 2: brew-ready -> serve under 20s
ZOE_SERVES_FOR_VIRAL = 3    # correct Zoe serves before the viral crowd event
RAFI_EVENINGS = 3           # distinct evenings served to unlock the Nightingale
MAYA_SERVES_FOR_BOOK = 5    # Maya serves after beat 2 before "Published"
REGULAR_SPAWN_P = 0.30      # spawn ticks that pick a regular over a walk-in
PURIST_REGULARS = ("maya", "chen")  # regulars whose patience the sponsor
                                    # poster offends (-10% for SPONSOR_DAYS)


def level_threshold(n: int) -> int:
    """Cumulative XP needed to REACH level n: 20*n*(n+1)/2.
    L1 -> 20, L2 -> 60, L3 -> 120, ... (player starts at level 1)."""
    return 20 * n * (n + 1) // 2

INGREDIENTS = ["espresso", "milk", "chocolate", "caramel", "mint", "ice"]
ING_ICON = {"espresso": "\u2615\ufe0f", "milk": "\U0001f95b",
            "chocolate": "\U0001f36b", "caramel": "\U0001f36c",
            "mint": "\U0001f33f", "ice": "\U0001f9ca"}

# name -> (sorted ingredient tuple, price). Sorted-tuple compare = order-free.
RECIPES = {
    "espresso":           {"combo": ("espresso",), "price": 8,
                           "icon": "\u2615\ufe0f"},
    "latte":              {"combo": ("espresso", "milk"), "price": 12,
                           "icon": "\U0001f95b"},
    "mocha":              {"combo": ("chocolate", "espresso", "milk"), "price": 16,
                           "icon": "\U0001f36b"},
    "caramel_macchiato":  {"combo": ("caramel", "espresso", "milk"), "price": 18,
                           "icon": "\U0001f36c"},
    "mint_mocha":         {"combo": ("chocolate", "espresso", "mint"), "price": 18,
                           "icon": "\U0001f33f"},
    "iced_latte":         {"combo": ("espresso", "ice", "milk"), "price": 14,
                           "icon": "\U0001f9ca"},
    # --- Wave 1 expansion: 6 -> 12 ---
    "hot_chocolate":      {"combo": ("chocolate", "milk"), "price": 10,
                           "icon": "\U0001f36b"},
    "caramel_espresso":   {"combo": ("caramel", "espresso"), "price": 11,
                           "icon": "\U0001f36c"},
    "mint_espresso":      {"combo": ("espresso", "mint"), "price": 11,
                           "icon": "\U0001f33f"},
    "mint_latte":         {"combo": ("espresso", "milk", "mint"), "price": 16,
                           "icon": "\U0001f95b"},
    "iced_mocha":         {"combo": ("chocolate", "espresso", "ice"), "price": 18,
                           "icon": "\U0001f9ca"},
    "nightingale":        {"combo": ("caramel", "chocolate", "espresso"),
                           "price": 22, "icon": "\U0001f319"},
}
# Story-arc-locked recipes: name -> arc beat that unlocks it. Brewing the
# combo before the unlock yields sludge with NO learning and no hint that
# the combo is special. Wave 2 adds the unlock action; the grant helper
# grant_recipe_unlock() below is the mechanism.
RECIPE_LOCKS = {"nightingale": "rafi_beat_2"}
NIGHTINGALE_HINT = "\U0001f512 ??? \u2014 someone out there knows this one\u2026"


def recipe_open(st: dict, name: str) -> bool:
    """True when a recipe is brewable / learnable / orderable: never-locked
    recipes are always open; locked ones need their arc unlock in the
    user's recipes_unlocked list."""
    return (name not in RECIPE_LOCKS
            or name in st.get("recipes_unlocked", []))
# Future menu, stubbed as locked catalog entries (visible shape, not playable).
LOCKED_RECIPES = [
    {"name": "flat_white", "icon": "\u2615\ufe0f", "locked": True,
     "hint": "Season 2 menu"},
    {"name": "affogato", "icon": "\U0001f368", "locked": True,
     "hint": "Season 2 menu"},
    {"name": "tiramisu_latte", "icon": "\U0001f370", "locked": True,
     "hint": "Season 2 menu"},
    {"name": "honey_oat_latte", "icon": "\U0001f36f", "locked": True,
     "hint": "Season 2 menu"},
    {"name": "midnight_espresso", "icon": "\U0001f319", "locked": True,
     "hint": "Event exclusive"},
    {"name": "golden_cappuccino", "icon": "\u2b50", "locked": True,
     "hint": "Premium menu"},
]

# id -> spec. seats>0 = customers can sit here. brew_cut = fraction off brew
# time (multiplicative across placed items). tip_bonus adds to tip multiplier.
CATALOG = {
    # --- furniture ---
    "wooden_table":  {"name": "Wooden Table", "icon": "\U0001fab5",
                      "cat": "furniture", "cost": 50, "cozy": 5, "w": 2, "h": 1,
                      "seats": 2, "set": "blush-parlor"},
    "armchair":      {"name": "Armchair", "icon": "\U0001fa91",
                      "cat": "furniture", "cost": 30, "cozy": 4, "w": 1, "h": 1,
                      "seats": 1, "set": "blush-parlor"},
    "bar_counter":   {"name": "Bar Counter", "icon": "\U0001f378",
                      "cat": "furniture", "cost": 120, "cozy": 6, "w": 2, "h": 1,
                      "brew_cut": 0.10, "set": "noir"},
    "bookshelf":     {"name": "Bookshelf", "icon": "\U0001f4da",
                      "cat": "furniture", "cost": 70, "cozy": 5, "w": 1, "h": 1,
                      "set": "botanical"},
    # --- plants ---
    "potted_fern":   {"name": "Potted Fern", "icon": "\U0001fab4",
                      "cat": "plants", "cost": 25, "cozy": 3, "w": 1, "h": 1,
                      "set": "teal-terrace"},
    "hanging_ivy":   {"name": "Hanging Ivy", "icon": "\U0001f33f",
                      "cat": "plants", "cost": 40, "cozy": 5, "w": 1, "h": 1,
                      "set": "teal-terrace"},
    # --- lighting ---
    "paper_lantern": {"name": "Paper Lantern", "icon": "\U0001f3ee",
                      "cat": "lighting", "cost": 35, "cozy": 4, "w": 1, "h": 1,
                      "set": "golden-hour"},
    "neon_sign":     {"name": "Neon Sign", "icon": "\U0001f4a1",
                      "cat": "lighting", "cost": 90, "cozy": 7, "w": 1, "h": 1,
                      "set": "golden-hour"},
    # --- wall art ---
    "poster":        {"name": "Poster", "icon": "\U0001f5bc\ufe0f",
                      "cat": "wall", "cost": 20, "cozy": 2, "w": 1, "h": 1,
                      "set": "festival"},
    "chalk_menu":    {"name": "Chalkboard Menu", "icon": "\U0001f4cb",
                      "cat": "wall", "cost": 45, "cozy": 3, "w": 1, "h": 1,
                      "tip_bonus": 0.05, "set": "noir"},
    # --- floor ---
    "cozy_rug":      {"name": "Cozy Rug", "icon": "\U0001f9f6",
                      "cat": "floor", "cost": 60, "cozy": 6, "w": 2, "h": 2,
                      "set": "botanical"},
    "espresso_machine": {"name": "Espresso Machine", "icon": "\u2615\ufe0f",
                      "cat": "furniture", "cost": 200, "cozy": 4, "w": 1, "h": 1,
                      "brew_cut": 0.25, "set": "noir"},
    # --- Wave 1 expansion: furniture ---
    "round-cafe-table": {"name": "Round Caf\u00e9 Table",
                      "icon": "\U0001fab5", "cat": "furniture", "cost": 45,
                      "cozy": 4, "w": 1, "h": 1, "seats": 2,
                      "set": "blush-parlor"},
    "blush-loveseat": {"name": "Blush Loveseat",
                      "icon": "\U0001f6cb\ufe0f", "cat": "furniture", "cost": 80,
                      "cozy": 7, "w": 2, "h": 1, "seats": 2,
                      "set": "blush-parlor"},
    "window-booth":  {"name": "Window Booth", "icon": "\U0001fa9f",
                      "cat": "furniture", "cost": 110, "cozy": 8, "w": 2,
                      "h": 1, "seats": 2, "set": "festival"},
    "pastry-case":   {"name": "Pastry Display Case", "icon": "\U0001f950",
                      "cat": "furniture", "cost": 95, "cozy": 5, "w": 1,
                      "h": 1, "tip_bonus": 0.05, "set": "festival"},
    "coffee-cart":   {"name": "Coffee Cart", "icon": "\U0001f6d2",
                      "cat": "furniture", "cost": 150, "cozy": 5, "w": 1,
                      "h": 1, "brew_cut": 0.05, "set": "noir"},
    "upright-piano": {"name": "Upright Piano", "icon": "\U0001f3b9",
                      "cat": "furniture", "cost": 300, "cozy": 9, "w": 2,
                      "h": 1, "tip_bonus": 0.05, "set": "festival"},
    "magazine-rack": {"name": "Magazine Rack", "icon": "\U0001f4f0",
                      "cat": "furniture", "cost": 35, "cozy": 3, "w": 1,
                      "h": 1, "set": "botanical"},
    # --- Wave 1 expansion: plants ---
    "monstera-pot":  {"name": "Monstera Pot", "icon": "\U0001fab4",
                      "cat": "plants", "cost": 45, "cozy": 5, "w": 1, "h": 1,
                      "set": "teal-terrace"},
    "succulent-trio": {"name": "Succulent Trio", "icon": "\U0001f331",
                      "cat": "plants", "cost": 20, "cozy": 2, "w": 1, "h": 1,
                      "set": "teal-terrace"},
    "flower-box":    {"name": "Flower Window Box", "icon": "\U0001f338",
                      "cat": "plants", "cost": 55, "cozy": 6, "w": 1, "h": 1,
                      "set": "teal-terrace"},
    "spiral-topiary": {"name": "Spiral Topiary", "icon": "\U0001f333",
                      "cat": "plants", "cost": 120, "cozy": 9, "w": 1, "h": 1,
                      "set": "teal-terrace"},
    # --- Wave 1 expansion: lighting ---
    "brass-pendant": {"name": "Brass Pendant Light", "icon": "\U0001f4a1",
                      "cat": "lighting", "cost": 60, "cozy": 5, "w": 1, "h": 1,
                      "set": "golden-hour"},
    "fairy-lights":  {"name": "Fairy Light Strand", "icon": "\u2728",
                      "cat": "lighting", "cost": 75, "cozy": 7, "w": 1, "h": 1,
                      "set": "golden-hour"},
    "table-candle":  {"name": "Table Candle Set", "icon": "\U0001f56f\ufe0f",
                      "cat": "lighting", "cost": 25, "cozy": 3, "w": 1, "h": 1,
                      "set": "blush-parlor"},
    # --- Wave 1 expansion: wall ---
    "gold-mirror":   {"name": "Gold-Framed Mirror", "icon": "\U0001fa9e",
                      "cat": "wall", "cost": 85, "cozy": 6, "w": 1, "h": 1,
                      "set": "golden-hour"},
    "photo-wall":    {"name": "Photo Wall Collage",
                      "icon": "\U0001f5bc\ufe0f", "cat": "wall", "cost": 50,
                      "cozy": 4, "w": 1, "h": 1, "set": "blush-parlor"},
    "menu-board":    {"name": "Illuminated Menu Board", "icon": "\U0001f4cb",
                      "cat": "wall", "cost": 70, "cozy": 4, "w": 1, "h": 1,
                      "tip_bonus": 0.05, "set": "noir"},
    "wall-sconce":   {"name": "Teal Wall Sconce", "icon": "\U0001f54e",
                      "cat": "wall", "cost": 40, "cozy": 4, "w": 1, "h": 1,
                      "set": "botanical"},
    # Arc-reward decor: locked until a story beat grants them. unlock_via is
    # the key looked up in the user's unlocked_decor list (Wave 2 grants it).
    # NOT the Stars premium pack — they stay earnable in-game.
    "brass-clock":   {"name": "Antique Brass Clock", "icon": "\U0001f570\ufe0f",
                      "cat": "wall", "cost": 0, "cozy": 8, "w": 1, "h": 1,
                      "locked": True, "unlock_via": "brass-clock",
                      "unlock_hint": "\U0001f570\ufe0f A reward from Mr. Chen's"
                                     " story arc", "set": "golden-hour"},
    "signed-edition": {"name": "Signed First Edition", "icon": "\U0001f4d6",
                      "cat": "wall", "cost": 0, "cozy": 6, "w": 1, "h": 1,
                      "locked": True, "unlock_via": "signed-edition",
                      "unlock_hint": "\U0001f4d6 A reward from Maya's story"
                                     " arc", "set": "botanical"},
    # --- Wave 1 expansion: floor ---
    "round-rug":     {"name": "Round Blush Rug", "icon": "\U0001f9f6",
                      "cat": "floor", "cost": 55, "cozy": 5, "w": 2, "h": 2,
                      "set": "blush-parlor"},
    "tile-medallion": {"name": "Tile Medallion", "icon": "\U0001f3f5\ufe0f",
                      "cat": "floor", "cost": 90, "cozy": 7, "w": 1, "h": 1,
                      "set": "golden-hour"},
    "garden-fountain": {"name": "Garden Fountain", "icon": "\u26f2",
                      "cat": "floor", "cost": 400, "cozy": 14, "w": 2, "h": 2,
                      "set": "teal-terrace"},
    # --- Wave 2: referral trophy (E.3). Unlock-only, NOT in any set, NOT
    # for sale: granted to inventory by the referral flow (both sides).
    # "trophy" blocks buy_decor; place works once unlocked_decor has it.
    "friendship-fern": {"name": "Friendship Fern", "icon": "\U0001fab4",
                      "cat": "plants", "cost": 0, "cozy": 5, "w": 1, "h": 1,
                      "locked": True, "unlock_via": "friendship-fern",
                      "unlock_hint": "\U0001f331 Earned by inviting a friend",
                      "trophy": True},
    # --- premium pack (Stars) ---
    "velvet_sofa":   {"name": "Velvet Sofa", "icon": "\U0001f6cb\ufe0f",
                      "cat": "premium", "cost": 0, "cozy": 10, "w": 2, "h": 1,
                      "seats": 2, "locked": True, "pack": "premium_decor"},
    "crystal_chandelier": {"name": "Crystal Chandelier", "icon": "\U0001f4a0",
                      "cat": "premium", "cost": 0, "cozy": 12, "w": 1, "h": 1,
                      "locked": True, "pack": "premium_decor"},
    "marble_counter": {"name": "Marble Counter", "icon": "\U0001f3db\ufe0f",
                      "cat": "premium", "cost": 0, "cozy": 9, "w": 2, "h": 1,
                      "brew_cut": 0.15, "locked": True, "pack": "premium_decor"},
    "bonsai":        {"name": "Bonsai Tree", "icon": "\U0001f332",
                      "cat": "premium", "cost": 0, "cozy": 11, "w": 1, "h": 1,
                      "locked": True, "pack": "premium_decor"},
    "jukebox":       {"name": "Vintage Jukebox", "icon": "\U0001f3b5",
                      "cat": "premium", "cost": 0, "cozy": 10, "w": 1, "h": 1,
                      "tip_bonus": 0.10, "locked": True, "pack": "premium_decor"},
}


def decor_locked(st: dict, spec: dict) -> str:
    """Buy/place gate for locked decor. Returns "" when the item is usable,
    otherwise a human-readable lock reason. Two lock kinds:

    - premium pack ("pack" key): usable only with st["decor_pack"];
    - arc rewards ("unlock_via" key): usable only once the matching key is
      in the user's unlocked_decor list (granted by story beats, Wave 2).
    """
    if not spec.get("locked"):
        return ""
    if spec.get("pack") == "premium_decor":
        return "" if st.get("decor_pack") else "item is locked (premium pack)"
    unlock = spec.get("unlock_via")
    if unlock and unlock not in st.get("unlocked_decor", []):
        return spec.get("unlock_hint") or "item is locked (story reward)"
    return ""


def grant_decor_unlock(st: dict, did: str):
    """Wave-2 story beats call this to permanently unlock an arc decor item
    (brass-clock, signed-edition)."""
    st.setdefault("unlocked_decor", [])
    if did not in st["unlocked_decor"]:
        st["unlocked_decor"].append(did)


def grant_recipe_unlock(st: dict, name: str):
    """Wave-2 story beats call this to unlock a RECIPE_LOCKS recipe
    (nightingale)."""
    st.setdefault("recipes_unlocked", [])
    if name not in st["recipes_unlocked"]:
        st["recipes_unlocked"].append(name)


# ------------------------------------------------- Wave 2: state blob
def _w2_defaults() -> dict:
    """Defaults for the Wave-2 JSON state blob (one `w2` column instead of
    a dozen new columns). Arcs: {beat, pool, progress...} per regular."""
    return {
        "level": 1, "xp": 0, "pending_levelups": [],
        "mastery": {}, "serves_total": 0,
        "arcs": {
            "maya": {"beat": 1, "pool": False, "progress": 0},
            "chen": {"beat": 0, "pool": False, "fast_chain": 0},
            "zoe": {"beat": 0, "pool": False, "serves": 0,
                    "choice_pending": False, "choice": None},
            "rafi": {"beat": 0, "pool": False, "evenings": []},
            "elena": {"arc_done": False, "comeback": False},
        },
        "modal_queue": [],
        "pending_grants": [],
        "lb_opt_in": 0, "weekly_earned": 0.0, "week": "",
        "sponsored": 0, "sponsored_until": 0.0,
        "tips_received_today": 0.0,
        "viral": None,
        "referred_by": None,
    }


def _iso_week(now: float) -> str:
    return time.strftime("%G-W%V", time.gmtime(now))


def ensure_w2(st: dict, now: float):
    """Merge stored w2 blob over defaults (forward-compat for old saves)
    and roll the weekly earnings bucket on ISO-week change."""
    w2 = st.get("w2")
    if not isinstance(w2, dict):
        w2 = {}
    dflt = _w2_defaults()
    for k, v in dflt.items():
        if k == "arcs":
            arcs = w2.setdefault("arcs", {})
            for reg, ad in v.items():
                a = arcs.setdefault(reg, {})
                for ak, av in ad.items():
                    a.setdefault(ak, av)
        else:
            w2.setdefault(k, v)
    st["w2"] = w2
    # weekly earnings bucket (leaderboard): reset on ISO-week change
    if w2.get("week") != _iso_week(now):
        w2["week"] = _iso_week(now)
        w2["weekly_earned"] = 0.0
    return w2


def earn(st: dict, amt: float):
    """Grant coins; positive amounts also count toward the weekly
    leaderboard earnings. Refunds/subtractions bypass this (not earnings)."""
    st["coins"] += amt
    if amt > 0 and isinstance(st.get("w2"), dict):
        st["w2"]["weekly_earned"] = st["w2"].get("weekly_earned", 0.0) + amt

CUSTOMER_NAMES = [
    ("Leo", "\U0001f468"), ("Aiko", "\U0001f467"),
    ("Raj", "\U0001f474"), ("Sofia", "\U0001f469\u200d\U0001f9b0"),
    ("Tom", "\U0001f468\u200d\U0001f9b1"), ("Nina", "\U0001f467\u200d\U0001f9b1"),
    ("Omar", "\U0001f473"),
]
# NOTE: "Maya" is intentionally absent — she is seeded deterministically as
# the FTUE regular (see seed_maya_if_needed), never a random walk-in.
STREAK_BONUSES = [25, 60, 120, 250, 500, 1000, 2000]  # day 1..7+

# Regulars (Wave 2 narrative arcs, PRODUCTION_PLAN §2). look = client-side
# visual descriptor consumed by the customer builder (palette + accessory
# built from cached geometries — no new draw-call-heavy meshes).
REGULARS = {
    "maya": {"name": "Maya", "avatar": "\U0001f469",
             "look": {"palette": "teal", "accessory": "bun"}},
    "chen": {"name": "Mr. Chen", "avatar": "\u231a",
             "look": {"palette": "grey-sepia", "accessory": "pocket-watch"}},
    "zoe": {"name": "Zoe", "avatar": "\U0001f933",
            "look": {"palette": "pink-gold", "accessory": "phone"}},
    "rafi": {"name": "Rafi", "avatar": "\U0001fa7a",
             "look": {"palette": "teal-scrubs", "accessory": "scrub-cap"}},
}

_db_lock = threading.Lock()
_rate = {}  # user_id -> last mutating-call timestamp


# ---------------------------------------------------------------- db
def db():
    con = sqlite3.connect(DB_PATH, check_same_thread=False)
    con.row_factory = sqlite3.Row
    return con


def init_db():
    with _db_lock, db() as con:
        con.execute(
            "CREATE TABLE IF NOT EXISTS users("
            "user_id INTEGER PRIMARY KEY, first_name TEXT, shop_name TEXT,"
            "coins REAL DEFAULT 0, rep REAL DEFAULT 3.0,"
            "day INTEGER DEFAULT 1, day_start REAL DEFAULT 0,"
            "served_today INTEGER DEFAULT 0, earned_today REAL DEFAULT 0,"
            "rep_day_start REAL DEFAULT 3.0,"
            "streak INTEGER DEFAULT 0, streak_day TEXT DEFAULT '',"
            "rooms TEXT DEFAULT '', inventory TEXT DEFAULT '{}',"
            "stock TEXT DEFAULT '{}',"
            "recipes TEXT DEFAULT '[\"espresso\"]',"
            "pending_brew TEXT DEFAULT '',"
            "customers TEXT DEFAULT '[]', next_spawn_at REAL DEFAULT 0,"
            "rush_until REAL DEFAULT 0, last_ad_at REAL DEFAULT 0,"
            "golden_machine INTEGER DEFAULT 0, adfree INTEGER DEFAULT 0,"
            "decor_pack INTEGER DEFAULT 0, last_seen REAL DEFAULT 0,"
            "created REAL DEFAULT 0, events TEXT DEFAULT '[]',"
            "ftue_step INTEGER DEFAULT 0, ftue_done INTEGER DEFAULT 0,"
            "ftue_grant_used INTEGER DEFAULT 0,"
            "w2 TEXT DEFAULT '{}')"
        )
        con.execute(
            "CREATE TABLE IF NOT EXISTS purchases("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, product TEXT,"
            "payload TEXT UNIQUE, created_at INTEGER)"
        )
        # Workstream G: client analytics events. Distinct table name on
        # purpose — the user-state JSON already has an "events" feed and the
        # two must not be confused.
        con.execute(
            "CREATE TABLE IF NOT EXISTS analytics_events("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL,"
            " ts REAL NOT NULL, event TEXT NOT NULL,"
            " props TEXT NOT NULL DEFAULT '{}')"
        )
        con.execute(
            "CREATE INDEX IF NOT EXISTS idx_analytics_events_user_ts"
            " ON analytics_events(user_id, ts)"
        )
        # Wave 2 (E.1): visit-tip ledger — 3 tips/day per visitor→host pair.
        con.execute(
            "CREATE TABLE IF NOT EXISTS visit_tips("
            "visitor INTEGER NOT NULL, host INTEGER NOT NULL, day TEXT NOT NULL,"
            " count INTEGER DEFAULT 0,"
            " PRIMARY KEY(visitor, host, day))"
        )
        # Forward migration for DBs created before the FTUE columns existed.
        for col in ("ftue_step INTEGER DEFAULT 0",
                    "ftue_done INTEGER DEFAULT 0",
                    "ftue_grant_used INTEGER DEFAULT 0",
                    "stock TEXT DEFAULT '{}'"):
            try:
                con.execute(f"ALTER TABLE users ADD COLUMN {col}")
            except sqlite3.OperationalError:
                pass  # column already present
        # Grandfather genuinely old saves out of the tutorial: anyone who has
        # already played (past day 1 or has served/earned) skips FTUE. Brand-new
        # users (day 1, nothing served) keep it.
        con.execute(
            "UPDATE users SET ftue_done=1 WHERE ftue_done=0 AND ftue_step=0"
            " AND (day>1 OR served_today>0 OR earned_today>0)")


# ------------------------------------------------- Telegram initData
def validate_init_data(init_data: str, bot_token: str):
    """Verify Telegram WebApp initData per the documented algorithm."""
    if not init_data:
        raise ValueError("empty init_data (open the game inside Telegram)")
    params = dict(urllib.parse.parse_qsl(init_data, keep_blank_values=True))
    recv_hash = params.pop("hash", None)
    if not recv_hash:
        raise ValueError("init_data has no hash field")
    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(params.items()))
    secret = hmac.new(b"WebAppData", bot_token.encode(), hashlib.sha256).digest()
    calc = hmac.new(secret, data_check_string.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(calc, recv_hash):
        raise ValueError("init_data hash mismatch")
    try:
        auth_date = int(params.get("auth_date", "0"))
    except ValueError:
        raise ValueError("bad auth_date")
    if abs(time.time() - auth_date) > INITDATA_TTL_S:
        raise ValueError("init_data expired")
    return params


# ------------------------------------------------------- Bot API stub
def tg_api(method: str, payload: dict):
    if BOT_TOKEN.startswith("TODO"):
        raise RuntimeError("BOT_TOKEN not configured — see README step 2")
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/{method}"
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        out = json.loads(r.read().decode())
    if not out.get("ok"):
        raise RuntimeError(f"Telegram API error: {out}")
    return out["result"]


# ------------------------------------------------------- game economy
def default_rooms():
    return [
        {"id": "main_hall", "name": "Main Hall", "cols": 8, "rows": 6,
         "unlocked": True, "locked_reason": "",
         # Starter layout: SPARSE by design. Coziness is the progression curve —
         # the first decorations must be *earned*, never granted. 15 cozy
         # (bar_counter 6 + wooden_table 5 + armchair 4), 3 seats: Maya + 2.
         # The FTUE grants one free wooden_table for the place-a-table beat.
         "grid": [{"decor": "bar_counter", "x": 0, "y": 0},
                  {"decor": "wooden_table", "x": 3, "y": 0},
                  {"decor": "armchair", "x": 6, "y": 0}]},
        {"id": "terrace", "name": "Sunny Terrace", "cols": 6, "rows": 4,
         "unlocked": False, "locked_reason": "Coming soon — Season 1",
         "grid": []},
        {"id": "lounge", "name": "Upstairs Lounge", "cols": 6, "rows": 4,
         "unlocked": False, "locked_reason": "Coming soon — Season 2",
         "grid": []},
    ]


def new_state(user_id: int, first_name: str, now: float) -> dict:
    st = {
        "user_id": user_id, "first_name": first_name,
        "shop_name": f"{first_name}'s Caf\u00e9",
        "coins": 150.0, "rep": 3.0,
        "day": 1, "day_start": now,
        "served_today": 0, "earned_today": 0.0, "rep_day_start": 3.0,
        "streak": 0, "streak_day": "",
        "rooms": default_rooms(), "inventory": {},
        "recipes": ["espresso"],
        "stock": {ing: 30 for ing in INGREDIENTS},
        "pending_brew": None,
        "customers": [], "next_spawn_at": now + 5.0,
        "rush_until": 0.0, "last_ad_at": 0.0,
        # Organic telegraphed rush cycle (D): next_telegraph_at fires
        # rush_telegraph; the rush itself runs telegraph_at+60 .. +240.
        "rush_sched": {"next_telegraph_at": now + RUSH_CYCLE_S,
                       "telegraphed": False, "active_until": 0.0},
        # Elena Voss mystery critic (D2): day=-1 means "not yet scheduled".
        "critic": {"day": -1, "at": 0.0, "done": False, "history": []},
        "cards": [],            # review cards earned from the critic
        "surge_until": 0.0,     # customer surge after a 4-5 star review
        # Daily quest counters (E); progress is derived from these at read.
        "tips_today": 0.0, "placed_today": 0, "discovered_today": 0,
        "golden_machine": 0, "adfree": 0, "decor_pack": 0,
        "last_seen": now, "created": now, "events": [],
        "ftue_step": 0, "ftue_done": 0, "ftue_grant_used": 0,
        # Wave 1 unlock contract: arc-reward decor keys granted by story
        # beats (Wave 2); story-locked recipe names granted by their arcs.
        "unlocked_decor": [], "recipes_unlocked": [],
        # Wave 2 blob: levels, mastery, arcs, social (see _w2_defaults).
        "w2": _w2_defaults(),
    }
    ensure_w2(st, now)  # stamps the current ISO week bucket
    ensure_quests(st)
    return st


def load_state(con, user_id: int, first_name: str, now: float) -> dict:
    # Schema migration for workstreams D (pressure) and E (quests), kept
    # here rather than init_db so old and fresh DBs converge on first load
    # — ALTER is a no-op when the column already exists. Runs before any
    # save so brand-new rows get the columns too.
    for col in ("rush_sched TEXT DEFAULT '{}'",
                "critic TEXT DEFAULT '{}'",
                "cards TEXT DEFAULT '[]'",
                "surge_until REAL DEFAULT 0",
                "quests TEXT DEFAULT '{}'",
                "tips_today REAL DEFAULT 0",
                "placed_today INTEGER DEFAULT 0",
                "discovered_today INTEGER DEFAULT 0",
                "unlocked_decor TEXT DEFAULT '[]'",
                "recipes_unlocked TEXT DEFAULT '[]'",
                "w2 TEXT DEFAULT '{}'"):
        try:
            con.execute(f"ALTER TABLE users ADD COLUMN {col}")
        except sqlite3.OperationalError:
            pass  # column already present
    row = con.execute("SELECT * FROM users WHERE user_id=?",
                      (user_id,)).fetchone()
    if row is None:
        st = new_state(user_id, first_name, now)
        save_state(con, st)
        return st
    st = dict(row)
    for k in ("rooms", "inventory", "recipes", "customers", "events"):
        st[k] = json.loads(st[k] or ("[]" if k in ("recipes", "customers", "events")
                                    else "{}"))
    st["pending_brew"] = json.loads(st["pending_brew"]) if st["pending_brew"] else None
    for k, default in (("rush_sched", {}), ("critic", {}), ("quests", {})):
        raw = st.get(k)
        if isinstance(raw, str):
            try:
                st[k] = json.loads(raw) if raw else default
            except json.JSONDecodeError:
                st[k] = default
        elif not isinstance(st[k], dict):
            st[k] = default
    raw_cards = st.get("cards")
    if isinstance(raw_cards, str):
        try:
            st["cards"] = json.loads(raw_cards) if raw_cards else []
        except json.JSONDecodeError:
            st["cards"] = []
    elif not isinstance(st["cards"], list):
        st["cards"] = []
    rs = st["rush_sched"]
    rs.setdefault("next_telegraph_at", now + RUSH_CYCLE_S)
    rs.setdefault("telegraphed", False)
    rs.setdefault("active_until", 0.0)
    cr = st["critic"]
    cr.setdefault("day", -1)
    cr.setdefault("at", 0.0)
    cr.setdefault("done", False)
    cr.setdefault("history", [])
    st.setdefault("surge_until", 0.0)
    st.setdefault("tips_today", 0.0)
    st.setdefault("placed_today", 0)
    st.setdefault("discovered_today", 0)
    ensure_quests(st)
    # Forward-compat for saves predating the ingredient-stock column: parse
    # defensively, then fill any missing ingredient with the full 30.
    raw_stock = st.get("stock")
    if isinstance(raw_stock, str):
        try:
            st["stock"] = json.loads(raw_stock) if raw_stock else {}
        except json.JSONDecodeError:
            st["stock"] = {}
    elif not isinstance(raw_stock, dict):
        st["stock"] = {}
    for ing in INGREDIENTS:
        st["stock"].setdefault(ing, 30)
    # Forward-compat for saves predating the FTUE columns.
    st.setdefault("ftue_step", 0)
    st.setdefault("ftue_done", 0)
    st.setdefault("ftue_grant_used", 0)
    # Wave 1 unlock contract: arc-reward decor keys / story-locked recipes.
    for k in ("unlocked_decor", "recipes_unlocked"):
        raw = st.get(k)
        if isinstance(raw, str):
            try:
                st[k] = json.loads(raw) if raw else []
            except json.JSONDecodeError:
                st[k] = []
        elif not isinstance(st[k], list):
            st[k] = []
    # Wave 2 blob: parse, merge defaults, roll the weekly bucket, then
    # drain any pending referral grants (both sides get the fern).
    raw_w2 = st.get("w2")
    if isinstance(raw_w2, str):
        try:
            st["w2"] = json.loads(raw_w2) if raw_w2 else {}
        except json.JSONDecodeError:
            st["w2"] = {}
    w2 = ensure_w2(st, now)
    for g in w2.get("pending_grants", []):
        if g in CATALOG:
            st["inventory"][g] = st["inventory"].get(g, 0) + 1
            grant_decor_unlock(st, g)
            push_event(st, {"type": "referral_grant", "decor": g,
                            "name": CATALOG[g]["name"]})
    w2["pending_grants"] = []
    # Forward-compat: ensure locked rooms exist even for old saves.
    ids = {r["id"] for r in st["rooms"]}
    for r in default_rooms():
        if r["id"] not in ids:
            st["rooms"].append(r)
    if st["first_name"] != first_name:
        st["first_name"] = first_name
    return st


def save_state(con, st: dict):
    con.execute(
        "INSERT INTO users(user_id, first_name, shop_name, coins, rep, day,"
        " day_start, served_today, earned_today, rep_day_start,"
        " streak, streak_day, rooms, inventory, stock, recipes, pending_brew,"
        " customers, next_spawn_at, rush_until, last_ad_at,"
        " golden_machine, adfree, decor_pack, last_seen, created, events,"
        " ftue_step, ftue_done, ftue_grant_used,"
        " rush_sched, critic, cards, surge_until, quests,"
        " tips_today, placed_today, discovered_today,"
        " unlocked_decor, recipes_unlocked, w2)"
        " VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?"
        ",?,?,?,?,?,?,?,?,?,?,?)"
        " ON CONFLICT(user_id) DO UPDATE SET"
        " first_name=excluded.first_name, shop_name=excluded.shop_name,"
        " coins=excluded.coins, rep=excluded.rep, day=excluded.day,"
        " day_start=excluded.day_start, served_today=excluded.served_today,"
        " earned_today=excluded.earned_today, rep_day_start=excluded.rep_day_start,"
        " streak=excluded.streak, streak_day=excluded.streak_day,"
        " rooms=excluded.rooms, inventory=excluded.inventory,"
        " stock=excluded.stock,"
        " recipes=excluded.recipes, pending_brew=excluded.pending_brew,"
        " customers=excluded.customers, next_spawn_at=excluded.next_spawn_at,"
        " rush_until=excluded.rush_until, last_ad_at=excluded.last_ad_at,"
        " golden_machine=excluded.golden_machine, adfree=excluded.adfree,"
        " decor_pack=excluded.decor_pack, last_seen=excluded.last_seen,"
        " events=excluded.events,"
        " ftue_step=excluded.ftue_step, ftue_done=excluded.ftue_done,"
        " ftue_grant_used=excluded.ftue_grant_used,"
        " rush_sched=excluded.rush_sched, critic=excluded.critic,"
        " cards=excluded.cards, surge_until=excluded.surge_until,"
        " quests=excluded.quests, tips_today=excluded.tips_today,"
        " placed_today=excluded.placed_today,"
        " discovered_today=excluded.discovered_today,"
        " unlocked_decor=excluded.unlocked_decor,"
        " recipes_unlocked=excluded.recipes_unlocked,"
        " w2=excluded.w2",
        (st["user_id"], st["first_name"], st["shop_name"], st["coins"], st["rep"],
         st["day"], st["day_start"], st["served_today"], st["earned_today"],
         st["rep_day_start"], st["streak"], st["streak_day"],
         json.dumps(st["rooms"]), json.dumps(st["inventory"]),
         json.dumps(st["stock"]), json.dumps(st["recipes"]),
         json.dumps(st["pending_brew"]) if st["pending_brew"] else "",
         json.dumps(st["customers"]), st["next_spawn_at"], st["rush_until"],
         st["last_ad_at"], st["golden_machine"], st["adfree"], st["decor_pack"],
         st["last_seen"], st["created"], json.dumps(st["events"][-20:]),
         st.get("ftue_step", 0), st.get("ftue_done", 0),
         st.get("ftue_grant_used", 0),
         json.dumps(st.get("rush_sched", {})),
         json.dumps(st.get("critic", {})),
         json.dumps(st.get("cards", [])),
         st.get("surge_until", 0.0),
         json.dumps(st.get("quests", {})),
         st.get("tips_today", 0.0), st.get("placed_today", 0),
         st.get("discovered_today", 0),
         json.dumps(st.get("unlocked_decor", [])),
         json.dumps(st.get("recipes_unlocked", [])),
         json.dumps(st.get("w2", {}))),
    )


def coziness(st: dict):
    """Effective coziness with duplicate-decor diminishing returns.

    Copies of the same decor id across unlocked rooms contribute 1.0x /
    0.5x / 0.25x of their catalog coziness (1st / 2nd / 3rd+ copy). Spamming
    one cheap item no longer buys linear power.

    Wave 2 (C.2): when ALL items of a set are placed, that set's placed
    items gain +15% cozy (multiplicative on their cozy contribution).
    """
    done = _completed_sets(st)
    counts = {}
    total = 0.0
    for room in st["rooms"]:
        if not room.get("unlocked"):
            continue
        for p in room["grid"]:
            spec = CATALOG.get(p["decor"])
            if not spec:
                continue
            n = counts.get(p["decor"], 0) + 1
            counts[p["decor"]] = n
            factor = 1.0 if n == 1 else (0.5 if n == 2 else 0.25)
            c = spec.get("cozy", 0) * factor
            if spec.get("set") in done:
                c *= SET_BONUS_MULT
            total += c
    return int(total) if float(total).is_integer() else round(total, 1)


def patience_mult(st: dict) -> float:
    # Soft cap: +75% patience max. Beyond ~75 effective cozy, decor is
    # expression, not power.
    return min(1.0 + coziness(st) / 100.0, 1.75)


def tip_mult(st: dict) -> float:
    # Soft cap on the coziness part: +100% max. Per-item tip_bonus stays
    # additive on top — that's the item's identity, not raw cozy.
    m = min(1.0 + coziness(st) / 80.0, 2.0)
    for room in st["rooms"]:
        if not room.get("unlocked"):
            continue
        for p in room["grid"]:
            spec = CATALOG.get(p["decor"])
            if spec:
                m += spec.get("tip_bonus", 0.0)
    return m


def brew_time(st: dict) -> float:
    t = BREW_BASE_S
    for room in st["rooms"]:
        if not room.get("unlocked"):
            continue
        for p in room["grid"]:
            spec = CATALOG.get(p["decor"])
            if spec and spec.get("brew_cut"):
                t *= (1.0 - spec["brew_cut"])
    if st["golden_machine"]:
        t *= 0.5  # Golden Espresso Machine (Stars): 2x brew speed, permanent
    return max(1.0, t)


def free_seat(st: dict):
    """Return (room_id, x, y, seat_index) of a free seat, or None."""
    occupied = {(c.get("room"), c.get("sx"), c.get("sy"), c.get("seat"))
                for c in st["customers"]}
    for room in st["rooms"]:
        if not room.get("unlocked"):
            continue
        for p in room["grid"]:
            spec = CATALOG.get(p["decor"])
            if spec and spec.get("seats", 0) > 0:
                for s in range(spec["seats"]):
                    key = (room["id"], p["x"], p["y"], s)
                    if key not in occupied:
                        return room["id"], p["x"], p["y"], s
    return None


def push_event(st: dict, ev: dict):
    st["events"].append(ev)
    st["events"] = st["events"][-20:]


# ------------------------------------------------- workstream D: rush
def _rush_tick(st: dict, now: float):
    """Organic telegraphed rush cycle. Wall-clock driven:

    next_telegraph_at      -> push rush_telegraph (60s warning)
    next_telegraph_at + 60 -> push rush_start, active for RUSH_ACTIVE_S
    end of window         -> push rush_end, schedule next telegraph
    """
    rs = st.setdefault("rush_sched", {})
    rs.setdefault("next_telegraph_at", now + RUSH_CYCLE_S)
    rs.setdefault("telegraphed", False)
    rs.setdefault("active_until", 0.0)
    # 1. active window ends
    if rs["active_until"] and now >= rs["active_until"]:
        rs["active_until"] = 0.0
        rs["telegraphed"] = False
        rs["next_telegraph_at"] = now + RUSH_CYCLE_S
        push_event(st, {"type": "rush_end"})
        return
    # 2. telegraph fires
    if (not rs["telegraphed"] and not rs["active_until"]
            and now >= rs["next_telegraph_at"]):
        rs["telegraphed"] = True
        push_event(st, {"type": "rush_telegraph"})
    # 3. telegraph lead elapses -> rush goes active
    if (rs["telegraphed"]
            and now >= rs["next_telegraph_at"] + RUSH_TELEGRAPH_LEAD_S):
        end = (rs["next_telegraph_at"] + RUSH_TELEGRAPH_LEAD_S
               + RUSH_ACTIVE_S)
        rs["telegraphed"] = False
        if end <= now:
            # Whole window was missed while the player was away: reschedule
            # silently instead of firing a zero-length rush.
            rs["next_telegraph_at"] = now + RUSH_CYCLE_S
        else:
            rs["active_until"] = end
            push_event(st, {"type": "rush_start"})


def _rush_active(st: dict, now: float) -> bool:
    """True when EITHER rush source is active: the organic telegraphed
    cycle, or the ad-rewarded rush_until window."""
    return (st["rush_until"] > now
            or st.get("rush_sched", {}).get("active_until", 0.0) > now)


def _rush_public(st: dict, now: float) -> dict:
    """Public view of the organic telegraphed rush cycle."""
    rs = st.get("rush_sched", {})
    active_until = rs.get("active_until", 0.0)
    nxt = rs.get("next_telegraph_at", 0.0)
    if active_until > now:
        return {"active": True, "telegraph_in": None,
                "ends_in": max(0, int(active_until - now))}
    if rs.get("telegraphed"):
        ends = nxt + RUSH_TELEGRAPH_LEAD_S + RUSH_ACTIVE_S
        return {"active": False, "telegraph_in": 0,
                "ends_in": max(0, int(ends - now))}
    return {"active": False,
            "telegraph_in": max(0, int(nxt - now)),
            "ends_in": 0}


# ------------------------------------------- workstream D2: the critic
def _maybe_schedule_critic(st: dict, now: float):
    """Elena Voss mystery visit: on day change, if rep >= 3.0 she is booked
    for a random moment 30-150s into the day. One visit per day max."""
    crit = st.setdefault("critic", {"day": -1, "at": 0.0, "done": False,
                                   "history": []})
    if st["day"] != crit.get("day", -1) and st["rep"] >= 3.0:
        crit["day"] = st["day"]
        crit["at"] = st["day_start"] + random.uniform(30, 150)
        crit["done"] = False


def _maybe_spawn_critic(st: dict, now: float):
    crit = st.setdefault("critic", {"day": -1, "at": 0.0, "done": False,
                                   "history": []})
    if crit.get("done") or not crit.get("at"):
        return
    if now < crit["at"] or len(st["customers"]) >= MAX_CUSTOMERS:
        return
    seat = free_seat(st)
    if seat is None:
        return  # no seat yet — she waits for a table, unpenalized
    room_id, sx, sy, seat_i = seat
    st["customers"].append({
        "cid": f"elena{int(now * 1000)}",
        "name": "Elena Voss", "avatar": "\U0001f9d0",
        # locked recipes are never ordered, even by the critic
        "order": random.choice([n for n in RECIPES if recipe_open(st, n)]),
        "deadline": now + CRITIC_PATIENCE_S,
        "room": room_id, "sx": sx, "sy": sy, "seat": seat_i,
        "is_critic": True,
        "critic_label": "Elena Voss \u00b7 Food Critic",
        "critic_patience": CRITIC_PATIENCE_S,
        "regular": "elena",
    })
    crit["done"] = True
    push_event(st, {"type": "critic_arrived", "name": "Elena Voss"})


def critic_score(st: dict, cust: dict, drink: str, now: float) -> int:
    """Elena's 1..5 review: 2 base, +1 correct drink, +1 served in under
    half her patience, +1 for a cozy caf\u00e9 (>= CRITIC_COZY_BAR)."""
    patience = cust.get("critic_patience", CRITIC_PATIENCE_S)
    elapsed = patience - max(0.0, cust["deadline"] - now)
    s = (2
         + (1 if drink == cust["order"] else 0)
         + (1 if elapsed < patience / 2.0 else 0)
         + (1 if coziness(st) >= CRITIC_COZY_BAR else 0))
    return max(1, min(5, s))


def apply_critic_score(st: dict, cust: dict, score: int, now: float):
    """Apply Elena's verdict. 4-5 stars: rep boost, a review card on the
    wall, and a customer surge. 1-2: a scathing review. 3: a shrug."""
    score = max(1, min(5, score))
    # Wave 2 comeback quest: after a scathing arc review, her next visit
    # scores double (consumed here, before the per-visit branches below).
    el = st["w2"]["arcs"]["elena"]
    if el.get("comeback"):
        score = min(5, score * 2)
        el["comeback"] = False
        push_event(st, {"type": "comeback_used", "score": score})
    if score >= 4:
        st["rep"] = min(5.0, st["rep"] + 0.3)
        st.setdefault("cards", []).append(f"elena_card_d{st['day']}")
        st["surge_until"] = now + CRITIC_SURGE_S
    elif score <= 2:
        st["rep"] = max(1.0, st["rep"] - 0.25)
    else:
        st["rep"] = min(5.0, st["rep"] + 0.05)
    crit = st.setdefault("critic", {"day": -1, "at": 0.0, "done": False,
                                   "history": []})
    crit["history"].append({"day": st["day"], "score": score})
    push_event(st, {"type": "critic_scored", "score": score,
                    "name": "Elena Voss"})
    _elena_arc_check(st, score, now)


def _elena_arc_check(st: dict, score: int, now: float):
    """Wave 2: Elena's 3-visit arc (extends the per-visit scoring above,
    which is unchanged). Evaluated once, when the 3rd scored visit lands:

    - 3/3 high (>=4): "Five Stars" — +0.5 rep, 3-day customer surge.
    - 0-1/3 high: scathing review — -0.5 rep, but a comeback quest appears:
      her NEXT visit scores double.
    - exactly 2/3: a mixed review — no arc outcome, per-visit scoring stands.
    """
    el = st["w2"]["arcs"]["elena"]
    if el.get("arc_done"):
        return
    hist = st.get("critic", {}).get("history", [])
    if len(hist) < 3:
        return
    el["arc_done"] = True
    high = sum(1 for h in hist[-3:] if h.get("score", 0) >= 4)
    if high == 3:
        st["rep"] = min(5.0, st["rep"] + 0.5)
        st["surge_until"] = max(st.get("surge_until", 0.0),
                                now + 3 * DAY_LEN_S)
        queue_modal(st, "elena_five")
        push_event(st, {"type": "elena_five_stars"})
    elif high <= 1:
        st["rep"] = max(1.0, st["rep"] - 0.5)
        el["comeback"] = True
        queue_modal(st, "elena_scathing")
        push_event(st, {"type": "elena_scathing"})
    else:
        push_event(st, {"type": "elena_mixed"})


# --------------------------------- Wave 2: C.1 café levels (30)
def add_xp(st: dict, amount: int):
    """Award XP. Level-ups grant coins = 25*level immediately, plus every
    5th level a free decor from the player's lowest-owned set. The level-up
    *modal* always goes through pending_levelups; the client renders the
    queue once ftue_done (suppressed during the FTUE) and clears it with
    the levelups_seen action."""
    w2 = st["w2"]
    w2["xp"] = w2.get("xp", 0) + amount
    gained = []
    while (w2.get("level", 1) < LEVEL_MAX
           and w2["xp"] >= level_threshold(w2["level"] + 1)):
        w2["level"] += 1
        gained.append(_grant_level_reward(st, w2["level"]))
    if gained:
        w2["pending_levelups"].extend(gained)
        w2["pending_levelups"] = w2["pending_levelups"][-10:]
    return gained


def _grant_level_reward(st: dict, level: int) -> dict:
    """Coins + (every 5th level) a free decor. Returns the reward record
    for the level-up modal."""
    coins = 25 * level
    earn(st, coins)
    decor = _pick_set_reward(st) if level % 5 == 0 else None
    if decor:
        st["inventory"][decor] = st["inventory"].get(decor, 0) + 1
        push_event(st, {"type": "level_reward", "level": level,
                        "decor": decor, "name": CATALOG[decor]["name"]})
    return {"level": level, "coins": coins, "decor": decor}


def _pick_set_reward(st: dict):
    """Free random decor from the player's lowest-owned set (server picks).
    Pool: buyable set items only — arc/premium/trophy/zero-cost excluded."""
    pool_by_set = {}
    for did, spec in CATALOG.items():
        s = spec.get("set")
        if not s or spec.get("locked") or spec.get("trophy"):
            continue
        if spec.get("cost", 0) <= 0:
            continue
        pool_by_set.setdefault(s, []).append(did)
    if not pool_by_set:
        return None
    owned = {s: 0 for s in pool_by_set}
    inv = st.get("inventory", {})
    for did, spec in CATALOG.items():
        s = spec.get("set")
        if s not in owned:
            continue
        owned[s] += inv.get(did, 0)
    for room in st["rooms"]:
        if not room.get("unlocked"):
            continue
        for p in room["grid"]:
            spec = CATALOG.get(p["decor"])
            s = spec.get("set") if spec else None
            if s in owned:
                owned[s] += 1
    low = min(owned.values())
    cands = [s for s, n in owned.items() if n == low]
    chosen = random.choice(cands)
    # prefer an item the player doesn't own yet; duplicates are the fallback
    placed = {p["decor"] for room in st["rooms"] if room.get("unlocked")
              for p in room["grid"]}
    fresh = [d for d in pool_by_set[chosen]
             if not inv.get(d, 0) and d not in placed]
    return random.choice(fresh or pool_by_set[chosen])


# --------------------------------- Wave 2: C.2 decor set bonuses
def set_progress(st: dict) -> dict:
    """Per-set completion: distinct items placed (unlocked rooms only).
    Arc-locked items count once unlocked+placed — placement itself is
    unlock-gated, so counting placed copies is exact."""
    placed = {}
    for room in st["rooms"]:
        if not room.get("unlocked"):
            continue
        for p in room["grid"]:
            spec = CATALOG.get(p["decor"])
            if not spec:
                continue
            s = spec.get("set")
            if s:
                placed.setdefault(s, set()).add(p["decor"])
    out = {}
    for s in ("blush-parlor", "teal-terrace", "golden-hour", "botanical",
              "noir", "festival"):
        items = [did for did, spec in CATALOG.items()
                 if spec.get("set") == s]
        got = placed.get(s, set())
        out[s] = {"placed": len(got), "total": len(items),
                  "complete": set(items) <= got and bool(items)}
    return out


def _completed_sets(st: dict) -> set:
    return {s for s, v in set_progress(st).items() if v["complete"]}


def _check_set_completions(st: dict, before: set):
    """Toast newly-completed sets. Call around place/move/sell."""
    for s in sorted(_completed_sets(st) - before):
        push_event(st, {"type": "set_complete", "set": s})


# --------------------------------- Wave 2: C.3 drink mastery
def mastery_stars(serves: int) -> int:
    if serves >= 50:
        return 3
    if serves >= 25:
        return 2
    if serves >= 10:
        return 1
    return 0


def mastery_mult(st: dict, drink: str) -> float:
    """Price multiplier from mastery stars: +5%/+10%/+15%. Applied to the
    base price before tip math (and before the wrong-drink half-price)."""
    return (1.0, 1.05, 1.10, 1.15)[mastery_stars(
        st["w2"]["mastery"].get(drink, 0))]


def _count_mastery(st: dict, drink: str):
    """Count a correct serve toward drink mastery; toast new stars."""
    if drink not in RECIPES:
        return
    m = st["w2"]["mastery"]
    before = mastery_stars(m.get(drink, 0))
    m[drink] = m.get(drink, 0) + 1
    after = mastery_stars(m[drink])
    if after > before:
        push_event(st, {"type": "mastery_up", "drink": drink,
                        "stars": after})


# --------------------------------- Wave 2: D. narrative arcs
def queue_modal(st: dict, kind: str, **kw):
    """Queue a story modal. The client renders the queue (in order) once
    ftue_done; triggers are suppressed until then."""
    w2 = st["w2"]
    m = {"kind": kind, **ARC_MODALS[kind], **kw}
    w2["modal_queue"].append(m)
    w2["modal_queue"] = w2["modal_queue"][-20:]


ARC_MODALS = {
    "chen_intro": {
        "emoji": "\u23f1\ufe0f", "title": "Mr. Chen has opinions",
        "text": ("A grey-suited regular sets a stopwatch on the counter. "
                 "\u201cI time everything,\u201d Mr. Chen says. \u201cFive perfect "
                 "espressos \u2014 brewed to served in under 20 seconds each "
                 "\u2014 and I'll know this place is serious.\u201d"),
        "choices": None},
    "chen_beat2": {
        "emoji": "\u23f1\ufe0f", "title": "Five perfect pours",
        "text": ("Mr. Chen clicks his stopwatch. A pause. Then, the smallest "
                 "nod. \u201cAcceptable. More than acceptable.\u201d"),
        "choices": None},
    "chen_beat3": {
        "emoji": "\U0001f570\ufe0f", "title": "The brass clock",
        "text": ("\u201cMy shop had this clock for forty years,\u201d Mr. Chen "
                 "says, pressing a wrapped parcel into your hands. \u201cIt kept "
                 "perfect time. So will you.\u201d<br><br>Reward: <b>Antique "
                 "Brass Clock</b> (+8 cozy, wall) \u2014 check your catalog! "
                 "Stand near it and listen: it ticks."),
        "choices": None},
    "zoe_photo": {
        "emoji": "\U0001f4f8", "title": "Zoe's here!",
        "text": ("\u201cThis light is UNREAL,\u201d Zoe says, already filming. "
                 "She snaps your caf\u00e9 for her 200k followers: <b>+100 coins</b>."
                 "<br><br>Tap the \U0001f4f8 button anytime to take your own "
                 "photo and share your caf\u00e9!"),
        "choices": None},
    "zoe_viral": {
        "emoji": "\U0001f680", "title": "Going viral!",
        "text": ("Zoe's post just exploded \u2014 <b>10 customers</b> are headed "
                 "your way in the next 3 minutes. Survive the crowd!"),
        "choices": None},
    "zoe_choice": {
        "emoji": "\U0001f4bc", "title": "The brand deal",
        "text": ("A coffee brand offers Zoe <b>800 coins</b> to put their poster "
                 "on your wall. Purist regulars (Maya, Mr. Chen) would grumble "
                 "\u2014 their patience drops 10% for 3 days.<br><br>Your call:"),
        "choices": ["Take the deal (+800 \U0001fa99)",
                    "Stay independent (+0.2\u2605)"]},
    "zoe_accepted": {
        "emoji": "\U0001f4e2", "title": "Sponsored!",
        "text": ("+800 coins. The poster is up \u2014 your visit card now shows "
                 "\U0001f4e2. Maya and Mr. Chen will be a little less patient "
                 "for 3 days."),
        "choices": None},
    "zoe_declined": {
        "emoji": "\u2b50", "title": "Independent",
        "text": ("+0.2\u2605 reputation. Maya catches your eye from her corner "
                 "and smiles. Some things aren't for sale."),
        "choices": None},
    "rafi_intro": {
        "emoji": "\U0001f319", "title": "Rafi, night shift",
        "text": ("A nurse in teal scrubs collapses into a chair. \u201cLong "
                 "shift,\u201d he manages. \u201cMocha. Please.\u201d<br><br>"
                 "Serve him well on <b>3 evenings</b> and he might open up. "
                 "(Rafi only visits once the evening crowd unlocks at 4\u2605.)"),
        "choices": None},
    "rafi_beat2": {
        "emoji": "\U0001f319", "title": "The Nightingale",
        "text": ("\u201cYou know what this shift needs?\u201d Rafi says, and "
                 "describes it: mocha, but warmer \u2014 caramel in the dark. "
                 "You brew it together.<br><br>NEW RECIPE: <b>The Nightingale</b> "
                 "\U0001f319 \u2014 he'll be ordering it from now on."),
        "choices": None},
    "rafi_ward": {
        "emoji": "\U0001f3e5", "title": "The whole ward!",
        "text": ("Rafi's team piles in after shift \u2014 <b>5 at once</b>, all "
                 "craving mocha or the Nightingale. Don't keep nurses waiting!"),
        "choices": None},
    "maya_beat2": {
        "emoji": "\U0001f4d6", "title": "A plot twist in a cup",
        "text": ("\u201cYou actually made it,\u201d Maya whispers, tasting the "
                 "mint mocha. \u201cChocolate, espresso, mint \u2014 that's exactly "
                 "how a plot twist tastes.\u201d She opens her notebook. "
                 "Something's happening."),
        "choices": None},
    "maya_beat3": {
        "emoji": "\U0001f4da", "title": "Published!",
        "text": ("Maya slides a book across the counter \u2014 the dedication "
                 "page names YOUR caf\u00e9. \u201cCouldn't have finished it "
                 "anywhere else.\u201d<br><br>Reward: <b>Signed First Edition</b> "
                 "(+6 cozy, wall) \u2014 check your catalog!"),
        "choices": None},
    "elena_five": {
        "emoji": "\u2b50", "title": "FIVE STARS",
        "text": ("Elena Voss's review is front-page: three standout visits. "
                 "<b>+0.5\u2605 reputation</b>, and a customer surge for 3 days. "
                 "Your caf\u00e9 is officially a destination."),
        "choices": None},
    "elena_scathing": {
        "emoji": "\U0001f4f0", "title": "Scathing review",
        "text": ("Elena's review stings: <b>\u22120.5\u2605</b>. But the last line "
                 "is a dare: \u201cI'll be back. Impress me.\u201d<br><br>"
                 "COMEBACK QUEST: her next visit scores <b>DOUBLE</b>."),
        "choices": None},
}


def _arc_entry_ok(st: dict, reg: str) -> bool:
    """Beat-1 trigger conditions: regulars enter the walk-in pool only once
    these are met, so arcs feel earned. Maya stays FTUE-seeded."""
    if not st.get("ftue_done"):
        return False
    w2 = st["w2"]
    if reg == "maya":
        return True
    if reg == "chen":
        return w2.get("serves_total", 0) >= 10
    if reg == "zoe":
        return coziness(st) >= 40
    if reg == "rafi":
        return st["rep"] >= EVENING_REP  # evening = the 4★ crowd (Phase A)
    return False


def _arc_tick(st: dict, now: float):
    """Checked on serve/day rollover (runs inside advance): pool entries +
    Maya beat 2 (mint mocha known + Maya seated)."""
    if not st.get("ftue_done"):
        return
    w2 = st["w2"]
    for reg in ("maya", "chen", "zoe", "rafi"):
        arc = w2["arcs"][reg]
        if not arc["pool"] and _arc_entry_ok(st, reg):
            arc["pool"] = True
            push_event(st, {"type": "regular_unlocked",
                            "regular": reg,
                            "name": REGULARS[reg]["name"]})
    marc = w2["arcs"]["maya"]
    if (marc["beat"] == 1 and "mint_mocha" in st["recipes"]
            and any(c.get("regular") == "maya" for c in st["customers"])):
        marc["beat"] = 2
        queue_modal(st, "maya_beat2")


def _regular_order(st: dict, reg: str) -> str:
    """Signature orders; Maya/Rafi evolve with their arcs."""
    w2 = st["w2"]
    if reg == "maya":
        if (w2["arcs"]["maya"]["beat"] >= 2
                and "mint_mocha" in st["recipes"]):
            return "mint_mocha"
        return "latte"
    if reg == "chen":
        return "espresso"
    if reg == "zoe":
        return "iced_latte"
    if reg == "rafi":
        return ("nightingale"
                if "nightingale" in st["recipes_unlocked"] else "mocha")
    return "espresso"


def _regular_beat1(st: dict, reg: str, now: float):
    """First-spawn beat-1 effects (pool entry itself is silent)."""
    if reg == "chen":
        queue_modal(st, "chen_intro")
    elif reg == "zoe":
        earn(st, 100)
        queue_modal(st, "zoe_photo")
        push_event(st, {"type": "zoe_photo", "coins": 100})
    elif reg == "rafi":
        queue_modal(st, "rafi_intro")
    # Maya's beat 1 is the FTUE itself — no extra modal.


def _sponsored_active(st: dict, now: float) -> bool:
    w2 = st["w2"]
    return bool(w2.get("sponsored")) and w2.get("sponsored_until", 0.0) > now


def _apply_sponsor(st: dict, cust: dict, now: float):
    """Zoe's brand deal: purist regulars' patience −10% for 3 days."""
    if (_sponsored_active(st, now)
            and cust.get("regular") in PURIST_REGULARS):
        cust["deadline"] = now + (cust["deadline"] - now) * 0.9


def _maybe_regular_spawn(st: dict, now: float):
    """30% of spawn ticks pick an eligible regular over a walk-in.
    Rafi is evening-only (rep >= 4★, the Phase-A evening crowd)."""
    w2 = st["w2"]
    if not st.get("ftue_done"):
        return None
    seated = {c.get("regular") for c in st["customers"]}
    pool = [r for r in ("maya", "chen", "zoe", "rafi")
            if w2["arcs"][r]["pool"] and r not in seated]
    pool = [r for r in pool
            if r != "rafi" or st["rep"] >= EVENING_REP]
    if not pool or random.random() >= REGULAR_SPAWN_P:
        return None
    reg = random.choice(pool)
    seat = free_seat(st)
    if seat is None:
        return None
    room_id, sx, sy, seat_i = seat
    spec = REGULARS[reg]
    cust = {
        "cid": f"r{reg}{int(now * 1000)}{random.randrange(100)}",
        "name": spec["name"], "avatar": spec["avatar"],
        "order": _regular_order(st, reg),
        "deadline": now + PATIENCE_BASE_S * patience_mult(st),
        "room": room_id, "sx": sx, "sy": sy, "seat": seat_i,
        "regular": reg,
    }
    _apply_sponsor(st, cust, now)
    arc = w2["arcs"][reg]
    if arc["beat"] == 0:
        arc["beat"] = 1
        _regular_beat1(st, reg, now)
    return cust


def _spawn_with_order(st: dict, now: float, order: str):
    """Forced-order walk-in (Rafi's ward rush)."""
    seat = free_seat(st)
    if seat is None:
        st["rep"] = max(1.0, st["rep"] - REP_DOWN_NOSEAT)
        push_event(st, {"type": "no_seat", "name": "ward nurse",
                        "avatar": "\U0001f3e5"})
        return
    room_id, sx, sy, seat_i = seat
    name, avatar = random.choice(CUSTOMER_NAMES)
    st["customers"].append({
        "cid": f"w{int(now*1000)}{random.randrange(1000)}",
        "name": name, "avatar": avatar, "order": order,
        "deadline": now + PATIENCE_BASE_S * patience_mult(st),
        "room": room_id, "sx": sx, "sy": sy, "seat": seat_i,
    })


def _viral_tick(st: dict, now: float):
    """Zoe's viral crowd (10 in 3 min) / Rafi's ward rush (5 at once):
    scheduled spawn waves. Full tables defer (retry next tick), never drop."""
    v = st["w2"].get("viral")
    if not v:
        return
    times = v.get("spawn_times", [])
    orders = v.get("orders")
    while times and times[0] <= now:
        if len(st["customers"]) >= MAX_CUSTOMERS:
            break
        times.pop(0)
        if orders:
            _spawn_with_order(st, now, random.choice(orders))
        else:
            spawn_customer(st, now)
    if not times:
        st["w2"]["viral"] = None


def _serve_arcs(st: dict, cust: dict, drink: str, brew_ready_at: float,
                now: float):
    """Wave 2 per-serve arc triggers. Called for every serve outcome
    (sludge resets Chen's chain like any other non-fast serve)."""
    w2 = st["w2"]
    reg = cust.get("regular", "")
    correct = drink == cust["order"] and drink != "sludge"
    # --- Chen: 5 consecutive fast espressos (brew-ready -> serve < 20s) ---
    carc = w2["arcs"]["chen"]
    if carc["pool"] and 1 <= carc["beat"] < 3:
        # a *correct* fast espresso extends the chain; any other serve
        # (wrong drink, sludge, slow) resets it
        fast = (correct and drink == "espresso"
                and (now - brew_ready_at) < CHEN_FAST_S)
        if fast:
            carc["fast_chain"] = carc.get("fast_chain", 0) + 1
            if carc["fast_chain"] >= 5 and carc["beat"] == 1:
                carc["beat"] = 2
                queue_modal(st, "chen_beat2")
                push_event(st, {"type": "chen_beat2"})
        else:
            carc["fast_chain"] = 0
    # --- Chen beat 3: an espresso served TO Chen after beat 2 ---
    if reg == "chen" and carc["beat"] == 2 and correct and drink == "espresso":
        carc["beat"] = 3
        grant_decor_unlock(st, "brass-clock")
        queue_modal(st, "chen_beat3")
        push_event(st, {"type": "arc_reward", "regular": "chen",
                        "decor": "brass-clock"})
    # --- Maya beat 3: 5 serves after the mint-mocha beat ---
    marc = w2["arcs"]["maya"]
    if reg == "maya" and correct and marc["beat"] == 2:
        marc["progress"] = marc.get("progress", 0) + 1
        if marc["progress"] >= MAYA_SERVES_FOR_BOOK:
            marc["beat"] = 3
            grant_decor_unlock(st, "signed-edition")
            queue_modal(st, "maya_beat3")
            push_event(st, {"type": "arc_reward", "regular": "maya",
                            "decor": "signed-edition"})
    # --- Zoe: viral crowd, then the brand-deal choice ---
    zarc = w2["arcs"]["zoe"]
    if reg == "zoe" and correct:
        if zarc["beat"] == 1:
            zarc["serves"] = zarc.get("serves", 0) + 1
            if zarc["serves"] >= ZOE_SERVES_FOR_VIRAL:
                zarc["beat"] = 2
                w2["viral"] = {
                    "spawn_times": [now + i * 18.0 for i in range(1, 11)],
                    "kind": "zoe"}
                queue_modal(st, "zoe_viral")
                push_event(st, {"type": "viral_start", "regular": "zoe"})
        elif zarc["beat"] == 2 and not zarc.get("choice_pending"):
            zarc["choice_pending"] = True
            queue_modal(st, "zoe_choice")
    # --- Rafi: 3 evenings -> the Nightingale; nightingale serve -> ward ---
    rarc = w2["arcs"]["rafi"]
    if reg == "rafi" and correct:
        if rarc["beat"] == 1:
            evs = rarc.get("evenings", [])
            if st["day"] not in evs:
                evs.append(st["day"])
                rarc["evenings"] = evs
            if len(evs) >= RAFI_EVENINGS:
                rarc["beat"] = 2
                grant_recipe_unlock(st, "nightingale")
                queue_modal(st, "rafi_beat2")
                push_event(st, {"type": "arc_reward", "regular": "rafi",
                                "recipe": "nightingale"})
        elif rarc["beat"] == 2 and drink == "nightingale":
            rarc["beat"] = 3
            w2["viral"] = {
                "spawn_times": [now + 2 + i * 5.0 for i in range(5)],
                "kind": "rafi", "orders": ["mocha", "nightingale"]}
            queue_modal(st, "rafi_ward")
            push_event(st, {"type": "viral_start", "regular": "rafi"})


def _apply_arc_choice(st: dict, regular: str, choice: str, now: float):
    """Zoe's brand-deal 2-option choice. Real consequences, server-enforced:
    accept = +800 coins + sponsored poster (visit card 📢) + purist regulars'
    patience −10% for 3 days; decline = +0.2★ rep."""
    zarc = st["w2"]["arcs"]["zoe"]
    if regular != "zoe" or zarc["beat"] != 2 or not zarc.get("choice_pending"):
        return {"ok": False, "error": "no pending choice"}
    if choice not in ("accept", "decline"):
        return {"ok": False, "error": "choice must be accept/decline"}
    zarc["choice_pending"] = False
    zarc["choice"] = choice
    zarc["beat"] = 3
    # the choice modal is consumed; the follow-up modal queues normally
    st["w2"]["modal_queue"] = [m for m in st["w2"]["modal_queue"]
                               if m.get("kind") != "zoe_choice"]
    if choice == "accept":
        earn(st, 800)
        st["w2"]["sponsored"] = 1
        st["w2"]["sponsored_until"] = now + SPONSOR_DAYS * DAY_LEN_S
        queue_modal(st, "zoe_accepted")
        push_event(st, {"type": "sponsored_on"})
        return {"ok": True, "choice": "accept", "coins": 800}
    st["rep"] = min(5.0, st["rep"] + 0.2)
    queue_modal(st, "zoe_declined")
    push_event(st, {"type": "zoe_declined"})
    return {"ok": True, "choice": "decline", "rep": round(st["rep"], 2)}


# ------------------------------------------------ workstream E: quests
def ensure_quests(st: dict):
    """Assign 3 of the 6 quest defs per in-game day, deterministic per day
    (seeded by the day number) so re-loads agree."""
    q = st.setdefault("quests", {"day": -1, "list": []})
    if q.get("day") != st["day"]:
        picked = random.Random(st["day"]).sample(QUEST_DEFS, 3)
        q["day"] = st["day"]
        q["list"] = [{"id": d["id"], "desc": d["desc"], "target": d["target"],
                      "reward": d["reward"], "progress": 0, "claimed": False}
                     for d in picked]


def quest_progress(st: dict, q: dict):
    """Live progress for a quest, derived from today's counters."""
    qid = q["id"]
    if qid == "serve_8":
        return st.get("served_today", 0)
    if qid == "tips_60":
        return round(st.get("tips_today", 0.0), 1)
    if qid == "place_3":
        return st.get("placed_today", 0)
    if qid == "discover_1":
        return st.get("discovered_today", 0)
    if qid == "rep_35":
        return int(st.get("rep", 0.0) * 10)
    if qid == "earn_300":
        return round(st.get("earned_today", 0.0), 1)
    return 0


def spawn_customer(st: dict, now: float):
    seat = free_seat(st)
    name, avatar = random.choice(CUSTOMER_NAMES)
    if seat is None:
        # No table, no seating: the customer leaves angry.
        st["rep"] = max(1.0, st["rep"] - REP_DOWN_NOSEAT)
        push_event(st, {"type": "no_seat", "name": name, "avatar": avatar})
        return
    room_id, sx, sy, seat_i = seat
    # 70% order a learned recipe (fair), 30% anything (drives discovery).
    # Locked recipes never appear in the order pool.
    open_recipes = [n for n in RECIPES if recipe_open(st, n)]
    learned_open = [n for n in st["recipes"] if n in open_recipes]
    pool = learned_open if random.random() < 0.7 else open_recipes
    order = random.choice(pool)
    st["customers"].append({
        "cid": f"c{int(now*1000)}{random.randrange(1000)}",
        "name": name, "avatar": avatar, "order": order,
        "deadline": now + PATIENCE_BASE_S * patience_mult(st),
        "room": room_id, "sx": sx, "sy": sy, "seat": seat_i,
    })


def seed_maya_if_needed(st: dict, now: float):
    """Maya the novelist is every new player's first customer, pre-seated.

    Seeded (and re-seeded if she somehow leaves) while the FTUE is active.
    Her long patience means she never walks out mid-tutorial."""
    if st.get("ftue_done") or st.get("ftue_step", 0) >= 2:
        return
    for c in st["customers"]:
        if c.get("regular") == "maya":
            return
    seat = free_seat(st)
    if seat is None:
        return
    room_id, sx, sy, seat_i = seat
    st["customers"].append({
        "cid": f"maya{int(now * 1000)}",
        "name": "Maya", "avatar": "\U0001f469",
        "order": "espresso",
        "deadline": now + MAYA_PATIENCE_S,
        "room": room_id, "sx": sx, "sy": sy, "seat": seat_i,
        "regular": "maya",
    })


def advance(st: dict, now: float):
    """Server-side simulation: rush cycle, critic, spawn customers, expire
    patience. Returns events."""
    _rush_tick(st, now)
    _maybe_schedule_critic(st, now)
    _maybe_spawn_critic(st, now)
    _arc_tick(st, now)   # Wave 2: regular pool entries + Maya beat 2
    _viral_tick(st, now)  # Wave 2: Zoe viral crowd / Rafi ward rush waves
    # spawn schedule
    interval = BASE_SPAWN_S / (0.5 + st["rep"] / 5.0)
    if _rush_active(st, now):
        interval /= 2.0  # organic rush OR ad rush — either halves spawns
    if st.get("surge_until", 0.0) > now:
        interval *= 0.75  # post-review customer surge
    if st["rep"] >= EVENING_REP:
        interval *= 0.8  # the evening crowd
    while st["next_spawn_at"] <= now and len(st["customers"]) < MAX_CUSTOMERS:
        reg_cust = _maybe_regular_spawn(st, now)
        if reg_cust is not None:
            st["customers"].append(reg_cust)
        else:
            spawn_customer(st, now)
        st["next_spawn_at"] += interval * random.uniform(0.8, 1.2)
    if st["next_spawn_at"] <= now:
        st["next_spawn_at"] = now + interval
    # patience timeouts
    kept = []
    for c in st["customers"]:
        if c["deadline"] <= now:
            if c.get("is_critic"):
                # Elena walks out: an automatic 1-star review, not the
                # generic walkout penalty.
                apply_critic_score(st, c, 1, now)
            else:
                st["rep"] = max(1.0, st["rep"] - REP_DOWN_WALKOUT)
            push_event(st, {"type": "walkout", "name": c["name"],
                            "avatar": c["avatar"], "order": c["order"]})
        else:
            kept.append(c)
    st["customers"] = kept
    st["last_seen"] = now


def _refill_stock(st: dict):
    """Every ingredient back to full. Called on day rollover and paid restock."""
    st["stock"] = {ing: 30 for ing in INGREDIENTS}


def rollover_day(st: dict, now: float):
    """End-of-day summary + reset. Returns summary dict or None."""
    if now - st["day_start"] < DAY_LEN_S:
        return None
    summary = {
        "day": st["day"], "served": st["served_today"],
        "earned": round(st["earned_today"], 1),
        "rep_start": round(st["rep_day_start"], 2),
        "rep_end": round(st["rep"], 2),
        # Wave 2 (E.1): visit tips received today, e.g. "Maya tipped you 30"
        "tips_received": round(st["w2"].get("tips_received_today", 0.0), 1),
    }
    st["day"] += 1
    st["day_start"] = now
    st["served_today"] = 0
    st["earned_today"] = 0.0
    st["rep_day_start"] = st["rep"]
    _refill_stock(st)
    # Daily quest counters reset with the day; a fresh trio is dealt.
    st["tips_today"] = 0.0
    st["placed_today"] = 0
    st["discovered_today"] = 0
    st["w2"]["tips_received_today"] = 0.0
    ensure_quests(st)
    return summary


def apply_checkin(st: dict, now: float):
    today = time.strftime("%Y-%m-%d", time.gmtime(now))
    if st["streak_day"] == today:
        return 0.0, False
    yesterday = time.strftime("%Y-%m-%d", time.gmtime(now - 86400))
    st["streak"] = st["streak"] + 1 if st["streak_day"] == yesterday else 1
    st["streak_day"] = today
    bonus = float(STREAK_BONUSES[min(st["streak"] - 1, len(STREAK_BONUSES) - 1)])
    earn(st, bonus)  # Wave 2: check-in counts toward weekly earnings
    return bonus, True


def public_state(st: dict, now: float, day_summary=None) -> dict:
    cozy = coziness(st)
    customers = []
    for c in st["customers"]:
        r = RECIPES[c["order"]]
        pmax = c.get("critic_patience") or PATIENCE_BASE_S * patience_mult(st)
        reg = c.get("regular", "")
        customers.append({
            "cid": c["cid"], "name": c["name"], "avatar": c["avatar"],
            "order": c["order"], "order_icon": r["icon"],
            "order_name": c["order"].replace("_", " ").title(),
            "patience_left": max(0, int(c["deadline"] - now)),
            "patience_max": int(pmax),
            "room": c["room"], "sx": c["sx"], "sy": c["sy"],
            "regular": reg,
            # Wave 2: regular visual descriptor for the 3D customer builder
            "look": (REGULARS.get(reg) or {}).get("look"),
            "is_critic": bool(c.get("is_critic")),
            "critic_label": c.get("critic_label", ""),
        })
    catalog = []
    for did, spec in CATALOG.items():
        catalog.append({"id": did, **spec, "locked": bool(decor_locked(st, spec)),
                        "owned_unplaced": st["inventory"].get(did, 0)})
    recipes = []
    for name, r in RECIPES.items():
        # Wave 2 (C.3): mastery stars + serve counts in the recipe book.
        mstars = mastery_stars(st["w2"]["mastery"].get(name, 0))
        mserves = st["w2"]["mastery"].get(name, 0)
        # Story-locked recipes show as a teaser with no combo/price leak
        # until the arc unlocks them (Wave 2).
        if name in RECIPE_LOCKS and name not in st["recipes_unlocked"]:
            recipes.append({"name": name, "icon": "\U0001f512", "price": None,
                            "learned": False, "locked": True, "combo": [],
                            "display": NIGHTINGALE_HINT,
                            "mastery": 0, "serves": 0})
            continue
        recipes.append({"name": name, "icon": r["icon"], "price": r["price"],
                        "learned": name in st["recipes"], "locked": False,
                        "combo": list(r["combo"])
                        if name in st["recipes"] else [],
                        "mastery": mstars, "serves": mserves})
    out = {
        "ok": True, "now": now,
        "shop_name": st["shop_name"], "first_name": st["first_name"],
        "coins": round(st["coins"], 1),
        "rep": round(st["rep"], 2),
        "rep_stars": round(st["rep"], 1),
        "coziness": cozy,
        "patience_mult": round(patience_mult(st), 2),
        "tip_mult": round(tip_mult(st), 2),
        "brew_time": round(brew_time(st), 1),
        "day": st["day"], "day_left": max(0, int(st["day_start"] + DAY_LEN_S - now)),
        "rooms": st["rooms"],
        "catalog": catalog,
        "recipes": recipes,
        "locked_recipes": LOCKED_RECIPES,
        "ingredients": [{"id": i, "icon": ING_ICON[i]} for i in INGREDIENTS],
        "stock": st["stock"],
        "customers": customers,
        "pending_brew": st["pending_brew"],
        "rush_active": st["rush_until"] > now,
        "rush_left": max(0, int(st["rush_until"] - now)),
        "rush": _rush_public(st, now),
        "surge_active": st.get("surge_until", 0.0) > now,
        "cards": st.get("cards", []),
        "quests": [
            {"id": q["id"], "desc": q["desc"], "target": q["target"],
             "reward": q["reward"], "claimed": q["claimed"],
             "progress": quest_progress(st, q),
             "done": quest_progress(st, q) >= q["target"]}
            for q in st.get("quests", {}).get("list", [])
        ],
        "evening_unlocked": st["rep"] >= EVENING_REP,
        "streak": st["streak"],
        "expansion": {"available": True,
                      "cost": EXPANSION_COST,
                      "done": any(r["id"] == "main_hall" and r["cols"] >= 10
                                  for r in st["rooms"])},
        "stars_owned": {"golden_machine": bool(st["golden_machine"]),
                        "decor_pack": bool(st["decor_pack"]),
                        "adfree": bool(st["adfree"])},
        "events": st["events"],
        "share_base": f"https://t.me/{BOT_USERNAME}?startapp=visit_",
        "shop_id": st["user_id"],
        "ftue_step": st.get("ftue_step", 0),
        "ftue_done": bool(st.get("ftue_done", 0)),
        # ---- Wave 2: progression ----------------------------------
        "level": st["w2"]["level"], "xp": st["w2"]["xp"],
        "xp_next": (level_threshold(st["w2"]["level"] + 1)
                    if st["w2"]["level"] < LEVEL_MAX else None),
        # level-up modals, queued while the FTUE is active
        "levelups": (st["w2"]["pending_levelups"]
                     if st.get("ftue_done") else []),
        "set_progress": set_progress(st),
        # ---- Wave 2: narrative arcs --------------------------------
        "arcs": {
            reg: {"beat": a["beat"], "pool": a["pool"],
                  "progress": _arc_progress(st, reg)}
            for reg, a in st["w2"]["arcs"].items() if reg != "elena"},
        "elena_arc": {"arc_done": st["w2"]["arcs"]["elena"]["arc_done"],
                      "comeback": st["w2"]["arcs"]["elena"]["comeback"]},
        # guided-discovery hint chip for Maya's beat 2
        "maya_hint": bool(st.get("ftue_done"))
        and st["w2"]["arcs"]["maya"]["beat"] == 1
        and "mint_mocha" not in st["recipes"],
        # story modals, suppressed until the FTUE completes
        "arc_modals": (st["w2"]["modal_queue"]
                       if st.get("ftue_done") else []),
        # ---- Wave 2: social ----------------------------------------
        "sponsored": bool(st["w2"].get("sponsored")),
        "lb_opt_in": bool(st["w2"].get("lb_opt_in")),
        "weekly_earned": round(st["w2"].get("weekly_earned", 0.0), 1),
    }
    if day_summary is not None:
        out["day_summary"] = day_summary
    return out


def _arc_progress(st: dict, reg: str) -> str:
    """Human-readable arc progress for the client regulars strip."""
    a = st["w2"]["arcs"][reg]
    if not a["pool"]:
        return "not met yet"
    if reg == "maya":
        if a["beat"] == 1:
            return "discover her plot-twist drink"
        if a["beat"] == 2:
            return f"{a.get('progress', 0)}/{MAYA_SERVES_FOR_BOOK} serves"
        return "arc complete \u2728"
    if reg == "chen":
        if a["beat"] == 1:
            return f"fast chain {a.get('fast_chain', 0)}/5"
        if a["beat"] == 2:
            return "serve him an espresso"
        return "arc complete \u2728"
    if reg == "zoe":
        if a["beat"] == 1:
            return f"{a.get('serves', 0)}/{ZOE_SERVES_FOR_VIRAL} serves"
        if a["beat"] == 2:
            return ("brand deal pending" if a.get("choice_pending")
                    else "serve her again")
        return "arc complete \u2728"
    if reg == "rafi":
        if a["beat"] == 1:
            return f"{len(a.get('evenings', []))}/{RAFI_EVENINGS} evenings"
        if a["beat"] == 2:
            return "serve him the Nightingale"
        return "arc complete \u2728"
    return ""


# ------------------------------------------------------------- http
class Handler(BaseHTTPRequestHandler):
    server_version = "CafeBuilder/0.1"

    def log_message(self, fmt, *args):
        print(f"[{time.strftime('%H:%M:%S')}] {self.command} {self.path} ->", *args)

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        try:
            n = int(self.headers.get("Content-Length", 0))
        except ValueError:
            n = 0
        raw = self.rfile.read(n) if n else b"{}"
        try:
            return json.loads(raw.decode() or "{}")
        except (json.JSONDecodeError, UnicodeDecodeError):
            return None

    def _serve_file(self, name, ctype):
        path = os.path.join(BASE_DIR, name)
        if not os.path.isfile(path):
            self._json(404, {"ok": False, "error": "not found"})
            return
        with open(path, "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def _auth(self, init_data):
        # Local dev: with no bot token configured, empty init_data is accepted
        # as a fixed local player (same rules, local DB). With a real token
        # configured this path is dead — valid initData is always required.
        if not init_data and BOT_TOKEN.startswith("TODO"):
            return DEV_USER_ID, "Barista"
        try:
            params = validate_init_data(init_data, BOT_TOKEN)
        except ValueError as e:
            self._json(401, {"ok": False, "error": str(e)})
            return None
        try:
            user = json.loads(params.get("user", "{}"))
            return int(user["id"]), str(user.get("first_name", "barista"))[:64]
        except (KeyError, ValueError, TypeError):
            self._json(400, {"ok": False, "error": "bad user in init_data"})
            return None

    def _rate_ok(self, user_id):
        now = time.time()
        if now - _rate.get(user_id, 0) < RATE_LIMIT_S:
            self._json(429, {"ok": False, "error": "rate limited, slow down"})
            return None
        _rate[user_id] = now
        return now

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            self._serve_file("index.html", "text/html; charset=utf-8")
        elif parsed.path.startswith("/vendor/"):
            # vendored three.js (no CDN runtime dependency); traversal-guarded
            name = parsed.path.lstrip("/")
            p = os.path.normpath(os.path.join(BASE_DIR, name))
            if not p.startswith(os.path.join(BASE_DIR, "vendor") + os.sep):
                self._json(403, {"ok": False, "error": "forbidden"})
                return
            ctype = ("text/javascript; charset=utf-8" if p.endswith(".js")
                     else "application/octet-stream")
            self._serve_file(name, ctype)
        elif parsed.path == "/healthz":
            self._json(200, {"ok": True})
        elif parsed.path == "/api/state":
            qs = urllib.parse.parse_qs(parsed.query)
            self._handle_state((qs.get("init_data") or [""])[0],
                               (qs.get("ref") or [""])[0])
        elif parsed.path == "/api/leaderboard":
            qs = urllib.parse.parse_qs(parsed.query)
            self._handle_leaderboard((qs.get("init_data") or [""])[0])
        elif parsed.path == "/api/visit":
            qs = urllib.parse.parse_qs(parsed.query)
            self._handle_visit((qs.get("shop") or [""])[0])
        elif parsed.path == "/api/catalog":
            # Public static game data (single source of truth for the client;
            # used by read-only visit mode which has no auth).
            self._json(200, {"ok": True, "catalog": CATALOG})
        else:
            self._json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        body = self._read_json()
        if body is None:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        routes = {
            "/api/sync": self._handle_sync,
            "/api/ad/reward": self._handle_ad_reward,
            "/api/analytics": self._handle_analytics,
            "/api/stars/invoice": self._handle_invoice,
            "/api/webhook": self._handle_webhook,
            "/api/visit/tip": self._handle_visit_tip,
        }
        h = routes.get(parsed.path)
        if h:
            h(body)
        else:
            self._json(404, {"ok": False, "error": "not found"})

    # -- /api/state -------------------------------------------------
    def _handle_state(self, init_data, ref=""):
        auth = self._auth(init_data)
        if not auth:
            return
        user_id, first_name = auth
        now = time.time()
        with _db_lock, db() as con:
            is_new = (con.execute("SELECT 1 FROM users WHERE user_id=?",
                                  (user_id,)).fetchone() is None)
            st = load_state(con, user_id, first_name, now)
            # Wave 2 (E.3): referral — a NEW user arriving with ?ref=<shop>
            # grants the Friendship Fern to BOTH sides. The referrer may be
            # offline: their copy waits in pending_grants, drained on their
            # next state load.
            if is_new and ref and not st["w2"].get("referred_by"):
                try:
                    ref_id = int(ref)
                except (ValueError, TypeError):
                    ref_id = 0
                if ref_id and ref_id != user_id:
                    rrow = con.execute(
                        "SELECT w2 FROM users WHERE user_id=?",
                        (ref_id,)).fetchone()
                    if rrow is not None:
                        st["w2"]["referred_by"] = ref_id
                        st["inventory"]["friendship-fern"] = \
                            st["inventory"].get("friendship-fern", 0) + 1
                        grant_decor_unlock(st, "friendship-fern")
                        push_event(st, {"type": "referral_fern"})
                        try:
                            rw2 = json.loads(rrow["w2"]) if rrow["w2"] else {}
                        except (json.JSONDecodeError, TypeError):
                            rw2 = {}
                        pg = rw2.setdefault("pending_grants", [])
                        if "friendship-fern" not in pg:
                            pg.append("friendship-fern")
                        con.execute("UPDATE users SET w2=? WHERE user_id=?",
                                    (json.dumps(rw2), ref_id))
            advance(st, now)
            seed_maya_if_needed(st, now)
            summary = rollover_day(st, now)
            bonus, fresh = apply_checkin(st, now)
            save_state(con, st)
        out = public_state(st, now, day_summary=summary)
        out["checkin"] = {"bonus": bonus, "fresh": fresh, "streak": st["streak"]}
        self._json(200, out)

    # -- /api/visit/tip (Wave 2, E.1) ---------------------------------
    def _handle_visit_tip(self, body):
        """Tip a friend's café 10 of your own coins. Capped at 3/day per
        visitor→host pair (anti-farm); self-tips rejected. The host sees it
        in their day summary."""
        auth = self._auth(body.get("init_data", ""))
        if not auth:
            return
        user_id, first_name = auth
        now = self._rate_ok(user_id)
        if now is None:
            return
        try:
            shop_id = int(body.get("shop_id"))
        except (TypeError, ValueError):
            self._json(400, {"ok": False, "error": "bad shop id"})
            return
        if shop_id == user_id:
            self._json(400, {"ok": False, "error": "can't tip your own café"})
            return
        day = time.strftime("%Y-%m-%d", time.gmtime(now))
        with _db_lock, db() as con:
            host = con.execute(
                "SELECT user_id, first_name FROM users WHERE user_id=?",
                (shop_id,)).fetchone()
            if host is None:
                self._json(404, {"ok": False, "error": "no such café"})
                return
            row = con.execute(
                "SELECT count FROM visit_tips WHERE visitor=? AND host=?"
                " AND day=?", (user_id, shop_id, day)).fetchone()
            given = row["count"] if row else 0
            if given >= 3:
                self._json(429, {"ok": False,
                                 "error": "tip cap reached (3/day per café)"})
                return
            st = load_state(con, user_id, first_name, now)
            advance(st, now)
            if st["coins"] < 10:
                self._json(400, {"ok": False, "error": "not enough coins"})
                return
            st["coins"] -= 10  # tips are transfers, not earnings
            save_state(con, st)
            # host side: +10, weekly earnings, day-summary line, event ping
            hst = load_state(con, host["user_id"], host["first_name"], now)
            advance(hst, now)
            earn(hst, 10)
            hst["w2"]["tips_received_today"] = \
                hst["w2"].get("tips_received_today", 0.0) + 10
            push_event(hst, {"type": "tip_received", "from": first_name,
                             "coins": 10})
            save_state(con, hst)
            con.execute(
                "INSERT INTO visit_tips(visitor, host, day, count)"
                " VALUES(?,?,?,1)"
                " ON CONFLICT(visitor, host, day) DO UPDATE SET"
                " count=visit_tips.count+1",
                (user_id, shop_id, day))
        self._json(200, {"ok": True, "tipped": 10,
                         "tips_left_today": 3 - (given + 1)})

    # -- /api/leaderboard (Wave 2, E.4) --------------------------------
    def _handle_leaderboard(self, init_data):
        """Weekly opt-in leaderboard: ranks opt-in cafés by coins earned
        this ISO week. Top 20 {name, rep, weekly_earned}."""
        auth = self._auth(init_data)
        if not auth:
            return
        user_id, _ = auth
        now = time.time()
        week = _iso_week(now)
        with _db_lock, db() as con:
            rows = con.execute(
                "SELECT user_id, first_name, rep, w2 FROM users").fetchall()
        board = []
        opt_in = False
        for r in rows:
            try:
                w2 = json.loads(r["w2"]) if r["w2"] else {}
            except (json.JSONDecodeError, TypeError):
                w2 = {}
            if not w2.get("lb_opt_in"):
                continue
            earned = (w2.get("weekly_earned", 0.0)
                      if w2.get("week") == week else 0.0)
            if r["user_id"] == user_id:
                opt_in = True
            board.append({"name": r["first_name"], "rep": round(r["rep"], 1),
                          "weekly_earned": round(earned, 1),
                          "you": r["user_id"] == user_id})
        board.sort(key=lambda e: e["weekly_earned"], reverse=True)
        self._json(200, {"ok": True, "week": week,
                         "board": board[:20], "opt_in": opt_in})

    # -- /api/visit (public, read-only — viral shop tours) -----------
    def _handle_visit(self, shop):
        try:
            shop_id = int(shop)
        except (ValueError, TypeError):
            self._json(400, {"ok": False, "error": "bad shop id"})
            return
        with _db_lock, db() as con:
            row = con.execute(
                "SELECT shop_name, rep, rooms, w2 FROM users WHERE user_id=?",
                (shop_id,)).fetchone()
        if row is None:
            self._json(404, {"ok": False, "error": "no such café"})
            return
        rooms = json.loads(row["rooms"])
        cozy = coziness({"rooms": rooms})  # same duplicate-penalty math
        try:
            w2 = json.loads(row["w2"]) if row["w2"] else {}
        except (json.JSONDecodeError, TypeError):
            w2 = {}
        self._json(200, {"ok": True, "shop_name": row["shop_name"],
                         "rep": round(row["rep"], 1), "coziness": cozy,
                         "rooms": rooms,
                         # Wave 2 (D): Zoe's brand-deal poster shows on the
                         # visit card as 📢
                         "sponsored": bool(w2.get("sponsored"))})

    # -- /api/sync --------------------------------------------------
    def _handle_sync(self, body):
        auth = self._auth(body.get("init_data", ""))
        if not auth:
            return
        user_id, first_name = auth
        actions = body.get("actions", [])
        if not isinstance(actions, list) or len(actions) > 25:
            self._json(400, {"ok": False, "error": "actions must be a list (max 25)"})
            return
        # FTUE bookkeeping actions are idempotent/once-only — exempt from the
        # spam rate limit so tutorial beats can chain without 429s.
        if any(not str(a.get("t", "")).startswith("ftue_") for a in actions):
            now = self._rate_ok(user_id)
            if now is None:
                return
        else:
            now = time.time()
        results = []
        with _db_lock, db() as con:
            st = load_state(con, user_id, first_name, now)
            advance(st, now)
            seed_maya_if_needed(st, now)
            summary = rollover_day(st, now)
            apply_checkin(st, now)
            for a in actions:
                results.append(self._apply_action(st, a, now))
                if results[-1].get("fatal"):
                    break
            st["last_seen"] = now
            save_state(con, st)
        out = public_state(st, now, day_summary=summary)
        out["results"] = results
        self._json(200, out)

    # -- actions (all server-validated) ------------------------------
    def _apply_action(self, st: dict, a: dict, now: float):
        t = a.get("t")
        try:
            if t == "buy_decor":
                return self._a_buy_decor(st, a)
            if t == "place":
                return self._a_place(st, a)
            if t == "move":
                return self._a_move(st, a)
            if t == "sell":
                return self._a_sell(st, a)
            if t == "brew":
                return self._a_brew(st, a, now)
            if t == "restock":
                return self._a_restock(st)
            if t == "serve":
                return self._a_serve(st, a, now)
            if t == "end_day":
                return self._a_end_day(st, now)
            if t == "buy_expansion":
                return self._a_expansion(st)
            if t == "hint":
                return self._a_hint(st)
            if t == "quest_claim":
                return self._a_quest_claim(st, a)
            if t == "ftue_grant":
                return self._a_ftue_grant(st)
            if t == "ftue_step":
                return self._a_ftue_step(st, a)
            if t == "ftue_skip":
                st["ftue_done"] = 1
                return {"ok": True, "skipped": True}
            if t == "arc_choice":
                return _apply_arc_choice(st, a.get("regular", ""),
                                         a.get("choice", ""), now)
            if t == "modals_seen":
                # client rendered the queued arc modals (ftue_done only);
                # with kind=, only that modal is popped (choice flows)
                kind = a.get("kind")
                q = st["w2"]["modal_queue"]
                if kind:
                    idx = next((i for i, m in enumerate(q)
                                if m.get("kind") == kind), None)
                    if idx is not None:
                        q.pop(idx)
                else:
                    st["w2"]["modal_queue"] = []
                return {"ok": True, "cleared": True}
            if t == "levelups_seen":
                st["w2"]["pending_levelups"] = []
                return {"ok": True, "cleared": True}
            if t == "lb_opt_in":
                st["w2"]["lb_opt_in"] = 1 if a.get("on") else 0
                return {"ok": True,
                        "lb_opt_in": bool(st["w2"]["lb_opt_in"])}
            return {"ok": False, "error": f"unknown action {t!r}"}
        except Exception as e:  # never let one bad action kill the batch
            return {"ok": False, "error": f"action failed: {e}"}

    def _get_room(self, st: dict, room_id: str):
        for r in st["rooms"]:
            if r["id"] == room_id:
                return r
        return None

    def _a_buy_decor(self, st: dict, a: dict):
        did = a.get("decor")
        spec = CATALOG.get(did)
        if not spec:
            return {"ok": False, "error": "unknown decor"}
        if spec.get("trophy"):
            return {"ok": False, "error":
                    "the Friendship Fern is earned by inviting friends — "
                    "not for sale"}
        reason = decor_locked(st, spec)
        if reason:
            return {"ok": False, "error": reason}
        if st["coins"] < spec["cost"]:
            return {"ok": False, "error": "not enough coins"}
        st["coins"] -= spec["cost"]
        st["inventory"][did] = st["inventory"].get(did, 0) + 1
        return {"ok": True, "bought": did, "coins": round(st["coins"], 1)}

    def _a_place(self, st: dict, a: dict):
        did = a.get("decor")
        spec = CATALOG.get(did)
        room = self._get_room(st, a.get("room", "main_hall"))
        if not spec or not room or not room.get("unlocked"):
            return {"ok": False, "error": "bad decor or room"}
        before_sets = _completed_sets(st)  # Wave 2 (C.2): set-bonus toasts
        reason = decor_locked(st, spec)
        if reason:
            return {"ok": False, "error": reason}
        if st["inventory"].get(did, 0) < 1:
            return {"ok": False, "error": "not owned — buy it first"}
        try:
            x, y = int(a["x"]), int(a["y"])
        except (KeyError, ValueError, TypeError):
            return {"ok": False, "error": "bad coordinates"}
        w, h = spec.get("w", 1), spec.get("h", 1)
        if x < 0 or y < 0 or x + w > room["cols"] or y + h > room["rows"]:
            return {"ok": False, "error": "does not fit there"}
        # collision check against every placed footprint
        for p in room["grid"]:
            s2 = CATALOG[p["decor"]]
            if not (x + w <= p["x"] or p["x"] + s2.get("w", 1) <= x or
                    y + h <= p["y"] or p["y"] + s2.get("h", 1) <= y):
                return {"ok": False, "error": "overlaps another item"}
        room["grid"].append({"decor": did, "x": x, "y": y})
        st["inventory"][did] -= 1
        st["placed_today"] = st.get("placed_today", 0) + 1
        _check_set_completions(st, before_sets)
        return {"ok": True, "placed": did}

    def _a_move(self, st: dict, a: dict):
        room = self._get_room(st, a.get("room", "main_hall"))
        if not room or not room.get("unlocked"):
            return {"ok": False, "error": "bad room"}
        before_sets = _completed_sets(st)  # Wave 2 (C.2)
        try:
            x, y, nx, ny = (int(a[k]) for k in ("x", "y", "nx", "ny"))
        except (KeyError, ValueError, TypeError):
            return {"ok": False, "error": "bad coordinates"}
        idx = next((i for i, p in enumerate(room["grid"])
                    if p["x"] == x and p["y"] == y), None)
        if idx is None:
            return {"ok": False, "error": "nothing there"}
        p = room["grid"][idx]
        spec = CATALOG[p["decor"]]
        w, h = spec.get("w", 1), spec.get("h", 1)
        if nx < 0 or ny < 0 or nx + w > room["cols"] or ny + h > room["rows"]:
            return {"ok": False, "error": "does not fit there"}
        others = room["grid"][:idx] + room["grid"][idx + 1:]
        for q in others:
            s2 = CATALOG[q["decor"]]
            if not (nx + w <= q["x"] or q["x"] + s2.get("w", 1) <= nx or
                    ny + h <= q["y"] or q["y"] + s2.get("h", 1) <= ny):
                return {"ok": False, "error": "overlaps another item"}
        p["x"], p["y"] = nx, ny
        _check_set_completions(st, before_sets)
        return {"ok": True, "moved": p["decor"]}

    def _a_sell(self, st: dict, a: dict):
        room = self._get_room(st, a.get("room", "main_hall"))
        if not room or not room.get("unlocked"):
            return {"ok": False, "error": "bad room"}
        before_sets = _completed_sets(st)  # Wave 2 (C.2)
        try:
            x, y = int(a["x"]), int(a["y"])
        except (KeyError, ValueError, TypeError):
            return {"ok": False, "error": "bad coordinates"}
        idx = next((i for i, p in enumerate(room["grid"])
                    if p["x"] == x and p["y"] == y), None)
        if idx is None:
            return {"ok": False, "error": "nothing there"}
        p = room["grid"].pop(idx)
        refund = round(CATALOG[p["decor"]]["cost"] * SELL_REFUND, 1)
        st["coins"] += refund  # refunds are not earnings (bypass earn())
        _check_set_completions(st, before_sets)
        return {"ok": True, "sold": p["decor"], "refund": refund}

    def _a_brew(self, st: dict, a: dict, now: float):
        ing = a.get("ingredients", [])
        if not isinstance(ing, list) or not (1 <= len(ing) <= 3):
            return {"ok": False, "error": "brew needs 1-3 ingredients"}
        if any(i not in INGREDIENTS for i in ing):
            return {"ok": False, "error": "unknown ingredient"}
        combo = tuple(sorted(ing))
        # Ingredient stock: 1 unit per ingredient in the combo. Fails before
        # any state is touched — a failed brew leaves pending_brew alone.
        need = {}
        for i in combo:
            need[i] = need.get(i, 0) + 1
        for i, n in need.items():
            if st["stock"].get(i, 0) < n:
                return {"ok": False, "error": "out of stock — restock"}
        for i, n in need.items():
            st["stock"][i] -= n
        drink = None
        for name, r in RECIPES.items():
            # Story-locked combos brew as sludge with no learning and no
            # hint that the combo is special (no information leak).
            if r["combo"] == combo and recipe_open(st, name):
                drink = name
                break
        new_recipe = False
        if drink and drink not in st["recipes"]:
            st["recipes"].append(drink)  # DISCOVERY: learn by brewing right
            new_recipe = True
            st["discovered_today"] = st.get("discovered_today", 0) + 1
        st["pending_brew"] = {
            "combo": list(combo), "drink": drink or "sludge",
            "ready_at": now + brew_time(st), "new_recipe": new_recipe,
        }
        return {"ok": True, "drink": drink or "sludge",
                "new_recipe": new_recipe,
                "ready_in": round(brew_time(st), 1)}

    def _a_restock(self, st: dict):
        """Paid refill: RESTOCK_COST coins, every ingredient back to 30.
        One refill per action invocation; validated before any mutation."""
        if st["coins"] < RESTOCK_COST:
            return {"ok": False, "error": "not enough coins"}
        st["coins"] -= RESTOCK_COST
        _refill_stock(st)
        return {"ok": True, "restocked": True,
                "coins": round(st["coins"], 1)}

    def _a_serve(self, st: dict, a: dict, now: float):
        brew = st.get("pending_brew")
        if not brew:
            return {"ok": False, "error": "nothing brewed — brew first"}
        if brew["ready_at"] > now:
            return {"ok": False, "error": "still brewing",
                    "ready_in": round(brew["ready_at"] - now, 1)}
        cust = next((c for c in st["customers"] if c["cid"] == a.get("customer")),
                    None)
        if cust is None:
            return {"ok": False, "error": "customer is gone"}
        drink = brew["drink"]
        brew_ready_at = brew["ready_at"]
        st["pending_brew"] = None
        st["customers"] = [c for c in st["customers"] if c["cid"] != cust["cid"]]
        st["w2"]["serves_total"] = st["w2"].get("serves_total", 0) + 1
        evening = 1.2 if st["rep"] >= EVENING_REP else 1.0
        critic = bool(cust.get("is_critic"))
        if drink == "sludge":
            earn(st, 2)
            if critic:
                # Elena's verdict replaces the generic rep penalty.
                apply_critic_score(st, cust, critic_score(st, cust, drink, now),
                                   now)
            else:
                st["rep"] = max(1.0, st["rep"] - REP_DOWN_SLUDGE)
            st["served_today"] += 1
            st["earned_today"] += 2
            add_xp(st, 1)
            _serve_arcs(st, cust, drink, brew_ready_at, now)
            return {"ok": True, "served": "sludge", "payout": 2,
                    "event": "sludge"}
        if drink == cust["order"]:
            # Wave 2 (C.3): mastery raises the base price before tip math.
            price = RECIPES[drink]["price"] * mastery_mult(st, drink)
            tip = price * 0.2 * tip_mult(st) * evening
            payout = round(price + tip, 1)
            earn(st, payout)
            if critic:
                apply_critic_score(st, cust, critic_score(st, cust, drink, now),
                                   now)
            else:
                st["rep"] = min(5.0, st["rep"] + REP_UP)
            st["served_today"] += 1
            st["earned_today"] += payout
            st["tips_today"] = st.get("tips_today", 0.0) + round(tip, 1)
            _count_mastery(st, drink)
            # Wave 2 (C.1): 1 XP per serve + 1 more when the tip rounds >= 1
            add_xp(st, 1 + (1 if round(tip, 1) >= 1 else 0))
            _serve_arcs(st, cust, drink, brew_ready_at, now)
            return {"ok": True, "served": drink, "payout": payout,
                    "tip": round(tip, 1), "event": "happy"}
        # valid drink, wrong order: half price, small rep hit
        price = RECIPES[drink]["price"] * mastery_mult(st, drink)
        payout = round(price * 0.5, 1)
        earn(st, payout)
        if critic:
            apply_critic_score(st, cust, critic_score(st, cust, drink, now),
                               now)
        else:
            st["rep"] = max(1.0, st["rep"] - REP_DOWN_WRONG)
        st["served_today"] += 1
        st["earned_today"] += payout
        add_xp(st, 1)
        _serve_arcs(st, cust, drink, brew_ready_at, now)
        return {"ok": True, "served": drink, "payout": payout, "event": "wrong"}

    def _a_end_day(self, st: dict, now: float):
        summary = rollover_day(st, now)
        if summary is None:
            # force it: treat as end of day anyway
            summary = {
                "day": st["day"], "served": st["served_today"],
                "earned": round(st["earned_today"], 1),
                "rep_start": round(st["rep_day_start"], 2),
                "rep_end": round(st["rep"], 2),
                "tips_received": round(
                    st["w2"].get("tips_received_today", 0.0), 1),
            }
            st["day"] += 1
            st["day_start"] = now
            st["served_today"] = 0
            st["earned_today"] = 0.0
            st["rep_day_start"] = st["rep"]
            _refill_stock(st)
            st["tips_today"] = 0.0
            st["placed_today"] = 0
            st["discovered_today"] = 0
            st["w2"]["tips_received_today"] = 0.0
            ensure_quests(st)
        return {"ok": True, "day_summary": summary}

    def _a_expansion(self, st: dict):
        room = self._get_room(st, "main_hall")
        if room["cols"] >= 10:
            return {"ok": False, "error": "already expanded"}
        if st["coins"] < EXPANSION_COST:
            return {"ok": False, "error": "not enough coins"}
        st["coins"] -= EXPANSION_COST
        room["cols"], room["rows"] = 10, 8
        return {"ok": True, "expanded": "main_hall"}

    def _a_quest_claim(self, st: dict, a: dict):
        """Claim a completed daily quest's coin reward. Once-only."""
        ensure_quests(st)
        qid = a.get("quest")
        q = next((x for x in st.get("quests", {}).get("list", [])
                  if x["id"] == qid), None)
        if q is None:
            return {"ok": False, "error": "unknown quest"}
        if q["claimed"]:
            return {"ok": False, "error": "quest already claimed"}
        if quest_progress(st, q) < q["target"]:
            return {"ok": False, "error": "quest not complete yet"}
        q["claimed"] = True
        earn(st, q["reward"])  # Wave 2: quest rewards count as earnings
        return {"ok": True, "claimed": qid, "reward": q["reward"]}

    def _a_hint(self, st: dict):
        unlearned = [n for n in RECIPES
                     if n not in st["recipes"] and recipe_open(st, n)]
        if not unlearned:
            return {"ok": False, "error": "all recipes known"}
        if st["coins"] < 30:
            return {"ok": False, "error": "hint costs 30 coins"}
        st["coins"] -= 30
        pick = unlearned[0]  # deterministic: always the next one
        combo = list(RECIPES[pick]["combo"])
        shown = combo[:2]  # reveal 2 of up to 3 ingredients
        return {"ok": True, "recipe": pick, "hint": shown}

    # -- FTUE (first-time user experience) ---------------------------
    def _a_ftue_grant(self, st: dict):
        """One free wooden_table for the tutorial's place-a-table beat."""
        if st.get("ftue_grant_used"):
            return {"ok": False, "error": "FTUE grant already claimed"}
        if st.get("ftue_done"):
            return {"ok": False, "error": "FTUE already complete"}
        st["ftue_grant_used"] = 1
        st["inventory"]["wooden_table"] = \
            st["inventory"].get("wooden_table", 0) + 1
        return {"ok": True, "granted": "wooden_table"}

    def _a_ftue_step(self, st: dict, a: dict):
        """Advance the tutorial: 0=new, 1=table placed, 2=Maya served,
        3=complete. Monotonic — the client can safely re-send."""
        try:
            step = int(a.get("step", 0))
        except (TypeError, ValueError):
            return {"ok": False, "error": "bad step"}
        if not 0 <= step <= 3:
            return {"ok": False, "error": "bad step"}
        st["ftue_step"] = max(st.get("ftue_step", 0), step)
        if step >= 3:
            st["ftue_done"] = 1
        return {"ok": True, "ftue_step": st["ftue_step"],
                "ftue_done": bool(st["ftue_done"])}

    # -- /api/ad/reward ---------------------------------------------
    def _handle_ad_reward(self, body):
        """Rewarded ad: Rush Hour = 2x customer spawns for 5 minutes.
        Client calls after the ad SDK onReward fires; server cooldown is the
        backstop (verify via the network's S2S callback in production)."""
        auth = self._auth(body.get("init_data", ""))
        if not auth:
            return
        user_id, first_name = auth
        now = self._rate_ok(user_id)
        if now is None:
            return
        if body.get("kind") != "rush_hour":
            self._json(400, {"ok": False, "error": "kind must be 'rush_hour'"})
            return
        with _db_lock, db() as con:
            st = load_state(con, user_id, first_name, now)
            advance(st, now)
            if now - st["last_ad_at"] < AD_REWARD_COOLDOWN_S:
                self._json(429, {"ok": False,
                                 "error": "ad reward on cooldown"})
                return
            st["last_ad_at"] = now
            st["rush_until"] = max(now, st["rush_until"]) + RUSH_HOUR_S
            st["last_seen"] = now
            save_state(con, st)
        out = public_state(st, now)
        out["ad_reward"] = {"kind": "rush_hour",
                            "rush_until": st["rush_until"]}
        self._json(200, out)

    # -- /api/analytics (foundation) --------------------------------
    def _handle_analytics(self, body):
        """Client event ingestion (workstream G). Batched, capped at 200
        events per call, validated and stored in one transaction; the table
        is consumed by the summary script, not the game state."""
        auth = self._auth(body.get("init_data", ""))
        if not auth:
            return
        user_id, _ = auth
        now = self._rate_ok(user_id)
        if now is None:
            return
        events = body.get("events")
        if not isinstance(events, list):
            self._json(400, {"ok": False,
                             "error": "body.events must be a list"})
            return
        truncated = max(0, len(events) - 200)
        if truncated:
            events = events[:200]
        rows = []
        for item in events:
            if not isinstance(item, dict):
                continue
            name = item.get("event")
            if not isinstance(name, str) or not name.strip():
                continue
            ts = item.get("ts", now)
            # bool is an int subclass — treat as invalid, fall back to now
            if isinstance(ts, bool) or not isinstance(ts, (int, float)):
                ts = now
            props = item.get("props", {})
            if not isinstance(props, dict):
                props = {}
            try:
                props_json = json.dumps(props)
            except (TypeError, ValueError):
                props_json = "{}"
            rows.append((user_id, float(ts), name[:128], props_json))
        with _db_lock, db() as con:
            # one transaction; Connection as context manager commits on exit
            con.executemany(
                "INSERT INTO analytics_events(user_id, ts, event, props)"
                " VALUES(?,?,?,?)", rows)
        self._json(200, {"ok": True, "accepted": len(rows),
                         "truncated": truncated})

    # -- /api/stars/invoice -----------------------------------------
    def _handle_invoice(self, body):
        """Telegram Stars invoice links (XTR). Real Bot API flow documented
        inline; amounts are Stars (1 star ≈ $0.013 to the dev)."""
        auth = self._auth(body.get("init_data", ""))
        if not auth:
            return
        user_id, _ = auth
        CATALOG_STARS = {
            "golden_machine": ("Golden Espresso Machine",
                               "Brew 2x faster, forever. A solid-gold beauty.",
                               150),
            "decor_pack": ("Designer Decor Pack",
                           "5 exclusive items: velvet sofa, crystal chandelier,"
                           " marble counter, bonsai, vintage jukebox.", 100),
            "remove_ads": ("Remove ads", "No more rewarded ads, forever.", 50),
        }
        product = body.get("product")
        if product not in CATALOG_STARS:
            self._json(400, {"ok": False, "error": "unknown product"})
            return
        title, desc, stars = CATALOG_STARS[product]
        try:
            payload = f"{product}:{user_id}:{int(time.time())}"
            link = tg_api("createInvoiceLink", {
                "title": title, "description": desc, "payload": payload,
                "provider_token": "", "currency": "XTR",
                "prices": [{"label": title, "amount": stars}],
            })
        except Exception as e:  # TODO token, network failure, API error alike
            self._json(400, {"ok": False, "error": str(e)})
            return
        self._json(200, {"ok": True, "invoice_link": link})

    # -- /api/webhook ------------------------------------------------
    def _handle_webhook(self, update):
        try:
            if "pre_checkout_query" in update:
                q = update["pre_checkout_query"]
                tg_api("answerPreCheckoutQuery",
                       {"pre_checkout_query_id": q["id"], "ok": True})
            msg = update.get("message") or {}
            text = (msg.get("text") or "").strip()
            chat_id = (msg.get("chat") or {}).get("id")

            # Viral deep links: /start visit_<shop_id> -> read-only tour link
            # Wave 2 (E.3): /start visit_<shop_id>_ref -> tour link that also
            # carries ?ref=1, so a new signup from it grants the Friendship
            # Fern to both sides.
            if text.startswith("/start") and chat_id:
                parts = text.split(maxsplit=1)
                if len(parts) > 1 and parts[1].startswith("visit_"):
                    rest = parts[1][len("visit_"):]
                    is_ref, shop = False, rest
                    if rest.endswith("_ref"):
                        is_ref, shop = True, rest[:-len("_ref")]
                    link = (f"{WEBAPP_URL}/?visit={shop}&ref=1" if is_ref
                            else f"{WEBAPP_URL}/?visit={shop}")
                    text = ("\u2615\ufe0f <b>Someone invited you to tour their caf\u00e9!</b>\n"
                            "Tap below to take a look around." +
                            ("\n\U0001f331 <i>Join from their caf\u00e9 and you BOTH get a "
                             "Friendship Fern!</i>" if is_ref else ""))
                    tg_api("sendMessage", {
                        "chat_id": chat_id, "text": text, "parse_mode": "HTML",
                        "reply_markup": {"inline_keyboard": [[
                            {"text": "\U0001f3e0 Tour the caf\u00e9",
                             "web_app": {"url": link}}]]},
                    })
                else:
                    tg_api("sendMessage", {
                        "chat_id": chat_id,
                        "text": "\u2615\ufe0f <b>Your Caf\u00e9</b>\n\n"
                                "Build your dream coffee shop: decorate, craft "
                                "drinks, keep your regulars happy.\n"
                                "Tap below to open.",
                        "parse_mode": "HTML",
                        "reply_markup": {
                            "keyboard": [[{"text": "\U0001f3e0 Open my caf\u00e9",
                                          "web_app": {"url": WEBAPP_URL}}]],
                            "resize_keyboard": True,
                        },
                    })
            sp = msg.get("successful_payment")
            if sp and chat_id:
                product = sp.get("invoice_payload", "").split(":")[0]
                if product in ("golden_machine", "decor_pack", "remove_ads"):
                    with _db_lock, db() as con:
                        con.execute(
                            "INSERT OR IGNORE INTO purchases(user_id, product,"
                            " payload, created_at) VALUES(?,?,?,?)",
                            (msg["from"]["id"], product,
                             sp.get("invoice_payload", ""), int(time.time())))
                        row = con.execute("SELECT * FROM users WHERE user_id=?",
                                          (msg["from"]["id"],)).fetchone()
                        if row:
                            con.execute(
                                f"UPDATE users SET {product}=1 WHERE user_id=?",
                                (msg["from"]["id"],))
                    names = {
                        "golden_machine": "\u2b50 Golden Espresso Machine installed — "
                                          "you now brew 2x faster, forever.",
                        "decor_pack": "\u2b50 Designer Decor Pack unlocked — 5 "
                                      "exclusive items in your catalog.",
                        "remove_ads": "\u2b50 Ads removed — enjoy the quiet hum "
                                      "of your caf\u00e9.",
                    }
                    tg_api("sendMessage", {"chat_id": chat_id,
                                           "text": names[product]})
        except RuntimeError as e:
            print(f"[webhook] skipped Telegram call: {e}")
        except Exception as e:
            print(f"[webhook] error: {e}")
        self._json(200, {"ok": True})


def main():
    init_db()
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print("\u2615\ufe0f  Cafe Builder backend on :%d" % PORT)
    print(f"   game:      http://localhost:{PORT}/")
    print(f"   webhook:   POST /api/webhook   (TODO: set via Bot API setWebhook)")
    if BOT_TOKEN.startswith("TODO"):
        print("   [!] BOT_TOKEN not set — state/sync/webhook/Stars fail until README step 2")
    if WEBAPP_URL.startswith("TODO"):
        print("   [!] WEBAPP_URL not set — /start button + visit links need it (README step 3)")
    if BOT_USERNAME.startswith("TODO"):
        print("   [!] BOT_USERNAME not set — share links need it (README step 2)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
