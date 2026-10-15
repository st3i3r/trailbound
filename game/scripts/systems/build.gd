extends RefCounted
## Build/purchase layer (§5.1/§5.8/§6.1): decor, pads, gear,
## staples + the footprint law and undo inverses. Leaf subsystem —
## no save state here; everything reads/mutates `g` (the Game
## autoload). Public verbs stay one-line delegates on Game.

var g  # the Game autoload (untyped: circular ref)


func _init(game) -> void:
	g = game


func _layout(site := &"") -> Dictionary:
	if site == &"":
		site = g.site_id
	return Catalog.data.get("layouts", {}).get(site, {})


## Legal placement cells + footprint check (§5.8): decor lands only
## on the layout's decor_cells, never on pads, the fire, water or a
## cell another item already covers.
func _decor_cell_set() -> Dictionary:
	var out := {}
	for c in _layout().get("decor_cells", []):
		out[Vector2i(int(c[0]), int(c[1]))] = true
	return out


func _decor_blocked(ignore := -1) -> Dictionary:
	var st: Dictionary = g.site_state()
	var layout := _layout()
	var out := {}
	for pid in layout.get("pads", {}).get("spots", {}):
		var c: Array = layout["pads"]["spots"][pid]
		out[Vector2i(int(c[0]), int(c[1]))] = true
	out[st["campfire"]["cell"]] = true
	for i in st["decor"].size():
		if i == ignore:
			continue
		for c in st["decor"][i]["cells"]:
			out[c] = true
	return out


## Walkable/reachability delegate to SimGrid — the single parser
## for layout.nav (was a second, divergent implementation here).
func _walk_cells(layout: Dictionary) -> Dictionary:
	return SimGrid.walk_cells(layout)


func _reachable_set(cells: Dictionary) -> Dictionary:
	return SimGrid.reachable(cells)


## Placement deadlock guard: dropping pts must not strand any
## previously-reachable walkable cell.
func _strands_any(free: Dictionary, pts: Array) -> bool:
	var base := _reachable_set(free)
	var left := free.duplicate()
	for c in pts:
		left.erase(c)
	var after := _reachable_set(left)
	for c in base:
		if not pts.has(c) and not after.has(c):
			return true
	return false


func _footprint_ok(row: Dictionary, cells: Array,
		ignore := -1) -> bool:
	var size := String(row.get("size", "1x1"))
	if size == "campfire":
		return true                              # ring upgrade, no cells
	var legal := _decor_cell_set()
	var blocked := _decor_blocked(ignore)
	var want := 1 if size == "1x1" else 2
	if cells.size() != want:
		return false
	var pts := []
	for c in cells:
		var v: Vector2i = c if c is Vector2i \
			else Vector2i(int(c[0]), int(c[1]))
		if not legal.has(v) or blocked.has(v):
			return false
		pts.append(v)
	if want == 2 and abs(pts[1].x - pts[0].x) != 1:
		return false                             # 2x1 = horizontal pair
	var occ := {}
	for i in g.site_state()["decor"].size():
		if i == ignore:
			continue
		for c in g.site_state()["decor"][i]["cells"]:
			occ[c] = true
	var free := {}
	for c in _walk_cells(_layout()):
		if not occ.has(c):
			free[c] = true
	for c in pts:
		if not free.has(c):
			return false                     # decor can't sit on water/solid
	return not _strands_any(free, pts)


## Presenter reads for build mode (UI-033): the grid overlay needs
## the free legal cells; the ghost tint needs a dry-run of placement
## law — both are reads, the verbs stay the only writers.
func decor_cells_free(ignore := -1) -> Array:
	var legal := _decor_cell_set()
	var blocked := _decor_blocked(ignore)
	var occ := {}
	for i in g.site_state()["decor"].size():
		if i == ignore:
			continue
		for c in g.site_state()["decor"][i]["cells"]:
			occ[c] = true
	var walk := _walk_cells(_layout())
	var out := []
	for c in legal:
		if not blocked.has(c) and not occ.has(c) and walk.has(c):
			out.append(c)
	return out


