# Trailbound — Game Design Document

| | |
|---|---|
| Version | 3.1 — draft for approval |
| Date | 2026-10-11 |
| Platform | Android (Google Play), landscape, phones and tablets |
| Engine | Godot 4 (typed GDScript), 2D, Compatibility renderer |
| Languages | English, Vietnamese |
| Supersedes | The 2.x design and the café-era plans, removed from the repo (D-22) |

This document is the single source of truth for v1 and the plan after launch (§33). Earlier designs and the café-era plans were removed in a hard break (D-22) and live only in git history.

**Conventions**

- Priority tags: [M] Must, [S] Should, [C] Could, [W] Won't in v1. Untagged items are [M].
- Every price, fee and reward is defined in §6 and nowhere else. Other sections name items and point to §6.
- Any change to §6 means re-running the Appendix C sim and re-checking the §6.9 guardrails.
- "Verify:" marks a technical assumption not yet confirmed on the pinned toolchain or the test devices.
- Site abbreviations: P = Pinewatch Forest, W = Whisper River, L = Lantern Valley. "P3" means Pinewatch journal page 3.

**Contents**

- Vision: 1 At a glance · 2 Premise and story · 3 Pillars · 4 Core loop
- Systems: 5 Hosting · 6 Economy · 7 Errands and cooking · 8 Progression · 9 The dog · 10 Trail Daily
- Content: 11 Sites · 12 Cast · 13 Narrative · 14 Onboarding · 15 Vietnamese signature
- Presentation: 16 Art direction · 17 UI and UX · 18 Audio · 19 Localization
- Technology: 20 Stack · 21 Architecture and data · 22 Save system · 23 Performance budgets · 24 Monetization · 25 Analytics and KPIs · 26 Privacy, compliance and store
- Production: 27 Scope · 28 Assets and pipeline · 29 Roadmap and gates · 30 Testing · 31 Launch · 32 Risks · 33 After launch
- Appendices: A Decision log · B Open questions · C Economy simulation · D Backlog · E Glossary · F Changelog

---

## 1. At a glance

| | |
|---|---|
| Pitch | Trailbound is a cozy campsite puzzle-management game. Each evening you decide which guest sleeps where — the chilly hiker by the fire, the light-sleeping couple far from the guitar — and each morning you reshape your camp with what you earned. Reopen your grandfather's chain of forgotten trail campsites, one journal page at a time. |
| Genre | Cozy management with a placement-puzzle core |
| Hook | A small, readable seating puzzle every evening; a camp that visibly grows every morning |
| Audience | 13+; cozy and light-puzzle players on phones |
| Comparables | Good Pizza, Great Pizza (service loop) · Mini Motorways (placement under constraints) · Unpacking (calm, tactile) · Eastward (look) |
| Session | One in-game day takes about 4–6 minutes; safe to stop at any phase |
| Length | Main arc of about 34 in-game days for a median player (about 2.5–3.5 hours), then sandbox play and the Trail Daily. Volume II adds about 30 more days in v1.1 (§33) |
| Business model | Free to play and ad-supported: opt-in rewarded ads (Double tips on the Night summary, and a crew speed-up), an occasional interstitial between days, and a one-time Remove Ads purchase (§24). All three sites are free. No energy, premium currency or paywalled content; the only timers are the optional crew builds (§8.4) |
| Look | Eastward-style 3/4 top-down pixel art; mood from 2D lighting |
| Signature | A quiet Vietnamese layer in food, props, nature and sound (§15) |
| Team | One full-time developer, AI-assisted art with manual cleanup, licensed or CC0 audio. Re-plan after Phase 1 (§29) |

## 2. Premise and story

**You're reopening your grandfather's chain of forgotten trail campsites.**

Your grandfather was the Grand Trail's last warden. He kept a chain of rest stops from Pinewatch Forest to the coast, each one a chapter in his trail journal. When he stopped, the trail went quiet. You arrive at the first overgrown clearing with a backpack, a battered tent and that journal. Its first page says: *"The trail remembers those who tend it. Finish the book for me."*

So you rebuild, one site at a time. Relight the fire, host travelers, earn and reshape the camp until the site earns its stars, then follow the trail to the next one. Each site is a chapter: a forest camp, a river camp with a dock, a valley meadow under the stars. Travelers return, the trail wakes up, and the journal fills in.

v1 ships three sites: Pinewatch Forest, Whisper River and Lantern Valley. At each one, Ranger Mai's volunteer crew restores one of grandpa's old structures, and every finished stage turns up a keepsake from his life (§8.4). Grandpa's margin notes foreshadow Glasscoast and a hidden cove (Appendix D).

| Design need | What the story provides |
|---|---|
| Ordered unlocks | Grandpa's chain: each site is the next chapter |
| A goal beyond money | Finish the journal: pages, guests, field notes, recipes |
| Emotional hook | Restoration and hospitality — cozy, not conquest |
| Pacing | A letter from grandpa on most mornings |
| A reason to come back tomorrow | The crew's restorations, which finish in real time (§8.4) |
| Content runway | The margins tease the coast and the cove |

**Tone:** warm, quiet, gently funny. Modern characters (hoodies, thermoses, film cameras) and no magic. The companion is a stray dog who adopts you on the first night — not a familiar, just a good dog who sometimes digs up mushrooms.

## 3. Pillars

**Fantasy:** *the free life of a trail host — days outdoors, evenings by the fire, a camp that slowly becomes home.*

| Pillar | This means | This rules out |
|---|---|---|
| 1. Every evening is a small, fair puzzle | Deterministic scoring, a full preview before committing, conflicts designed into every board | Hidden stats, random rolls, placement timers, a Charm stat |
| 2. The camp is the reward | Every coin becomes something visible that changes tomorrow's puzzle | Stat sticks, consumable boosts, premium currency |
| 3. No pressure, still thinking | No fail state, debt or deadline; the player advances the day. The only real-time element is the optional crew (§8.4): it never blocks the arc and never expires | Energy, timers on the arc's critical path, streak penalties, upkeep and decay, FOMO, ads that interrupt a phase |
| 4. Alive in ten seconds, remembered forever | An inhabited cold open; nights replay your camp; everything becomes a journal entry | Menu-first starts, popup tutorials, invisible progress |

## 4. Core loop

| Loop | Length | Player does | Reward |
|---|---|---|---|
| Moment | Seconds | Drag a guest onto a pad and watch the stars change | Instant, readable feedback |
| Day | 4–6 min | Prep the camp, seat the guests, watch the night | Coins, reviews, a vignette |
| Chapter | About 9–14 days | Complete a site's five journal pages | The next site, a story beat |
| Arc | About 34 days | Three chapters | The finished journal; sandbox and Trail Daily; Volume II from v1.1 (§33) |
| Crew (beside the loop) | Hours of real time | Collect a finished stage, which starts the next | A keepsake; in the end a restored structure (§8.4) |

A day has four phases. The player ends each phase with one button; nothing in a day runs on a clock. Only the crew works in real time, beside the day (§8.4).

| Phase | Player does | Typical time | Ends with |
|---|---|---|---|
| Morning | Read grandpa's letter, check the forecast and the booking board, pick today's site on the trail map | 20–40 s | **Head out** |
| Prep | Forage, fish, cook, buy and place items, stock staples | 2–3 min | **Light the lanterns** |
| Evening | Guests arrive; drag their cards onto pads with a live star preview; Build mode stays available | 1–2 min | **Goodnight** |
| Night | Dinner is served, walk-ins eat, a vignette plays (skippable after 3 s), reviews and coins arrive, the journal updates, tomorrow's forecast shows | 30–60 s | **Sleep** (autosave) |

- Lighting follows the phase, not a clock (§16.3).
- Day 1 starts in Prep; there is no Morning on day 1 (§14).
- Quitting at any point resumes the same phase (§22).
- Ads appear only when the player taps a rewarded offer (Double tips on the Night summary, or a crew speed-up) and between Sleep and the next Morning (§24).

## 5. Hosting

### 5.1 Sites, cells and pads

- The camp is a grid of 64×64 px cells (2×2 tiles of 32 px).
- Each site has 8 pad spots. Pinewatch opens with 2, the other sites with 3. Locked spots look overgrown, and the player chooses which one to open next (prices §6.7).
- A pad fills 1 cell. Tent, platform and cabin art may overhang upward.
- Decor fills 1 cell, except four 2×1 items: Picnic Table, String Lights, Flower Arch and Swing.
- The camp core (pads, campfire and decor cells) is at most 10×4 cells, so the whole puzzle fits above the booking tray in a 640-px-wide view. Validate in Phase 1.
- Each site layout defines its pad spots, a hand-authored neighbour list (2–3 neighbours per pad), pad tags (Water, View), errand spots, a lookout and the crew plots outside the camp core (§8.4). Whisper River also marks bank cells along the water.
- An item affects a pad when any pad cell is within the item's radius of any item cell (Chebyshev distance; r1 means the 8 surrounding cells).
- Layout rule, enforced by a lint: an r1 item can reach about 2 pads, an r2 item about 4.
- Every site has a built-in campfire: Warmth r2, reaching about 3 pads. The Stone Fire Pit upgrade raises it to r3.
- Pad comfort: bare pad 0, Platform +1, Cabin +2. Cabins are also covered from rain.

| Effect | Sources | Read by |
|---|---|---|
| Warmth | Campfire, Stone Fire Pit | Chilly |
| Light | Lantern, String Lights, Silk Lantern | Night Owl (need), Stargazer (aversion) |
| Nature | Planter, Lotus Planter, Flower Arch | Nature Lover |
| Cover | Tarp; Cabins are always covered | Rain (§5.7) |
| Privacy | Hedge, Reed Screen | Introvert |
| Dog | Dog Bed | Dog Lover (need), Dog-wary (aversion) |
| Music | Guitar Stump, Wind Chime, Radio | Music Lover (need), Light Sleeper (aversion) |
| Play | Swing, Kite Pole | Kids |
| Stars | Telescope | Stargazer |
| Seats | Stools, Bench, Picnic Table | Walk-ins (§5.6) |
| Water, View | Pad tags in the layout | Angler, Shutterbug |

### 5.2 Bookings

- Each morning the booking board shows tonight's requests: open pads + 1, plus 1 more on in-game weekends (days 6 and 7 of every 7). Day 1 is scripted.
- A card shows the archetype, party size (1 pad, or 2 for a family), fee, trait icons and favourite meal. Until the player has cooked that recipe, the favourite shows as "??" with one of its two ingredients as a hint.
- The board is seeded by save, site and site day (§21.3), so reloading never rerolls it.
- From day 6, every board includes at least one conflicting pair (Social and Introvert, Loud and Light Sleeper, Night Owl and Stargazer).
- Families appear about one night in three once at least 4 pads are open. Their card stays disabled while no two neighbouring pads are free.
- The Food Blogger (elite) appears only while the site rating is at least 4.5, at most one per night.
- Regulars (§12.3) arrive on ribboned cards. Turning one away only delays their story.
- In the Evening the cards wait in the tray. Cards still in the tray at Goodnight leave politely: no penalty, no review.

### 5.3 Traits

| Trait | Condition | Type | Weight P / W / L |
|---|---|---|---|
| Chilly | Warmth in range | Need | 3 / 2 / 2 |
| Social | At least one occupied neighbouring pad | Need | 2 / 1 / 1 |
| Introvert | Privacy in range, or no occupied neighbour | Need | 2 / 2 / 1 |
| Nature Lover | Nature in range | Need | 2 / 1 / 2 |
| Night Owl | Light in range | Need | 2 / 2 / 1 |
| Music Lover | Music in range | Need | 1 / 2 / 1 |
| Light Sleeper | Music in range, or a Loud guest on a neighbouring pad | Aversion | 2 / 2 / 1 |
| Dog Lover | Dog in range | Need | 2 / 1 / — |
| Kids | Play in range of either family pad | Need | Families only |
| Angler | Water-tagged pad | Need | — / 3 / — |
| Shutterbug | View-tagged pad | Need | — / 2 / 2 |
| Stargazer | Stars in range (need); Light in range (aversion) | Both | — / — / 2 |
| Dog-wary | Dog in range | Aversion | — / — / 1 |

- Every check is binary: a need is met or not, an aversion is triggered or not.
- Traits per guest: 1 at Pinewatch on days 1–4, then 2. Families get Kids + 1. The Food Blogger gets 3, at least one of them an aversion.
- Each archetype's signature traits (§12.2) are drawn at double weight where the site's pool has them. The rest come from the site's pool with the weights above.
- Loud guests (Family, Van-lifer) show a Loud icon on their card.

### 5.4 Stars

```
stars = clamp(2 + comfort + meal + traits + weather, 1, 5)
```

| Term | Values |
|---|---|
| comfort | Bare pad 0 · Platform +1 · Cabin +2 |
| meal | Favourite +1 · another meal 0 · no meal −1 |
| traits | +1 per need met · −1 per aversion triggered |
| weather | −1 if it rains and the pad has no Cover · otherwise 0 |

- Families use the worse of their two pads for comfort and cover. A need counts if it is met on either pad; an aversion counts if it is triggered on either pad.
- There is no randomness: the same camp and the same guests always score the same.

| Example | Sum | Result |
|---|---|---|
| Hiker (Chilly, Nature Lover) on a Platform beside the fire and a Planter, favourite meal, clear night | 2 + 1 + 1 + 2 + 0 = 6 | 5★ |
| Couple (Light Sleeper, Introvert) on a bare pad next to a Loud Van-lifer, another meal, rain, no Tarp | 2 + 0 + 0 − 1 − 1 = −1 | 1★ |
| The same couple moved away from the Van-lifer, behind a Hedge, under a Tarp | 2 + 0 + 0 + 1 + 0 = 3 | 3★ |
| …and served their favourite | 2 + 0 + 1 + 1 + 0 = 4 | 4★ |

**Preview:**
- While a card is dragged, every free pad shows the stars that guest would get there.
- Holding over a pad opens a breakdown strip with one icon and number per term.
- Pads whose value changed because of the last move pulse once.
- The night summary shows the same breakdown for each review.

### 5.5 Dinner

- Meals are cooked during Prep (§7.5) and served automatically at Goodnight.
- Allocation maximises the night's total stars. A guest who can't get a favourite receives the cheapest remaining meal, which keeps pricier meals for walk-ins; ties also keep the pricier meal back.
- Dinner is included in a booked guest's fee. A guest with no meal takes −1.
- Walk-ins then buy leftovers (§5.6). Whatever remains goes to the dog (§9). Meals never carry over to the next day.

### 5.6 Reviews, tips, rating and walk-ins

- Each party leaves one review (1–5★) with a short comment based on its strongest term (at most 20 words).
- Each party tips according to its stars (§6.4).
- Site rating = mean of the last 15 reviews at that site (of all reviews while there are fewer than 15), shown to one decimal. Turning guests away never lowers it.
- Walk-ins per night = min(Seats, max(0, ⌊rating⌋ − 2)). Each buys one leftover meal at its menu price (§6.5), most valuable first; with no leftover there is no sale. Walk-ins don't review.
- A Food Blogger's 5★ stay adds one walk-in at that site the next night, still capped by Seats.

### 5.7 Weather

| Weather | Effect |
|---|---|
| Clear | None |
| Cloudy | Mood only |
| Rain | −1★ on uncovered pads; fishing gives +1 catch per spot |

- The morning forecast is always right.
- It never rains on a site's first day. Pinewatch day 4 rains by script (§14).
- Otherwise rain is seeded per site and day: about 1 day in 5 at Pinewatch, 1 in 4 at Whisper River and 1 in 6 at Lantern Valley.

## 6. Economy (single source of truth)

### 6.1 Rules

- One currency: coins. A new game starts with 0.
- No debt, upkeep, decay or price changes.
- Anything bought today can be returned for a full refund until Goodnight. Build mode (place, move, store, return) works in Prep and in the Evening. Items bought on earlier days can be moved or stored for free but not sold.
- Pads, upgrades and decor belong to their site. Gear, staples and catalog unlocks are global.
- Coins come only from guest fees and tips, walk-ins buying leftovers, page gifts, and the optional rewarded ad that doubles a night's tips (§6.4). There is no raw selling. Volume II (v1.1) adds a Gathering bonus (§6.11).
- Cosmetics have no effect and are left out of the sim.
- The crew (§8.4) costs and pays no coins in v1, so the sim leaves it out. Coins never buy crew time; only rewarded ads speed it up (§6.10).

### 6.2 Income model

From the median sim run (Appendix C, `tools/sim.py`):

| Source | Share of income |
|---|---|
| Fees + tips | 85% |
| Walk-ins | 9% |
| Page gifts | 6% |

Staples are about 8% of spending; the rest goes into pads, upgrades, decor and gear.

