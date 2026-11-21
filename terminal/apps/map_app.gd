extends HBoxContainer
## Map of Kessel (Approved Areas): the places in this run's town, the leads people gave you.
## Going out to them is step 2 (short hands-on scenes); for now it's your planning board.

const T := preload("res://terminal/os_theme.gd")
const WorldGen := preload("res://sim/world_gen.gd")

var desk
var state
var _list: ItemList
var _ids: Array = []
var _detail: RichTextLabel


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(360, 0)
	_list.item_selected.connect(_show)
	add_child(_list)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.meta_clicked.connect(func(m): desk.open_app("browser", str(m).substr(3)))
	add_child(_detail)
	var biz: Array = state.world.get("businesses", []).duplicate()
	biz.sort_custom(func(a, b): return (1 if state.leads.has(a["id"]) else 0) > (1 if state.leads.has(b["id"]) else 0))
	for b in biz:
		_ids.append(b["id"])
		var lead: bool = state.leads.has(b["id"])
		var is_target: bool = WorldGen.data()["business_kinds"].get(b["kind"], {}).get("target", false)
		_list.add_item("%s%s   (%s)%s" % ["[LEAD] " if lead else "", b["name"], WorldGen.business_label(str(b["kind"])), "  *" if is_target else ""])
		if lead:
			_list.set_item_custom_fg_color(_list.item_count - 1, T.DANGER)
	_detail.text = "[b]%s[/b]\n\n%d places on the approved map. [color=#a03020]LEAD[/color] = someone pointed you here. * = worth hitting later (guns, materials, dirt).\n\n[color=#6b6b5f]Going out (short hands-on visits) arrives in step 2.[/color]" % [state.world.get("town", "Kessel"), _ids.size()]


func _show(i: int) -> void:
	var b: Dictionary = WorldGen.find(state.world, "businesses", _ids[i])
	var k: Dictionary = WorldGen.data()["business_kinds"].get(b["kind"], {})
	var why := ""
	match str(b["kind"]):
		"gun_store":
			why = "Guns and ammunition."
		"refinery":
			why = "War materials: metal for gear, meds, tech, guns."
		"ministry":
			why = "Dirt. Dirt pulls people in."
		"cafe", "lounge":
			why = "Public computers: post and browse without it being your laptop."
		"hospital":
			why = "Meds, staff with badges."
		"police":
			why = "Dispatch, evidence room. Dangerous."
	_detail.text = "[b]%s[/b]\n%s, %s %d\n\n%s\n%s\n\n%s\n\n[url=go:netstate.vd/biz/%s]Open its NetState page[/url]" % [
		b["name"], WorldGen.business_label(str(b["kind"])), b["street"], int(b["number"]), b["flavor"],
		"[color=#a03020]What you know: %s[/color]" % b["weakness"] if state.leads.has(b["id"]) else "[color=#6b6b5f]You don't know its weak spot yet.[/color]",
		why, b["id"]]