func decor_placement_ok(item_id: String, cells: Array,
		ignore := -1) -> bool:
	var row: Dictionary = g._row("decor", item_id)
	return not row.is_empty() and _footprint_ok(row, cells, ignore)


## True once the Stone Fire Pit upgrade is in place — campfire-size
## decor lives on the ring radius, not in st["decor"].
func fire_pit_upgraded() -> bool:
	var base := int(_layout().get("campfire", {}).get("radius", 2))
	return int(g.site_state()["campfire"]["radius"]) > base


func buy_decor(item_id: String, cells: Array) -> bool:
	var row: Dictionary = g._row("decor", item_id)
	var st: Dictionary = g.site_state()
	if row.is_empty() or g.coins < int(row.get("price", 0)) \
			or not g._is_unlocked(row.get("unlock", "")) \
			or not _footprint_ok(row, cells):
		return false
	g.coins -= int(row["price"])
	if row.get("size") == "campfire":                # Stone Fire Pit
		st["campfire"]["radius"] = 3
	else:
		st["decor"].append({"id": item_id,
			"effect": row.get("effect", ""),
			"reach": int(row.get("reach", 1)),
			"cells": cells})
		st["seats"] += int(row.get("seats", 0))
	g._record("buy_decor", {"item_id": item_id, "cells": cells},
		{"verb": "return_bought", "params": {"item_id": item_id}})
	g._log("buy", {"kind": "decor", "id": item_id,
		"price": int(row["price"])})
	Analytics.log_event(&"purchase_item", {"kind": "decor",
		"id": item_id, "price": int(row["price"])})
	g.touch()
	return true


## §6.1 build verbs: move and store are always free; today's buys
## return for a full refund until Goodnight; older items store, not
## sell.
func move_decor(idx: int, cells: Array) -> bool:
	var st: Dictionary = g.site_state()
	if idx < 0 or idx >= st["decor"].size() \
			or st["decor"][idx].get("aura", false):
		return false                    # restoration auras are permanent
	if not _footprint_ok(g._row("decor", st["decor"][idx]["id"]),
			cells, idx):
		return false
	var old: Array = st["decor"][idx]["cells"]
	var iid := String(st["decor"][idx]["id"])
	st["decor"][idx]["cells"] = cells
	g._record("move_decor", {"idx": idx, "cells": cells, "expect": iid},
		{"verb": "move_decor", "params": {"idx": idx,
			"cells": old, "expect": iid}})
	g._log("move", {"id": iid})
	g.touch()
	return true


func store_decor(idx: int) -> bool:
	var st: Dictionary = g.site_state()
	if idx < 0 or idx >= st["decor"].size() \
			or st["decor"][idx].get("aura", false):
		return false
	var d: Dictionary = st["decor"][idx]
	st["seats"] -= int(g._row("decor", d["id"]).get("seats", 0))
	var kept: Dictionary = {"id": d["id"], "effect": d["effect"],
		"reach": d["reach"]}
	if d.get("variant", "") != "":
		kept["variant"] = d["variant"]
	st["stored"].append(kept)
	st["decor"].remove_at(idx)
	g._record("store_decor", {"idx": idx, "expect": d["id"]},
		{"verb": "place_stored", "params": {"item_id": d["id"],
			"cells": d["cells"]}})
	g._log("store", {"id": d["id"]})
	g.touch()
	return true


func place_stored(item_id: String, cells: Array) -> bool:
	var st: Dictionary = g.site_state()
	var i := -1
	for j in st.get("stored", []).size():
		if st["stored"][j]["id"] == item_id:
			i = j
			break
	var row: Dictionary = g._row("decor", item_id)
	if i < 0 or row.is_empty() or not _footprint_ok(row, cells):
		return false                    # rowless ids (auras) can't place
	var d: Dictionary = st["stored"][i]
	st["stored"].remove_at(i)
	var placed: Dictionary = {"id": d["id"], "effect": d["effect"],
		"reach": d["reach"], "cells": cells}
	if d.get("variant", "") != "":
		placed["variant"] = d["variant"]
	st["decor"].append(placed)
	st["seats"] += int(g._row("decor", item_id).get("seats", 0))
	g._record("place_stored", {"item_id": item_id, "cells": cells},
		{"verb": "store_last", "params": {"expect": item_id}})
	g._log("place", {"id": item_id})
	g.touch()
	return true