These shares assume no ads. With a rewarded ad every night, ads supply about 12% of all coins earned; with one on half the nights, about 5% (§6.8).

### 6.3 Guest fees

A party pays its fee for one night, dinner included. Fee = base × site multiplier (P ×1.0, W ×1.15, L ×1.3), rounded to the nearest 5 (halves round up). Regulars pay +20%, rounded the same way: Hùng 35, the Minh family 130, Old Ba 70, Lan 95.

| Archetype | Base | P | W | L |
|---|---|---|---|---|
| Scout | 30 | 30 | 35 | 40 |
| Hiker | 40 | 40 | 45 | 50 |
| Cyclist | 45 | — | — | 60 |
| Van-lifer | 50 | — | 60 | 65 |
| Angler | 50 | — | 60 | — |
| Couple | 55 | 55 | 65 | 70 |
| Photographer | 60 | — | 70 | 80 |
| Family (2 pads) | 110 | 110 | 125 | 145 |
| Food Blogger (elite) | 150 | 150 | 175 | 195 |

With the archetype mix in §12.2, the average single-pad fee is 45 at Pinewatch, 52 at Whisper River and 58 at Lantern Valley. These are the sim's inputs.

### 6.4 Tips

```
tip = fee × 10% × max(0, stars − 2)
```

So 3★ adds 10%, 4★ adds 20% and 5★ adds 30%.

**Rewarded ad:** from night 3, the Night summary offers one opt-in rewarded ad per in-game day that doubles that night's tips (§24). The button shows the exact coins. The sim models it with A, the share of nights on which the player doubles tips (Appendix C).

### 6.5 Meal prices

Walk-ins pay these prices. Booked guests' meals are included in their fee.

| Meal | Price | Meal | Price |
|---|---|---|---|
| Camp Mash | 5 | Iced Coffee | 25 |
| Herb Tea | 10 | Gỏi Cuốn | 25 |
| Berry Tea | 15 | Grilled Fish | 30 |
| Campfire S'mores | 15 | Berry Pie | 30 |
| Trail Sandwich | 15 | Caramel Custard | 30 |
| Trail Stew | 20 | Mì Quảng | 30 |
| Mushroom Skewers | 20 | Noodle Soup | 35 |
| Cơm Nắm | 20 | Honey Cakes | 35 |
| Chè | 20 | Cá Kho | 35 |
| Sinh Tố | 25 | Goldcap Skillet | 45 |
| Trà Mật Ong | 25 | | |
| Cà Phê Trứng | 30 | | |

The sim assumes an average walk-in meal of 18 at Pinewatch, 25 at Whisper River and 30 at Lantern Valley.

### 6.6 Page gifts

| Site | Page 1 | Page 2 | Page 3 | Page 4 | Page 5 |
|---|---|---|---|---|---|
| Pinewatch | 20 | 30 | 30 | 40 | 50 |
| Whisper River | 30 | 40 | 50 | 60 | 75 |
| Lantern Valley | 40 | 50 | 60 | 75 | 100 |

### 6.7 Prices

"From" names the journal page that unlocks an item (§8.1). "W arrival" and "L arrival" mean reaching that site.

**Pads** (open any locked spot; prices rise in this order):

| Site | Open at start | Next pads |
|---|---|---|
| Pinewatch | 2 | 120 · 200 · 300 · 420 · 580 · 750 |
| Whisper River | 3 | 190 · 290 · 410 · 560 · 750 |
| Lantern Valley | 3 | 220 · 350 · 500 · 680 · 900 |

**Upgrades:**

| Upgrade | P | W | L | From | Effect |
|---|---|---|---|---|---|
| Platform | 100 | 125 | 150 | P2 | Pad comfort +1 |
| Cabin | — | 275 | 325 | W arrival | Upgrades a Platform: comfort +2, always covered |
| Stone Fire Pit | 300 | 300 | 300 | P5 | Campfire Warmth r2 → r3; once per site |

**Decor** (same price at every site):

| Item | Effect | Reach | Size | Price | From |
|---|---|---|---|---|---|
| Stools | Seats | 1 seat | 1×1 | 25 | P1 |
| Bench | Seats | 1 seat | 1×1 | 40 | P2 |
| Picnic Table | Seats | 2 seats | 2×1 | 140 | P3 |
| Lantern | Light | r1 | 1×1 | 50 | P1 |
| String Lights | Light | r2 | 2×1 | 190 | P4 |
| Silk Lantern | Light | r2 | 1×1 | 225 | W2 |
| Planter | Nature | r1 | 1×1 | 45 | P1 |
| Lotus Planter | Nature | r1 | 1×1, bank cells allowed | 90 | W arrival |
| Flower Arch | Nature | r2 | 2×1 | 250 | L arrival |
| Tarp | Cover | r1 | 1×1 | 75 | P1 |
| Hedge | Privacy | r1 | 1×1 | 60 | P1 |
| Reed Screen | Privacy | r1 | 1×1, bank cells allowed | 75 | W arrival |
| Dog Bed | Dog | r2 | 1×1 | 55 | P1 |
| Guitar Stump | Music | r2 | 1×1 | 110 | P2 |
| Wind Chime | Music | r1 | 1×1 | 90 | W arrival |
| Radio | Music | r2 | 1×1 | 100 | W1 |
| Swing | Play | r2 | 2×1 | 150 | P4 |
| Kite Pole | Play | r1 | 1×1 | 90 | L arrival |
| Telescope | Stars | r1 | 1×1 | 275 | L arrival |

Bench (beside Stools) and Radio (beside Guitar Stump) are style alternatives with the same effect. Every other pair with the same effect differs in reach, footprint or placement.

**Gear** (global, bought once):

| Gear | Price | From | Does |
|---|---|---|---|
| Fishing Rod | 150 | P3 | Fishing (§7.2) |
| Cooler | 200 | W arrival | Pantry 20 → 30 |
| Binoculars | 250 | W3 | Spotting (§7.3) |
| Camp Oven | 380 | L arrival | Baked recipes (§7.5) |

**Staples** (5 each, bought at the Outfitter into the pantry): Bread, Tea and Marshmallow from P1; Rice from P2; Eggs from P3; Noodles from W arrival; Coffee and Sweet Milk from L arrival.

**Cosmetics** [S] (no effect; 1×1 and from P1 unless noted): Woodpile 20 · Clothesline 30 · Bird Feeder 35 · Pennant String 40 · Chicken Coop 60 · Hammock 120 (2×1) · Koi Pond 120 (2×1, from W4) · Moped 150. Free story gifts: Scout Pennant (Hùng, §12.3) and Photo Wall (Lan, L4).

### 6.8 Pacing

Median sim run, skill factor K = 1.25 (Appendix C, `tools/sim.py` extended model; median seed shown):

| | Pinewatch | Whisper River | Lantern Valley |
|---|---|---|---|
| Days at the site | 1–8 | 9–19 | 20–35 |
| Purchases per day | 1.88 | 2.27 | 2.50 |
| Days without a purchase | 1 | 0 | 1 |
| Net coins per day, first → last | 74 → 192 | 157 → 453 | 174 → 508 |
| Average stars, first → last | 2.5 → 4.5 | 3.3 → 4.1 | 3.0 → 4.2 |
| Most parties / walk-ins in a night | 4 / 1 | 7 / 2 | 8 / 2 |
| Day each page completes (1 · 2 · 3 · 4 · 5) | 1 · 8 · 5 · 6 · 8 | 12 · 19 · 12 · 16 · 16 | 30 · 29 · 35 · 27 · 32 |

- Whole arc: about 12,700 coins earned and about 12,700 spent; the peak balance while the site's build order still had items is 746 coins (median of seeds; p90 877).
- Casual player (K = 1.0): reaches Whisper River on day 11 and Lantern Valley on day 21, and finishes on day 36.
- Expert (K = 1.5): days 10, 19 and 34. Coins and pad prices pace the arc more than skill; experts mostly earn more stars and tips.

**With rewarded ads** (A = share of nights on which the player doubles tips; Appendix C):

| Run | Reaches W / L on day | Arc done on day | Purchases per day | Peak balance* | Coins from ads |
|---|---|---|---|---|---|
| Median, no ads | 10 / 19 | 35 | 1.88–2.50 | 746 | — |
| Median, A = 0.5 | 10 / 19 | 33 | 1.89–3.07 | 660 | 5% |
| Median, A = 1 | 10 / 19 | 33 | 1.88–3.14 | 668 | 12% |
| Casual, A = 1 | 10 / 20 | 33 | 2.00–3.23 | 659 | 13% |
| Expert, A = 1 | 10 / 18 | 31 | 1.88–3.69 | 643 | 13% |

\* Peak while the site's build order still had items (median of seeds). After the order empties, income can't leave the wallet — that hoard is the leftover-order problem §6.11 sizes, not an arc-phase sink failure.

- Ads shorten every variant a little in the extended model: about 6–9% sooner (35 → 33, 36 → 33 and 34 → 31 days). The older baseline's "ads don't shorten the median" was an artifact of an always-open catalog; with unlock gating and non-blocking purchases, ad coins help.
- The 90th-percentile peak stays under 900–950 with ads. In rare seeds (~3%) a page unlock stalls the next buy and the balance can sit near 3,000 coins before the order empties — transient by construction, and Volume II's restoration sink exists for exactly this hoard.

### 6.9 Guardrails

CI runs the sim against the real data files, without ads (A = 0) and with an ad every night (A = 1, the upper bound). A change that breaks a guardrail fails the build. "No ads" is the median run; "Ads every night" is the worst of the median, casual and expert runs.

| Guardrail | Target | No ads | Ads every night |
|---|---|---|---|
| Median Pinewatch chapter complete | Day 8–11 | 9 | 9 |
| Arc complete: median / casual | 30–40 / ≤ 50 days | 35 / 36 | 33 / 33 |
| Ads shorten an arc by at most | 15% | — | 6–9% |
| Purchases per day, each site | ≥ 1.4 | 1.88–2.50 | 1.88–3.69 |
| Days without a purchase, each site | ≤ 2 without ads, ≤ 3 with | 0–1 | 0–1 |
| Share of income from fees + tips | ≥ 75% without ads | 85% | ~74–76%† |
| Coins from ads | ≤ 15% of income | — | 12–13% |
| Peak balance while order has items: median / p90 | ≤ 800 / 900 without ads · ≤ 950 / 950 with | 746 / 877 | 643–668 / 860–893 |
| No page needs an item unlocked by a later page | Holds | Holds | Holds |

† With ads, fees+tips land just under 75% by construction (ads take ~13%); the no-ads run is the meaningful check.

Peak balance is measured only while the active site's build order still had items — once it empties, income can't leave the wallet, and that accumulation is the post-arc problem §6.11 prices (Appendix C 3.1). The 90th-percentile bound makes the check test the tail, not just the median seed: rare seeds (~3%) stall near 3,000 coins while page-locked before the order empties, transient by construction. Two targets are looser with ads because the bot reaches Lantern Valley's 500-, 680- and 900-coin pads with nothing cheaper left on its list, and saves for them.

### 6.10 Crew time

The crew (§8.4) is the game's only real-time system. Its times live here with the other numbers, and in Remote Config with these defaults built in (§24).

| Structure | Site | Stage 1 | Stage 2 | Stage 3 | Total |
|---|---|---|---|---|---|
| Warden's Hut | Pinewatch | 10 min | 4 h | 8 h | 12 h 10 min |
| Boathouse | Whisper River | 1 h | 4 h | 8 h | 13 h |
| Lantern Workshop | Lantern Valley | 2 h | 6 h | 12 h | 20 h |

**Speed-up** (a rewarded ad, §24):
- Each ad removes one chunk of the current stage: chunk = max(15 min, stage time ÷ 6). The button shows it ("▶ −40 min").
- At most 3 speed-ups per stage and 6 per calendar day. Finish is free once 5 minutes or less remain.
- Three speed-ups halve any stage of 90 minutes or more, so ads shorten waits but never remove them. Coins never buy time.

| Stage time | Chunk | Left after 3 speed-ups |
|---|---|---|
| 10 min | 15 min | Done after 1 |
| 1 h | 15 min | 15 min |
| 2 h | 20 min | 1 h |
| 4 h | 40 min | 2 h |
| 6 h | 1 h | 3 h |
| 8 h | 1 h 20 min | 4 h |
| 12 h | 2 h | 6 h |

**Pacing check:** a player who plays once a day for about 20 minutes collects about one stage a day, so the crew's 9 stages take about 9 real days. That is about as long as the arc takes at that rate (34 in-game days of 4–6 minutes, about 8.5 real days). Phase 3 playtests and closed-test data replace this estimate (Q12).

### 6.11 Volume II (v1.1, draft)

Volume II (§33.3) gives coins a job after the finale. These numbers are a draft, checked at the v1.1 gate by a post-arc mode in `tools/sim.py` (Appendix C).

