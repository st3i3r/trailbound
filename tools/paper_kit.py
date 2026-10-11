#!/usr/bin/env python3
"""Generate the Phase -1 paper-prototype kit for Trailbound.

Prints a self-contained HTML file (docs/paper-kit.html): cut-out guest
cards, trait chips, pad grid, decor tiles, upgrade/gear strip, booking
board, night-log sheets and a cheatsheet — everything needed to run
10 Pinewatch nights by hand (DEV_WORKFLOW Phase -1, GDD 29).

    python tools/paper_kit.py            # writes docs/paper-kit.html
    python tools/paper_kit.py -o kit.html

Open the file in a browser, print landscape, cut along the dashed lines.
All content mirrors docs/GAME_DESIGN.md: 5.x hosting rules, 6.x prices,
8.1 pages, 11/12 sites and archetypes.
"""
import argparse, html, os

E = html.escape

# ---------------- GDD data (kept tiny — only what a paper session needs)
ARCHETYPES = [  # name, pads, fee@P, signature traits, loud
    ('Hiker', 1, 40, 'Chilly · Nature Lover', False),
    ('Scout', 1, 30, 'Social · Dog Lover', False),
    ('Couple', 1, 55, 'Introvert · Light Sleeper', False),
    ('Family', 2, 110, 'Kids + 1', True),
    ('Food Blogger', 1, 150, '3 traits, ≥1 aversion — only when rating ≥4.5', False),
]
TRAITS = [  # trait, condition, type (5.3)
    ('Chilly', 'Warmth in range', 'need'), ('Social', '≥1 occupied neighbour', 'need'),
    ('Introvert', 'Privacy in range, or no neighbour', 'need'),
    ('Nature Lover', 'Nature in range', 'need'),
    ('Night Owl', 'Light in range', 'need'), ('Music Lover', 'Music in range', 'need'),
    ('Light Sleeper', 'Music in range, or Loud neighbour', 'aversion'),
    ('Dog Lover', 'Dog in range', 'need'), ('Kids', 'Play in range of either pad', 'need'),
]
DECOR = [  # item, effect, reach, size, price, from (6.7) — Pinewatch set
    ('Stools', 'Seats', '1 seat', '1×1', 25, 'P1'), ('Bench', 'Seats', '1 seat', '1×1', 40, 'P2'),
    ('Picnic Table', 'Seats', '2 seats', '2×1', 140, 'P3'),
    ('Lantern', 'Light', 'r1', '1×1', 50, 'P1'), ('String Lights', 'Light', 'r2', '2×1', 190, 'P4'),
    ('Planter', 'Nature', 'r1', '1×1', 45, 'P1'),
    ('Flower Arch', 'Nature', 'r2', '2×1', 250, 'L'),
    ('Tarp', 'Cover', 'r1', '1×1', 75, 'P1'), ('Hedge', 'Privacy', 'r1', '1×1', 60, 'P1'),
    ('Dog Bed', 'Dog', 'r2', '1×1', 55, 'P1'), ('Guitar Stump', 'Music', 'r2', '1×1', 110, 'P2'),
    ('Swing', 'Play', 'r2', '2×1', 150, 'P4'), ('Telescope', 'Stars', 'r1', '1×1', 275, 'L'),
]
UPGRADES = [('Platform', 'comfort +1 on a pad', 100, 'P2'),
            ('Stone Fire Pit', 'campfire Warmth r2→r3', 300, 'P5')]
GEAR = [('Fishing Rod', 'fishing at the pond', 150, 'P3')]
PAD_PRICES = [120, 200, 300, 420, 580, 750]   # Pinewatch next pads (6.7)
PAGES = [('P1', 'Relight the fire (day 1)', 'Outfitter + Stools/Lantern/Planter/Hedge/Tarp/Dog Bed + staples'),
         ('P2', 'Welcome 20 guests', 'Platform · Bench · Guitar Stump'),
         ('P3', 'Cook 5 different recipes', 'Fishing Rod · Picnic Table'),
         ('P4', 'Host a family', 'Swing · String Lights'),
         ('P5', 'Reach a 4.0 rating (15 reviews)', 'Stone Fire Pit')]