func return_decor(idx: int) -> bool:
	var st: Dictionary = g.site_state()
	if idx < 0 or idx >= st["decor"].size() \
			or st["decor"][idx].get("aura", false):
		return false
	var d: Dictionary = st["decor"][idx]
	if d["id"] not in g.bought_today:
		return false                            # older items never sell
	var row: Dictionary = g._row("decor", d["id"])
	g.coins += int(row.get("price", 0))
	st["seats"] -= int(row.get("seats", 0))
	st["decor"].remove_at(idx)
	g._record("return_decor", {"idx": idx, "expect": d["id"]},
		{"verb": "rebuy", "params": {"item_id": d["id"],
			"cells": d["cells"], "price": int(row.get("price", 0))}})
	g._log("return", {"id": d["id"],
		"price": int(row.get("price", 0))})
	g.touch()
	return true


## §6.1 refund by id — covers today's buys the indexed return can't
## reach: the Stone Fire Pit (it mutates campfire.radius instead of
## entering st["decor"]) and pieces already packed into storage.
## Removes the most recent placement of that id.
func return_bought(item_id: String) -> bool:
	var st: Dictionary = g.site_state()
	var row: Dictionary = g._row("decor", item_id)
	if item_id not in g.bought_today or row.is_empty():
		return false
	var price := int(row.get("price", 0))
	var inverse: Variant = null
	if row.get("size") == "campfire":
		st["campfire"]["radius"] = int(_layout().get(
			"campfire", {}).get("radius", 2))
		inverse = {"verb": "rebuy_pit", "params": {"price": price}}
	else:
		var i: int = st["decor"].size() - 1
		while i >= 0 and st["decor"][i]["id"] != item_id:
			i -= 1
		if i >= 0:
			st["seats"] -= int(row.get("seats", 0))
			var cells: Array = st["decor"][i]["cells"]
			st["decor"].remove_at(i)
			inverse = {"verb": "rebuy", "params": {"item_id": item_id,
				"cells": cells, "price": price}}
		else:
			var si: int = st["stored"].size() - 1
			while si >= 0 and st["stored"][si]["id"] != item_id:
				si -= 1
			if si < 0:
				return false            # bought record, but no piece
			st["stored"].remove_at(si)
			inverse = {"verb": "rebuy_stored",
				"params": {"item_id": item_id, "price": price}}
	g.coins += price
	g._record("return_bought", {"item_id": item_id}, inverse)
	g._log("return", {"id": item_id, "price": price})
	g.touch()
	return true


## §5.1 pad opening is two steps: pay the price (unlock_pad — the
## spot stays overgrown and still blocks bookings), then Clear it
## (clear_pad — free; the ~2s transform lives in the scene). The
## price index counts owned spots (open OR paid), not just open.
func unlock_pad(pad_id: String) -> bool:
	var st: Dictionary = g.site_state()
	var row: Dictionary = g.site_row()
	var prices: Array = row.get("pad_prices", [])
	var owned := 0
	for pid in st["pads"]:
		if st["pads"][pid]["open"] or st["pads"][pid].get("paid", false):
			owned += 1
	var idx := owned - int(row.get("start_pads", 0))
	if idx < 0 or idx >= prices.size() \
			or not st["pads"].has(pad_id) \
			or st["pads"][pad_id]["open"] \
			or st["pads"][pad_id].get("paid", false) \
			or g.coins < int(prices[idx]):
		return false
	g.coins -= int(prices[idx])
	st["pads"][pad_id]["paid"] = true
	g._record("unlock_pad", {"pad_id": pad_id},
		{"verb": "unlock_refund",
			"params": {"pad_id": pad_id, "price": int(prices[idx])}})
	g._log("pad_unlock", {"pad": pad_id, "price": int(prices[idx])})
	Analytics.log_event(&"pad_unlock", {"pad": pad_id,
		"price": int(prices[idx])})
	g.touch()
	return true


