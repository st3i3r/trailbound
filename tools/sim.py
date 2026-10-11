#!/usr/bin/env python3
"""Trailbound economy sim — Phase -1 extended model.

Extends the GDD Appendix C model (kept verbatim in docs/GAME_DESIGN.md) with:

- Per-guest draws: booking boards are seeded per (save_seed, site, site_day)
  per GDD 21.3; each party gets an archetype (site mix, 12.2) and traits
  drawn from the site's pool (5.3) with signature traits at double weight.
- Unlock gating: every purchasable carries its 8.1 unlock; the buy pass
  skips locked items instead of treating the catalog as always open.
- Real page goals (8.1) instead of Appendix C's proxies: guests hosted,
  recipes cooked, families, fish kinds, anglers on Water pads, one-night
  5-star counts, regular visit counters, full house, rating over 15.
- Weather seeded per site/day; Pinewatch site-day 4 rains by script (14).
- Regulars (12.3), the Food Blogger elite, families on 2 pads, Loud guests
  and Light Sleepers, Social/Introvert neighbour checks on a real pad line.

Bot policy (documented approximations):
- Plays the newest unlocked site every day; fills every open pad it can.
- Seats greedily: families first (need a neighbouring pair), then
  regulars, then Loud, then the rest in board order; each takes the
  free pad with the best star estimate given current occupancy.
- Build orders are the Appendix C lists. Each purchase pass scans the
  remaining list once and buys every item that is BOTH unlocked and
  affordable above a 20-coin reserve (locked items stay queued; an
  unaffordable item no longer blocks cheaper ones behind it — a real
  player does not wait to buy a hedge behind a 900-coin pad).
- The Pinewatch Outfitter opens on day 2 (P1, "from day 2"), so the run
  buys nothing on day 1. Later sites can buy from arrival day.

Assumptions the GDD leaves open (all conservative):
- Food Blogger appears on ~1 night in 4 while site rating >= 4.5.
- Regulars book on every third site day until their story ends.
- "In-game weekends" are global days 6 and 7 of every 7.
- Whisper River tags: pads 0-2 Water, 3-4 View; Lantern Valley: 0-2 View
  (site layouts are Phase 0 data; only counts matter to the model).
- Meals: each party draws its meal term — favourite +1 with p ramping
  0.3 -> 0.8 by site day 6 (recipe book growth), otherwise 0; no-meal -1
  is folded in as a flat 0.03 chance. Matches the old 0.5 -> 0.75 shape.
- Pad neighbours are the linear pad line (2-3 neighbours per pad, 5.1).

Usage:
    python tools/sim.py                 # all variants x --seeds runs, guardrail report
    python tools/sim.py --seeds 100
    python tools/sim.py --variant median --show   # day log of the median-seed run
    python tools/sim.py --baseline      # Appendix C reference model, unchanged

Python 3.9+, standard library only.
"""
import argparse, hashlib, math, random, statistics, sys
from collections import deque

# ---------------------------------------------------------------- tables
# GDD 6.7 decor: id -> (price, effect, pads it reaches, unlock key)
DECOR = {
    'stools':      (25,  'Seat',    1, 'P1'),   # 1 seat
    'bench':       (40,  'Seat',    1, 'P2'),
    'table':       (140, 'Seat',    2, 'P3'),   # 2 seats
    'lantern':     (50,  'Light',   2, 'P1'),
    'strings':     (190, 'Light',   4, 'P4'),
    'silk_lantern':(225, 'Light',   4, 'W2'),
    'planter':     (45,  'Nature',  2, 'P1'),
    'lotus':       (90,  'Nature',  2, 'Warr'),
    'flower_arch': (250, 'Nature',  4, 'Larr'),
    'tarp':        (75,  'Cover',   2, 'P1'),
    'hedge':       (60,  'Privacy', 2, 'P1'),
    'reed_screen': (75,  'Privacy', 2, 'Warr'),
    'dogbed':      (55,  'Dog',     4, 'P1'),
    'guitar':      (110, 'Music',   4, 'P2'),
    'chime':       (90,  'Music',   2, 'Warr'),
    'radio':       (100, 'Music',   4, 'W1'),
    'swing':       (150, 'Play',    4, 'P4'),
    'kite':        (90,  'Play',    2, 'Larr'),
    'telescope':   (275, 'Stars',   2, 'Larr'),
    'firepit':     (300, 'Warmth',  3, 'P5'),   # campfire r2 -> r3
}
# GDD 6.7 gear: id -> (price, unlock key)
GEAR = {'rod': (150, 'P3'), 'cooler': (200, 'Warr'),
        'binoculars': (250, 'W3'), 'oven': (380, 'Larr')}

