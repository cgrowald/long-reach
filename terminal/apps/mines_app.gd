extends VBoxContainer
## Field Clearance: approved by the Ministry of Defense. (A minesweeper.)

const T := preload("res://terminal/os_theme.gd")
const W := 9
const H := 9
const MINES := 10

var desk
var state
var _grid: GridContainer
var _status: Label
var _mines: Array = []
var _open: Array = []
var _flag: Array = []
var _buttons: Array = []
var _over := false
var _first := true


func setup(d, st, _arg) -> void:
	desk = d
	state = st
	_status = T.label("Clear the field. Right-click to flag.", 13)
	add_child(_status)
	_grid = GridContainer.new()
	_grid.columns = W
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	add_child(_grid)
	var again := Button.new()
	again.text = "New field"
	again.pressed.connect(_reset)
	add_child(again)
	_reset()


func _reset() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_mines = []
	_open = []
	_flag = []
	for i in W * H:
		_mines.append(false)
		_open.append(false)
		_flag.append(false)
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		var idx := i
		b.gui_input.connect(func(e): _input_cell(e, idx))
		_grid.add_child(b)
		_buttons.append(b)
	_over = false
	_first = true
	_status.text = "Clear the field. Right-click to flag."


func _place(safe: int) -> void:
	var n := 0
	while n < MINES:
		var i := randi() % (W * H)
		if not _mines[i] and i != safe:
			_mines[i] = true
			n += 1


func _input_cell(e: InputEvent, i: int) -> void:
	if _over or not (e is InputEventMouseButton and e.pressed):
		return
	if e.button_index == MOUSE_BUTTON_RIGHT and not _open[i]:
		_flag[i] = not _flag[i]
		_buttons[i].text = "F" if _flag[i] else ""
		return
	if e.button_index != MOUSE_BUTTON_LEFT or _flag[i]:
		return
	desk.sfx.play("click")
	if _first:
		_place(i)
		_first = false
	if _mines[i]:
		_over = true
		for j in W * H:
			if _mines[j]:
				_buttons[j].text = "*"
				_buttons[j].modulate = Color(1, 0.5, 0.5)
		_status.text = "BOOM. The Ministry thanks you for your service."
		desk.sfx.play("error")
		return
	_reveal(i)
	var closed := 0
	for j in W * H:
		if not _open[j]:
			closed += 1
	if closed == MINES:
		_over = true
		_status.text = "Field cleared. The Marshal is proud of you."
		state.find_secret("mines", "Field Clearance champion")


func _reveal(i: int) -> void:
	if _open[i] or _flag[i]:
		return
	_open[i] = true
	var n := _count(i)
	var b: Button = _buttons[i]
	b.disabled = true
	b.text = str(n) if n > 0 else ""
	if n == 0:
		for j in _neighbors(i):
			_reveal(j)


func _count(i: int) -> int:
	var n := 0
	for j in _neighbors(i):
		if _mines[j]:
			n += 1
	return n


func _neighbors(i: int) -> Array:
	var out: Array = []
	var x := i % W
	var y := i / W
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and ny >= 0 and nx < W and ny < H:
				out.append(ny * W + nx)
	return out