**Restorations** (two per site, three stages each; the player pays for a stage, then that site's crew team works on it):

| Restoration | Site | Stage costs | Effect when restored |
|---|---|---|---|
| Fire Tower | P | 300 · 500 · 700 | View tag on about 3 pads (set in the layout); Photographers join the Pinewatch mix at 10%, taken from Couples |
| Pond Dock | P | 300 · 500 · 700 | Water tag on about 2 pads; Anglers join the Pinewatch mix at 10%, taken from Hikers |
| Bamboo Treehouse | W | 400 · 600 · 800 | A 9th pad with no neighbours: View tag, Cabin comfort, always covered |
| Bathhouse | W | 400 · 600 · 800 | Warmth r2 |
| Observatory | L | 500 · 700 · 900 | Stars r3 (about 4 pads) |
| Long Table | L | 500 · 700 · 900 | Seats +2; the walk-in limit from the rating rises by 1 (§5.6) |

- Every restoration stage takes 1 h · 4 h · 8 h of crew time, with speed-up chunks of 15 min · 40 min · 1 h 20 min (§6.10).
- In Volume II the crew splits into three teams, one per site, each working on one stage at a time.
- Totals: Pinewatch 3,000, Whisper River 3,600, Lantern Valley 4,200; 10,800 in all.
- Pinewatch fees for its new archetypes, by the §6.3 formula: Photographer 60, Angler 50.
- Volume II page gifts: 60 per page at Pinewatch, 80 at Whisper River and 100 at Lantern Valley.
- Gathering bonus: +25% of the Gathering's fees when its brief is met (§33.3).
- Verify: the Treehouse's 9th pad fits the 640-px view (§5.1).

**Sizing:** 10,800 coins of restorations, plus about 5,000 of Pinewatch and Whisper River items a median player hasn't bought yet, is about 15,800 coins: about 26 in-game days at the post-arc rate of about 600 a day (Appendix C). The target is 25–40 days. A player who plays about 20 minutes a day can start about three stages a day, one per team, so coins and the crew keep about the same pace. Players with longer sessions wait on the crew and play pages 8–10 meanwhile (§33.3).

**Guardrails** (checked at the v1.1 gate, assuming 4 in-game days per real day):

| Guardrail | Target |
|---|---|
| Median Volume II complete | 25–40 in-game days after the finale |
| A purchase or a stage start, each site | At least every 2 in-game days |
| Highest coin balance until Volume II is done | ≤ 2,500 |
| Coins from ads | ≤ 15% of income |
| No Volume II page needs an unlock from a later page | Holds |

## 7. Errands and cooking

### 7.1 Forage

- Each site has 6 forage nodes per day with 2 items each; hold for 1.5 s to gather. Nodes regrow overnight, and their positions and contents are seeded (§21.3).
- The dog digs up 1 bonus item per day (§9).

| Site | Finds |
|---|---|
| Pinewatch | Mushroom, Herb, Berries; Goldcap (rare, about 1 day in 3) |
| Whisper River | Mushroom, Herb, Berries |
| Lantern Valley | Herb, Berries, Honey |

### 7.2 Fishing

- Needs the Fishing Rod. Each spot gives 3 catches per day (+1 in rain).
- Cast, wait for a bite (2–6 s), then tap within 0.8 s (1.5 s in Assist mode). A miss costs nothing.
- This is the only timed input in the game.

| Site | Spots | Fish |
|---|---|---|
| Pinewatch | Pond ×1 | Perch, Carp |
| Whisper River | River ×2 | Trout, Catfish, Carp |
| Lantern Valley | Stream ×1 | Trout |

The Golden Koi appears only in Old Ba's story (W4). It is caught and released, and logged in Field Notes.

### 7.3 Spotting [S]

- Needs the Binoculars. Once per day per site, the lookout logs one bird not yet in Field Notes and reveals one bonus forage node for that day. When a site's birds are all logged, the lookout still reveals the bonus node.
- Pinewatch: Jay, Woodpecker, Red-whiskered Bulbul, Tawny Owl.
- Whisper River: Kingfisher, Heron, Wagtail, Dipper.
- Lantern Valley: Skylark, Bee-eater, Hoopoe, Kestrel.
- If spotting is cut, the Binoculars go with it and W3 gives only its coin gift. The sim impact is negligible, because the Binoculars are the last item in the sim's Whisper River build order.

### 7.4 Pantry

- 20 slots (30 with the Cooler), one ingredient or staple per slot. Nothing spoils.
- When the pantry is full, a forage node keeps its items until there is room.

### 7.5 Cooking

- Cook at the campfire; baked recipes need the Camp Oven. Every recipe is a unique pair of ingredients ("any fish" counts as one ingredient).
- Pick two ingredients to cook one portion. Known recipes offer Cook ×N.
- An unknown pair makes Camp Mash, a basic meal. The recipe book logs every pair tried.
- An oven pair tried at the campfire shows a hint and keeps the ingredients.
- Hints come from letters and from "??" favourites on booking cards.
- Meals last until Goodnight (§5.5).

| Recipe | Ingredients | Station | Needs | Look |
|---|---|---|---|---|
| Trail Stew | Mushroom + Herb | Campfire | — | Taught on day 1 |
| Mushroom Skewers | Mushroom + Mushroom | Campfire | — | |
| Herb Tea | Herb + Tea | Campfire | — | |
| Berry Tea | Berries + Tea | Campfire | — | |
| Campfire S'mores | Marshmallow + Bread | Campfire | — | |
| Trail Sandwich | Bread + Herb | Campfire | — | Bánh mì silhouette |
| Goldcap Skillet | Goldcap + Herb | Campfire | — | Rare |
| Grilled Fish | Any fish + Herb | Campfire | Fishing Rod | |
| Noodle Soup | Noodles + any fish | Campfire | Fishing Rod | Phở-style bowl |
| Iced Coffee | Coffee + Sweet Milk | Campfire | — | Phin filter |
| Cơm Nắm | Rice + Mushroom | Campfire | — | Charred rice balls |
| Gỏi Cuốn | Rice + Herb | Campfire | — | Fresh spring rolls |
| Mì Quảng | Noodles + Mushroom | Campfire | — | Turmeric noodles |
| Chè | Rice + Sweet Milk | Campfire | — | Sweet sticky-rice soup |
| Cá Kho | Any fish + Honey | Campfire | Fishing Rod | Clay-pot fish |
| Sinh Tố | Berries + Sweet Milk | Campfire | — | Fruit smoothie |
| Cà Phê Trứng | Coffee + Eggs | Campfire | — | Whipped egg coffee |
| Trà Mật Ong | Honey + Tea | Campfire | — | Warm honey tea |
| Berry Pie | Berries + Bread | Oven | Camp Oven | |
| Honey Cakes | Honey + Bread | Oven | Camp Oven | |
| Caramel Custard | Sweet Milk + Honey | Oven | Camp Oven | Bánh flan |

Pinewatch offers 9 recipes without the Fishing Rod, so P3 ("Cook 5 different recipes") never depends on it.

## 8. Progression

### 8.1 Journal pages

Each site has five pages, completed in any order. A page pays its gift (§6.6), stamps an illustration and may unlock items. Completing all five finishes the chapter and opens the next site.

| Page | Goal | Unlocks |
|---|---|---|
| P1 | Relight the fire (day 1) | The Outfitter (from day 2); Stools, Lantern, Planter, Hedge, Tarp, Dog Bed; Bread, Tea, Marshmallow |
| P2 | Welcome 20 guests (a family counts once) | Platform, Bench, Guitar Stump |
| P3 | Cook 5 different recipes | Fishing Rod, Picnic Table |
| P4 | Host a family | Swing, String Lights |
| P5 | Reach a 4.0 rating | Stone Fire Pit |
| Chapter 1 | — | Whisper River |
| W arrival | — | Reed Screen, Wind Chime, Lotus Planter, Cabin, Cooler, Noodles |
| W1 | Catch 3 kinds of fish here (needs the Fishing Rod) | Radio |
| W2 | Host 6 Anglers on Water pads | Silk Lantern |
| W3 | Three 5★ reviews in one night | Binoculars |
| W4 | Old Ba's golden koi (his story) | Koi Pond |
| W5 | Reach a 4.2 rating | — |
| Chapter 2 | — | Lantern Valley |
| L arrival | — | Telescope, Kite Pole, Flower Arch, Camp Oven, Coffee, Sweet Milk |
| L1 | A Stargazer gives 5★ | — |
| L2 | Bake all 3 oven recipes | — |
| L3 | Full house: 8 occupied pads in one night | — |
| L4 | Lan's exhibition (her story) | Photo Wall |
| L5 | Reach a 4.4 rating | — |
| Chapter 3 | — | Finale letter; Glasscoast appears on the map as "coming later" |

- Rating pages need at least 15 reviews at that site, so one lucky night can't complete them.
- Unlocks are tied to specific pages (D-14). The Phase −1 sim models the gating itself: locked items stay queued until their page lands, and no purchase is blocked in any seed (Appendix C).

### 8.2 Site rules

- One site per day, chosen on the trail map in the Morning. Other sites wait: no offline income and no decay. The crew works in real time whichever site the player is at (§8.4).
- Completed sites stay open as sandboxes. Bookings, rating and walk-ins carry on.
- Letters arrive in order, at most one per morning. Each has a trigger: the Nth morning at a site, or an event such as a family's first booking or a finished chapter. Event letters go first; unread letters wait in the journal.

### 8.3 Journal

| Section | Entries | Filled by |
|---|---|---|
| Chapters | 15 pages | Completing pages |
| Guestbook | 13 (9 archetypes + 4 regulars) | A first stay; a regular's finished story |
| Field Notes | 22 (5 forage finds, 5 fish including the Golden Koi, 12 birds) | A first find, catch or sighting |
| Recipes | 21 | A first cook |
| Keepsakes | 9 (3 per site) | Collecting a crew stage (§8.4) |
| Letters | 25 | Reading |
| Days log | One line per day | Each night: site, weather, guests, best review, coins |

The cover shows completion as a percentage of the 72 collectible entries (Chapters, Guestbook, Field Notes, Recipes, Keepsakes).

### 8.4 The crew and grandpa's structures

On day 2, Ranger Mai's van drops off a small volunteer crew. At each site they restore one of grandpa's old structures in three stages that take real time (§6.10), and every stage turns up a keepsake from his life. This is the game's only real-time system, and it runs beside the day: it never blocks a page, a chapter or a site, costs nothing in v1 and never expires (D-23).

| Structure | Site | Keepsakes, one per stage | When restored |
|---|---|---|---|
| Warden's Hut | Pinewatch | Grandpa's thermos (brambles cleared) · the old trail register (roof fixed) · a photo of him on the porch (porch rebuilt) | "Porch light" vignette [S] |
| Boathouse | Whisper River | An oar carved with two sets of initials · his river chart · the boat he shared with Old Ba, afloat again | "Boat on the river" vignette [S] |
| Lantern Workshop | Lantern Valley | Bamboo frames and rice paper · his pattern book · his last unfinished lantern, which you finish | "Lanterns over the valley" vignette [S] |

**Rules:**
- One crew works on one stage at a time, in site order. The hut's first stage starts by itself on day 2; the Boathouse and the Workshop start by themselves once the player has reached their site and the crew is free.
- Stages run in real time, including while the app is closed and whichever site the player is at.
- A finished stage shows a bubble on the structure and on the site's trail-map marker; nothing pops up. Collecting it (tap either) plays a 2–4 s ceremony (§17.3), adds the keepsake to the journal (§8.3) and starts the next stage.
- A keepsake is a journal entry: an illustration and a note of at most 80 words (§13.1). In v1 the crew gives no coins, stars, tags or unlocks, so it never touches the economy or the puzzle.
- Nothing waits on the crew and nothing expires; a finished stage stays ready until collected.
- The crew sheet (§17.2) shows the stage, the time left, Collect, the speed-up offer and Finish. It opens from the structure or its trail-map marker in the Morning and Prep; never in the Evening or the Night.
- Speed-ups are rewarded ads (§6.10, §24), offered from day 4 and never in the Evening, the Trail Daily or onboarding.
- Clock: progress counts in UTC, and each check adds max(0, now − last seen). Setting the device clock back never undoes work; setting it forward finishes stages early, an accepted risk while keepsakes are the only reward (§32).
- The structures stand on crew plots outside the camp core (§5.1), so they never take pad or decor space. Each layout also reserves 2 overgrown plots for Volume II's restorations (§6.11); in v1 they are scenery.
- Keepsake notes are side stories about grandpa; the main reveals stay in the letters (§13.1). The Workshop's last keepsake may foreshadow the cove once its story is settled (Q8).

## 9. The dog

- On night 1 a stray turns up by the fire and eats the leftover stew. The player names it (default Bean in English, Bơ in Vietnamese). Its collar tag reads "B.", a story thread for after v1 (Appendix D).
- It follows the player, lies by the fire in the evening and sleeps on the Dog Bed if there is one.
- It digs up 1 bonus forage item per day.
- Bond (4 levels) grows from a daily pet and from leftovers. Each level unlocks a cosmetic trick; the last is chasing the đá cầu shuttlecock (§15).
- It has no needs, causes no penalties and can't be lost.
- The Dog effect on guests comes only from the Dog Bed, never from where the dog wanders, so scoring stays deterministic.

## 10. Trail Daily [S]

- One shared puzzle per calendar day, offline. It unlocks with Pinewatch letter 6.
- Pinewatch traits and items only, no families, clear weather. The puzzle has 5 pads, a kit of 4 decor items to place, 6 requests of which 5 can be seated, and 5 ready-cooked meals of 4 kinds (allocated as in §5.5). The kit may include Pinewatch items the player hasn't unlocked yet.
- Score = total stars, out of 25. No coins, so it never touches the economy.
- One scored attempt per day; unlimited practice afterwards.
- Share text: "Trailbound Daily #N — x/25" followed by one row of stars per guest. N counts days since launch.
- Seed = hash("daily", local device date). No leaderboard or Trail Passport until v1.1 (§33.5), and no streaks.
- A CI solver checks the next 400 dailies. A seed is rerolled deterministically if its best score is below 22, or if a naive placement scores within 2 of the best.
- A compact layout that reuses Pinewatch art.
- No ads inside the Daily (§24).

## 11. Sites

| | Pinewatch Forest | Whisper River | Lantern Valley |
|---|---|---|---|
| Chapter | 1 | 2 | 3 |
| Palette | Deep greens, ember orange | River blues, bamboo green | Golden meadow, dusk violet |
| Pads at start / max | 2 / 8 | 3 / 8 | 3 / 8 |
| Pad tags | None | 3 Water, 2 View | 3 View |
| Errands | Forage, pond, lookout | Forage, river ×2, lookout | Forage (with Honey), stream, lookout |
| New archetypes | Hiker, Scout, Couple, Family | Van-lifer, Angler, Photographer | Cyclist |
| New traits | 9 base traits, including Kids | Angler, Shutterbug | Stargazer, Dog-wary |
| Signature features | Campfire circle under the pines | Bamboo bridge, lotus pads, dock | Terraced hills behind, a banyan, a telescope deck |
| Crew structure (§8.4) | Warden's Hut | Boathouse | Lantern Workshop |
| Regulars | Hùng, the Minh family | Old Ba | Lan |
| Rain | About 1 day in 5 | About 1 in 4 | About 1 in 6 |
| Rating page | 4.0 | 4.2 | 4.4 |

Glasscoast and the hidden cove are only foreshadowed in v1 (Appendix D).

## 12. Cast

### 12.1 Main characters

| Character | Role | Notes |
|---|---|---|
| You | The new warden | Hoodie, fixed look, never named, no dialogue choices |
| Grandpa | Letters, journal margins, one photo | Never appears in person |
| Ranger Mai | Tutorial guide; drives the Outfitter van from site to site and brings the volunteer crew (§8.4) | Short lines; never blocks play |
| The dog | Companion (§9) | Named by the player |

### 12.2 Guest archetypes

| Archetype | Pads | Signature traits | Loud | Sites |
|---|---|---|---|---|
| Hiker | 1 | Chilly, Nature Lover | | All |
| Scout | 1 | Social, Dog Lover | | All |
| Couple | 1 | Introvert, Light Sleeper | | All |
| Family | 2 neighbouring | Kids + 1 | Yes | All, once 4 pads are open |
| Van-lifer | 1 | Music Lover, Night Owl | Yes | W, L |
| Angler | 1 | Angler (always) | | W |
| Photographer | 1 | Shutterbug (always) | | W, L |
| Cyclist | 1 | Chilly, Stargazer | | L |
| Food Blogger (elite) | 1 | 3 traits, at least one an aversion | | Any site rated 4.5 or more; at most 1 per night |

Single-pad archetype mix by site:

| Archetype | P | W | L |
|---|---|---|---|
| Hiker | 35% | 25% | 20% |
| Scout | 20% | 25% | 20% |
| Couple | 45% | 10% | 15% |
| Van-lifer | — | 10% | 10% |
| Angler | — | 20% | — |
| Photographer | — | 10% | 10% |
| Cyclist | — | — | 25% |

### 12.3 Regulars

| Regular | Site | Story | Reward |
|---|---|---|---|
| Hùng, a scout [S] | P | Earns a camping badge over 3 visits | Scout Pennant (cosmetic) |
| The Minh family | P | Weekend visitors; the kids play đá cầu | Usually your first family (P4) |
| Old Ba, a retired angler | W | Knew grandpa; after 3 visits the golden koi appears | W4 |
| Lan, a photographer | L | 3 visits, then an exhibition of her photos of your camp | L4 and the Photo Wall |

- Regulars book about every third day at their site until their story ends.
- Other guests' names come from an international pool that includes a few Vietnamese names (Bích, Tuấn, Thảo).

## 13. Narrative

### 13.1 Structure

- About 25 letters: 10 at Pinewatch, 7 at Whisper River, 7 at Lantern Valley and a finale.
- 9 keepsake notes, one per crew stage (§8.4): side stories about grandpa, never the main reveals, which stay in the letters.
- Ranger Mai's short notes announce unlocks and explain mechanics in context. They also fill mornings after a site's letters run out.
- Each site's arc: arrival → the regular's story → a reveal about grandpa → the rating payoff. Whisper River and Lantern Valley letters are written to this shape in Phase 4.
- The finale, "The trail continues": grandpa's last margin note points to Glasscoast and a hidden cove. The cove's story must be settled before the Pinewatch letters are written, so they can foreshadow it (Q8). Ranger Mai then hands the player a blank second volume; until v1.1 it reads "coming soon", with no date (§33.2).

### 13.2 Voice

- Letters are at most 80 words; guest lines at most 20. No puns that can't survive translation.
- Vietnamese is adapted, not translated literally: grandpa writes as "Ông" to "cháu".
- All narrative text ships as data inside the app; there is no remote content.

### 13.3 Pinewatch letters

| # | Trigger | Theme | Introduces |
|---|---|---|---|
| 1 | Day 1, the journal's first page | "Finish the book for me" | The journal, the fire |
| 2 | Morning 2 | "The trail remembers" | The booking board, the Outfitter |
| 3 | Morning 3 | "Some like company, some like quiet" | Social and Introvert; choosing pads |
| 4 | Morning 4 | Rain on canvas | The forecast, the Tarp |
| 5 | Morning 5 | "Nobody wants just one thing" | Two traits per guest |
| 6 | Morning 6 | Grandpa's practice camp | The Trail Daily |
| 7 | Morning 7 | "A full pot is a full camp" | Recipes, experimenting |
| 8 | The morning a family first books | Families and noise | Loud guests and Light Sleepers |
| 9 | Morning 9 | Word of mouth | Rating, walk-ins, Seats |
| 10 | The morning after the chapter completes | "Further up the river…" | Whisper River, the trail map |

### 13.4 Night vignettes

| Vignette | Trigger | Priority |
|---|---|---|
| Campfire song | Guitar Stump + a Music Lover | [M] |
| Đá cầu rally | A family + Play in range | [M] |
| Dog's rounds | A Dog Bed is placed | [M] |
| Rain on tarps | A rainy night | [M] |
| Fireflies | A clear night + 2 or more Nature items | [M] |
| Quiet night | Fallback | [M] |
| Stargazing | Telescope + a Stargazer | [S] |
| Reading by lantern | A Night Owl in Light | [S] |
| Slow dance | A Couple + String Lights | [S] |
| Old Ba's fish story | Old Ba is staying | [S] |
| Lan's long exposure | Lan is staying (no flash) | [S] |
| Marshmallow roast | A Chilly guest + S'mores served | [S] |
| Porch light | The Warden's Hut is restored (once) | [S] |
| Boat on the river | The Boathouse is restored (once) | [S] |
| Lanterns over the valley | The Lantern Workshop is restored (once) | [S] |

- One vignette per night, 6–12 s, skippable after 3 s. It replays your actual camp and guests.
- Unseen vignettes play first. Among the eligible ones, the trigger with the most matching guests wins.
- A restoration vignette plays on the first night the player spends at that site after the structure is restored, ahead of any other unseen vignette.

## 14. Onboarding

**Rule:** one new idea per day, and the scene is the tutorial. No popups or walls of text.

**Day 1:**

| Beat | What happens | Teaches |
|---|---|---|
| Cold open | First launch skips the title screen and opens on the overgrown clearing at golden hour. The journal's first page reads "Finish the book for me" | Mood, the journal |
| The fire | Ranger Mai: "Help me get this fire going." Tap the fire ring; P1 is stamped | Tapping objects, pages |
| Supper | Gather from two forage nodes, then cook Trail Stew twice. The Ranger teaches the recipe and adds a spare portion | Forage, cooking |
| Guests | "Light the lanterns": two travelers with one trait each. Drag them onto pads; one sentence explains the stars | Seating, the preview |
| Night | "Goodnight": a vignette, then reviews and coins | The night |
| The dog | A stray eats the leftover stew; the player names it | The dog |
| Sleep | "Sleep" autosaves; letter 2 arrives next morning | Advancing the day |

**Days 2–7:**

| Day | New idea |
|---|---|
| 2 | A booking board with 3 requests for 2 pads, so someone is turned away; Ranger Mai opens the Outfitter, and her van drops off a volunteer crew who start clearing grandpa's hut (§8.4) |
| 3 | The Ranger suggests opening a third pad; neighbours start to matter (Social, Introvert) |
| 4 | Scripted rain; the Tarp |
| 5 | Guests now have two traits |
| 6 | The first guaranteed conflict; the Trail Daily unlocks |
| 7 onward | New items arrive through pages |

**The crew in onboarding:** the crew needs nothing from the player on day 2. When the 10-minute first stage is done, a bubble appears on the hut; collecting it shows grandpa's thermos, starts the 4-hour roof and asks once about the crew notification (§17.6).

**Ads in onboarding:** none on days 1 and 2. Where the law requires it, the privacy consent form shows once, at the start of Morning 2, after the cold open and the first night. Rewarded offers start on night 3 (the crew speed-up on day 4) and interstitials on day 5 (§24).

Settings → "Ranger's tips" replays any tip.

## 15. Vietnamese signature

**Intent:** the game never says "Vietnam", but players who know will feel it over the weeks. Each detail is deniable on its own; only the pattern gives it away.

**Rule:** no Vietnamese text in the English build, no flag and no named real places. The Vietnamese build keeps the same generic names.

| Channel | Details |
|---|---|
| Food | Iced Coffee in a phin filter with condensed milk; a phở-style Noodle Soup; a Trail Sandwich with a bánh mì silhouette; Caramel Custard as bánh flan |
| Props | Low red and blue plastic Stools; Silk Lanterns; Lotus Planters; a bamboo bridge; a Cub-style Moped; a nón lá hanging on the Outfitter van; Pennant String |
| Nature | Bamboo clumps, a banyan as the big tree, the red-whiskered bulbul (chào mào) |
| Backdrops | Terraced hills behind Lantern Valley; karst islets in the Glasscoast teaser |
| Costumes | Hùng's red scarf, Old Ba's green pith helmet, a nón lá on one traveler |
| Animation | The Minh kids play đá cầu |
| Sound | A rooster at dawn, free-range chickens (Chicken Coop), cicadas at dusk |
| Names | A few Vietnamese guest names in an international pool |
| Later | Lunar New Year and Mid-Autumn festival weeks: star lanterns, rice cakes, mooncakes (v1.2, §33.4) |

**Đá cầu animation:**
- The kids' play animation has kick, ready and balance poses without the shuttlecock.
- The shuttlecock is a separate sprite of about 8×12 px with tucked, flared and squash frames. Simple physics drives it: an impulse on each kick, normal gravity on the way up, a slow drag-limited fall with the feathers open, and slight randomness so no two rallies match. It z-sorts with characters.
- A rally ends when the shuttlecock drops: a kid picks it up, or the dog pounces (§9).

The identity stays subtle (D-07, confirmed; Q2 resolved).

## 16. Art direction

### 16.1 Targets

| Reference | Use |
|---|---|
| `reference/eastward.jpg` | Primary: fixed 3/4 top-down view (flat ground, object fronts), painterly soft-dithered pixel art, bright lush daylight |
| `reference/example.png` | Prop density and the ember-lit dusk mood, which comes from lighting rather than baked-in art |
| `reference/eastward_ui.webp` | UI: cream paper panels, forest green and ember gold accents, chunky rounded controls |

### 16.2 Technical rules

- 640×360 base resolution with integer scaling (§20).
- 32 px tiles and 64 px placement cells.
- Characters about 48 px tall in 64×64 frames, anchored bottom-center.
- One pixel density everywhere, enforced on import.
- One sun angle and one wind direction across all assets.
- A contact shadow under every object and character.
- A locked palette per site.
- Atlases with 2 px padding, no mipmaps and nearest filtering.

### 16.3 Lighting by phase

| Phase | Look |
|---|---|
| Morning | Soft light; low mist over grass and water |
| Prep | Full daylight; drifting cloud shadows |
| Evening | Golden hour; the lanterns and the fire come up |
| Night | Blue CanvasModulate; warm PointLight2D on the fire and lights; additive glow sprites; fireflies |
| Rain | Darker tint, rain overlay, wet sheen, puddle decals |

### 16.4 Production tells and QA gates

Ten details separate a shipped game from a toy:

| # | Tell | Production standard |
|---|---|---|
| 1 | Pixel density | One pixel size everywhere |
| 2 | Contact shadows | A soft shadow under every object and character |
| 3 | Embedded objects | Grass and debris decals overlap prop bases |
| 4 | Terrain depth | Base texture + tuft clusters + 1–2 px specks |
| 5 | Wear | Moss, scuffs and patches break up large surfaces |
| 6 | Micro-states | Interactive objects have open, occupied and lit variants |
| 7 | Directional consistency | One sun angle and one wind vector |
| 8 | Idle life | Blinks, breathing, cloth sway, tail wags |
| 9 | Transitions | In-between frames instead of popping states (pot: empty → cooking → done) |
| 10 | Atlas hygiene | Padding, no mipmaps, palette lock |

**QA gates on every batch:**
1. Import lint: uniform pixel size, no stray 1 px orphans, feet anchored bottom-center.
2. Palette reduction of the whole batch to the shared ramp.
3. Shadow check: every cast shadow points the same way.
4. Outline check: consistent outline weight on characters and props.

Tells 1–3 and 8 close most of the gap cheaply. Do them before any new feature art.

### 16.5 Density

Eastward's richness comes from detail assets placed with judgment. Three layers:
1. **AI detail library:** batched clutter families (weeds, petals, leaf litter, pebbles, scuffs, pinecones) and weathered variants of base props.
2. **Seeded scatter rules:** deterministic per site, about one detail per two tiles, placed by rule rather than noise (tufts near trees, wear near paths and the fire, petals near planters).
3. **Hero spots:** 3–4 hand-polished spots per site where players look longest (the fire circle, the dock bend, the gate corner).

## 17. UI and UX

### 17.1 Principles

- Landscape, respecting safe areas and cutouts.
- Status lives on objects (a lit lantern, a steaming pot), not in panels.
- HUD: at most four pills (coins, day and weather, rating, journal badge) plus one phase button. Chrome fades after about 3 s idle.
- Proximity bubbles over interactive objects; tap to walk.
- Signs are buttons: the site sign opens that site's journal page, the trail sign opens the map and the notice board opens the booking board.
- Touch targets of at least 48 dp, with hit areas larger than the art.
- Any placement or purchase can be undone until Goodnight.

### 17.2 Screens

| Screen | Purpose |
|---|---|
| Title | Continue, settings, credits; skipped on first launch |
| Camp | The world: errands, objects, the phase button |
| Booking board | Tonight's requests with traits, fees and favourites |
| Build mode | Place, move, store and return items; radius rings; a ghost preview with star changes |
| Evening tray | Guest cards to drag onto pads; live star preview and breakdown strip |
| Pantry and cooking | Ingredients, pair picker, recipe book, Cook ×N |
| Outfitter | The catalog in tabs: decor, pads and upgrades, gear, staples, cosmetics; the Remove Ads offer at the end (§24) |
| Night summary | Reviews with breakdowns, tips, walk-ins, coin tally, page progress, tomorrow's forecast; the opt-in "Double tips" ad (§24) |
| Journal | Chapters, Guestbook, Field Notes, Recipes, Keepsakes, Letters, Days log |
| Trail map | Site choice and locked sites; crew status and ready bubbles on each site (§8.4); the Glasscoast teaser after the finale |
| Crew sheet | The current stage and time left, Collect, the speed-up offer and Finish (§8.4, §24); opened from the structure or its trail-map marker in the Morning and Prep |
| Remove Ads | The one-time Remove Ads offer and restore, opened from Settings or the Outfitter (§24) |
| Trail Daily | The daily puzzle, result and share |
| Settings | §17.4 |

### 17.3 Feel

- Smoke and mist wipes between scenes; squash on press; guests walk in rather than pop in.
- Short ceremonies (2–4 s) for a page stamp, a completed chapter, a site unlock, an all-5★ night and a collected crew stage.
- Coins tick up, and haptics match the pops.
- Reopening the app returns to the live camp, never a menu or an ad.
- [C] An attract mode on the title screen.

### 17.4 Settings

Music, ambience and SFX volume · haptics · Daily reminder (on/off and time) · crew notification (on/off) · language · text size (normal, large) · reduced motion · reduced flashing (at most 3 Hz) · Assist mode · left-handed layout · Remove Ads and restore purchases · privacy options (ad consent, where required) · Ranger's tips · credits and licences · privacy policy.

**Assist mode:** a wider fishing window (§7.2), highlighted forage nodes, and a suggested cook plan for tonight's favourites. It never solves the seating.

### 17.5 Accessibility

- Never colour alone: every state also has an icon or a number.
- Pixel font for headings and labels; a readable sans for letters and long text.
- Fishing is the only timed input, and Assist mode widens it.
- Not in v1: screen reader support, colour-blind themes (the palette is checked with simulators instead), portrait mode, controller support.

### 17.6 Platform UX

- Back closes the most recently opened sheet. On the Camp screen it asks before quitting.
- Two local notifications, both opt-in (D-17, D-25). The Daily reminder [S] is requested after the first completed Daily. The crew notification [S] is requested once when the hut's roof starts (§14), after a one-line in-game explanation, and never in the same session as the consent form.
- The crew notification says what is ready to collect, never "hurry" or "don't miss". At most one a calendar day; none between 21:00 and 09:00 local time (it waits until 09:00); merged with the Daily reminder when the two fall within 2 hours of each other.
- Both are scheduled on the device with inexact timing: no exact-alarm permission and no push service. Verify: the scheduling plugin, delivery after a reboot, and any permissions it adds.
- In-app review prompt [S]: after the first night where every guest gave 5★, not before day 7, at most once every 90 days, and never in the same break as an interstitial.
- Ads follow §24: opt-in rewarded ads (Double tips on the Night summary, the crew speed-up) and an occasional interstitial between Sleep and the next Morning. No ad starts on its own during a phase, and none appear in the Evening, the Trail Daily or onboarding, or right after a purchase.

### 17.7 Edge cases

| Case | Behaviour |
|---|---|
| App killed during the Evening | Resume with the seating intact |
| No meals cooked | Guests take −1; the preview warns before Goodnight |
| Every guest turned away | Allowed; no reviews and no penalty |
| Family with no free neighbouring pair | Card disabled, with a hint |
| Pantry full | The node keeps its items |
| Unknown recipe pair | Camp Mash |
| Oven pair at the campfire | Hint; ingredients kept |
| Purchase would go below 0 | Blocked; coins never go negative |
| Rain on a Cabin | No penalty (Cabins are covered) |
| Device date or time changed | The Trail Daily follows the new date. Crew: forward finishes stages sooner; back never undoes progress (§8.4) |
| Crew stage finishes while the app is closed | A bubble on the structure and its trail-map marker; no popup. The crew notification, if the player opted in (§17.6) |
| Speed-up cap reached | The offer hides; the sheet says when it returns (the next stage, or tomorrow) |
| Purchase pending | Shown as pending and granted when it clears (§24) |
| No ad loaded, or offline | Rewarded offers are hidden and the interstitial skipped; play is unaffected |
| Rewarded ad closed early | No reward. Double tips stays until Sleep; the speed-up stays in the crew sheet |
| App backgrounded during an ad | Resume returns to the same screen; a rewarded ad that finished still pays |
| Ad consent declined | Ads follow the consent result (limited ads or none); the game is unaffected |
| Corrupt save | Load the backup; otherwise offer a fresh start and keep the corrupt file |

## 18. Audio

- Music: three loops (day, evening, night) and a title theme, crossfaded on phase changes.
- Ambience per site with day and night layers: birds, wind, water at Whisper River, cicadas at dusk, a rooster in the Morning, chickens near the Chicken Coop, and a rain layer.
- About 30 SFX: UI, place and return, coins, page stamp, cooking, catch, dog.
- Licensed or CC0 audio only. Every file is logged with its licence in the in-game credits and in a credits file under `LEGAL/`.

## 19. Localization

- English and Vietnamese at launch. Strings live in CSV files keyed by stable IDs; plurals use `tr_n()`.
- Layouts allow 40% longer text. A pseudo-locale is used in QA.
- The font must render stacked Vietnamese diacritics (ặ, ẫ, ổ). Candidates to test in Phase 0: Silkscreen, Pixelify Sans, VT323 and Tiny5 (coverage unverified). Fallback: an extended fork of an OFL font, renamed if the font declares a Reserved Font Name, or Be Vietnam Pro for long text.
- Numbers and dates follow the locale.
- The store listing is in both languages.

## 20. Stack

| Area | Choice |
|---|---|
| Engine | Godot 4 with typed GDScript. Pin the latest stable release at Phase 0: 4.7.2 today (D-13) |
| Renderer | Compatibility (recommended for 2D and low-end devices). Verify: 2D light cost on Device B |
| Display | Base 640×360; stretch mode `canvas_items`, aspect `expand`, integer scaling |
| Particles | CPUParticles2D by default. GPUParticles2D also work in Compatibility, without trails or SDF collision |
| Lighting | CanvasModulate + PointLight2D + additive glow sprites (Compatibility has no 2D HDR) |
| World | TileMapLayer, Y-sort, AStarGrid2D for walking |
| UI | Control nodes with one shared Theme |
| Tests | GUT |
| Android | AAB, which needs Godot's Gradle build. Target API 36, set with the `gradle_build/target_sdk` export option; minSdk 24 (required by the AdMob plugin; the billing plugin needs 23), set with `gradle_build/min_sdk`. Verify on 4.7.2: the template's compile and target SDK (the 4.7 export docs still list SDK Platform 35), and that target 36 builds with the ads, billing and Firebase plugins |
| Ads | AdMob through the Poing Studios godot-admob-plugin: Google UMP consent and privacy options, rewarded and interstitial formats, impression-level revenue (paid) events, mock ads in the editor. It needs Godot 4.5+, minSdk 24 and compileSdk 35+. Pin a release at Phase 0. Verify: the pinned release on 4.7.2. AdMob only at launch; mediation later (Q11) |
| Billing | The official GodotGooglePlayBilling plugin, v3.x, for Remove Ads (v3.2.0 uses Play Billing Library 8.3.0). Verify: Play's minimum Billing Library version at submission |
| Firebase | Analytics (linked to AdMob), Crashlytics and Remote Config through a thin custom Godot Android plugin over the Firebase BoM, built in the Phase 0 spike (D-21, Q6). Verify: Crashlytics setup in Godot's Gradle build, native symbol upload, and a custom Godot `Logger` that reports script errors as non-fatals |
| Crash reporting | Crashlytics, including native engine crashes, plus Android vitals |
| Analytics | Firebase Analytics behind the Analytics adapter (§25) |
| Backend | None. AdMob and Firebase are the only network services; without a connection the whole game still plays, and ads and analytics pause |

Visible canvas with integer scaling (examples):

| Screen | Visible canvas |
|---|---|
| 1920×1080 (16:9) | 640×360 |
| 2400×1080 (20:9) | 800×360 |
| 2560×1600 (16:10) | 640×400 |
| 2048×1536 (4:3) | 682×512 |

The camp core and HUD must work inside the 640×360 frame; the extra area shows scenery.

## 21. Architecture and data

### 21.1 Autoloads

| Autoload | Responsibility |
|---|---|
| Game | Phase state machine (Boot → Title → Morning → Prep → Evening → Night), day and site flow, and the crew clock (§8.4) |
| Catalog | Loads and validates the JSON data; serves items, traits, recipes and pages |
| Econ | Pure functions: stars, tips, rating, walk-ins, meal allocation. No scene access |
| Save | Load, save, backup, migrations (§22) |
| Audio | Music crossfades, ambience layers, SFX pools |
| Analytics | Event adapter over Firebase Analytics (§25); a no-op on desktop and in tests |
| Ads | Consent (UMP), loading, placements and pacing caps (§24); mock ads on desktop |
| Platform | Billing (Remove Ads), notifications, in-app review, back button, safe areas |

### 21.2 Data files (`game/data/`)

| File | Contents |
|---|---|
| `sites.json` | Sites, multipliers, rain rates, forage and fish tables, trait pools, archetype mix |
| `layouts/*.json` | Per site: cells, pad spots, neighbour lists, tags, bank cells, errand spots, lookout, crew plots |
| `decor.json`, `gear.json`, `upgrades.json` | §6.7 |
| `archetypes.json`, `traits.json` | §5.3, §12.2 |
| `recipes.json`, `ingredients.json`, `fish.json`, `birds.json` | §7 |
| `chapters.json` | Pages, goals, gifts, unlocks |
| `crew.json` | Crew structures and stages: times, speed-up chunks, keepsakes, art states (§6.10, §8.4) |
| `letters.json`, `vignettes.json`, `reviews.json` | §13 and review comments |
| `strings/*.csv` | UI and narrative text per language |

- IDs are stable snake_case strings. Saves store IDs, never indexes.
- CI validation: every reference resolves, recipe pairs are unique, every unlock is reachable, no page needs an item from a later page, layouts pass the §5.1 lint, every crew structure has a plot in its site's layout, and every string exists in both languages.

### 21.3 Determinism

- Each save has a 64-bit seed.
- Each day's content (board, rain, forage, bites, walk-in choices) draws from an RNG seeded with hash(save seed, site, site day), so reloading never rerolls anything.
- The Trail Daily uses hash("daily", local date).
- The crew runs on the device clock (UTC) and never feeds an RNG, so it can't change a board, the weather or a Daily.

### 21.4 Repo layout

```
game/                        Godot project
  data/                      JSON and strings (§21.2)
  scenes/  scripts/  assets/  tests/
  addons/                    AdMob, billing and Firebase plugins (pinned)
tools/                       sim, content lint, Daily solver, art scripts
docs/                        GDD, DEV_WORKFLOW, reference/
LEGAL/                       privacy policy, terms, credits
assets_src/                  source art (not imported)
```

## 22. Save system

- One save slot: `user://save.json` plus `user://save.bak`. Writes go to a temporary file that is then renamed.
- A `save_version` field with migrations; every migration has a fixture test.
- Saves happen at the start of each Morning, after purchases (debounced 2 s), when a crew stage is collected or sped up, at the end of the Night and when the app pauses. Resume restores the exact phase, including the Evening seating.
- Contents: seed, day, current site, phase, coins, per-site state (pads, upgrades, decor, reviews, pages, site day, regulars), pantry, today's meals, known recipes and tried pairs, journal, letters read, dog (name, bond), Daily (last date, score), crew (structure, stage, seconds left, the last-seen UTC time, speed-ups used on this stage and today), the cached Remove Ads entitlement and ad pacing (the day and time of the last interstitial, and whether tonight's rewarded offer was used). Settings live in a separate file.
- Android Auto Backup covers device moves (export option `user_data_backup/allow`). Play Games Saved Games arrives in v1.1.
- Budget: under 100 KB; loads in under 100 ms.

