extends Control
## Base for a station screen (what you see when you lean in). Subclasses override build().
## garage = the garage scene (spend hours, toasts, open other screens); def = the station's JSON.

const Kit := preload("res://v2/ui/kit.gd")
const Pal := preload("res://v2/ui/pal.gd")
const Menus := preload("res://v2/ui/menus.gd")
const Content := preload("res://v2/sim/content.gd")

var garage: Node
var game: Node
var def: Dictionary = {}


func setup(p_garage: Node, p_def: Dictionary) -> void:
	garage = p_garage
	game = p_garage.game
	def = p_def
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)


func build() -> void:
	pass


## Esc / right-click. Return true if the screen handled it itself (e.g. closed an inner window).
## Subclasses that override this call put_paper_down() first.
func back() -> bool:
	return put_paper_down()


# ------------------------------------------------------------------ paper (v2/ui/paper.gd)

var paper: Control


## Look at a depot plan file (a Bureau SERVICE FORM).
func show_plan(item: Dictionary) -> void:
	var sheet: Dictionary = load("res://v2/sim/depot_run.gd").plan_sheet(game.state, item)
	_new_paper().show_plan(sheet)


## Look at someone's ID card (the prisoner's).
func show_id(person: Dictionary) -> void:
	_new_paper().show_id(person)


func _new_paper() -> Control:
	put_paper_down()
	paper = load("res://v2/ui/paper.gd").new()
	add_child(paper)
	paper.size = size
	return paper


## Close the paper if one is up. True if it was.
func put_paper_down() -> bool:
	if paper and is_instance_valid(paper):
		paper.put_down()
		paper = null
		return true
	return false


func close() -> void:
	garage.close_station()


## A framed panel taking most of the screen: title bar + close button. Returns the content area.
func frame(title: String, margin := Vector2(18, 16)) -> Control:
	var pc := PanelContainer.new()
	pc.position = margin
	pc.size = size - margin * 2.0
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_left = margin.x
	pc.offset_top = margin.y
	pc.offset_right = -margin.x
	pc.offset_bottom = -margin.y
	add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	bar.add_child(Kit.title_tag(title))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	if def.get("hours", 0.0) > 0.0:
		bar.add_child(Kit.label("%sh" % _h(def["hours"]), Pal.DIM, 8))
	bar.add_child(Kit.button("X", close, game))
	v.add_child(HSeparator.new())
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	return body


## The locked placeholder: why it's locked and how it'll open.
func locked_panel() -> void:
	var v := Kit.panel(self, def.get("name", "").to_upper(), Vector2(220, 0))
	v.add_child(Kit.label("LOCKED", Pal.MULT, 10))
	v.add_child(Kit.label(def.get("lock_text", ""), Pal.TEXT, 10, 220))
	v.add_child(Kit.label("(Debug: F1 > Unlock all.)", Pal.DIM, 8))
	var r := Kit.row(v)
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(Kit.button("Back", close, game))


static func _h(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