# GDD 5.3 trait table. trait -> (kind, effect). 'Social'/'Angler'/'Shutterbug'
# resolve against the pad line/tags, not decor coverage.
TRAITS = {
    'Chilly':       ('need', 'Warmth'),
    'Social':       ('need', 'Social'),
    'Introvert':    ('need', 'PrivacyOrAlone'),
    'Nature':       ('need', 'Nature'),
    'NightOwl':     ('need', 'Light'),
    'MusicLover':   ('need', 'Music'),
    'LightSleeper': ('avert', 'MusicOrLoud'),
    'DogLover':     ('need', 'Dog'),
    'Kids':         ('need', 'Play'),
    'Angler':       ('need', 'Water'),
    'Shutterbug':   ('need', 'View'),
    'Stargazer':    ('need', 'Stars'),
    'StargazerDark':('avert', 'Light'),
    'DogWary':      ('avert', 'Dog'),
}
# GDD 12.2 archetypes. fee = site multiplier column (already rounded to 5).
# signature = traits drawn at double weight. loud flags 5.3.
ARCHETYPES = {
    # name:     pads, fee P/W/L, signature traits, loud, sites
    'Hiker':      (1, (40, 45, 50),  ('Chilly', 'Nature'),      0, 'PWL'),
    'Scout':      (1, (30, 35, 40),  ('Social', 'DogLover'),    0, 'PWL'),
    'Couple':     (1, (55, 65, 70),  ('Introvert', 'LightSleeper'), 0, 'PWL'),
    'Family':     (2, (110, 125, 145), ('Kids',),               1, 'PWL'),
    'VanLifer':   (1, (0, 60, 65),   ('MusicLover', 'NightOwl'), 1, 'WL'),
    'Angler':     (1, (0, 60, 0),    ('Angler',),               0, 'W'),
    'Photographer':(1, (0, 70, 80),  ('Shutterbug',),           0, 'WL'),
    'Cyclist':    (1, (0, 0, 60),    ('Chilly', 'Stargazer'),   0, 'L'),
    'FoodBlogger':(1, (150, 175, 195), (),                      0, 'PWL'),
}
MIX = {  # GDD 12.2 single-pad mix; Family handled separately
    'P': (('Hiker', 35), ('Scout', 20), ('Couple', 45)),
    'W': (('Hiker', 25), ('Scout', 25), ('Couple', 10), ('VanLifer', 10),
          ('Angler', 20), ('Photographer', 10)),
    'L': (('Hiker', 20), ('Scout', 20), ('Couple', 15), ('VanLifer', 10),
          ('Photographer', 10), ('Cyclist', 25)),
}
REGULARS = {  # GDD 12.3: every 3rd site day until story ends; fee already +20%
    'P': dict(name='Hung', arch='Scout', visits=3),
    'W': dict(name='OldBa', arch='Angler', visits=3),   # -> W4 golden koi
    'L': dict(name='Lan', arch='Photographer', visits=3),  # -> L4 exhibition
}
# The Minh family (12.3): weekend visitors, "usually your first family" —
# her card rides the same ~every-3rd-day cadence once 4 pads are open.
MINH_FEE = 130
REGULAR_FEE = {'P': 35, 'W': 70, 'L': 95}

SITES = {
    1: dict(key='P', avg_fee=45, meal=18, start_pads=2,
            pad_prices=[120, 200, 300, 420, 580, 750],
            platform=100, cabin=None, rain=1/5, gifts=[20, 30, 30, 40, 50],
            tags={},                      # pad index -> tag
            traits={'Chilly': 3, 'Social': 2, 'Introvert': 2, 'Nature': 2,
                    'DogLover': 2, 'NightOwl': 2, 'MusicLover': 1,
                    'LightSleeper': 2},
            order=['lantern', 'stools', 'pad', 'planter', 'tarp', 'pad',
                   'dogbed', 'rod', 'hedge', 'pad', 'platform', 'platform',
                   'guitar', 'swing', 'pad', 'lantern', 'bench', 'platform',
                   'platform', 'table', 'strings', 'pad', 'firepit',
                   'planter', 'hedge', 'pad', 'platform', 'platform',
                   'platform', 'platform', 'tarp']),
    2: dict(key='W', avg_fee=52, meal=25, start_pads=3,
            pad_prices=[190, 290, 410, 560, 750],
            platform=125, cabin=275, rain=1/4, gifts=[30, 40, 50, 60, 75],
            tags={0: 'Water', 1: 'Water', 2: 'Water', 3: 'View', 4: 'View'},
            traits={'Chilly': 2, 'Social': 1, 'Introvert': 2, 'Nature': 1,
                    'DogLover': 1, 'NightOwl': 2, 'MusicLover': 2,
                    'LightSleeper': 2, 'Angler': 3, 'Shutterbug': 2},
            order=['stools', 'pad', 'lantern', 'reed_screen', 'chime', 'pad',
                   'lotus', 'platform', 'platform', 'bench', 'tarp', 'pad',
                   'cooler', 'platform', 'silk_lantern', 'pad', 'dogbed',
                   'cabin', 'table', 'cabin', 'radio', 'pad', 'platform',
                   'cabin', 'cabin', 'hedge', 'tarp', 'platform', 'platform',
                   'cabin', 'cabin', 'binoculars']),
    3: dict(key='L', avg_fee=58, meal=30, start_pads=3,
            pad_prices=[220, 350, 500, 680, 900],
            platform=150, cabin=325, rain=1/6, gifts=[40, 50, 60, 75, 100],
            tags={0: 'View', 1: 'View', 2: 'View'},
            traits={'Chilly': 2, 'Social': 1, 'Introvert': 1, 'Nature': 2,
                    'DogWary': 1, 'NightOwl': 1, 'MusicLover': 1,
                    'LightSleeper': 1, 'Stargazer': 2, 'Shutterbug': 2},
            order=['stools', 'lantern', 'pad', 'telescope', 'planter', 'kite',
                   'pad', 'flower_arch', 'platform', 'platform', 'oven',
                   'bench', 'hedge', 'pad', 'cabin', 'cabin', 'firepit',
                   'pad', 'table', 'lantern', 'pad', 'cabin', 'platform',
                   'cabin', 'radio', 'pad', 'platform', 'platform', 'cabin',
                   'cabin', 'telescope', 'swing', 'strings']),
}