## 23. Performance budgets

| Metric | Budget |
|---|---|
| Frame rate | 60 fps on Device B in the busiest scene (8 guests, rain, all lights); menus may cap at 30 |
| Cold start | At most 5 s to the live camp; ads and Firebase initialise after the first frame and never delay a phase |
| Memory | At most 500 MB |
| AAB size | At most 80 MB, ad and Firebase SDKs included |
| Save and load | At most 100 ms |
| Crash-free sessions | At least 99.5%, ad and Firebase SDKs included. Play's bad-behaviour thresholds are about 1.09% user-perceived crashes and 0.47% ANRs (Verify) |

| Device | Profile |
|---|---|
| A | The developer's daily phone |
| B | Low-end: Snapdragon 4xx class, 3 GB RAM, Android 10–11 |
| C | A 16:10 or 4:3 tablet |

## 24. Monetization

Free to play and ad-supported (D-03, D-20). All three sites and every item are free. Revenue comes from opt-in rewarded ads, an occasional interstitial between days and a one-time Remove Ads purchase. Player-paced days make this fit: the day boundary is a natural break that never cuts into a puzzle, and the tips offer comes right after the player sees the night's result. The crew speed-up adds a second opt-in offer, outside the puzzle (§8.4).

### 24.1 Placements

| Placement | Format | Where and when | Rule |
|---|---|---|---|
| Double tips | Rewarded, opt-in | Night summary, from night 3; once per in-game day | Doubles that night's tips; the button shows the exact coins. Sim-checked (§6.8, §6.9) |
| Crew speed-up | Rewarded, opt-in | Crew sheet (§17.2) in the Morning or Prep, from day 4; never in the Evening, the Trail Daily or onboarding | Removes one chunk of the current stage, shown on the button (§6.10); at most 3 per stage and 6 per calendar day; Finish is free with 5 minutes or less left. Coins never buy time |
| Ranger's crate [C] | Rewarded, opt-in | Morning, once per in-game day | Ingredients for tonight's favourite meals. Ships only once the sim models its effect on meals |
| Between days | Interstitial | After Sleep and the autosave, before the next Morning; from day 5 | At most one every 2 in-game days, at least 4 minutes apart; skipped if a rewarded ad played in the last 3 minutes |

