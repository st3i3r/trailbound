# Spec 002 — Cozy time model

Status: **Landed** → D-UI-8 (decision laws), `_letter_due` gate in
`game.gd`. Source: design note received 2026-10-13 (`time.txt`).

## Problem

Real-time day pressure is the Stardew anxiety: the clock ticks, the
day is short, idling is punished, menus burn daylight. Cozy
philosophy inverts it — time serves the player.

## Audit finding

Trailbound already ran the spec's best pattern natively: the day is a
verb chain (`MORNING→PREP→EVENING→NIGHT` on player action) — no
clock exists to freeze. The only wall-clock systems (crew, restore)
are UTC reward timers that mature *offline* and never expire.
Income is engagement-bound (`goodnight()` pays only on seated
guests + cooked meals → empty day = 0). No energy resource.

The proposed `CozyClock` (real-time clock + pause flags + speed
slider) was rejected: a regression that re-introduces the anxiety
instrument just to freeze it.

## Two laws (D-UI-8)

1. **No visible day clock** — HUD shows phase names, never a
   countdown. The clock widget *is* the anxiety instrument.
2. **Per-day yields must be engagement-gated or wall-clock-gated,
   never day-gated** — spam is made unprofitable, not forbidden.

## Shipped fix

16/23 letters were `{"morning": N}` day-gates — a sleep-binge could
hoover them. `morning` triggers now also require
`guests_welcomed >= 1` **per site**: nobody writes to a campground
nobody visited. Exception: a site's *morning-1* letter is the
arrival greeting — it welcomes the warden, not the guests, so it
never waits for a stay (keeps `w01`/`l01` honest on a fresh site
before the first hosting night). Event triggers were always gated.

## Forward applications

- Trail Daily: rewards for showing up, **no consecutive-day streaks**
- Seasonal events (when built): two-tier — real-world date →
  cosmetic/economy overlays (decor sockets, shop stock, merchant
  fallback for missed cosmetics — no FOMO), in-game incidents
  separate; resolve at `advance_day` boundary; settings opt-out
  (`track_real_world_holidays`)
- `crew_notify`: opt-in good-news only
- Residual accepted: board/weather fishing via sleep cycles (each
  pull costs a full phase cycle; prize still needs playing)
