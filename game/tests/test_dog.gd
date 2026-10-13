extends "res://tests/harness.gd"
## Headless dog checks (GDD §9). Run:
##   godot --headless --path game tests/test_dog.tscn
## Exit code = number of failed checks.


func _ready() -> void:
	print("=== the dog (§9) ===")

	Game.dog = {"name": "Bean", "bond": 0, "met": false,
		"pet_today": false}
	# Night 1 at Pinewatch: the stray comes for the leftover stew —
	# with no seats the walk-ins can't take them, so the dog eats.
	Game.visit_site(&"pinewatch")
	Game.day = 0
	Game.sites_visited["pinewatch"] = 0          # site_day 1
	Game.new_day()
	Game.site_state()["seats"] = 0
	Game.meals = [{"id": "stew", "price": 18}, {"id": "tea", "price": 8}]
	Game.set_phase(Game.Phase.EVENING)
	Game.goodnight()
	check("stray meets night 1", Game.dog["met"])
	check("leftovers feed bond", Game.dog["bond"] == 2,
		"got %d" % Game.dog["bond"])
	check("pet once a day", Game.dog_pet() and Game.dog["bond"] == 4
		and not Game.dog_pet())
	Game.pantry = {}
	Game.new_day()                               # resets pet + dig
	var dug: int = Game.pantry.size() + Game.pantry.values().reduce(
		func(a, x): return a + int(x), 0)
	check("digs a bonus item", Game.dog["pet_today"] == false
		and dug >= 1 and Game.dog_pet())
	# Bond levels and the đá cầu chase.
	var lvls := []
	for b in [0, 9, 10, 24, 25, 49, 50, 79, 80]:
		Game.dog["bond"] = b
		lvls.append(Game.dog_level())
	check("bond levels 0-4", lvls == [0, 0, 1, 1, 2, 2, 3, 3, 4],
		"got %s" % [lvls])
	check("last trick is đá cầu", Game.dog_trick() == "da_cau")
	Game.name_dog("Bơ")
	check("rename keeps value", Game.dog["name"] == "Bơ")
	Game.name_dog("   ")
	check("blank name rejected", Game.dog["name"] == "Bơ")
	check("dog in save", Game.state_dict()["dog"]["met"] == true)

	finish()