- No banners and no app-open ads [W].
- No ad starts on its own during a phase. Rewarded ads play only when tapped, and never in the Evening, the Trail Daily or onboarding. No ad on app open or resume, before night 3, or right after a purchase.
- Nothing requires an ad. With no ad loaded or no connection, the rewarded offer is hidden and the interstitial skipped.
- A rewarded ad pays only when it completes. Closed early, Double tips stays until Sleep and the speed-up stays in the crew sheet.
- Ads preload in the background during the Night; the game never waits for one.
- Start days, caps, crew times and chunks (§6.10), and a 5% ads-off holdout live in Remote Config, with the defaults above built in.
- AdMob settings: maximum ad content rating G; sensitive categories such as gambling and dating blocked.
- Crew timers only delay a keepsake: they never expire, never shrink a reward and can't be bought with coins or money (D-24). Review them against the Digital Fairness Act when it is published (§26).

### 24.2 Remove Ads

- Product `remove_ads`: one-time and non-consumable. Price $2.99, test $3.99 (Q3).
- It removes interstitials for good. Rewarded ads stay available, because they are opt-in.
- Offered in Settings and at the end of the Outfitter catalog, never as a popup.

| Situation | Handling |
|---|---|
| Purchase completes | Grant, then acknowledge (Play refunds purchases left unacknowledged for 3 days) |
| Purchase pending | Show "pending"; grant once it completes, checked on start and resume |
| Restore | Query purchases on start, on resume and from Settings |
| Offline | Use the entitlement cached in the save |
| Play reports the item as not owned (refund) | Interstitials return; nothing else changes |

- No server-side validation in v1: an accepted risk for a low-price entitlement.
- Test with license testers, including pending and refunded purchases.

### 24.3 Consent

- Google UMP requests consent information on every launch. Where a form is required (EEA, UK, Switzerland), it shows once, at the start of Morning 2, so the cold open and the first night stay untouched.
- Ads are requested only when UMP allows it. Firebase consent mode follows the UMP result; where consent is required, analytics runs with consent denied until the form is answered (Verify).
- Settings has a privacy options entry that reopens the form; it also covers US state privacy opt-outs.
- Target audience 13+ and not designed for children, so ad requests are not tagged as child-directed.
- Mediation: AdMob only at launch; add bidding partners once volume justifies it (Q11).

## 25. Analytics and KPIs

Events go through the Analytics adapter and never include names, free text or contact details. Firebase adds its own identifiers: the app instance ID, and the advertising ID only where consent allows.

