extends "res://v2/os/app.gd"
## ShopNet (the legal shop) and Lantern (the black market on the PC): v2/sim/markets.gd.
## One list, one BUY button per row. The window's app id picks the market ("shop" or "lantern").

const Markets := preload("res://v2/sim/markets.gd")
const Mat := preload("res://v2/sim/materials.gd")

const ROW_H := 26.0
const HEAD_H := 40.0

var market := "shopnet"
var hover := Vector2(-1, -1)
var scroll := 0
var _msg := ""
var _msg_t := 0.0
var _flash := 0.0


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	market = "lantern" if win != null and str(win.get("app_id")) == "lantern" else "shopnet"


func _dark() -> bool:
	return market == "lantern"


func _bg() -> Color:
	return Color(0.06, 0.05, 0.045) if _dark() else P.FACE


func _ink() -> Color:
	return Color(0.95, 0.72, 0.32) if _dark() else P.INK


func _dim() -> Color:
	return Color(0.6, 0.48, 0.3) if _dark() else P.INK_DIM


func _list() -> Array:
	return Markets.offers(state(), market)


func _row(i: int) -> Rect2:
	return Rect2(4, HEAD_H + 14 + (i - scroll) * (ROW_H + 2), size.x - 8, ROW_H)


func _buy_rect(i: int) -> Rect2:
	var r := _row(i)
	return Rect2(r.end.x - 70, r.position.y + 4, 66, 18)


func _visible_rows() -> int:
	return maxi(1, int((size.y - HEAD_H - 40) / (ROW_H + 2)))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover = e.position
		queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		accept_event()
		if not Markets.unlocked(state(), market):
			return
		var n := _list().size()
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampi(scroll + 1, 0, maxi(0, n - _visible_rows()))
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = maxi(0, scroll - 1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			for i in range(scroll, mini(n, scroll + _visible_rows())):
				if _buy_rect(i).has_point(e.position):
					buy(i)
					return
		queue_redraw()


func buy(i: int) -> void:
	var r := Markets.buy(state(), market, i)
	if r["ok"]:
		os.game.sfx.play("confirmation_002", 1.2, -6.0)
		_flash = 1.0
	else:
		os.game.deny()
	_say(r["msg"])


func _say(m: String) -> void:
	_msg = m
	_msg_t = 5.0
	queue_redraw()


func _process(delta: float) -> void:
	if _msg_t > 0.0 or _flash > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg())
	var md := Markets.mdef(market)
	# header
	var hr := Rect2(4, 4, size.x - 8, HEAD_H - 8)
	draw_rect(hr, Color(0.12, 0.09, 0.07) if _dark() else P.PETROL)
	draw_string(P.font(), hr.position + Vector2(6, 13), str(md.get("name", market)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, P.FS + 2, _ink() if _dark() else P.FACE_L)
	P.text(self, hr.position + Vector2(6, 17), str(md.get("sub", "")), _dim() if _dark() else Color(P.FACE_L, 0.7))
	draw_string(P.font(), Vector2(hr.end.x - 110, hr.position.y + 13), "%d cr" % state().money, HORIZONTAL_ALIGNMENT_RIGHT, 104, P.FS + 2, _ink() if _dark() else P.FACE_L)
	var pending := 0
	for od in Markets._s(state())["orders"]:
		if od["market"] == market:
			pending += 1
	P.text(self, Vector2(hr.end.x - 110, hr.position.y + 18), "%d on the way" % pending, _dim() if _dark() else Color(P.FACE_L, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 104)
	if not Markets.unlocked(state(), market):
		P.text(self, Vector2(10, HEAD_H + 20), "lantern://  ADDRESS NOT FOUND", _ink())
		draw_multiline_string(P.font(), Vector2(10, HEAD_H + 46), "Nobody types this address by accident. The fixer knows it: sell him enough files (trust %d) and he'll pass it on." % int(md.get("unlock_trust", 3)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, P.FS, -1, _dim())
		return
	# the list
	var list := _list()
	var cols := ["ITEM", "GRADE", "QTY", "PRICE"]
	var cx := [26.0, size.x - 210, size.x - 160, size.x - 125]
	for c in cols.size():
		P.text(self, Vector2(cx[c], HEAD_H + 1), cols[c], _dim())
	for i in range(scroll, mini(list.size(), scroll + _visible_rows())):
		var o: Dictionary = list[i]
		var r := _row(i)
		var sold: bool = o["sold"]
		draw_rect(r, Color(0.1, 0.08, 0.06) if _dark() else P.WIN)
		draw_rect(r, Color(0.3, 0.22, 0.12) if _dark() else P.FACE_D, false, 1.0)
		var a := 0.35 if sold else 1.0
		P.icon(self, _icon(o), r.position + Vector2(4, 5), 14.0)
		P.text(self, Vector2(cx[0], r.position.y + 3), P.fit(str(o["name"]), cx[1] - cx[0] - 6), Color(_ink(), a))
		var sub := ""
		if int(o.get("logged", 0)) > 0:
			sub = "REGISTERED: tied to your ID"
		elif o["kind"] == "tool":
			sub = "Tool" + (" (you have one)" if state().tools.has(o["cat"]) else "")
		else:
			sub = str(o["kind"]).capitalize()
		draw_string(P.font(), Vector2(cx[0], r.position.y + 22), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, P.FS - 1, Color(P.BAD.lightened(0.2) if int(o.get("logged", 0)) > 0 else _dim(), a))
		if int(o.get("grade", 0)) > 0:
			_pips(Vector2(cx[1], r.position.y + 9), int(o["grade"]), a)
		P.text(self, Vector2(cx[2], r.position.y + 7), "x%d" % int(o["qty"]), Color(_ink(), a))
		P.text(self, Vector2(cx[3], r.position.y + 7), "%d cr" % int(o["price"]), Color(_ink(), a))
		var br := _buy_rect(i)
		var can: bool = not sold and state().money >= int(o["price"])
		var hov := br.has_point(hover) and can
		var bc := P.COPPER if can else Color(P.FACE_D, 0.6)
		draw_rect(br, bc.lightened(0.15) if hov else bc)
		P.text(self, br.position + Vector2(0, 3), "SOLD" if sold else "BUY", P.FACE_L, HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	var foot := "Arrives overnight. Grades 1-2 only." if market == "shopnet" else "Delivered to a dead drop overnight. Not every seller is honest."
	P.text(self, Vector2(6, size.y - 34), foot, _dim())
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(P.COPPER, _flash * 0.12))
	if _msg_t > 0.0:
		var al := minf(1.0, _msg_t)
		var mr := Rect2(4, size.y - 20, size.x - 8, 16)
		draw_rect(mr, Color(P.PETROL_D, 0.9 * al))
		P.text(self, mr.position + Vector2(6, 3), P.fit(_msg, mr.size.x - 12), Color(P.FACE_L, al))


func _icon(o: Dictionary) -> String:
	match str(o["kind"]):
		"material":
			return "package"
		"tool":
			return "gear"
		"gear":
			return "target"
		_:
			return "drive"


func _pips(at: Vector2, g: int, a: float) -> void:
	for k in 5:
		var c := Vector2(at.x + k * 8, at.y)
		if k < g:
			draw_circle(c, 2.6, Color(P.COPPER if not _dark() else Color(1.0, 0.7, 0.25), a))
		else:
			draw_arc(c, 2.6, 0, TAU, 10, Color(_dim(), 0.6 * a), 1.0)