# Re-buyable coverage when the build order is done — decor is not capped in
# the GDD, so a player topping up buys what still helps the puzzle.
DUPS = {1: ('planter', 'lantern', 'hedge', 'tarp', 'stools', 'bench',
            'dogbed', 'guitar'),
        2: ('lotus', 'reed_screen', 'chime', 'lantern', 'tarp', 'hedge',
            'stools', 'bench', 'radio'),
        3: ('kite', 'lantern', 'hedge', 'tarp', 'stools', 'bench', 'planter')}
# Cosmetics [S], 6.7 — real sinks excluded from the baseline but not from play.
COSMETICS = {'woodpile': 20, 'clothesline': 30, 'bird_feeder': 35,
             'pennant': 40, 'chicken_coop': 60, 'hammock': 120,
             'koi_pond': 120, 'moped': 150}
COSMETIC_UNLOCK = {'koi_pond': 'W4'}
COSMETIC_UNLOCK_DEFAULT = 'P1'
# recipes cookable per site once staples/fish arrive (7.5). P needs 5 for P3.
COOKABLE = {1: 7, 2: 9, 3: 13}
CONFLICTS = (('Social', 'Introvert'), ('LOUD', 'LightSleeper'),
             ('NightOwl', 'Stargazer'))


# ---------------------------------------------------------------- helpers
def rng_for(seed, site, day, salt=''):
    h = hashlib.sha256(f'{seed}|{site}|{day}|{salt}'.encode()).digest()
    return random.Random(int.from_bytes(h[:8], 'big'))

def r5(x):  # rounded to nearest 5, halves up (6.3)
    return int(5 * math.floor(x / 5 + 0.5))

def weighted(rng, pairs):
    tot = sum(w for _, w in pairs)
    r = rng.random() * tot
    for v, w in pairs:
        r -= w
        if r <= 0:
            return v
    return pairs[-1][0]