CSS = """
@page { size: A4 landscape; margin: 8mm }
* { box-sizing: border-box; font-family: 'Segoe UI', Arial, sans-serif }
body { margin: 0; color: #222 }
h1 { font-size: 20px } h2 { font-size: 15px; margin: 14px 0 6px }
h2::before { content: '✂ '; }
.sheet { page-break-after: always }
.grid { display: flex; flex-wrap: wrap; gap: 4mm }
.card, .tile, .pad, .chip { border: 1.5px dashed #888; border-radius: 6px;
  padding: 6px 8px; page-break-inside: avoid }
.card { width: 62mm; min-height: 40mm }
.card h3 { margin: 0 0 4px; font-size: 14px }
.card .fee { float: right; font-weight: 700 }
.card .traits { font-size: 11px; color: #444 }
.tile { width: 40mm; min-height: 26mm; font-size: 11px }
.tile b { font-size: 12px }
.tile .p { float: right; font-weight: 700 }
.chip { width: 30mm; min-height: 12mm; font-size: 10px; text-align: center }
.chip.need { background: #e8f4e8 } .chip.aversion { background: #fdecec }
.pad { width: 48mm; height: 48mm; position: relative; font-size: 11px;
  border-style: solid }
.pad.locked { background: repeating-linear-gradient(45deg,#eee,#eee 6px,#e2e2e2 6px,#e2e2e2 12px); color:#777 }
.pad .num { position: absolute; top: 3px; left: 6px; font-size: 18px; font-weight:700 }
.pad .tags { position: absolute; bottom: 3px; left: 6px; color:#555 }
.camp { display:flex; gap:4mm; align-items:flex-end; flex-wrap:wrap }
.fire { width:48mm; height:48mm; border:2px solid #a63; border-radius:6px;
  background:#f7e6d0; font-size:11px; padding:6px }
table { border-collapse: collapse; font-size: 11px }
td, th { border: 1px solid #bbb; padding: 2px 7px; text-align: left }
.note { font-size: 11px; color: #555; max-width: 240mm }
.log td { height: 20px }
.star { font-size: 13px; letter-spacing: 1px }
"""

def card(name, fee, traits, loud=False, regular=None, pads=1):
    tag = ' <span style="color:#a00">🔊 LOUD</span>' if loud else ''
    rib = f'<div style="color:#06c">🎗 {E(regular)}</div>' if regular else ''
    padtxt = 'needs 2 neighbouring pads' if pads == 2 else '1 pad'
    return (f'<div class="card"><span class="fee">{fee}c</span>'
            f'<h3>{E(name)}</h3>{rib}<div class="traits">{E(traits)}</div>'
            f'<div class="traits"><i>{padtxt} · fee incl. dinner</i></div>'
            f'<div class="traits">attach trait chips: ____ ____ ____</div></div>')

def tile(t):
    return (f'<div class="tile"><span class="p">{t[4]}c</span><b>{E(t[0])}</b><br>'
            f'{E(t[1])} · {E(t[2])} · {E(t[3])}<br><i>from {E(t[5])}</i></div>')

def pad(n, locked=False, tags=''):
    return (f'<div class="pad{" locked" if locked else ""}">'
            f'<span class="num">{n}</span>'
            f'<span class="tags">{E(tags or ("overgrown — pay to open" if locked else "bare pad · comfort 0"))}</span></div>')

def chips():
    out = []
    for name, cond, kind in TRAITS:
        out.append(f'<div class="chip {kind}"><b>{E(name)}</b><br>{E(cond)}<br><i>{kind}</i></div>')
    return ''.join(out)

