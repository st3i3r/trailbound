extends RefCounted
## §33.5 Camp Postcards [C]: a short text code carrying
## {version, site, seed, decor placements} + checksum — a friend
## types ~45 chars and replays that camp as a seeded sandbox night.
## No backend, no free text: the code IS the state.
##
## Wire format (big-endian bitstream, Crockford base32 chars):
##   ver 4b | site 2b | seed 20b | ndecor 5b |
##   per item: {item 6b into the site's decor row order,
##              cell 7b into the layout's decor_cells order}
##   check 10b (FNV-1a over the payload chars)
## ~2 + 3·N chars of layout for N placed items — a typical camp
## (8–12 pieces) lands inside the 40–50 char target.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # no ILOU
const VERSION := 1
const SITE_IDS := ["pinewatch", "whisper_river", "lantern_valley"]
const SEED_BITS := 20                      # night seeds stay < 1M


class BitWriter:
	var chars := ""
	var acc := 0
	var nbits := 0

	func push(value: int, bits: int) -> void:
		acc = (acc << bits) | (value & ((1 << bits) - 1))
		nbits += bits
		while nbits >= 5:
			var sh := nbits - 5
			chars += ALPHABET[(acc >> sh) & 31]
			acc &= (1 << sh) - 1
			nbits = sh

	func finish() -> String:
		if nbits > 0:                        # pad the tail with zeros
			chars += ALPHABET[(acc << (5 - nbits)) & 31]
		return chars


class BitReader:
	var data := 0
	var nbits := 0
	var src := ""
	var at := 0

	func _init(s: String) -> void:
		src = s

	func take(bits: int) -> int:
		while nbits < bits:
			if at >= src.length():
				return -1                  # short code
			var v := ALPHABET.find(src[at])
			if v < 0:
				return -1
			at += 1
			data = (data << 5) | v
			nbits += 5
		var sh := nbits - bits
		var out := (data >> sh) & ((1 << bits) - 1)
		data &= (1 << sh) - 1
		nbits = sh
		return out


## FNV-1a over the payload text — catches typos, not adversaries;
## the code carries no free text so a bad checksum just no-ops.
static func _checksum(payload: String) -> int:
	var h := 0x811c9dc5
	for i in payload.length():
		h = ((h ^ payload.unicode_at(i)) * 0x01000193) & 0x3fffffff
	return h & 0x3ff


## decor items are addressed as indices into the decor catalog
## order (stable: sorted by id) — the receiver needs the same
## data files, which the version field guards.
static func _decor_ids() -> Array:
	var ids := []
	for r in Catalog.data.get("decor", []):
		ids.append(String(r.get("id", "")))
	ids.sort()
	return ids


static func encode(site_id: String, seed: int, decor: Array) -> String:
	var bw := BitWriter.new()
	bw.push(VERSION, 4)
	bw.push(maxi(0, SITE_IDS.find(site_id)), 2)
	bw.push(seed & ((1 << SEED_BITS) - 1), SEED_BITS)
	var ids := _decor_ids()
	var layout: Dictionary = Catalog.data.get("layouts", {}).get(
		site_id, {})
	var cells_all: Array = layout.get("decor_cells", [])
	var packable := []
	for d in decor:
		var ii := ids.find(String(d.get("id", "")))
		var cs: Array = d.get("cells", [])
		if ii < 0 or cs.is_empty():
			continue
		var c0: Variant = cs[0]
		var c_arr: Array = [int(c0.x), int(c0.y)] \
			if c0 is Vector2i else c0
		var ci := -1
		for i in cells_all.size():
			var lc: Array = cells_all[i]
			if int(lc[0]) == int(c_arr[0]) \
					and int(lc[1]) == int(c_arr[1]):
				ci = i
				break
		if ci >= 0:
			packable.append([ii, ci])
	bw.push(mini(packable.size(), 31), 5)
	for p in packable.slice(0, 31):
		bw.push(p[0], 6)
		bw.push(p[1], 7)
	var payload := bw.finish()
	return "%s-%s%s" % [payload, ALPHABET[_checksum(payload) >> 5],
		ALPHABET[_checksum(payload) & 31]]


## -> {ok, site, seed, decor, version} | {ok:false}
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges().to_upper().replace("-", "")
	if c.length() < 8:
		return {"ok": false}
	var payload := c.substr(0, c.length() - 2)
	var want := (ALPHABET.find(c[c.length() - 2]) << 5) \
		| ALPHABET.find(c[c.length() - 1])
	if want < 0 or want != _checksum(payload):
		return {"ok": false}
	var br := BitReader.new(payload)
	var ver := br.take(4)
	var site_i := br.take(2)
	var seed := br.take(SEED_BITS)
	var nd := br.take(5)
	if ver != VERSION or site_i < 0 or seed < 0 or nd < 0:
		return {"ok": false}
	var site: String = SITE_IDS[mini(site_i, SITE_IDS.size() - 1)]
	var ids := _decor_ids()
	var cells_all: Array = Catalog.data.get("layouts", {}).get(
		site, {}).get("decor_cells", [])
	var decor := []
	for _i in nd:
		var ii := br.take(6)
		var ci := br.take(7)
		if ii < 0 or ci < 0 or ii >= ids.size() \
				or ci >= cells_all.size():
			return {"ok": false}
		var row: Dictionary = {}
		for r in Catalog.data.get("decor", []):
			if String(r.get("id", "")) == ids[ii]:
				row = r
				break
		var lc: Array = cells_all[ci]
		var cells := [Vector2i(int(lc[0]), int(lc[1]))]
		if String(row.get("size", "1x1")) == "2x1":
			cells.append(Vector2i(int(lc[0]) + 1, int(lc[1])))
		decor.append({"id": ids[ii], "cells": cells})
	return {"ok": true, "version": ver, "site": site,
		"seed": seed, "decor": decor}


## §33.5 consumer half: a typed code → a sandbox site-state that
## cast_night/cast_day accept unchanged. The shared camp is the
## layout + decor; guests arrive as trailhead wanderers (nothing is
## seated — it's a visit, not a takeover) and weather/beats roll off
## the postcard seed, so the same code casts the same night.
static func materialize(code: String) -> Dictionary:
	var d := decode(code)
	if not d.get("ok"):
		return {"ok": false}
	var site: String = d["site"]
	var srow := {}
	for r in Catalog.data.get("sites", []):
		if String(r.get("id", "")) == site:
			srow = r
			break
	var layout: Dictionary = Catalog.data.get("layouts", {}).get(
		site, {})
	if srow.is_empty() or layout.is_empty():
		return {"ok": false}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["seed"])
	var roll := rng.randf()
	var storm := float(srow.get("storm_chance", 0.08))
	var rain := float(srow.get("rain_chance", 0.2))
	var weather := "storm" if roll < storm \
		else ("rain" if roll < storm + rain else "clear")
	var pad_ids: Array = layout.get("pads", {}).get("spots",
		{}).keys()
	var board: Array = Seating.board(srow,
		Catalog.data.get("archetypes", []),
		8 + rng.randi() % 20, pad_ids, 4.0, rng)
	var st := {"decor": d["decor"], "weather": weather,
		"event": "", "board": board, "assignments": {},
		"guests": {}, "served": {}, "music_night": false,
		"dog": {}}
	return {"ok": true, "site": site, "seed": int(d["seed"]),
		"st": st, "layout": layout}