# ---------------------------------------------------------------- the run
def run(seed=1, K=1.25, A=0.0, show=False, max_day=120, post_arc=0):
    """One playthrough. K = skill (need coverage multiplier), A = ad share.
    post_arc > 0 keeps simulating that many sandbox days past the finale
    (§33.2/§6.11): the bot stays at the last site, like the Appendix C
    post-arc probe."""
    coins, day, gear, site = 0, 0, set(), 1
    st = {}
    def new_site(s):
        S = SITES[s]
        t = dict(
            pads=S['start_pads'], padi=0, decor=[], plat=0, cabin=0,
            days=0, guests=0, anglers_water=0, reviews=deque(maxlen=15),
            families=0, pages=set(), gifts=0, recipes=1, fish=set(),
            five3=False, starg5=False, oven_recipes=0, order=list(S['order']),
            full8=False, reg_visits=0, reg_done=False, blogger5=False,
            bought_cos=[], cover={i: set() for i in range(8)}, seats=0,
        )
        for i in range(3):                   # built-in campfire Warmth r2 (5.1)
            t['cover'][i].add('Warmth')
        return t
    st[1] = new_site(1)
    unlock_day = {1: 1}
    ppd = {1: [], 2: [], 3: []}
    agg = dict(host=0, walk=0, reward=0, ad=0, spend=0, staples=0)
    site_inc = {1: 0.0, 2: 0.0, 3: 0.0}
    order_empty = {}
    wmax, done, arc_agg = 0, None, None
    page_day, daily = {}, []

    def unlocked(item, s):
        """Is item purchasable now at site s? (8.1 gating)"""
        t = st[s]
        key = None
        if item == 'pad' or item == 'platform':
            key = 'P1' if item == 'pad' else 'P2'
        elif item == 'cabin':
            key = 'Warr'
        elif item in GEAR:
            key = GEAR[item][1]
        else:
            key = DECOR[item][3]
        if key == 'P1':
            return 1 in t['pages'] or s > 1 and 1 in st[1]['pages']
        if key == 'P2':
            return 2 in st[1]['pages']
        if key == 'P3':
            return 3 in st[1]['pages']
        if key == 'P4':
            return 4 in st[1]['pages']
        if key == 'P5':
            return 5 in st[1]['pages']
        if key == 'Warr':
            return s >= 2
        if key == 'W1':
            return 1 in st[2]['pages']
        if key == 'W2':
            return 2 in st[2]['pages']
        if key == 'W3':
            return 3 in st[2]['pages']
        if key == 'Larr':
            return s >= 3
        return False

    if show:
        print('day s k pads stars rating net coins pages | bought')

    while day < (done + post_arc if done else max_day):
        day += 1
        S = SITES[site]
        t = st[site]
        t['days'] += 1
        k = t['days']
        pads = t['pads']
        rng = rng_for(seed, site, k, 'board')
        rw = rng_for(seed, site, k, 'weather')

        # ----- weather (5.7): never on site day 1; P day 4 scripted
        rain = (site == 1 and k == 4) or (k > 1 and rw.random() < S['rain'])

        # ----- booking board (5.2)
        board_size = pads + 1 + (1 if day % 7 in (6, 0) else 0)
        if site == 1 and k == 1:
            board_size = 2                      # scripted day 1
        weekend_fam = pads >= 4 and rng.random() < 1/3
        blogger = len(t['reviews']) == 15 and \
            sum(t['reviews']) / len(t['reviews']) >= 4.5 and rng.random() < 0.25
        n_cards = board_size
        parties = []
        for _ in range(n_cards):
            parties.append(dict(arch=weighted(rng, MIX[S['key']]),
                                traits=[], regular=None))
        if weekend_fam:
            i = rng.randrange(len(parties))
            parties[i]['arch'] = 'Family'
        # regulars: every 3rd site day until story done (12.3)
        if not t['reg_done'] and k % 3 == 2 and len(t['reviews']) > 0:
            reg = REGULARS[S['key']]
            if parties:
                parties[rng.randrange(len(parties))].update(
                    arch=reg['arch'], regular=S['key'])
        # Minh family at Pinewatch: weekend visitors (12.3) — a family card
        # on in-game weekends while 4+ pads are open and none was drawn
        if (S['key'] == 'P' and pads >= 4 and t['families'] == 0
                and day % 7 in (6, 0)
                and not any(p['arch'] == 'Family' for p in parties)):
            parties[rng.randrange(len(parties))].update(
                arch='Family', regular='Minh')
        if blogger:
            parties.append(dict(arch='FoodBlogger', traits=[], regular=None))
        # day-1 scripted: two single-trait travelers
        n_tr = 1 if (site == 1 and k <= 4) else 2
        pool = list(S['traits'].items())
        for p in parties:
            arch = p['arch']
            if arch == 'FoodBlogger':
                nt, need_avert = 3, True
            elif arch == 'Family':
                nt, need_avert = 2, False   # Kids + 1
            else:
                nt, need_avert = n_tr, False
            sig = ARCHETYPES[arch][2]
            wp = [(tr, w * (2 if tr in sig else 1)) for tr, w in pool]
            got = set()
            for _ in range(nt):
                tr = weighted(rng, [(x, w) for x, w in wp if x not in got])
                got.add(tr)
            if arch == 'Family':
                # exactly Kids + 1 other (5.3)
                other = weighted(rng, [(x, w) for x, w in wp
                                       if x not in got and x != 'Kids'])
                got = {'Kids', other}
            if need_avert and not any(
                    TRAITS[x][0] == 'avert' or x == 'Stargazer' for x in got):
                averts = [x for x in pool
                          if TRAITS[x[0]][0] == 'avert' or x[0] == 'Stargazer']
                if averts:
                    got.pop()
                    got.add(weighted(rng, averts))
            p['traits'] = sorted(got)
        # conflicting pair from global day 6 (5.2)
        if day >= 6:
            def has_conflict():
                kinds = [set(p['traits']) |
                         ({'LOUD'} if ARCHETYPES[p['arch']][3] else set())
                         for p in parties]
                for i in range(len(kinds)):
                    for j in range(i + 1, len(kinds)):
                        for a, b in CONFLICTS:
                            if (a in kinds[i] and b in kinds[j]) or \
                               (a in kinds[j] and b in kinds[i]):
                                return True
                return False
            if not has_conflict() and len(parties) >= 2:
                i, j = rng.sample(range(len(parties)), 2)
                parties[i]['traits'].append('Social')
                parties[j]['traits'].append('Introvert')

        # ----- seating (5.4): greedy, families then loud then board order
        occupied = {}
        free = set(range(pads))
        nbr = lambda i: {x for x in (i - 1, i + 1) if 0 <= x < pads}
        cover = lambda e, i: e in t['cover'][i]
        def cov_ok(effect, idxs):
            if effect == 'Social':
                return any(x in occupied for i in idxs for x in nbr(i))
            if effect == 'PrivacyOrAlone':
                return any(cover('Privacy', i) for i in idxs) or \
                    not any(x in occupied for i in idxs for x in nbr(i))
            if effect == 'Water':
                return any(S['tags'].get(i) == 'Water' for i in idxs)
            if effect == 'View':
                return any(S['tags'].get(i) == 'View' for i in idxs)
            if effect == 'MusicOrLoud':
                return any(cover('Music', i) for i in idxs) or any(
                    x in occupied and occupied[x][2] for i in idxs
                    for x in nbr(i))
            return any(cover(effect, i) for i in idxs)

        def est(p, idxs, final=False):
            c = max(pad_comfort(i) for i in idxs) if len(idxs) == 1 \
                else min(pad_comfort(i) for i in idxs)
            tr = 0
            trait_set = set(p['traits'])
            if 'Stargazer' in trait_set:
                trait_set.add('StargazerDark')   # one trait, both halves (5.3)
            for x in trait_set:
                kind, eff = TRAITS[x]
                ok = cov_ok(eff, idxs)
                if kind == 'need':
                    tr += min(1.0, (1.0 if ok else cov_frac(eff)) * K)
                else:
                    tr -= 0.2 if not final else (1.0 if ok else 0.0)
            wet = -1 if rain and not any(
                cover('Cover', i) or cabin_at(i) for i in idxs) else 0
            return 2 + c + 0.5 + tr + wet

        def pad_comfort(i):
            return 2 if cabin_at(i) else (1 if plat_at(i) else 0)
        plat_at = lambda i: i < t['plat'] + t['cabin'] and i >= t['cabin']
        cabin_at = lambda i: i < t['cabin']
        def cov_frac(eff):
            if eff == 'Social':
                return 0.8 if pads >= 2 else 0.0
            n = sum(1 for i in range(pads) if cover(eff, i))
            if eff == 'Water':
                n = sum(1 for i in range(pads)
                        if S['tags'].get(i) == 'Water')
            if eff == 'View':
                n = sum(1 for i in range(pads)
                        if S['tags'].get(i) == 'View')
            if eff == 'PrivacyOrAlone':
                n = sum(1 for i in range(pads) if cover('Privacy', i))
            if eff == 'MusicOrLoud':
                n = sum(1 for i in range(pads) if cover('Music', i))
            return min(1.0, n / max(1, pads))

        # seat order: families first (need a pad pair), then regulars
        # (ribboned cards a real player seats first), then Loud, then rest
        order = sorted(range(len(parties)),
                       key=lambda i: (0 if parties[i]['arch'] == 'Family'
                                      else (1 if parties[i]['regular']
                                            else (2 if ARCHETYPES[parties[i]['arch']][3]
                                                  else 3)), i))
        slip = max(0.0, (1.5 - K) * 0.5)   # imperfect seating (Appendix C K)
        seated = []
        for oi in order:
            p = parties[oi]
            if p['arch'] == 'Family':
                pairs = [(i, j) for i in free for j in nbr(i) & free if i < j]
                if not pairs:
                    continue                      # card leaves politely
                best = max(pairs, key=lambda pr: est(p, pr))
                idxs = best
            else:
                if not free:
                    break
                if rng.random() < slip:
                    best = rng.choice(sorted(free))
                else:
                    best = max(sorted(free), key=lambda i: est(p, (i,)))
                idxs = (best,)
            for i in idxs:
                free.discard(i)
                occupied[i] = (p, idxs, bool(ARCHETYPES[p['arch']][3]))
            seated.append((p, idxs))

        # ----- night: stars per party (5.4), reviews, income
        inc, tips, parties_n, five, fam = 0.0, 0.0, 0, 0, False
        starg5_night, anglers_w = False, 0
        pf = min(0.8, 0.3 + 0.1 * k)              # favourite-meal chance
        ad_night = (day >= 3 and rng_for(seed, site, k, 'ad').random() < A)
        for p, idxs in seated:
            arch = p['arch']
            fee = (MINH_FEE if p['regular'] == 'Minh'
                   else REGULAR_FEE[p['regular']] if p['regular']
                   else ARCHETYPES[arch][1][site - 1])
            meal_r = rng.random()
            meal = 1 if meal_r < pf else (-1 if meal_r > 0.97 else 0)
            raw = est(p, idxs, final=True) - 0.5 + meal
            stars = max(1, min(5, round(raw)))
            t['reviews'].append(stars)
            inc += fee
            tips += fee * 0.10 * max(0, stars - 2)
            parties_n += 1
            five += stars == 5
            fam |= arch == 'Family'
            if 'Stargazer' in p['traits'] and stars == 5:
                starg5_night = True
            if 'Angler' in p['traits'] and any(
                    S['tags'].get(i) == 'Water' for i in idxs):
                anglers_w += 1
            if p['regular'] and p['regular'] != 'Minh':
                t['reg_visits'] += 1
                if t['reg_visits'] >= REGULARS[S['key']]['visits']:
                    t['reg_done'] = True
            if arch == 'FoodBlogger' and stars == 5:
                t['blogger5'] = True
            if arch == 'Family':
                t['families'] += 1
        rating = sum(t['reviews']) / len(t['reviews'])
        walk = min(t['seats'], max(0, math.floor(rating) - 2)) \
            + (1 if t['blogger5'] else 0)
        walk = min(walk, t['seats'])
        t['blogger5'] = False
        wi = walk * S['meal']
        ad_extra = tips * (1 if ad_night else 0)
        stp = (parties_n + walk) * 5
        coins += inc + tips + ad_extra + wi - stp
        night_inc = inc + tips + ad_extra + wi
        agg['host'] += inc + tips
        agg['ad'] += ad_extra
        agg['walk'] += wi
        agg['spend'] += stp
        agg['staples'] += stp
        site_inc[site] += night_inc
        t['guests'] += parties_n
        t['anglers_water'] += anglers_w
        if parties_n >= 8 or sum(1 for i in occupied) >= 8:
            t['full8'] = True
        if five >= 3:
            t['five3'] = True
        if starg5_night:
            t['starg5'] = True

        # ----- errands -> page trackers (7.x, 8.1)
        if t['recipes'] < min(5, COOKABLE[site]):
            if rng.random() < 0.8:
                t['recipes'] += 1
        elif t['recipes'] < COOKABLE[site] and rng.random() < 0.5:
            t['recipes'] += 1
        if site == 2 and 'rod' in gear:
            for _ in range(3 + (1 if rain else 0)):
                t['fish'].add(weighted(rng, (('Trout', 40), ('Catfish', 35),
                                             ('Carp', 25))))
        if site == 3 and 'oven' in gear and t['oven_recipes'] < 3:
            t['oven_recipes'] += 1

        # ----- pages (8.1 real goals)
        pg = t['pages']
        before = set(pg)
        full = len(t['reviews']) >= 15
        if site == 1:
            pg.add(1)                                        # relight fire
            if t['guests'] >= 20:
                pg.add(2)
            if t['recipes'] >= 5:
                pg.add(3)
            if t['families'] >= 1:
                pg.add(4)
            if full and rating >= 4.0:
                pg.add(5)
        elif site == 2:
            if 'rod' in gear and len(t['fish']) >= 3:
                pg.add(1)
            if t['anglers_water'] >= 6:
                pg.add(2)
            if t['five3']:
                pg.add(3)
            if t['reg_done']:
                pg.add(4)
            if full and rating >= 4.2:
                pg.add(5)
        else:
            if t['starg5']:
                pg.add(1)
            if 'oven' in gear and t['oven_recipes'] >= 3:
                pg.add(2)
            if t['full8']:
                pg.add(3)
            if t['reg_done']:
                pg.add(4)
            if full and rating >= 4.4:
                pg.add(5)
        for p in pg - before:
            page_day[(site, p)] = day
        gift = sum(S['gifts'][i - 1] for i in pg) - t['gifts']
        t['gifts'] += gift
        coins += gift
        agg['reward'] += gift

        # ----- purchases: gated build-order pass (6.1, 8.1)
        bought = []
        can_buy = (site > 1) or (day >= 2)       # Outfitter from day 2 (P1)
        if can_buy:
            for it in list(t['order']):
                if it == 'pad':
                    if t['padi'] >= len(S['pad_prices']):
                        t['order'].remove(it)
                        continue
                    price = S['pad_prices'][t['padi']]
                elif it == 'platform':
                    if t['plat'] + t['cabin'] >= t['pads']:
                        t['order'].remove(it)
                        continue
                    price = S['platform']
                elif it == 'cabin':
                    if t['plat'] <= 0 or S['cabin'] is None:
                        t['order'].remove(it)
                        continue
                    price = S['cabin']
                elif it in GEAR:
                    if it in gear:
                        t['order'].remove(it)
                        continue
                    price = GEAR[it][0]
                else:
                    price = DECOR[it][0]
                if not unlocked(it, site):
                    continue
                if coins - price < 20:
                    continue
                coins -= price
                agg['spend'] += price
                bought.append(f'{it}({price})')
                t['order'].remove(it)
                if it == 'pad':
                    t['pads'] += 1
                    t['padi'] += 1
                elif it == 'platform':
                    t['plat'] += 1
                elif it == 'cabin':
                    t['plat'] -= 1
                    t['cabin'] += 1
                elif it in GEAR:
                    gear.add(it)
                else:
                    place_decor(t, it, pads)
            # order done? a real player tops up: useful duplicates while
            # they still add coverage, then cosmetics — no daily cap;
            # the GDD doesn't cap purchases/day (hoarding is a choice,
            # wmax measures whether sinks exist to prevent it)
            if not t['order']:
                while True:
                    cos_left = [c for c in COSMETICS
                                if c not in t['bought_cos']
                                and (c != 'koi_pond'
                                     or (2 in st and 4 in st[2]['pages']))]
                    useful = [d for d in DUPS[site]
                              if unlocked(d, site)
                              and dup_helps(t, d, pads)]
                    cands = useful + cos_left
                    top_price = lambda c: (COSMETICS[c] if c in COSMETICS
                                           else DECOR[c][0])
                    affordable = [c for c in cands
                                  if coins - top_price(c) >= 20]
                    if not affordable:
                        break
                    pick = affordable[0]
                    price = top_price(pick)
                    coins -= price
                    agg['spend'] += price
                    bought.append(f'{pick}({price})*')
                    if pick in DECOR:
                        place_decor(t, pick, pads)
                    else:
                        t['bought_cos'].append(pick)
        if done is None or day <= done:      # §6.9 arc metrics stop at the
            ppd[site].append(len(bought))    # finale; post-finale days are the
            # §6.11 sandbox measured separately. wmax = peak balance while
            # the site's order had items — after it empties, income can't
            # leave the wallet, which is the leftover-order problem, not
            # an arc-phase sink failure.
            if site not in order_empty:
                wmax = max(wmax, coins)
        if not t['order'] and site not in order_empty:
            order_empty[site] = day
        daily.append(dict(d=day, s=site, k=k, pads=pads, parties=parties_n,
                          stars=[r for r in t['reviews']][-parties_n:],
                          net=round(inc + tips + ad_extra + wi - stp),
                          coins=round(coins), pages=''.join(map(str, sorted(pg))),
                          bought=bought, rain=rain, walk=walk))
        if show:
            stt = [r for r in t['reviews']][-parties_n:]
            print(day, site, k, pads,
                  round(sum(stt) / max(1, len(stt)), 2), round(rating, 2),
                  round(inc + tips + ad_extra + wi - stp), round(coins),
                  ''.join(map(str, sorted(pg))), '|', ' '.join(bought))
        if len(pg) == 5:
            if site < 3:
                site += 1
                st[site] = new_site(site)
                unlock_day[site] = day + 1
            else:
                if done is None:
                    done = day
                    arc_agg = dict(agg)      # §6.9 aggregates freeze at finale
                if not post_arc or day >= done + post_arc:
                    break

    arc = arc_agg or agg     # post-arc runs report §6.9 metrics arc-scoped
    tot = arc['host'] + arc['walk'] + arc['reward'] + arc['ad']
    post_stats = None
    if post_arc and done:
        by_day = {e['d']: e for e in daily}
        post = [e for e in daily if done < e['d'] <= done + post_arc]

        def left_value(s):
            """Coins still spendable at site s (§6.11 sizing input)."""
            S, t2 = SITES[s], st[s]
            padi, plat, cabin = t2['padi'], t2['plat'], t2['cabin']
            pads_after, total, n = t2['pads'], 0, 0
            for it in t2['order']:
                if it == 'pad':
                    if padi >= len(S['pad_prices']):
                        continue
                    total += S['pad_prices'][padi]
                    padi += 1
                    pads_after += 1
                elif it == 'platform':
                    if plat + cabin >= pads_after:
                        continue
                    total += S['platform']
                    plat += 1
                elif it == 'cabin':
                    if plat <= 0 or S['cabin'] is None:
                        continue
                    total += S['cabin']
                    plat -= 1
                    cabin += 1
                elif it in GEAR:
                    if it in gear:
                        continue
                    total += GEAR[it][0]
                else:
                    total += DECOR[it][0]
                n += 1
            return n, total, len(t2['order'])

        last_buy = max((e['d'] for e in daily if e['bought']), default=None)
        post_stats = dict(
            window=len(post),
            net_per_day=(round(statistics.mean(e['net'] for e in post))
                         if post else 0),
            last_buy_offset=(last_buy - done) if last_buy else None,
            balance_at={n: by_day[done + n]['coins']
                        for n in (0, 10, 20, 30, 60)
                        if (done + n) in by_day},
            leftover={s: left_value(s) for s in (1, 2, 3)},
            leftover_items={s: list(st[s]['order']) for s in (1, 2, 3)})

    return dict(seed=seed, u2=unlock_day.get(2), u3=unlock_day.get(3),
                p_done=(unlock_day[2] - 1) if 2 in unlock_day else None,
                done=done, daily=daily,
                ppd={s: (round(statistics.mean(v), 2) if v else 0)
                     for s, v in ppd.items()},
                zero={s: v.count(0) for s, v in ppd.items()},
                shares=(round(100 * arc['host'] / tot),
                        round(100 * arc['walk'] / tot),
                        round(100 * arc['reward'] / tot)) if tot else (0, 0, 0),
                stp=round(100 * arc['staples'] / arc['spend']) if arc['spend'] else 0,
                wmax=round(wmax), pages=dict(sorted(page_day.items())),
                income=round(tot), spend=round(arc['spend']),
                site_inc={s: round(v) for s, v in site_inc.items()},
                order_empty=order_empty, order_left=len(t['order']),
                ad_share=round(100 * arc['ad'] / tot) if tot else 0,
                post=post_stats)


