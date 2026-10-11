extends Node
## Econ — pure functions: stars, tips, rating, walk-ins, meal
## allocation (GDD 21.1). No scene access; formulas mirror §5 and the
## Appendix C / tools/sim.py model so the sim stays a valid harness.


## §5.4: stars = clamp(2 + comfort + meal + needs met - aversions
## tripped + weather, 1, 5).
static func stars(comfort: int, meal: int, needs_met: int,
		aversions: int, weather: int) -> int:
	return clampi(2 + comfort + meal + needs_met - aversions + weather,
		1, 5)


## §5.6: tip = fee × 10% × max(0, stars − 2).
static func tip(fee: int, star_count: int) -> float:
	return fee * 0.10 * maxi(0, star_count - 2)


## Site rating = mean of the last 15 reviews (§5.6).
static func rating(reviews: Array) -> float:
	if reviews.is_empty():
		return 0.0
	var total := 0.0
	for review in reviews:
		total += float(review)
	return total / reviews.size()


## Walk-ins = min(Seats, floor(rating) − 2), floored at 0 (§5.6).
static func walk_ins(seat_count: int, site_rating: float) -> int:
	return mini(seat_count, maxi(0, int(floor(site_rating)) - 2))


## §6.3: displayed prices round to the nearest 5.
static func round5(value: float) -> int:
	return int(5 * floor(value / 5.0 + 0.5))