func clear_pad(pad_id: String) -> bool:
	var st: Dictionary = g.site_state()
	if not st["pads"].has(pad_id) or st["pads"][pad_id]["open"] \
			or not st["pads"][pad_id].get("paid", false):
		return false
	st["pads"][pad_id]["open"] = true
	# §6.1 "refund-until-clear" falls out of LIFO: while open, the
	# unlock's refund inverse fails and skips; undo the Clear first
	# and the refund unlocks again — no tombstones needed.
	g._record("clear_pad", {"pad_id": pad_id},
		{"verb": "unclear_pad", "params": {"pad_id": pad_id}})
	g._log("pad_clear", {"pad": pad_id})
	g.touch()
	return true


## One-shot convenience (tests/tools): pay and clear in one call.
func open_pad(pad_id: String) -> bool:
	return unlock_pad(pad_id) and clear_pad(pad_id)


## Display-side reads for the pad menu (presenter-only; verbs write).
## Price mirrors unlock_pad's ladder so the label can't lie.
func pad_unlock_price(pad_id: String) -> int:
	var st: Dictionary = g.site_state()
	if not st["pads"].has(pad_id) or st["pads"][pad_id]["open"] \
			or st["pads"][pad_id].get("paid", false):
		return -1
	var row: Dictionary = g.site_row()
	var prices: Array = row.get("pad_prices", [])
	var owned := 0
	for pid in st["pads"]:
		if st["pads"][pid]["open"] or st["pads"][pid].get("paid", false):
			owned += 1
	var idx := owned - int(row.get("start_pads", 0))
	return int(prices[idx]) if idx >= 0 and idx < prices.size() else -1


## Open + still-bare pad -> shelter offers ({shelter, price, unlocked}).
func pad_shelter_options(pad_id: String) -> Array:
	var st: Dictionary = g.site_state()
	if not st["pads"].get(pad_id, {}).get("open", false) \
			or st["pads"][pad_id].get("shelter", "bare") != "bare":
		return []
	var row: Dictionary = g.site_row()
	var out := []
	for spec in [["platform", "P2"], ["cabin", "W0"]]:
		var raw: Variant = row.get(spec[0] + "_price")
		if raw != null:
			out.append({"shelter": spec[0], "price": int(raw),
				"unlocked": g._is_unlocked(spec[1])})
	return out


func upgrade_pad(pad_id: String, shelter: String) -> bool:
	var st: Dictionary = g.site_state()
	var row: Dictionary = g.site_row()
	var raw: Variant = row.get("platform_price") \
		if shelter == "platform" else row.get("cabin_price")
	var price := int(raw) if raw != null else 0
	var need := "P2" if shelter == "platform" else "W0"
	if not st["pads"].get(pad_id, {}).get("open", false) \
			or price <= 0 or g.coins < price or not g._is_unlocked(need):
		return false
	g.coins -= price
	st["pads"][pad_id]["shelter"] = shelter
	g._record("upgrade_pad", {"pad_id": pad_id, "shelter": shelter},
		{"verb": "downgrade_pad",
			"params": {"pad_id": pad_id, "price": price}})
	g._log("shelter", {"pad": pad_id, "shelter": shelter,
		"price": price})
	g.touch()
	return true


func buy_gear(item_id: String) -> bool:
	var row: Dictionary = g._row("gear", item_id)
	if row.is_empty() or item_id in g.gear \
			or g.coins < int(row.get("price", 0)) \
			or not g._is_unlocked(row.get("unlock", "")):
		return false
	g.coins -= int(row["price"])
	g.gear.append(item_id)
	g._record("buy_gear", {"item_id": item_id},
		{"verb": "refund_gear", "params": {"item_id": item_id,
			"price": int(row["price"])}})
	g._log("buy", {"kind": "gear", "id": item_id,
		"price": int(row["price"])})
	Analytics.log_event(&"purchase_item", {"kind": "gear",
		"id": item_id, "price": int(row["price"])})
	g.touch()
	return true