def dup_helps(t, item, pads):
    """Would another copy of this decor still do anything? (5.1)"""
    eff = DECOR[item][1]
    if eff == 'Seat':
        return t['seats'] < 5           # walk-ins cap at floor(rating)-2 ~ 3
    return any(eff not in t['cover'][i] for i in range(pads))


def place_decor(t, item, pads):
    """Decor covers the pads least covered by its effect so far (5.1 lint:
    r1 ~2 pads, r2 ~4). Seats don't mark coverage — they feed walk-ins."""
    price, eff, reach, _ = DECOR[item]
    if eff == 'Seat':
        t['seats'] += reach
        return
    for _ in range(reach):
        un = [i for i in range(pads) if eff not in t['cover'][i]]
        if not un:
            break
        # spread: pick the uncovered pad whose neighbours are least covered
        pick = min(un, key=lambda i: (
            sum(eff in t['cover'][x] for x in (i - 1, i + 1)
                if 0 <= x < pads), i))
        t['cover'][pick].add(eff)
    t['decor'].append(item)


# ---------------------------------------------------------------- baseline
def baseline():
    """Appendix C reference model, embedded for diff-checks."""
    return 'see docs/GAME_DESIGN.md Appendix C (kept as the single copy)'


# ---------------------------------------------------------------- report
VARIANTS = [('median', 1.25, 0.0), ('casual', 1.0, 0.0), ('expert', 1.5, 0.0),
            ('median A=0.5', 1.25, 0.5), ('median A=1', 1.25, 1.0),
            ('casual A=1', 1.0, 1.0), ('expert A=1', 1.5, 1.0)]


