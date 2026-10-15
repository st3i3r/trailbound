class_name SimGrid
extends RefCounted
## Shared cell-grid helpers — the ONE parser for layout.nav and
## the ONE home of the 64px cell contract (was duplicated across
## SimDirector, game.gd and tests). Pure data, no Nodes.

const CELL := 64.0


static func px_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / CELL), int(p.y / CELL))


static func cell_pt(c: Vector2i, dy := 48.0) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + dy)


static func blocked(layout: Dictionary) -> Dictionary:
	var out := {}
	for c in layout.get("nav", {}).get("blocked", []):
		out[Vector2i(int(c[0]), int(c[1]))] = true
	return out


## Walkable = core grid minus nav.blocked (pads are soft-passable,
## so they stay in the set).
static func walk_cells(layout: Dictionary) -> Dictionary:
	var out := {}
	var core: Array = layout.get("camp_core_max_cells", [0, 0])
	var nav := blocked(layout)
	for y in int(core[1]):
		for x in int(core[0]):
			var c := Vector2i(x, y)
			if not nav.has(c):
				out[c] = true
	return out


## BFS from `seed`; sentinel means "first inserted cell" (legacy callers).
## Maps with isolated pockets (west bank, yard) must seed from a known
## gameplay cell — the pads pass one explicitly.
static func reachable(cells: Dictionary,
		seed := Vector2i(-999, -999)) -> Dictionary:
	if cells.is_empty():
		return {}
	if seed.x == -999:
		seed = cells.keys()[0]
	if not cells.has(seed):
		return {}
	var seen := {seed: true}
	var queue := [seed]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## Largest connected component — the playable field when a layout has
## isolated pockets (painted water/banks that are real cells but not
## reachable from camp).
static func largest_component(cells: Dictionary) -> Dictionary:
	var rest: Dictionary = cells.duplicate()
	var best := {}
	while not rest.is_empty():
		var comp := reachable(rest, rest.keys()[0])
		if comp.size() > best.size():
			best = comp
		for c in comp:
			rest.erase(c)
	return best