## Staples are global, 5 coins each, gated by the site's staples
## unlock rank (P1 < W0 < L0 — §6.7).
func buy_staple(item_id: String) -> bool:
	var row: Dictionary = g._row("ingredients", item_id)
	if row.get("kind") != "staple" \
			or g.coins < int(row.get("price", 5)):
		return false
	if not g._is_unlocked(row.get("unlock", "P1")):
		return false
	if g.pantry_add(item_id, 1) < 1:
		return false                                   # pantry full
	g.coins -= int(row.get("price", 5))
	g._record("buy_staple", {"item_id": item_id},
		{"verb": "refund_staple", "params": {"item_id": item_id,
			"price": int(row.get("price", 5))}})
	g._log("buy", {"kind": "staple", "id": item_id})
	g.touch()
	return true


# -------------------------------------------------------- inverses

## Inverse helpers — the half of §6.1 no public verb needs.
## Index-addressed inverses verify the item id first: a later
## removal shifts decor indices, and undoing into the wrong piece
## is worse than skipping.

func _move_checked(idx: int, cells: Array, expect: String) -> bool:
	var st: Dictionary = g.site_state()
	if idx < 0 or idx >= st["decor"].size() \
			or (expect != "" and st["decor"][idx]["id"] != expect):
		return false
	return move_decor(idx, cells)


func _store_last(item_id: String) -> bool:
	var st: Dictionary = g.site_state()
	for i in range(st["decor"].size() - 1, -1, -1):
		if st["decor"][i]["id"] == item_id:
			return store_decor(i)
	return false


func _unlock_refund(pad_id: String, price: int) -> bool:
	var st: Dictionary = g.site_state()
	if not st["pads"].has(pad_id) or st["pads"][pad_id]["open"] \
			or not st["pads"][pad_id].get("paid", false):
		return false                               # cleared is one-way
	st["pads"][pad_id]["paid"] = false
	g.coins += price
	g.touch()
	return true


func _unclear_pad(pad_id: String) -> bool:
	var st: Dictionary = g.site_state()
	if not st["pads"].has(pad_id) or not st["pads"][pad_id]["open"]:
		return false
	st["pads"][pad_id]["open"] = false           # paid flag survives
	g.touch()
	return true


func _downgrade_pad(pad_id: String, price: int) -> bool:
	var st: Dictionary = g.site_state()
	if not st["pads"].has(pad_id) \
			or st["pads"][pad_id].get("shelter", "bare") == "bare":
		return false
	st["pads"][pad_id]["shelter"] = "bare"
	g.coins += price
	g.touch()
	return true


func _refund_gear(item_id: String, price: int) -> bool:
	if item_id not in g.gear:
		return false
	g.gear.erase(item_id)
	g.coins += price
	g.touch()
	return true


func _refund_staple(item_id: String, price: int) -> bool:
	if g.pantry_remove(item_id, 1) < 1:
		return false                               # already cooked away
	g.coins += price
	g.touch()
	return true


## Re-buy a returned piece at its captured price and cells — the
## refund's mirror. Stays bought_today-eligible (it IS today's buy).
func _rebuy(item_id: String, cells: Array, price: int) -> bool:
	var st: Dictionary = g.site_state()
	var row: Dictionary = g._row("decor", item_id)
	if row.is_empty() or g.coins < price \
			or not _footprint_ok(row, cells):
		return false
	g.coins -= price
	st["decor"].append({"id": item_id, "effect": row.get("effect", ""),
		"reach": int(row.get("reach", 1)), "cells": cells})
	st["seats"] += int(row.get("seats", 0))
	g.touch()
	return true


func _rebuy_stored(item_id: String, price: int) -> bool:
	var row: Dictionary = g._row("decor", item_id)
	if row.is_empty() or g.coins < price:
		return false
	g.coins -= price
	g.site_state()["stored"].append({"id": item_id,
		"effect": row.get("effect", ""),
		"reach": int(row.get("reach", 1))})
	g.touch()
	return true


func _rebuy_pit(price: int) -> bool:
	var st: Dictionary = g.site_state()
	if g.coins < price or fire_pit_upgraded():
		return false
	g.coins -= price
	st["campfire"]["radius"] = 3
	g.touch()
	return true
