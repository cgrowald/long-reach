extends VBoxContainer
## Nod - Citizen Social. The state's social network: cheerful propaganda, neighbours, your posts.
## Posting dirt here brings followers, and the Bureau reads every word.

const T := preload("res://terminal/os_theme.gd")
const POSTS := [
	["Ministry_of_Information", "Reminder: a connected citizen is a safe citizen. Report fakes for Citizen Points."],
	["StateTelevision", "Tonight at 8: the Marshal's birthday week continues with a 4-hour tribute concert."],
	["{name}", "Bread at {business} today! Queue already round the block 🍞"],
	["{name}", "Somebody on {street} runs power tools at 2am. Some of us have to sleep."],
	["{name}", "[post removed by moderators]"],
	["Kessel_Precinct", "Thank you to the citizens who reported suspicious activity this week. Rewards have been paid."],
	["{name}", "Proud of my son, accepted into the Youth Vigilance League today!"],
	["{name}", "does anyone know why the Oster bridge took 3 hours today"],
	["CitizenCare", "Did you know? Deleting a post does not delete it. Post responsibly."],
]

var desk
var state
var _head: Label
var _feed: RichTextLabel
var _text: TextEdit
var _attach: OptionButton
var _paths: Array = []


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_head = T.label("", 15)
	add_child(_head)
	var bg := PanelContainer.new()
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_theme_stylebox_override("panel", T.box(Color(0.95, 0.94, 0.9), Color(0.55, 0.53, 0.48), 1, 0))
	add_child(bg)
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	bg.add_child(_feed)
	add_child(T.label("New post (verified citizen number required. Your post will be reviewed for your safety):", 12, T.DIM))
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, 56)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.placeholder_text = "What's on your mind, citizen?"
	add_child(_text)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(T.label("Attach:"))
	_attach = OptionButton.new()
	row.add_child(_attach)
	var post := Button.new()
	post.text = "Post"
	post.pressed.connect(_post)
	row.add_child(post)
	state.changed.connect(_refresh)
	_fill_attach()
	_refresh()


func _fill_attach() -> void:
	_attach.clear()
	_paths = [""]
	_attach.add_item("(nothing)")
	for path in state.files:
		var f: Dictionary = state.files[path]
		if str(f.get("type", "")) in ["image", "text"] and (f.has("stars") or str(path).begins_with("/Pictures")):
			_paths.append(path)
			_attach.add_item(("%s  %s" % ["*".repeat(int(f.get("stars", 0))), str(path).get_file()]).strip_edges())


func _refresh() -> void:
	if not is_inside_tree():
		return
	_head.text = "@citizen_0447   -   followers: %d   -   account status: %s" % [state.followers, ["GOOD STANDING", "NOTED", "UNDER REVIEW", "RESTRICTED"][state.exposure_level()]]
	var people: Array = state.world.get("people", [])
	var biz: Array = state.world.get("businesses", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.world.get("seed", 1)) + state.day * 13
	var txt := ""
	for p in state.posts:
		txt += "[b]@citizen_0447 (you)[/b]   [color=#3c7a3c]+%d followers[/color]\n%s\n\n" % [int(p["gained"]), str(p["text"]).replace("[", "[lb]")]
	for i in 7:
		var tpl: Array = POSTS[rng.randi() % POSTS.size()]
		var who: String = str(tpl[0])
		var body: String = str(tpl[1])
		if not people.is_empty():
			var p: Dictionary = people[rng.randi() % people.size()]
			who = who.replace("{name}", "%s_%s" % [p["first"].to_lower(), p["last"].to_lower()])
			body = body.replace("{street}", str(p["street"]))
		if not biz.is_empty():
			body = body.replace("{business}", str(biz[rng.randi() % biz.size()]["name"]))
		txt += "[b]@%s[/b]\n%s\n\n" % [who, body]
	_feed.text = txt


func _post() -> void:
	var text := _text.text.strip_edges()
	var path: String = str(_paths[_attach.selected])
	if text == "" and path == "":
		desk.sfx.play("error")
		return
	state.make_post(text if text != "" else "(no text)", path)
	if path != "" and state.files.get(path, {}).has("stars"):
		state.add_exposure(1, "posted %s on Nod (the Bureau reads Nod)" % path.get_file())
	desk.sfx.play("chime", -12.0)
	_text.text = ""
	_refresh()