| Event | Key fields |
|---|---|
| `app_open` | Cold or warm start; whether a notification opened it, and which (Daily or crew) |
| `tutorial_step` | Step ID |
| `day_start`, `day_end` | Day, site, guests, average stars, coins |
| `purchase_item` | Item ID, site, price |
| `page_complete` | Page ID, day |
| `site_unlock` | Site, day |
| `ad_offer_shown`, `ad_rewarded_complete` | Placement, day |
| `ad_interstitial_shown` | Day, minutes since the last one |
| `ad_revenue` | Value, currency, placement (from the plugin's paid event) |
| `consent_status` | UMP status, whether a form was required |
| `iap_remove_ads`, `iap_restore` | Source, result |
| `daily_start`, `daily_complete` | Daily number, score |
| `letter_open` | Letter ID |
| `settings_change` | Setting, value |
| `notification_opt_in` | Type (Daily or crew); accepted or declined |
| `crew_stage_start`, `crew_stage_collect` | Structure, stage; on collect, minutes waited and speed-ups used |

| KPI | Target |
|---|---|
| Players who finish the first night | At least 85% |
| Retention D1 / D7 / D30 | At least 30% / 10% / 3% |
| Players who complete Pinewatch | At least 35% |
| Rewarded opt-in | At least 40% of daily players watch one or more rewarded ads |
| Rewarded ads per daily player | 1.5–3 |
| Interstitials per daily player | At most 2 |
| Remove Ads purchases | At least 0.5% of installs |
| Ad revenue per daily player | Baseline set in the first month, by country tier |
| Retention cost of ads | D7 retention within 5% (relative) of the ads-off holdout |
| Crash-free sessions | At least 99.5% |
| Median in-game day | 4–6 minutes |
| Crew engagement | At least 70% of players who reach day 4 have collected the hut's first stage |
| Speed-ups per crew stage | Watch: an average above 2 means the waits are too long (Q12) |
| Crew notification opt-in | Baseline set in the first month |

Firebase is the vendor (D-21), with consent from UMP (§24.3); both await confirmation (Q6).

## 26. Privacy, compliance and store

- Privacy policy in `LEGAL/PRIVACY.md`, hosted on a developer website and linked from the store listing and Settings. The same site serves `app-ads.txt` for AdMob.
- The data safety form follows Google's published guidance for the AdMob and Firebase SDKs actually shipped (device and advertising IDs, app interactions, diagnostics, approximate location from the IP address) and covers the Remove Ads purchase. Play Console declares that the app contains ads.
- Permissions: POST_NOTIFICATIONS for the Daily reminder and the crew notification, requested in context (§17.6); no exact-alarm permission. INTERNET, ACCESS_NETWORK_STATE and AD_ID come from the ad SDK. No location, contacts or storage permissions.
- Content rating through the IARC questionnaire, which declares the ads; expected Everyone / PEGI 3. Target audience 13+; not designed for children, outside the Families program, and no child-directed marketing.
- EU Digital Fairness Act: the Commission planned its proposal for the second half of 2026 (Verify its status). It targets dark patterns such as artificial urgency. Review the crew (§8.4), the speed-up (§6.10) and the ad rules (§24) against it when it is published.
- Target API 36 now (required for new apps and updates since 2026-08-31). Plan for API 37 after 2027-08-31.
- 16 KB memory page support. Verify: whether the requirement applies and whether the 4.7.2 export template complies.
- Personal developer accounts created after 2023-11-13 must run a closed test with at least 12 testers for 14 continuous days before production access; pre-registration waits for it too. Organization accounts are exempt. Create the account and recruit testers early (§29).
- Listing assets: 512 px icon, 1024×500 feature graphic, 6–8 screenshots, a short description of at most 80 characters and a full description of at most 4,000, in English and Vietnamese.

## 27. Scope

**Must:** the four-phase day; 3 sites with 5 pages each; bookings, traits, stars and preview; pads, upgrades and decor; foraging, fishing and 13 recipes; the dog; the journal; the crew with three structures and 9 keepsakes (§8.4); about 25 letters; the six [M] vignettes; onboarding; settings and accessibility (§17.4, §17.5); English and Vietnamese; save and resume; ads with consent (Double tips, the crew speed-up, the between-days interstitial, UMP) and the Remove Ads purchase; analytics and crash reporting; the whole game playable offline.

**Should:** the Trail Daily and its reminder; the crew notification; spotting; Hùng's story; the nine [S] vignettes (six guest scenes and three restorations); cosmetics; the in-app review prompt.

**Could:** a title-screen attract mode; a vignette log in the journal; a shareable camp image; the Ranger's crate rewarded ad.

**Won't in v1:** Volume II, the Trail Passport and Play Games (achievements, leaderboards, Saved Games) until v1.1; seasons, festivals and Camp Postcards until v1.2 (§33); photo mode; new sites; iOS; more languages; real-time multiplayer or live visits; banner and app-open ads; energy, premium currency or paywalled content; timers on the arc's critical path; raw selling; upkeep, decay, hazards, ranks or prestige.

## 28. Assets and pipeline

| Category | Count |
|---|---|
| Terrain tiles and edges | About 40 |
| Decor with states | About 30 |
| Cosmetics | About 10 |
| Pads (bare, Platform, Cabin × 3 sites) | 9 |
| Structures (Outfitter van, fire ring, boards, signs, lookouts) | About 15 |
| Site sets (forage nodes, water features, backdrops) | About 45 |
| Clutter library (batched) | 64 |
| Characters (player, dog, Ranger Mai, guests) + regular variants | About 16 + 4 |
| Items (ingredients, fish, meals, gear icons) | About 45 |
| UI icons + kit | About 30 + kit |
| Journal and map art | About 10 |
| Crew: structures (3 × 4 states), a scaffold, 6 overgrown Volume II plots, 2 volunteers | About 22 |
| Keepsake illustrations | 9 |
| VFX | About 10 |
| **Total** | **About 330 + 64 clutter** |

Manual cleanup is estimated at 80–165 hours (about 110). Phase 2 re-estimates it from measured times.

**Pipeline:**
- Generation: PixelLab through the MCP server configured in `.devin/config.json` (token in the `PIXELLAB_TOKEN` environment variable), and scripted batches with `tools/pixellab_gen.py`.
- Cleanup and hero spots in Pixelorama.
- Batch order: Batch 0 style lock (player, grass and shore samples, one prop, palette lock) → terrain → camp props → site sets → characters → world animations → items, UI and VFX → store art.
- Phase 2 writes the prompt library, cast sheet and coverage checklist from this section and §16.
- Download generated images immediately, because map objects expire after 8 hours. Prefer image URLs over inline base64 for references larger than 32 px. Keep sources in `assets_src/`.
- Every batch passes the QA gates (§16.4) before import.

## 29. Roadmap and gates

| Phase | Weeks | Deliverable | Exit gate |
|---|---|---|---|
| −1 Paper and numbers | 1 | Paper prototype (guest cards, pad grid, decor tiles; 10 nights by hand); sim extended with unlock gating and per-guest traits | 5 paper sessions show real trade-offs; §6.9 guardrails hold |
| 0 Scaffold | 1–2 | Godot project, display settings, autoloads, data loading and validation, save v1, debug menu, Android export to the internal track; spikes for the renderer, lights, Vietnamese font, and the AdMob and Firebase plugins | The AAB installs from the internal track; 20 lights run at 60 fps on Device B; a Vietnamese pangram renders; a test ad and a test analytics event come through on Device A |
| 1 Greybox | 2–3 | Pinewatch days 1–5 in greybox: Morning → Prep (forage, cook, build) → Evening seating with preview → Night | At least 3 of 5 testers want to continue; median day 4–6 min; testers can explain their stars |
| 2 Style lock | 1–2 | Batch 0 → approval → one production Pinewatch dusk screen; every asset timed | Look approved on device; art hours re-estimated |
| 3 Pinewatch complete | 7–9 | All Pinewatch content, onboarding, letters 1–10, the dog, journal, settings, English and Vietnamese, audio; the crew and the Warden's Hut | 5 testers finish the chapter; median completion on day 8–11; at least 4 of 5 testers come back for the hut's roof |
| 4 River, Valley, Daily | 6–8 | Sites 2 and 3, regulars, finale, Trail Daily, the Boathouse and the Lantern Workshop | Arc completable; guardrails hold on real data; Daily deterministic and solver-checked |
| 5 Platform | 3–5 | Ad placements and pacing (Double tips, the crew speed-up, the interstitial), UMP consent and privacy options, Remove Ads (purchase and restore), Firebase Analytics, Crashlytics and Remote Config, the Daily reminder and the crew notification, privacy policy and data safety | Ads verified with test units, including no fill; consent verified with the EEA debug geography; Remove Ads purchase, pending and refund verified with license testers; notifications respect quiet hours and the daily cap; §23 budgets met with ads on |
| 6 Store | 3–4 | Closed test (12 testers × 14 days), listing in English and Vietnamese, pre-launch report, staged rollout; Volume II work starts while the closed test runs | Closed test complete; crash-free at least 99.5%; listing approved |
| 7 Volume II (v1.1) | 4–6 | Volume II (§33.3), the Trail Passport, Play Games; a post-arc mode in the sim | §6.11 guardrails hold; ships 4–6 weeks after the 100% rollout |

- Total to launch (Phases −1 to 6): 24–34 weeks plus about 15% contingency, roughly 6.5–9 months for one full-time developer. The crew adds about 1–2 weeks (Phases 3 and 5). Phase 7 overlaps Phase 6 and the rollout.
- **Do now:** create the Play developer account and start recruiting testers, including Vietnamese players. The closed test can run with any build; starting it during Phase 4 takes it off the critical path. Create the AdMob account and the Firebase project too: AdMob's payment and tax setup takes time.

## 30. Testing

| Layer | Coverage |
|---|---|
| Unit (GUT) | Econ (every star term, families, tips, the rating window, walk-ins, meal allocation), recipes (unique pairs, the oven rule), all 15 page conditions, the crew clock (clock moved forward and back, app killed mid-stage, speed-up caps per stage and per day), save migrations (one fixture per version) |
| Simulation | The Appendix C model on the real data files, with and without ads; CI fails if a §6.9 guardrail breaks |
| Content lint | References, duplicate pairs, unreachable unlocks, page order, layout rules, missing strings, text length |
| Daily solver | The next 400 dailies (§10) |
| Golden days | Recorded inputs replay to identical saves |
| Device passes | Devices A, B and C: kill and resume in every phase, airplane mode, low storage, language switch, large text, the back button; ads on and off, no fill, consent declined, Remove Ads bought and refunded; the crew across reboots and clock changes; notification timing, quiet hours and the daily cap |
| Store checks | The Play pre-launch report on every closed-test build |
| Playtests | Phases −1, 1, 3 and 6, including Vietnamese players |

## 31. Launch

- Before launch: short devlog clips (the seating puzzle, night vignettes), a press kit, and pre-registration once the closed test is done.
- Store listing in English and Vietnamese, with keywords around cozy, camping, puzzle and offline play. The listing says what the ads are: opt-in rewards and an occasional break between days.
- The Daily share text is the organic loop.
- Staged rollout at 10%, then 50%, then 100%, watching Android vitals, ad metrics and the ads-off holdout.
- Before production ads: link the AdMob app to the published listing and publish `app-ads.txt`.
- The finale says a second volume is coming, without a date (§13.1).
- v1.1 brings Volume II, the Trail Passport and Play Games (achievements, leaderboards, Saved Games) 4–6 weeks after the 100% rollout; later updates follow §33.2.

## 32. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The puzzle is shallow (one obvious placement) | Medium | High | Conflicts designed in from day 6; paper test (Phase −1); greybox gate; solver lint on campaign boards |
| Pacing feels off with real players | Medium | Medium | Sim in CI on real data; tune data only; Phase 3 gate |
| AI art reads as a toy | High | High | Batch 0 style lock; production tells; QA gates; budgeted cleanup |
| The pixel font lacks Vietnamese coverage | Medium | Medium | Phase 0 font spike; fallback fonts (§19) |
| The camp core is too cramped on small phones | Medium | High | 64 px cells; a core of at most 10×4 cells; Phase 1 thumb test |
| Ads hurt the cozy feel or retention | Medium | High | Rewarded first; interstitials only between days, capped; an ads-off holdout in Remote Config; Remove Ads |
| Low ad revenue (low eCPM in Vietnam and other emerging markets) | High | High | A global English listing; a rewarded-heavy mix; mediation after launch (Q11); caps tuned through Remote Config |
| Ad or Firebase SDKs add crashes, ANRs or size | Medium | Medium | Initialise after the first frame; pinned versions; Device B passes; vitals watched through the staged rollout |
| A Godot plugin breaks on an engine or SDK update | Medium | Medium | Phase 0 spike; pinned versions; a thin Firebase plugin we own; upgrades only between releases |
| 2D lights too slow on low-end devices | Medium | Medium | Compatibility renderer; a light budget; glow sprites; Device B from Phase 0 |
| Play or AdMob policy issues, or review delays | Medium | Medium | Account and testers early; target API 36; closed test started in Phase 4; ad placements per AdMob policy; a 13+ audience and no child-directed marketing |
| Solo-developer scope | High | High | MoSCoW scope; phase gates; cut Should items first |
| Save loss | Low | High | Atomic writes, a backup, migrations, Auto Backup |
| Players finish the arc before v1.1 ships | High | High | Volume II work starts in Phase 6 and ships 4–6 weeks after the 100% rollout; the finale promises a second volume; sandbox and the Trail Daily hold finishers meanwhile (§33) |
| Crew timers feel like pressure or a paywall | Medium | Medium | Keepsakes only in v1; nothing blocks the arc or expires; coins never buy time; capped speed-ups; calm notification copy (§8.4, §17.6); speed-ups per stage watched (§25) |
| Clock changes skip crew stages | Medium | Low | Back never undoes; forward is accepted while keepsakes are the only reward; revisit before Volume II's restorations, which have real effects (§6.11) |
| EU rules on game design tighten (Digital Fairness Act) | Medium | Medium | Timers only delay keepsakes and never expire; no event currency, countdowns or limited-time offers (§33.6); review when the proposal is published (§26) |

## 33. After launch

### 33.1 Why a second act

- Ad revenue grows with in-game days played. The crew brings players back on more calendar days, but only new content gives them more days to play.
- After the finale, coins pile up at about 600 a day and the last useful purchase comes a day later (Appendix C). Sandbox play and the Trail Daily keep some finishers, but nothing asks for their coins.
- Finishers are the most engaged players, and they play almost half of all days.

Illustrative cohort of 1,000 installs:

| Segment | Players | In-game days each | Days played |
|---|---|---|---|
| Leave on days 1–2 | 150 | 1.5 | 225 |
| Leave during Pinewatch | 500 | 5 | 2,500 |
| Leave during Whisper River | 140 | 14 | 1,960 |
| Leave during Lantern Valley | 60 | 27 | 1,620 |
| Finish, plus about 5 sandbox days | 150 | 39 | 5,850 |
| **Total** | **1,000** | | **12,155** |

- Finishers play about 48% of all days.
- If finishers play Volume II through, it adds about 30 days each in place of about 5 sandbox days: about +31% days played.
- Seasons add about 20 more days per finisher: about +56% in total.
- For comparison, raising Pinewatch completion from 35% to 40% (§25) adds about 9%.
- The shares are assumptions; soft-launch and rollout data replace them.

### 33.2 Release plan

| Version | When | Adds |
|---|---|---|
| 1.0 | Launch | Volume I (the three-site arc), the crew and its three structures, the Trail Daily |
| 1.1 | 4–6 weeks after the 100% rollout; work starts in Phase 6 (§29) | Volume II (§33.3), the Trail Passport (§33.5), Play Games (achievements, leaderboards, Saved Games) |
| 1.2 | Timed for the next festival after v1.1: Mid-Autumn 2027 or Lunar New Year 2028 (Verify against the launch date) | Seasons of the Trail and the first festival week (§33.4); Camp Postcards [C] (§33.5) |
| 1.3+ | Later | Glasscoast, the hidden cove, Snowpass and the "B." reveal (Appendix D) |

- The finale says a second volume is coming, without a date (§13.1). No in-game text promises a date.
- Every update ships its content inside the app (§13.2) and follows the live-ops rules (§33.6).

### 33.3 Volume II: "Your book" (v1.1, draft)

Volume I was grandpa's book; Volume II is the player's own. It opens at every site the morning after the finale. Each site gets five new pages, completed in any order, and two more of grandpa's old places to restore (numbers in §6.11).

| Page | Pinewatch | Whisper River | Lantern Valley |
|---|---|---|---|
| 6 | Restore the Fire Tower | Restore the Bamboo Treehouse | Restore the Observatory |
| 7 | Restore the Pond Dock | Restore the Bathhouse | Restore the Long Table |
| 8 | Meet 3 Gathering briefs | Meet 3 Gathering briefs | Meet 3 Gathering briefs |
| 9 | A perfect night: 6 or more parties, all 5★ | All 9 pads occupied, every party 4★ or better (needs the Treehouse) | A rainy night with 8 occupied pads, every party 4★ or better |
| 10 | Reach a 4.5 rating | Reach a 4.6 rating | Reach a 4.7 rating |

- The crew paces pages 6 and 7: the player pays for each stage and that site's crew team builds it (§6.11). Pages 8–10 never wait on the crew, so there is always something to play while a stage runs.
- Volume II stays off Volume I's critical path: Glasscoast (v1.3+) unlocks from the Volume I finale, never from Volume II.
- Finishing all 15 pages brings a last keepsake from grandpa, found in the final restoration, and a Volume II stamp on the journal cover (Q15).

**Gatherings:**
- From Volume II, the booking board may offer one Gathering a night: 3–5 parties booked together with one brief.
- A Gathering replaces cards on the board; a night never has more parties than before.
- The Evening preview checks the brief live, like stars. Meeting it pays the Gathering bonus (§6.11) and counts for page 8. The first time each brief is met, its guests leave a cosmetic gift.
- About 24 templates, 8 per site. Each brief is a deterministic rule over the seating, so a CI solver checks that every brief offered can be met.

| Gathering | Site | Brief |
|---|---|---|
| Scout troop | P | 4 Scouts, all within reach of the campfire |
| Wedding party | W | 3 Couples and a Family, nobody below 4★ |
| Photo club | L | 3 Photographers on View pads under clear skies |

### 33.4 Seasons of the Trail (v1.2, draft)

- Seasons follow the device date: spring, summer, autumn and winter, northern hemisphere (Q14).
- Each season shifts one trait weight per site by ±1 (§5.3) and the rain rate by at most ±50% (§5.7), changes the ambience, and adds a seasonal ingredient and recipe, 4 Field Notes, 3–4 decor variants that copy an existing item's price and effect, and a seasonal regular with a 3-visit story.
- Festival weeks for Lunar New Year and Mid-Autumn: a Star Lantern decor variant, a Rice Cake or Mooncake recipe (generic names, §15) and a festival vignette.
- No FOMO: every season and festival returns each year, with no event currency and no countdown, so nothing is lost for good. The Daily reminder mentions a new season or festival.
- Data lives in `seasons.json`, with festival dates precomputed for 2027–2032. Verify: the dates against the Vietnamese lunar calendar (UTC+7).
- The sim runs each season's modifiers, and the §6.9 and §6.11 guardrails must hold in every season.

### 33.5 Social

- **Trail Passport (v1.1):** a stamp for each completed Trail Daily; every 7 stamps unlock a cosmetic. It never resets, so a missed day costs nothing (no streaks, §10).
- **Play Games (v1.1):** achievements mapped to journal pages, leaderboards for Trail Daily stars, and Saved Games (§22). Verify: Play Games leaderboard resets don't follow the player's local date.
- **Camp Postcards [C] (v1.2):** a short text code (layout, seed, version and a checksum; about 40–50 characters, Verify) that shares one night at the player's camp. A friend plays that night as a sandbox: no coins, no backend and no free text.

### 33.6 Live-ops rules

- Content ships inside app updates. Remote Config tunes values, caps and feature flags only; there is no remote narrative (§13.2).
- Seasonal content returns every year. No event currency, countdowns or limited-time offers.
- Real time never blocks Volume I (D-23); in Volume II it paces only the restoration pages (§33.3).
- Every update re-runs the sim and its guardrails (§6.9, §6.11) before release.

| v1.1 KPI | Target |
|---|---|
| Finishers who open Volume II | At least 80% |
| Finishers still playing 14 days after the finale | At least 40% |
| Rewarded opt-in among Volume II players | At least 40% |

---

## Appendix A — Decision log

D-01 to D-12 were proposed defaults in the design review. D-13 to D-19 were added while writing 3.0, D-20 to D-22 after the decisions of 2026-10-11, and D-23 to D-28 in 3.1. The status column says which are decided.

| ID | Decision | Status |
|---|---|---|
| D-01 | The core loop is the nightly hosting puzzle: guests assigned to pads, decor working by radius. Foraging, fishing and cooking are short errands that feed it | Default, awaiting confirmation |
| D-02 | Days advance when the player chooses (Path B). No timers on the arc's critical path, no offline accrual and no streaks; the only real-time element is the optional crew (D-23) | Decided 2026-10-11 on recommendation (Q1): it suits ad pacing, keeps the puzzle deterministic and fits the cozy pillars. Amended the same day by D-23 |
| D-03 | Free to play and ad-supported (§24): all three sites free; revenue from opt-in rewarded ads, an occasional interstitial between days and a one-time Remove Ads purchase (price: Q3). No energy, premium currency or paywalled content | Decided 2026-10-11; replaces the Full Trail unlock |
| D-04 | Landscape, confirmed by the Phase 1 thumb test (Q5) | Default, awaiting confirmation |
| D-05 | Godot 4 with GDScript, Android first, no backend. The whole game plays offline; ads and analytics need a connection. Version pinned by D-13 | Default, awaiting confirmation (updated for ads) |
| D-06 | Eastward-inspired art at one pixel density; mood from Godot 2D lighting (CanvasModulate, PointLight2D), with optional normal maps on hero props. Time Batch 0 before committing | Default, awaiting confirmation |
| D-07 | Keep the subtle Vietnamese signature layer (§15) | Confirmed 2026-10-11 (Q2) |
| D-08 | English and Vietnamese at launch; the font must cover Vietnamese diacritics | Default, awaiting confirmation |
| D-09 | No energy meter. Content sets the limits: 6 forage nodes with 2 items each, 3 catches per spot, a 20-slot pantry (30 with the Cooler) | Default, awaiting confirmation (pantry and node numbers updated in 3.0) |
| D-10 | No raw selling. Leftover meals go to walk-ins, capped by Seats | Default, awaiting confirmation |
| D-11 | Sites unlock through chapter goals (5 journal pages per site), never coins | Default, awaiting confirmation |
| D-12 | No separate Charm stat; guest tiers come from the site rating | Default, awaiting confirmation |
| D-13 | Pin Godot 4.7.2 stable (the latest stable on 2026-10-11) at Phase 0, replacing 4.5.1 in DEV_WORKFLOW | New in 3.0, awaiting confirmation |
| D-14 | Catalog unlocks are tied to specific pages; checked against the sim's purchase log | New in 3.0, awaiting confirmation |
| D-15 | Add Caramel Custard, a third oven recipe, so L2 ("Bake all 3 oven recipes") works | New in 3.0, awaiting confirmation |
| D-16 | Same-day purchases are refundable until Goodnight, and Build mode also works in the Evening | New in 3.0, awaiting confirmation |
| D-17 | Two opt-in local notifications: the Daily reminder, requested after the first completed Daily, and the crew notification (D-25) | New in 3.0, awaiting confirmation; the crew notification is decided (D-25) |
| D-18 | String Lights are 2×1; Lotus Planter and Reed Screen may sit on bank cells (this justifies their prices) | New in 3.0, awaiting confirmation |
| D-19 | The Binoculars enable spotting (birds plus a bonus forage node) | New in 3.0, awaiting confirmation |
| D-20 | Ad design (§24): a Double tips rewarded ad on the Night summary from night 3, once per in-game day; at most one interstitial every 2 in-game days and 4 minutes, only between Sleep and Morning, from day 5; no banners or app-open ads; Remove Ads removes interstitials | New, default awaiting confirmation |
| D-21 | Ads and services stack: AdMob through the Poing Studios plugin with Google UMP; Firebase Analytics, Crashlytics and Remote Config through a thin custom Android plugin; minSdk 24 | New, default awaiting confirmation (Q6) |
| D-22 | Hard break: the legacy prototypes, the café-era plans and code, the 2.x design, unused art packs and old scripts are removed from the repo and live only in git history | Done 2026-10-11 |
| D-23 | Hybrid timers: the arc stays player-paced, and a volunteer crew restores one of grandpa's structures per site in real time (§8.4, §6.10). In v1 it gives keepsakes only, never blocks the arc, costs nothing and never expires. Volume II's restorations use the same crew with real effects (§6.11) | Decided 2026-10-11 |
| D-24 | Crew speed-up: a rewarded ad removes one chunk, max(15 min, stage time ÷ 6); at most 3 per stage and 6 per calendar day; Finish is free once 5 minutes or less remain; coins never buy time (§6.10, §24) | Decided 2026-10-11; values tuned in playtests (Q12) |
| D-25 | Crew notification: opt-in, asked once when the hut's roof starts; at most one a calendar day; none between 21:00 and 09:00; merged with the Daily reminder within 2 hours; no urgent copy (§17.6) | Decided 2026-10-11 |
| D-26 | Volume II (§6.11, §33.3) ships in v1.1, 4–6 weeks after the 100% rollout, not in v1 | Decided 2026-10-11 |
| D-27 | Live-ops rules (§33.6): content ships in app updates; Remote Config tunes values only; seasonal content returns every year; no event currency, countdowns or limited-time offers | New in 3.1, awaiting confirmation |
| D-28 | Release plan (§33.2): v1.1 Volume II, the Trail Passport and Play Games; v1.2 Seasons with the first festival week, and Camp Postcards [C]; v1.3 and later Glasscoast and the cove | New in 3.1, awaiting confirmation |

## Appendix B — Open questions

| # | Question | Needed by | Default or answer |
|---|---|---|---|
| Q1 | Confirm Path B (player-paced days, no real-time systems) | Phase −1 | **Resolved 2026-10-11:** yes, on recommendation (D-02); amended the same day: the optional crew runs in real time (D-23) |
| Q2 | Keep the Vietnamese identity subtle, or make it the headline? | Phase 2 | **Resolved 2026-10-11:** subtle (D-07) |
| Q3 | Remove Ads price | Phase 5 | $2.99, test $3.99 |
| Q4 | Team size and weekly hours | Phase 0 | **Resolved 2026-10-11:** one full-time developer |
| Q5 | Landscape confirmed by the greybox thumb test | Phase 1 | Landscape |
| Q6 | Confirm Firebase (Analytics, Crashlytics, Remote Config) and the UMP consent setup (D-21) | Phase 0 spike | Yes; Sentry is the crash-reporting fallback |
| Q7 | Does the Full Trail include future sites? | — | **Closed:** there is no paid content (D-03) |
| Q8 | The hidden cove's story | Phase 3 (Pinewatch letters foreshadow it) | None; must be decided |
| Q9 | Repo housekeeping | — | **Resolved 2026-10-11:** hard break, old content removed (D-22) |
| Q10 | Crash reporting vendor | — | **Merged into Q6:** Crashlytics |
| Q11 | Which bidding partners to add to AdMob mediation after launch? | First month after launch | AdMob only until volume justifies mediation |
| Q12 | Crew stage times and speed-up chunks (§6.10) | Phase 3 playtest | The §6.10 defaults, tuned from the roof gate (§29) and speed-ups per stage (§25) |
| Q13 | A regional soft launch before the global rollout? | Phase 6 | Staged rollout only (§31). Alternative: 4–6 weeks in 2–3 English-speaking markets to measure retention and ad revenue first |
| Q14 | Which hemisphere's seasons (§33.4)? | v1.2 | Northern |
| Q15 | Volume II's last keepsake and its Glasscoast hooks | v1.1 | None; decide together with Q8 |

## Appendix C — Economy simulation

The sim is a deliberately simple model used to set §6 prices and check pacing. Phase −1 extended it into **`tools/sim.py`**, which is the canonical model: §6.8 and §6.9 quote it, and CI runs it on the real data files (§30). The code and reference output below are the original **baseline model**, kept verbatim for diffing (`--baseline` points here).

**Extended model (`tools/sim.py`, Phase −1):**
- Per-guest draws: booking boards are seeded per (save_seed, site, site_day) per §21.3; each party gets an archetype from the site mix (§12.2) and traits drawn from the site's pool (§5.3), signature traits at double weight.
- Real §8.1 page goals instead of the proxies below: guests hosted, recipes cooked, families, fish kinds, anglers on Water pads, one-night 5-star counts, regular visit counters, full house, rating over 15.
- §8.1 unlock gating: locked items stay queued; an unaffordable item no longer blocks cheaper ones behind it.
- Weather seeded per site/day — Pinewatch site-day 4 rains by script (§14); regulars (§12.3), the Food Blogger elite, families on two pads, Loud/Light-Sleeper neighbour checks on a real pad line.
- Remaining approximations: greedy best-pad seating; favourite-meal probability ramps 0.3 → 0.8 by site day 6; the blogger shows ~1 night in 4 at rating ≥ 4.5; regulars every third site day; weekends are global days 6–7 of every 7; the Pinewatch Outfitter opens on day 2.

**Baseline model:**
- One bot plays the newest unlocked site every day and fills every open pad.
- Skill factor K: a need contributes min(1, coverage × K) and an aversion −0.2 × coverage. K = 1.0 casual, 1.25 median, 1.5 expert.
- Trait term = 2 × the weighted mean over the site's trait pool (§5.3 weights). Social counts 0.8 once 2 or more pads are open.
- Coverage: an r1 item covers 2 pads, an r2 item 4, and the Stone Fire Pit adds 3. Built in: campfire Warmth covers 3 pads; Whisper River has Water 3 and View 2; Lantern Valley has View 3.
- Meal term 0.5 on a site's first day, then 0.75.
- Families come every third night once 4 or more pads are open, scored with Play in place of half the trait term.
- One staple (5 coins) per meal served.
- Fixed build orders per site; the bot keeps a 20-coin reserve and buys after each night.
- Rewarded ads: A is the share of nights on which the player doubles tips (0 = no ads, 1 = every night). The extra coins are reported as the ad share. The Ranger's crate [C] isn't modelled.
- Page proxies: P1 day 1 · P2 20 guests · P3 site day 5 · P4 first family · P5 rating 4.0 over 15 reviews · W1 Fishing Rod owned and site day 2 · W2 6 Anglers (20% of parties, at most 3 a night) · W3 average stars 4.2 with 4 or more pads · W4 site day 8 · W5 rating 4.2 · L1 Telescope placed and stars 4.0 · L2 Camp Oven owned for 2 days · L3 8 pads · L4 site day 9 · L5 rating 4.4.
- Sim IDs are short forms: `strings` = String Lights, `table` = Picnic Table, `chime` = Wind Chime, `kite` = Kite Pole, `dogbed` = Dog Bed, `guitar` = Guitar Stump, `lotus` = Lotus Planter, `firepit` = Stone Fire Pit.

**Baseline limitations:**
- No unlock gating. The median purchase logs without ads (below) and with an ad every night were checked by hand against §8.1: no purchase comes before its unlock (pages are scored before the bot buys). The extended model gates natively.
- More coins make the bot open pads sooner, which thins decor coverage; a real player may balance this better.
- Traits are averages, not per-guest draws.
- No meal shortages, no Goldcap or fish, no elites or regulars, no cosmetics.
- A staple is charged for every meal served, which is conservative because many recipes need none.
- Rain falls on fixed multiples of the day number, so Pinewatch first rains on day 5 rather than the scripted day 4.

**Running it:** `python tools/sim.py` — all seven variants × 30 seeds plus the §6.9 guardrails; `--variant X --show` prints the median-seed day log; `--post-arc DAYS` the post-finale probe (§3.1 below); `--baseline` points at the code block below. Python 3, standard library only. The extended model's output must match the reference output below exactly; the baseline model's own output follows it for history.

<details>
<summary>Extended-model reference output (python tools/sim.py --variant median --show, 30 seeds)</summary>

```
median K=1.25 A=0.0: done median 34 (p10 32, p90 38) W 10 L 19 | ppd [1.88, 2.27, 2.5] zero [1, 0, 1] wmax 746/877 shares (85, 9, 6) ad 0% inc 12736 emptied {3: 34}
  pages: {(1, 1): 1, (1, 2): 8, (1, 3): 5, (1, 4): 6, (1, 5): 8, (2, 1): 12, (2, 2): 19, (2, 3): 12, (2, 4): 16, (2, 5): 16, (3, 1): 30, (3, 2): 29, (3, 3): 35, (3, 4): 27, (3, 5): 32}

=== Guardrails (GDD 6.9) ===
  [OK] Pinewatch chapter done day 8-11 (median of seeds): 9.0
  [OK] Arc done 30-40: 34.5
  [OK] ppd >= 1.4 all sites: [1.88, 2.27, 2.5]
  [OK] zero-buy days <= 2 all sites: [1, 0, 1]
  [OK] fees+tips share >= 75%: (85, 9, 6)
  [OK] wmax <= 800 median / <= 900 p90 (peak while order had items): 746 (p90 877)

=== day log, seed 4 (nearest to median) ===
day s k pads parties stars net coins pages | bought
1 1 1 2 2 2.50 74 94 1 |
2 1 2 2 2 2.00 86 60 1 | lantern(50) stools(25) planter(45)
3 1 3 2 2 3.50 98 38 1 | pad(120)
4 1 4 3 3 2.67 130 38 1 | tarp(75) dogbed(55)  RAIN
5 1 5 3 3 4.33 160 27 13 | pad(200)
6 1 6 4 3 3.33 224 30 134 | rod(150) hedge(60) lantern(50)
7 1 7 4 4 4.00 204 40 134 | swing(150) planter(45)  RAIN
8 1 8 4 4 4.50 192 72 12345 | platform(100) platform(100) bench(40)
9 2 1 3 3 3.33 157 40  | stools(25) lantern(50) reed_screen(75) bench(40)
10 2 2 3 3 4.33 246 20  | pad(190) tarp(75)
11 2 3 4 4 3.50 248 34  | chime(90) lotus(90) dogbed(55)  RAIN
12 2 4 4 4 5.00 260 24 13 | pad(290) hedge(60)
13 2 5 5 5 3.80 302 76 13 | platform(125) platform(125)
14 2 6 5 4 3.50 331 82 13 | cooler(200) platform(125)
15 2 7 5 5 4.60 281 48 13 | table(140) radio(100) tarp(75)
16 2 8 5 5 4.40 346 120 1345 | pad(410)
17 2 9 6 6 4.17 426 170 1345 | platform(125) platform(125) platform(125)
18 2 10 6 6 4.33 447 57 1345 | pad(560)  RAIN
19 2 11 7 7 4.14 453 75 12345 | silk_lantern(225) binoculars(250)
20 3 1 3 3 3.00 174 40  | stools(25) lantern(50) planter(45) kite(90)
21 3 2 3 3 2.67 201 20  | pad(220)
22 3 3 4 3 3.67 309 54  | telescope(275)
23 3 4 4 4 4.50 305 70  | flower_arch(250) bench(40)
24 3 5 4 3 3.67 384 44  | pad(350) hedge(60)  RAIN
25 3 6 5 5 3.40 376 70  | platform(150) platform(150) lantern(50)
26 3 7 5 5 4.00 358 47  | oven(380)
27 3 8 5 5 4.60 374 56 4 | firepit(300) table(140)
28 3 9 5 5 4.40 392 48 4 | platform(150) radio(100) platform(150)
29 3 10 5 4 4.25 428 26 24 | pad(500)  RAIN
30 3 11 6 5 4.40 482 124 124 | platform(150) telescope(275)
31 3 12 6 5 4.40 464 248 124 | swing(150) strings(190)
32 3 13 6 6 4.83 480 148 1245 | pad(680)
33 3 14 7 6 4.00 540 687 1245 |
34 3 15 7 7 4.57 566 33 1245 | pad(900) kite(90)* lantern(50)* hedge(60)* hedge(60)* hedge(60)*
35 3 16 8 8 4.25 508 30 12345 | kite(90)* lantern(50)* hedge(60)* tarp(75)* tarp(75)* tarp(75)* tarp(75)* stools(25)* planter(45)*
```

(`*` marks top-up purchases: once a site's build order is empty the bot buys coverage-useful decor duplicates, then cosmetics — days 34–35 show it topping up at Lantern Valley. `RAIN` marks a weather day.)

</details>

<details>
<summary>Baseline model — reference output (kept verbatim; superseded by the extended model)</summary>

**Baseline reference output:**

```
day s k pads stars rating net coins pages | bought
1 1 1 2 3.12 3.12 90 35 1 | lantern(50) stools(25)
2 1 2 2 3.62 3.38 108 23 1 | pad(120)
3 1 3 3 3.58 3.46 154 57 1 | planter(45) tarp(75)
4 1 4 3 3.79 3.56 157 214 1 | 
5 1 5 3 3.46 3.54 153 142 13 | pad(200) dogbed(55)
6 1 6 4 3.91 3.69 207 139 13 | rod(150) hedge(60)
7 1 7 4 4.07 3.74 232 42 1234 | pad(300) platform(100)
8 1 8 5 4.11 3.87 260 92 1234 | platform(100) guitar(110)
9 1 9 5 4.39 4.12 267 259 12345 | swing(150)
10 2 1 3 3.35 3.35 162 81  | stools(25) pad(190) lantern(50) reed_screen(75)
11 2 2 4 3.8 3.61 245 266 1 | chime(90)
12 2 3 4 2.92 3.34 248 134 1 | pad(290) lotus(90)
13 2 4 5 3.76 3.48 301 70 1 | platform(125) platform(125) bench(40) tarp(75)
14 2 5 5 4.16 3.69 311 381 1 | 
15 2 6 5 4.16 3.91 335 106 1 | pad(410) cooler(200)
16 2 7 6 3.28 3.77 342 138 12 | platform(125) silk_lantern(225)
17 2 8 6 4.24 3.84 372 60 1234 | pad(560)
18 2 9 7 4.07 3.95 449 39 1234 | dogbed(55) cabin(275) table(140)
19 2 10 7 4.3 4.17 453 117 1234 | cabin(275) radio(100)
20 2 11 7 4.13 4.2 446 638 12345 | 
21 3 1 3 3.12 3.12 179 112  | stools(25) lantern(50) pad(220) telescope(275) planter(45) kite(90)
22 3 2 4 3.71 3.46 277 39  | pad(350)
23 3 3 5 3.54 3.5 375 163  | flower_arch(250)
24 3 4 5 2.67 3.25 309 173  | platform(150) platform(150)
25 3 5 5 4.07 3.44 350 83 1 | oven(380) bench(40) hedge(60)
26 3 6 5 4.13 3.58 392 475 1 | 
27 3 7 5 4.13 4.01 377 76 12 | pad(500) cabin(325)
28 3 8 6 4.13 4.13 442 194 12 | cabin(325)
29 3 9 6 4.3 4.18 488 457 124 | firepit(300)
30 3 10 6 3.72 4.02 428 65 124 | pad(680) table(140)
31 3 11 7 4.24 4.04 512 527 124 | lantern(50)
32 3 12 7 4.27 4.18 552 29 124 | pad(900) platform(150)
33 3 13 8 4.26 4.25 579 93 1234 | cabin(325) radio(100) platform(150)
34 3 14 8 4.57 4.42 593 311 12345 | platform(150) cabin(325)
{'u2': 10, 'u3': 21, 'done': 34, 'ppd': [1.56, 1.91, 1.93], 'zero': [1, 2, 1], 'shares': (86, 8, 6), 'stp': 8, 'wmax': 638, 'pages': {(1, 1): 1, (1, 2): 7, (1, 3): 5, (1, 4): 7, (1, 5): 9, (2, 1): 11, (2, 2): 16, (2, 3): 17, (2, 4): 17, (2, 5): 20, (3, 1): 25, (3, 2): 27, (3, 3): 33, (3, 4): 29, (3, 5): 34}, 'total_income': 12911, 'total_spend': 12600, 'ad_share': 0}
site 1 net/day first,last 90 267 stars first,last 3.12 4.39 max walk-ins 1 max parties 5
site 2 net/day first,last 162 446 stars first,last 3.35 4.13 max walk-ins 2 max parties 7
site 3 net/day first,last 179 593 stars first,last 3.12 4.57 max walk-ins 2 max parties 8
casual K 1.0 unlocks 13 27 done 44 ppd [1.75, 2.0, 1.67]
expert K 1.5 unlocks 10 20 done 34 ppd [1.56, 2.1, 1.87]
ads A 0.5 median K 1.25 unlocks 10 22 done 37 ppd [1.67, 1.92, 1.94] zero [0, 1, 0] wmax 512 shares (87, 8, 5) ad share 6
ads A 1.0 median K 1.25 unlocks 10 21 done 35 ppd [2.0, 2.09, 2.07] zero [0, 0, 3] wmax 915 shares (88, 7, 5) ad share 12
ads A 1.0 casual K 1.0 unlocks 13 24 done 39 ppd [1.83, 2.09, 1.94] zero [0, 1, 1] wmax 789 shares (89, 7, 4) ad share 12
ads A 1.0 expert K 1.5 unlocks 9 17 done 30 ppd [1.75, 2.62, 1.93] zero [0, 1, 1] wmax 818 shares (87, 7, 6) ad share 12
```

</details>

<details>
<summary>Baseline model — code (kept verbatim; the extended model lives in tools/sim.py)</summary>

```python
from collections import deque
import math
DECOR={'stools':(25,'Seat',1),'bench':(40,'Seat',1),'table':(140,'Seat',2),'lantern':(50,'Light',2),'strings':(190,'Light',4),'silk_lantern':(225,'Light',4),'planter':(45,'Nature',2),'lotus':(90,'Nature',2),'flower_arch':(250,'Nature',4),'tarp':(75,'Cover',2),'hedge':(60,'Privacy',2),'reed_screen':(75,'Privacy',2),'dogbed':(55,'Dog',4),'guitar':(110,'Music',4),'chime':(90,'Music',2),'radio':(100,'Music',4),'swing':(150,'Play',4),'kite':(90,'Play',2),'firepit':(300,'Warmth',3),'telescope':(275,'Stars',2)}
GEAR={'rod':150,'cooler':200,'oven':380,'binoculars':250}
SITES={
1:dict(fee=45,family_fee=110,meal=18,start_pads=2,pad_prices=[120,200,300,420,580,750],platform=100,cabin=None,rain_every=5,base={'Warmth':3},traits={'Chilly':('need','Warmth',3),'Social':('need','Social',2),'Introvert':('need','Privacy',2),'Nature':('need','Nature',2),'DogLover':('need','Dog',2),'NightOwl':('need','Light',2),'MusicLover':('need','Music',1),'LightSleeper':('avert','Music',2)},rewards=[20,30,30,40,50],
 order=['lantern','stools','pad','planter','tarp','pad','dogbed','rod','hedge','pad','platform','platform','guitar','swing','pad','lantern','bench','platform','platform','table','strings','pad','firepit','planter','hedge','pad','platform','platform','platform','platform','tarp']),
2:dict(fee=52,family_fee=125,meal=25,start_pads=3,pad_prices=[190,290,410,560,750],platform=125,cabin=275,rain_every=4,base={'Warmth':3,'Water':3,'View':2},traits={'Chilly':('need','Warmth',2),'Social':('need','Social',1),'Introvert':('need','Privacy',2),'Nature':('need','Nature',1),'DogLover':('need','Dog',1),'NightOwl':('need','Light',2),'MusicLover':('need','Music',2),'LightSleeper':('avert','Music',2),'Angler':('need','Water',3),'Shutterbug':('need','View',2)},rewards=[30,40,50,60,75],
 order=['stools','pad','lantern','reed_screen','chime','pad','lotus','platform','platform','bench','tarp','pad','cooler','platform','silk_lantern','pad','dogbed','cabin','table','cabin','radio','pad','platform','cabin','cabin','hedge','tarp','platform','platform','cabin','cabin','binoculars']),
3:dict(fee=58,family_fee=145,meal=30,start_pads=3,pad_prices=[220,350,500,680,900],platform=150,cabin=325,rain_every=6,base={'Warmth':3,'View':3},traits={'Chilly':('need','Warmth',2),'Social':('need','Social',1),'Introvert':('need','Privacy',1),'Nature':('need','Nature',2),'DogWary':('avert','Dog',1),'NightOwl':('need','Light',1),'MusicLover':('need','Music',1),'LightSleeper':('avert','Music',1),'Stargazer':('need','Stars',2),'StargazerDark':('avert','Light',2),'Shutterbug':('need','View',2)},rewards=[40,50,60,75,100],
 order=['stools','lantern','pad','telescope','planter','kite','pad','flower_arch','platform','platform','oven','bench','hedge','pad','cabin','cabin','firepit','pad','table','lantern','pad','cabin','platform','cabin','radio','pad','platform','platform','cabin','cabin','telescope','swing','strings']),
}
def run(P,show=False):
    W=P['W'];A=P.get('A',0);coins=0;day=0;gear=set();site=1;st={}
    ns=lambda s:dict(pads=SITES[s]['start_pads'],padi=0,decor=[],plat=0,cabin=0,guests=0,anglers=0.0,reviews=deque(maxlen=W),days=0,families=0,ffd=None,pages=set(),oi=0,rw=0,oven_day=None)
    st[1]=ns(1);unlock={1:1};ppd={1:[],2:[],3:[]};agg=dict(host=0,walk=0,reward=0,staples=0,spend=0,ad=0);wmax=0;done=None;pl={};daily=[]
    if show:print('day s k pads stars rating net coins pages | bought')
    while day<90:
        day+=1;S=SITES[site];t=st[site];t['days']+=1;k=t['days'];pads=t['pads']
        covers=lambda e:S['base'].get(e,0)+sum(DECOR[d][2] for d in t['decor'] if DECOR[d][1]==e)
        cov=lambda e:(0.8 if pads>=2 else 0) if e=='Social' else min(1.0,covers(e)/pads)
        tw=sum(w for _,_,w in S['traits'].values())
        ts=2*sum(w/tw*(min(1.0,cov(e)*P['K']) if kd=='need' else -0.2*cov(e)) for kd,e,w in S['traits'].values())
        comfort=(t['plat']+2*t['cabin'])/pads;meal=0.5 if k==1 else 0.75
        rain=(day%S['rain_every']==0) and k>1;cover=min(1.0,(covers('Cover')+t['cabin'])/pads)
        raw=2.0+comfort+meal+ts-((1-cover) if rain else 0);stars=max(1,min(5,raw))
        fam=False
        if pads>=4:
            if t['ffd'] is None:t['ffd']=k
            fam=((k-t['ffd'])%3==1)
        fstars=max(1,min(5,raw-ts/2+min(1,cov('Play')*P['K'])))
        tipf=lambda s:0.10*max(0,s-2);n=pads;inc=0;tm=1+A
        if fam:inc+=S['family_fee']*(1+tm*tipf(fstars));agg['ad']+=A*S['family_fee']*tipf(fstars);n-=2;t['families']+=1;t['reviews'].append(fstars)
        inc+=n*S['fee']*(1+tm*tipf(stars));agg['ad']+=A*n*S['fee']*tipf(stars);t['reviews'].extend([stars]*n);parties=n+(1 if fam else 0)
        rating=sum(t['reviews'])/len(t['reviews'])
        walk=min(covers('Seat'),max(0,math.floor(rating)-2));wi=walk*S['meal'];stp=(parties+walk)*1.0*5
        coins+=inc+wi-stp;agg['host']+=inc;agg['walk']+=wi;agg['staples']+=stp;agg['spend']+=stp;t['guests']+=parties
        if site==2:t['anglers']+=min(3,0.2*parties)
        pg=t['pages'];full=len(t['reviews'])>=W;R=(4.0,4.2,4.4);before=set(pg)
        if site==1:
            pg.add(1)
            if t['guests']>=20:pg.add(2)
            if k>=5:pg.add(3)
            if t['families']>=1:pg.add(4)
            if rating>=R[0] and full:pg.add(5)
        elif site==2:
            if k>=2 and 'rod' in gear:pg.add(1)
            if t['anglers']>=6:pg.add(2)
            if stars>=4.2 and pads>=4:pg.add(3)
            if k>=8:pg.add(4)
            if rating>=R[1] and full:pg.add(5)
        else:
            if 'telescope' in t['decor'] and stars>=4.0:pg.add(1)
            if t['oven_day'] is not None and k-t['oven_day']>=2:pg.add(2)
            if pads>=8:pg.add(3)
            if k>=9:pg.add(4)
            if rating>=R[2] and full:pg.add(5)
        for p in pg-before:pl[(site,p)]=day
        rw=sum(S['rewards'][i-1] for i in pg)-t['rw'];t['rw']+=rw;coins+=rw;agg['reward']+=rw
        bought=[]
        while t['oi']<len(S['order']):
            it=S['order'][t['oi']]
            if it=='pad':
                if t['padi']>=len(S['pad_prices']):t['oi']+=1;continue
                price=S['pad_prices'][t['padi']]
            elif it=='platform':
                if t['plat']+t['cabin']>=t['pads']:t['oi']+=1;continue
                price=S['platform']
            elif it=='cabin':
                if t['plat']<=0:t['oi']+=1;continue
                price=S['cabin']
            elif it in GEAR:
                if it in gear:t['oi']+=1;continue
                price=GEAR[it]
            else:price=DECOR[it][0]
            if coins-price<20:break
            coins-=price;agg['spend']+=price;bought.append('%s(%d)'%(it,price))
            if it=='pad':t['pads']+=1;t['padi']+=1
            elif it=='platform':t['plat']+=1
            elif it=='cabin':t['plat']-=1;t['cabin']+=1
            elif it in GEAR:
                gear.add(it)
                if it=='oven':t['oven_day']=k
            else:t['decor'].append(it)
            t['oi']+=1
        ppd[site].append(len(bought));wmax=max(wmax,coins);daily.append((site,round(inc+wi-stp),round(stars,2),round(rating,2),parties,walk))
        if show:print(day,site,k,pads,round(stars,2),round(rating,2),round(inc+wi-stp),round(coins),''.join(map(str,sorted(pg))),'|',' '.join(bought))
        if len(pg)==5:
            if site<3:site+=1;st[site]=ns(site);unlock[site]=day+1
            else:done=day;break
    tot=agg['host']+agg['walk']+agg['reward']
    return dict(u2=unlock.get(2),u3=unlock.get(3),done=done,ppd=[round(sum(ppd[s])/max(1,len(ppd[s])),2) for s in (1,2,3)],zero=[ppd[s].count(0) for s in (1,2,3)],shares=(round(100*agg['host']/tot),round(100*agg['walk']/tot),round(100*agg['reward']/tot)),stp=round(100*agg['staples']/agg['spend']),wmax=round(wmax),pages=dict(sorted(pl.items())),daily=daily,total_income=round(tot),total_spend=round(agg['spend']),ad_share=round(100*agg['ad']/tot))
m=run(dict(W=15,K=1.25),show=True)
d=m.pop('daily');print({k:v for k,v in m.items()})
for s in (1,2,3):
    xs=[x for x in d if x[0]==s];print('site',s,'net/day first,last',xs[0][1],xs[-1][1],'stars first,last',xs[0][2],xs[-1][2],'max walk-ins',max(x[5] for x in xs),'max parties',max(x[4] for x in xs))
for K,lab in ((1.0,'casual'),(1.5,'expert')):
    c=run(dict(W=15,K=K));c.pop('daily');print(lab,'K',K,'unlocks',c['u2'],c['u3'],'done',c['done'],'ppd',c['ppd'])
for A,K,lab in ((0.5,1.25,'median'),(1.0,1.25,'median'),(1.0,1.0,'casual'),(1.0,1.5,'expert')):
    c=run(dict(W=15,K=K,A=A));print('ads A',A,lab,'K',K,'unlocks',c['u2'],c['u3'],'done',c['done'],'ppd',c['ppd'],'zero',c['zero'],'wmax',c['wmax'],'shares',c['shares'],'ad share',c['ad_share'])
```

</details>

**Post-arc probe (3.1):** `python tools/sim.py --post-arc 60` — the finale's stop is skipped for 60 sandbox days, 30 seeds. After the finale the bot earns a median of 600 coins a day over the next 60 days (714 with an ad every night, 595 for a casual player). Its last build-order purchase comes 1 day after the finale: nothing is left to buy at Lantern Valley, and the bot never goes back to the other sites (it only tops up duplicates and cosmetics — `*` in the day log). In the median seed (seed 4, finale on day 35) the balance reaches 5,688, 11,365, 17,514 and 35,666 coins 10, 20, 30 and 60 days after the finale, and 16 Pinewatch items and 1 Whisper River item on the build orders, worth 4,275 coins, are never bought. Across seeds those leftovers are worth a median of 5,052 coins (3,275–5,580). §6.11 is sized from these numbers.

## Appendix D — Backlog

- **v1.1:** Volume II; the Trail Passport; Play Games achievements, leaderboards and Saved Games (§33.2).
- **v1.2:** Seasons of the Trail with Lunar New Year and Mid-Autumn festival weeks (§33.4); Camp Postcards [C] (§33.5).
- **Content (v1.3 and later):** Glasscoast; the hidden cove; Snowpass and the "B." collar-tag reveal.
- **Later:** photo mode; a shareable camp image, if it doesn't make v1 (§27).
- **Platforms and languages:** iOS; Spanish; Brazilian Portuguese.
- **Parked 2.x ideas** (each needs a design reason to return): auto-running sites, supply runs, warden ranks, upkeep, hazards, prestige.

## Appendix E — Glossary

| Term | Meaning |
|---|---|
| Aversion | A trait condition that costs 1★ when triggered |
| Bank cell | A Whisper River cell at the water's edge; only the Lotus Planter and Reed Screen can go there |
| Booking board | The morning list of tonight's requests |
| Cell | A 64×64 px placement square |
| Chapter | One site's five journal pages |
| Crew | Ranger Mai's volunteers, who restore grandpa's structures in real time (§8.4) |
| Elite | The Food Blogger, who appears only at highly rated sites |
| Gathering | A Volume II booking of 3–5 parties with one brief (§33.3) |
| Interstitial | A full-screen ad, shown only between Sleep and the next Morning (§24) |
| Keepsake | A journal entry found in a finished crew stage (§8.4) |
| Loud | A guest that triggers Light Sleepers on neighbouring pads |
| Lookout | The spot at each site used for spotting |
| Need | A trait condition worth 1★ when met |
| Pad | A guest spot: bare, Platform or Cabin |
| Page | A journal goal; five per site |
| Party | One booking: one pad, or two for a family |
| Reach | Which pads an item affects (r1 or r2) |
| Regular | A named guest with a short story |
| Remove Ads | The one-time purchase that turns off interstitials |
| Restoration | One of grandpa's structures, rebuilt by the crew in three stages (§8.4); Volume II adds two per site (§6.11) |
| Rewarded ad | An opt-in ad: Double tips on the Night summary, or a crew speed-up (§24) |
| Seats | Walk-in capacity from seat decor |
| Site day | The Nth day spent at a particular site |
| Speed-up | A rewarded ad that removes one chunk of a crew stage (§6.10) |
| Staple | An ingredient bought at the Outfitter (Bread, Tea, Marshmallow, Noodles, Coffee, Sweet Milk) |
| Trail Daily | The shared daily puzzle |
| Trail Passport | The v1.1 stamp card for completed Dailies (§33.5) |
| Vignette | The short scene that plays each night |
| Volume II | Five more journal pages per site after the finale, from v1.1 (§33.3) |
| Walk-in | A passer-by who buys a leftover meal |

## Appendix F — Changelog

| Version | Date | Changes |
|---|---|---|
| 3.1 | 2026-10-11 | Hybrid timers: a volunteer crew restores one of grandpa's structures per site in real time, for keepsakes (§8.4, §6.10), with a capped rewarded speed-up (§24) and an opt-in crew notification (§17.6). D-02 and D-17 amended; D-23 to D-28 added. New §33 After launch: Volume II in v1.1 (§6.11, §33.3), sized from a post-arc sim probe (Appendix C); Seasons in v1.2; the Trail Passport, Camp Postcards and live-ops rules. Pillar 3, the journal (72 entries), scope, assets, roadmap, KPIs, risks and backlog updated |
| 3.0 | 2026-10-11 | Rewritten around the evening hosting puzzle. One economy table, sim-checked pacing, and production sections (stack, save, budgets, monetization, compliance, roadmap). Same day: ads-first monetization replaces the Full Trail unlock (all sites free; rewarded ads, a capped interstitial, Remove Ads; the sim gains an ads switch), and a hard break removes earlier designs and legacy code from the repo |
| 2.x | — | Activity-loop design. Removed in the 3.0 hard break; see git history |

**Removed in 3.0:** the energy meter; "Sleep anytime" and the real-time clock; Wang-tile terrain sets; coin-gated site unlocks; sites running offline; supply runs and the dog courier; the streak lantern; weekly events; the Charm stat; warden ranks; the bear and other hazards; bike and kayak activities; FCM push; the 10-day arc; the PixiJS client plan; raw selling.

**Kept from 2.x:** the premise and tone; the Eastward art direction; the Vietnamese signature layer and đá cầu spec; the production tells and QA gates; the density strategy; the UX polish rules; the asset pipeline notes; AdMob and Remote Config, re-scoped for §24.
