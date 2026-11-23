extends PanelContainer
## F1 debug panel: poke the hidden state, jump days, trigger events, open the old prototypes.
## F3 toggles a live state readout.

const Kit := preload("res://v2/ui/kit.gd")
const Materials := preload("res://v2/sim/materials.gd")
const Pal := preload("res://v2/ui/pal.gd")

var garage: Node
var game: Node
var _readout: Label


func setup(p_garage: Node) -> void:
	garage = p_garage
	game = p_garage.game
	z_index = 35
	position = Vector2(4, 40)
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(Kit.label("DEBUG (F1)", Pal.GREEN, 10))
	var grid := GridContainer.new()
	grid.columns = 2
	v.add_child(grid)
	var add := func(text: String, cb: Callable) -> void:
		var b := Kit.button(text, func() -> void:
			cb.call()
			garage.refresh(), game)
		b.add_theme_font_size_override("font_size", 8)
		grid.add_child(b)
	add.call("+100 cr", func() -> void: game.state.money += 100)
	add.call("Refill hours", func() -> void: game.state.minute = int(game.state.end_minute) - 8 * 60)
	add.call("-1 hour", func() -> void: game.state.spend(1.0))
	add.call("End day", func() -> void: garage.sleep())
	add.call("Attention +20", func() -> void: game.state.attention = minf(100.0, game.state.attention + 20.0))
	add.call("Attention 0", func() -> void: game.state.attention = 0.0)
	add.call("Pool -500", func() -> void: game.state.pool = maxi(1, game.state.pool - 500))
	add.call("Unlock all", func() -> void:
		for id in ["bench_gun", "forgery", "hatch"]:
			if not game.state.unlocked.has(id):
				game.state.unlocked.append(id)
		garage.toast("Everything unlocked."))
	add.call("+5 materials", func() -> void:
		for k in game.state.materials.keys():
			Materials.add(game.state, k, 5, 3)
		garage.toast("+5 of every material."))
	add.call("Master recipes", func() -> void:
		for r in load("res://v2/sim/crafting.gd").data().get("recipes", []):
			game.state.mastery[r["id"]] = {"made": 3, "good": 3, "sum": 2.4}
		garage.toast("Every recipe mastered (batching on)."))
	add.call("Learn all hacks", func() -> void:
		load("res://v2/sim/hack.gd").learn_all(game.state)
		garage.toast("Every hacking program learned (DIRT, EYES, REROUTE, PAYDAY)."))
	add.call("+1 drop stick", func() -> void:
		game.state.items.append({"id": game.state.next_item_id, "name": "Drop stick", "type": "device", "device": "drop_stick", "stars": 2, "quality": 0.6, "perks": [], "day": game.state.day})
		game.state.next_item_id += 1
		garage.toast("A drop stick is on the shelves."))
	add.call("+1 night action", func() -> void: game.state.actions += 1)
	add.call("Raid warning", func() -> void: garage.raid())
	add.call("Arrest", func() -> void: garage.arrest("They came at 04:00. Placeholder."))
	add.call("Quicksave (F5)", func() -> void: garage.quicksave())
	add.call("Toy: Packet Pit", func() -> void: game.run_external("res://v2/pit_toy.tscn"))
	add.call("Toy: Breach Hand", func() -> void: game.run_external("res://v2/hand_toy.tscn"))
	add.call("Combat proto", func() -> void: game.run_external("res://tactical/watch/watch_main.tscn"))
	_readout = Kit.label("", Pal.DIM, 8)
	v.add_child(_readout)


func _process(_delta: float) -> void:
	if not visible or game.state == null:
		return
	var s = game.state
	_readout.text = "seed %d  day %d  min %d\nattention %.0f  pool %d\nunlocked %s\nplaytime %ds" % [
		s.world_seed, s.day, s.minute, s.attention, s.pool, str(s.unlocked), int(s.playtime)]