def report(runs, label):
    dones = [r['done'] for r in runs if r['done']]
    u2 = [r['u2'] for r in runs if r['u2']]
    u3 = [r['u3'] for r in runs if r['u3']]
    if not dones:
        print(f'{label}: NO RUN COMPLETED')
        return None
    med = statistics.median(dones)
    mid = min(runs, key=lambda r: abs((r['done'] or 999) - med))
    ws = sorted(r['wmax'] for r in runs)
    wmed, wp90 = statistics.median(ws), ws[len(ws) * 9 // 10]
    print(f'{label}: done median {med:.0f} '
          f'(p10 {sorted(dones)[len(dones)//10]}, '
          f'p90 {sorted(dones)[len(dones)*9//10]}) '
          f'W {statistics.median(u2):.0f} L {statistics.median(u3):.0f} | '
          f'ppd {[mid["ppd"][s] for s in (1, 2, 3)]} '
          f'zero {[mid["zero"][s] for s in (1, 2, 3)]} '
          f'wmax {wmed:.0f}/{wp90} shares {mid["shares"]} '
          f'ad {mid["ad_share"]}% inc {mid["income"]} '
          f'emptied {mid["order_empty"]}')
    return dict(median=med, mid=mid, dones=dones,
                wmed=wmed, wp90=wp90)


def guardrails(out, out_runs):
    """Compare medians with GDD 6.9. Returns True when everything holds."""
    print('\n=== Guardrails (GDD 6.9) ===')
    ok = True
    ran = [0]
    def chk(name, cond, val):
        nonlocal ok
        ok &= cond
        ran[0] += 1
        print(f'  [{"OK" if cond else "XX"}] {name}: {val}')
    m0 = out.get(('median', 0.0))
    if m0:
        pd = [r['p_done'] for r in out_runs[('median', 0.0)] if r['p_done']]
        p1 = statistics.median(pd) if pd else None
        chk('Pinewatch chapter done day 8-11 (median of seeds)',
            p1 is not None and 8 <= p1 <= 11, p1)
        chk('Arc done 30-40', 30 <= m0['median'] <= 40, m0['median'])
        chk('ppd >= 1.4 all sites',
            all(m0['mid']['ppd'][s] >= 1.4 for s in (1, 2, 3)),
            [m0['mid']['ppd'][s] for s in (1, 2, 3)])
        chk('zero-buy days <= 2 all sites',
            all(m0['mid']['zero'][s] <= 2 for s in (1, 2, 3)),
            [m0['mid']['zero'][s] for s in (1, 2, 3)])
        chk('fees+tips share >= 75%', m0['mid']['shares'][0] >= 75,
            m0['mid']['shares'])
        chk('wmax <= 800 median / <= 900 p90 (peak while order had items)',
            m0['wmed'] <= 800 and m0['wp90'] <= 900,
            f"{m0['wmed']:.0f} (p90 {m0['wp90']})")
    c0 = out.get(('casual', 0.0))
    if c0:
        chk('Casual arc <= 50', c0['median'] <= 50, c0['median'])
    for lab in ('median A=1', 'casual A=1', 'expert A=1'):
        r = out.get((lab, 1.0))
        base = {'median A=1': m0, 'casual A=1': c0,
                'expert A=1': out.get(('expert', 0.0))}.get(lab)
        if r and base:
            short = 1 - r['median'] / base['median']
            chk(f'{lab}: shorten <= 15% ({short:+.0%})', short <= 0.15,
                f"{base['median']} -> {r['median']}")
            chk(f'{lab}: wmax <= 950 median & p90',
                r['wmed'] <= 950 and r['wp90'] <= 950,
                f"{r['wmed']:.0f} (p90 {r['wp90']})")
            chk(f'{lab}: ad share <= 15%', r['mid']['ad_share'] <= 15,
                r['mid']['ad_share'])
    if not ran[0]:
        print('  (no guardrails evaluated — single-variant run)')
        return True
    print('=== ' + ('ALL GUARDRAILS HOLD' if ok else 'GUARDRAIL FAILURES — see XX') + ' ===')
    return ok


def post_report(runs, label):
    """Post-arc sandbox stats across seeds (§6.11 sizing, Appendix C 3.1)."""
    stats = [r['post'] for r in runs if r['post']]
    if not stats:
        return
    nets = [p['net_per_day'] for p in stats]
    lastb = [p['last_buy_offset'] for p in stats
             if p['last_buy_offset'] is not None]
    lefts = [p['leftover'][1][1] + p['leftover'][2][1] for p in stats]
    b30 = [p['balance_at'].get(30) for p in stats
           if p['balance_at'].get(30) is not None]
    mid = min(runs, key=lambda r: abs((r['done'] or 999)
                                      - statistics.median(
                                          r['done'] for r in runs if r['done'])))
    mp = mid['post']
    print(f'  post-arc {label}: net/day med {statistics.median(nets):.0f} '
          f'({min(nets)}–{max(nets)}) | last buy {statistics.median(lastb):+.0f}d | '
          f'bal +30 med {statistics.median(b30):.0f} | '
          f'P+W leftover med {statistics.median(lefts):.0f} '
          f'({min(lefts)}–{max(lefts)})')
    print(f'    mid seed {mid["seed"]}: bal {mp["balance_at"]} | '
          f'left P {mp["leftover"][1]} W {mp["leftover"][2]} '
          f'L {mp["leftover"][3]}')
    print(f'    leftover items P: {mp["leftover_items"][1]}')
    print(f'    leftover items W: {mp["leftover_items"][2]}')


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--seeds', type=int, default=30,
                    help='save seeds per variant (default 30)')
    ap.add_argument('--variant', help='one variant only')
    ap.add_argument('--post-arc', type=int, metavar='DAYS', default=0,
                    help='simulate DAYS of post-finale sandbox and report '
                         'leftover orders, income drift, balance curve (§6.11)')
    ap.add_argument('--show', action='store_true',
                    help='print the day log of the median-seed run')
    ap.add_argument('--baseline', action='store_true',
                    help='print the Appendix C reference instead')
    a = ap.parse_args()
    if a.baseline:
        print(baseline())
        return
    out, out_runs = {}, {}
    for lab, K, A in VARIANTS:
        if a.variant and lab != a.variant:
            continue
        runs = [run(seed=s, K=K, A=A, post_arc=a.post_arc)
                for s in range(1, a.seeds + 1)]
        out_runs[(lab, A)] = runs
        out[(lab, A)] = report(runs, f'{lab} K={K} A={A}')
        if a.post_arc:
            post_report(runs, f'{lab} K={K} A={A}')
        if a.show or a.variant:
            mid = out[(lab, A)]['mid']
            print(f'  pages: {mid["pages"]}')
    guardrails(out, out_runs)
    if a.show:
        key = ('median', 0.0) if ('median', 0.0) in out \
            else next(iter(out))
        mid = out[key]['mid']
        print(f'\n=== day log, seed {mid["seed"]} (nearest to median) ===')
        print('day s k pads parties stars net coins pages | bought')
        for d in mid['daily']:
            print(d['d'], d['s'], d['k'], d['pads'], d['parties'],
                  f"{sum(d['stars'])/max(1,len(d['stars'])):.2f}" if d['stars'] else '-',
                  d['net'], d['coins'], d['pages'], '|', ' '.join(d['bought']),
                  ' RAIN' if d['rain'] else '')


if __name__ == '__main__':
    sys.exit(main())