def build():
    cards = ''.join(card(n, f'{f}', t, l, pads=p) for n, p, f, t, l in ARCHETYPES)
    cards += card('Hùng (scout regular)', '35', 'Social · Dog Lover — visits ~every 3rd day, pays +20%', regular='regular')
    cards += card('Minh family', '130', 'Kids + 1 — weekend visitors, "usually your first family"', loud=True, regular='regular', pads=2)
    tiles = ''.join(tile(t) for t in DECOR)
    tiles += ''.join(f'<div class="tile"><span class="p">{p}c</span><b>{E(n)}</b><br>{E(d)}<br><i>from {u}</i></div>'
                     for n, d, p, u in UPGRADES + GEAR)
    pads = ''.join(pad(i + 1, locked=i >= 2,
                       tags='campfire Warmth r2' if i < 3 else '')
                   for i in range(8))
    page_rows = ''.join(f'<tr><td>{p}</td><td>{E(g)}</td><td>{E(u)}</td></tr>'
                        for p, g, u in PAGES)
    trait_rows = ''.join(f'<tr><td>{E(t[0])}</td><td>{E(t[1])}</td><td>{t[2]}</td></tr>'
                         for t in TRAITS)
    pad_price = ' · '.join(str(p) for p in PAD_PRICES)
    log_rows = ''.join(
        f'<tr><td>{d}</td><td></td><td></td><td></td><td></td><td></td><td></td></tr>'
        for d in range(1, 11))
    return f"""<!doctype html><meta charset="utf-8"><title>Trailbound — Phase -1 paper kit</title>
<style>{CSS}</style>
<div class="sheet">
<h1>Trailbound — Phase -1 paper kit (Pinewatch Forest)</h1>
<p class="note">Run <b>10 in-game days</b> per session, 5 sessions. Each day:
Morning (read the booking board, weather) → Prep (cook, buy, place — use the
journal-page unlocks; the Outfitter opens day 2) → Evening (drag guest cards
onto pads; check the star preview by hand) → Night (score stars, pay fees +
tips, walk-ins, page gifts; buy phase again tomorrow). Record each night on
the log sheet. Compare with the sim: <code>python tools/sim.py --show</code>.</p>
<h2>How a night scores (§5.4)</h2>
<p class="note"><span class="star">stars = clamp(2 + comfort + meal + traits + weather, 1, 5)</span>
· comfort: bare 0 / Platform +1 / Cabin +2 · meal: favourite +1 / other 0 / none −1
· +1 per need met, −1 per aversion · rain −1 on uncovered pads (Tarp r1, cabins always dry)
· tip = fee × 10% × max(0, stars−2) · site rating = mean of last 15 reviews
· walk-ins = min(Seats, ⌊rating⌋−2), each buys a leftover meal (avg 18c at Pinewatch)</p>
<h2>Trait → effect map (§5.3)</h2>
<table><tr><th>Trait</th><th>Condition</th><th>Type</th></tr>{trait_rows}</table>
<p class="note">Effects: Warmth=campfire (r2, ~3 pads)+Fire Pit · Light=Lantern/String Lights ·
Nature=Planter/Flower Arch · Cover=Tarp/Cabin · Privacy=Hedge · Dog=Dog Bed ·
Music=Guitar Stump · Play=Swing · Stars=Telescope · Seats=walk-in capacity.</p>
<h2>Journal pages → unlocks (§8.1)</h2>
<table><tr><th>Page</th><th>Goal</th><th>Unlocks</th></tr>{page_rows}</table>
<p class="note">Pads open in this order: start 2, then {pad_price} · staples 5c each
per meal served · refund in full until Goodnight.</p>
</div>
<div class="sheet">
<h2>Camp sheet — Pinewatch (cut around; pads are the 64px cells)</h2>
<div class="camp"><div class="fire"><b>Campfire</b><br>Warmth r2 reaches
~3 pads (shown on pads 1–3). Stone Fire Pit → r3 (+3 more).</div>{pads}</div>
<p class="note">Neighbour rule for this kit: pads in a row — each pad's
neighbours are the pads immediately left/right (2–3 per pad, §5.1).
An item "reaches" a pad when any pad cell is within Chebyshev r1 of the item
cell — on paper, count the item's r as "~2 pads (r1) / ~4 pads (r2)" and
place its effect chit under the pads you choose.</p>
</div>
<div class="sheet">
<h2>Guest cards (deck: ×3 Hiker, ×2 Scout, ×4 Couple, ×2 Family — redraw as needed)</h2>
<div class="grid">{cards}</div>
<h2>Trait chips (cut out; draw per the day's rules: day 1–4 → 1 trait, then 2)</h2>
<div class="grid">{chips()}{chips()}</div>
</div>
<div class="sheet">
<h2>Decor & upgrade tiles</h2>
<div class="grid">{tiles}</div>
<h2>Board strip</h2>
<p class="note">Each morning line up <b>open pads + 1</b> cards (+1 more on in-game
weekends, days 6–7 of 7). Day 1 is scripted: two single-trait travellers.
From day 6 every board must contain one conflicting pair
(Social×Introvert, Loud×Light Sleeper, Night Owl×Stargazer). Families appear
~1 night in 3 once ≥4 pads open; their card stays disabled with no free
pad pair. Cards left in the tray at Goodnight leave politely — no penalty.</p>
</div>
<div class="sheet">
<h2>Night log (one row per day)</h2>
<table class="log"><tr><th>Day</th><th>Weather</th><th>Guests seated / stars</th>
<th>Fees + tips</th><th>Walk-ins</th><th>Coins end</th><th>Pages / buys</th></tr>
{log_rows}</table>
<p class="note">Session questions (Phase -1 exit): did a night ever present a
real trade-off (a guest you could not satisfy)? Did the board's conflicting
pair change your layout? Which item did you save for and was it worth it?</p>
</div>"""

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-o', '--out', default='docs/paper-kit.html')
    a = ap.parse_args()
    path = os.path.join(os.path.dirname(__file__), '..', a.out)
    path = os.path.abspath(path)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(build())
    print(f'wrote {path} — open in a browser, print landscape, cut & play')

if __name__ == '__main__':
    main()
