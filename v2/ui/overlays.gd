extends RefCounted
## Full-screen in-game overlays: the morning card, the night ledger, the pause menu, the raid stub, game over.
## Each frees itself; the garage tracks the top one through Menus.back_top.

const Kit := preload("res://v2/ui/kit.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Menus := preload("res://v2/ui/menus.gd")
const Content := preload("res://v2/sim/content.gd")
const JobCards := preload("res://v2/ui/job_cards.gd")


static func _base(parent: Control, alpha := 0.6) -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.z_index = 30
	parent.add_child(o)
	Kit.dim(o, alpha)
	return o


static func _paper(v: VBoxContainer) -> VBoxContainer:
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.058, 0.045, 0.97)
	sb.border_color = Pal.BRASS
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	paper.add_theme_stylebox_override("panel", sb)
	v.add_child(paper)
	var pv := VBoxContainer.new()
	paper.add_child(pv)
	return pv


## Morning: the day number and the rule of the day. Click to start.
static func day_card(parent: Control, game: Node, on_close: Callable) -> Control:
	var st = game.state
	if st.job == "" and not st.job_offers.is_empty():
		# a new game (or you got fired): three job cards, then the normal morning card
		var econ0 = load("res://v2/sim/economy.gd")
		return JobCards.open(parent, game, st.job_offers, func(offer: Dictionary) -> void:
			econ0.take_job(st, offer)
			day_card(parent, game, on_close))
	var o := _base(parent, 0.5)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var v := VBoxContainer.new()
	center.add_child(v)
	var pv := _paper(v)
	pv.add_child(Kit.title_tag("DAY %d" % st.day, 16))
	pv.add_child(Kit.label("%s. Your shift is over. Tonight you have %d big actions; small things are free." % [Content.world().get("town", ""), int(st.actions)], Pal.TEXT, 9, 230))
	var econ = load("res://v2/sim/economy.gd")
	var must_choose := false
	if st.job != "" and not st.steal_done:
		must_choose = true
		var jd2: Dictionary = econ.job_def(st.job)
		pv.add_child(Kit.label("AT %s TODAY  (suspicion %d)" % [str(jd2.get("place", "work")).to_upper(), int(st.suspicion)], Pal.BRASS, 9))
		var row := HBoxContainer.new()
		pv.add_child(row)
		var steal: Dictionary = econ.data().get("steal", {})
		for k in ["nothing", "little", "lot"]:
			var choice: String = k
			var b2 := Kit.button(str(steal.get(k, {}).get("label", k)), func() -> void:
				var lines: Array = econ.steal(st, choice)
				game.sfx.play("drop_002", 0.9, -6.0)
				o.queue_free()
				game.set_meta("work_lines", lines)
				day_card(parent, game, on_close), game)
			b2.add_theme_font_size_override("font_size", 8)
			row.add_child(b2)
	if game.has_meta("work_lines"):
		for ln in game.get_meta("work_lines"):
			pv.add_child(Kit.label(str(ln), Pal.MULT if str(ln).begins_with("AUDIT") or str(ln).begins_with("FIRED") else Pal.TEXT, 8, 230))
		game.remove_meta("work_lines")
	# the Bureau notice (D): what your raid caused, in their words, and what it does to Krall's clock
	var kr = load("res://v2/sim/krall.gd")
	for n in kr.unseen_notes(st):
		pv.add_child(Kit.label("BUREAU NOTICE", Color(1.0, 0.55, 0.45), 9))
		pv.add_child(Kit.label(str(n["text"]), Pal.TEXT, 8, 230))
		var nn := float(n.get("nights", 0.0))
		pv.add_child(Kit.label("Because of it, Inspector Krall is %s night%s closer. %s." % [str(snappedf(nn, 0.5)).trim_suffix(".0"), "" if nn <= 1.0 else "s", "Next: " + str(kr.summary(st)).replace("KRALL: ", "").to_lower()], Pal.DIM, 8, 230))
	var picking_job: bool = st.job == "" and not st.job_offers.is_empty()
	var rule: Dictionary = st.rule()
	if not picking_job:
		pv.add_child(Kit.label("RULE OF THE DAY", Pal.BRASS, 9))
		pv.add_child(Kit.label(str(rule.get("title", "")), Pal.TEXT, 12, 230))
		pv.add_child(Kit.label(str(rule.get("text", "")), Pal.DIM, 8, 230))
	var go := Kit.button("Into the garage", func() -> void:
		o.queue_free()
		on_close.call(), game)
	go.disabled = must_choose
	v.add_child(go)
	if not must_choose:
		o.set_meta("back", func() -> void:
			o.queue_free()
			on_close.call())
	# Slide in.
	center.position.y = 40
	center.modulate.a = 0.0
	var tw := center.create_tween().set_parallel(true)
	tw.tween_property(center, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(center, "modulate:a", 1.0, 0.2)
	game.sfx.play("bong_001", 0.8, -8.0)
	return o


## Night: what the Bureau did, typed out line by line.
static func ledger(parent: Control, game: Node, lines: Array, saved: bool, on_close: Callable) -> Control:
	var o := _base(parent, 0.92)
	var v := Kit.panel(o, "NIGHT %d" % (int(game.state.day) - 1), Vector2(260, 0))
	v.add_child(Kit.label("While you slept:", Pal.DIM, 9))
	var labels: Array = []
	for line in lines:
		var l := Kit.label("- " + str(line), Pal.TEXT, 9, 250)
		l.visible_ratio = 0.0
		v.add_child(l)
		labels.append(l)
	var saved_l := Kit.label("Game saved." if saved else "Autosave FAILED.", Pal.GREEN if saved else Pal.MULT, 8)
	saved_l.modulate.a = 0.0
	v.add_child(saved_l)
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	var done := func() -> void:
		o.queue_free()
		on_close.call()
	r.add_child(Kit.button("Wake up", done, game))
	o.set_meta("back", done)
	var tw := o.create_tween()
	for l in labels:
		tw.tween_property(l, "visible_ratio", 1.0, 0.5)
		tw.tween_callback(func() -> void: game.sfx.play("tick_001", 0.7, -12.0))
	tw.tween_property(saved_l, "modulate:a", 1.0, 0.3)
	return o


static func pause(parent: Control, game: Node, garage: Node) -> Control:
	var o := _base(parent, 0.6)
	var v := Kit.panel(o, "PAUSED", Vector2(160, 0))
	var close := func() -> void: o.queue_free()
	v.add_child(Kit.button("Resume", close, game))
	v.add_child(Kit.button("Save game", func() -> void: Menus.slots(parent, game, true), game))
	v.add_child(Kit.button("Load game", func() -> void: Menus.slots(parent, game, false), game))
	v.add_child(Kit.button("Settings", func() -> void: Menus.settings(parent, game), game))
	v.add_child(Kit.button("Main menu", func() -> void:
		Menus.confirm(parent, game, "Back to the main menu? Anything since your last save is lost.", func() -> void: game.quit_to_title()), game))
	v.add_child(Kit.button("Quit to desktop", func() -> void:
		Menus.confirm(parent, game, "Quit? Anything since your last save is lost.", func() -> void: game.quit_game()), game))
	v.add_child(HSeparator.new())
	v.add_child(Kit.label("Day %d  %s" % [game.state.day, game.state.clock_text()], Pal.DIM, 8))
	o.set_meta("back", close)
	return o


## The raid stub: a warning, a 20 second scramble, a placeholder result.
static func raid(parent: Control, game: Node, garage: Node) -> Control:
	var o := _base(parent, 0.4)
	var v := Kit.panel(o, "RAID WARNING", Vector2(250, 0))
	v.add_child(Kit.label("Your scanner crackles: Bureau vans turning onto your street.", Pal.TEXT, 9, 240))
	var timer_l := Kit.label("20", Pal.MULT, 20)
	v.add_child(timer_l)
	var items := ["Laptop: wipe it", "Rig: hide it in the pit", "Notes: burn them", "Parts: out the back"]
	for it in items:
		var holder: Array = []
		var b: Button = Kit.button(it, func() -> void:
			var me: Button = holder[0]
			if me.disabled:
				return
			me.disabled = true
			me.text = it + "  (done)"
			game.sfx.play("drop_002", 0.8, -4.0)
			garage.shake(0.2), game)
		holder.append(b)
		v.add_child(b)
	v.add_child(Kit.label("Placeholder: the raid isn't simulated yet.", Pal.DIM, 8))
	var left := [20.0]
	var tick := Timer.new()
	tick.wait_time = 0.1
	o.add_child(tick)
	var finish := func() -> void:
		garage.set_alarm(false)
		o.queue_free()
		Menus.message(parent, game, "They searched the garage and left. (Placeholder: nothing was taken.)", Callable(), "THE RAID")
	tick.timeout.connect(func() -> void:
		left[0] -= 0.1
		timer_l.text = "%d" % ceili(maxf(left[0], 0.0))
		if left[0] <= 0.0:
			tick.stop()
			finish.call())
	tick.start()
	garage.set_alarm(true)
	game.sfx.play("error_006", 0.6, 0.0)
	o.set_meta("back", func() -> void: pass)
	return o


static func game_over(parent: Control, game: Node, reason: String) -> Control:
	var o := _base(parent, 0.95)
	var v := Kit.panel(o, "ARRESTED", Vector2(240, 0))
	v.add_child(Kit.label(reason, Pal.TEXT, 10, 230))
	v.add_child(Kit.label("Day %d. Early on, nobody is coming for you. (Placeholder game over.)" % game.state.day, Pal.DIM, 8, 230))
	v.add_child(Kit.button("Load a save", func() -> void: Menus.slots(parent, game, false), game))
	v.add_child(Kit.button("Main menu", func() -> void: game.quit_to_title(), game))
	game.sfx.play("error_004", 0.5, 0.0)
	o.set_meta("back", func() -> void: pass)
	return o
