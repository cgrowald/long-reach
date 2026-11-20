extends HBoxContainer
## Messages: encrypted-ish chats. Contacts on the left, the conversation on the right, reply choices below.

const T := preload("res://terminal/os_theme.gd")

var desk
var state
var _list: ItemList
var _ids: Array = []
var _current: String = ""
var _header: Label
var _log: RichTextLabel
var _typing: Label
var _replies: VBoxContainer
var _delete: Button
var _sig: String = ""
var _names: Array = []


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	add_child(left)
	var newb := Button.new()
	newb.text = "+ New chat"
	newb.focus_mode = Control.FOCUS_NONE
	newb.pressed.connect(_new_chat)
	left.add_child(newb)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i): _open(_ids[i]))
	left.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	_header = T.label("Select a conversation", 16)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	_delete = Button.new()
	_delete.text = "Delete chat"
	_delete.focus_mode = Control.FOCUS_NONE
	_delete.visible = false
	_delete.pressed.connect(_delete_chat)
	top.add_child(_delete)
	var bg := PanelContainer.new()
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_theme_stylebox_override("panel", T.box(Color(0.97, 0.97, 0.95), Color(0.6, 0.62, 0.62), 1, 2))
	right.add_child(bg)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	bg.add_child(_log)
	_typing = T.label("", 13, T.DIM)
	right.add_child(_typing)
	_replies = VBoxContainer.new()
	right.add_child(_replies)

	state.changed.connect(_refresh)
	_refresh()
	# Open the most recent unread conversation automatically.
	for c in _ids:
		if int(state.convos[c]["unread"]) > 0:
			_open(c)
			break


func _refresh() -> void:
	if not is_inside_tree():
		return
	var ids: Array = []
	var names: Array = []
	for c in state.convos:
		var cv: Dictionary = state.convos[c]
		if not cv["started"]:
			continue
		ids.append(c)
		var u: int = int(cv["unread"])
		names.append(state.contact_name(c) + ("   (%d)" % u if u > 0 and c != _current else ""))
	if names != _names:
		_names = names
		_ids = ids
		_list.clear()
		for n in names:
			_list.add_item(n)
	var idx := _ids.find(_current)
	if idx >= 0:
		_list.select(idx)
		_show(_current)


func _open(c: String) -> void:
	desk.sfx.play("click")
	_current = c
	_refresh()


func _show(c: String) -> void:
	var cv: Dictionary = state.convos[c]
	cv["unread"] = 0
	_header.text = state.contact_name(c)
	_delete.visible = true
	_typing.text = ("%s is typing..." % state.contact_name(c)) if state.is_typing(c) else ""
	var sig := "%s|%d|%s" % [c, cv["log"].size(), str(cv["replies"])]
	if sig == _sig:
		return
	_sig = sig
	var txt := ""
	for m in cv["log"]:
		if str(m["from"]) == "me":
			txt += "[right][bgcolor=#cfe3e0] %s [/bgcolor][/right]\n\n" % _esc(str(m["text"]))
		else:
			txt += "[bgcolor=#e6e6e2] %s [/bgcolor]\n\n" % _esc(str(m["text"]))
	if cv["log"].is_empty():
		txt = "[color=#888]No messages.[/color]"
	_log.text = txt
	for b in _replies.get_children():
		b.queue_free()
	var reps: Array = state.replies_for(c)
	for i in reps.size():
		var b := Button.new()
		b.text = str(reps[i]["text"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var idx := i
		b.pressed.connect(func():
			desk.sfx.play("key")
			state.reply(c, idx))
		_replies.add_child(b)


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _delete_chat() -> void:
	if _current == "":
		return
	var cv: Dictionary = state.convos[_current]
	cv["log"] = []
	state.flags["deleted_" + _current] = true
	desk.sfx.play("click")
	state.changed.emit()


func _new_chat() -> void:
	var box := VBoxContainer.new()
	box.add_child(T.label("Number:"))
	var le := LineEdit.new()
	le.placeholder_text = "e.g. 0412 345 678"
	box.add_child(le)
	var msg := T.label("", 13, T.DANGER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)
	var go := Button.new()
	go.text = "Start chat"
	box.add_child(go)
	var win = desk.open_window("New chat", box, Vector2(340, 190))
	var submit := func(_t = ""):
		var c: String = state.dial(le.text)
		if c != "":
			desk.sfx.play("click")
			_current = c
			state.changed.emit()
			win.close()
			return
		var special: String = state.dial_special(le.text)
		desk.sfx.play("error")
		msg.text = special if special != "" else "This number is not registered in the Citizen Directory."
	go.pressed.connect(submit)
	le.text_submitted.connect(submit)
	le.grab_focus()
