extends RefCounted
## The hands-on bench verbs. Each is a small Node3D under bench_work: it draws its marks and tool,
## reacts to the cursor on the bench plane (work.hit), press / release / key, reports a gauge for the UI,
## and emits done(score 0..1). Placeholder feel: tune the numbers here.


static func make(id: String) -> Node3D:
	match id:
		"drill": return Drill.new()
		"file": return FileDown.new()
		"cut": return Cut.new()
		"sew": return Sew.new()
		"tear": return Tear.new()
		"pour": return Pour.new()
		"solder": return Solder.new()
	return Fit.new()


class Verb extends Node3D:
	signal done(score: float)
	var work: Node3D
	var step: Dictionary
	var holding := false
	var scores: Array = []
	var count := 1
	var hint := ""
	var _finished := false

	func begin(w: Node3D, s: Dictionary) -> void:
		work = w
		step = s
		count = int(s.get("count", 1))
		_build()

	func _build() -> void:
		pass

	func moved() -> void:
		pass

	func press() -> void:
		pass

	func release() -> void:
		pass

	func key() -> void:
		pass

	## {"value": 0..1, "band": Vector2, "label": String} or {} for no gauge.
	func gauge() -> Dictionary:
		return {}

	## Where the player acts next: {"pos": Vector3 (local), "text": String, "drag": Vector3 (optional arrow),
	## "both": bool (two-way arrow), "size": float}. {} hides the marker.
	func cue() -> Dictionary:
		return {}

	## 1 inside the band, falling off outside it.
	static func band_score(v: float, band: Vector2, falloff := 0.25) -> float:
		if v >= band.x and v <= band.y:
			return 1.0
		var d := band.x - v if v < band.x else v - band.y
		return clampf(1.0 - d / falloff, 0.0, 1.0)

	func progress() -> String:
		return "%d / %d" % [scores.size(), count] if count > 1 else ""

	func record(s: float, at: Vector3) -> void:
		scores.append(s)
		var word := "PERFECT" if s >= 0.95 else ("GOOD" if s >= 0.75 else ("OK" if s >= 0.5 else "ROUGH"))
		work.say("%s %d%%" % [word, int(round(s * 100.0))], at, s >= 0.75)
		var g := get_node_or_null("/root/Game")
		if g:
			g.sfx.play("glass_001" if s >= 0.75 else "tick_004", 0.9 + s * 0.4, -6.0)
		if scores.size() >= count:
			finish()

	func finish() -> void:
		if _finished:
			return
		_finished = true
		var t := 0.0
		for s in scores:
			t += float(s)
		var avg := t / maxf(1.0, scores.size())
		get_tree().create_timer(0.5).timeout.connect(func() -> void: done.emit(avg))


# ---------------------------------------------------------------- drill: hold on the mark, stop in the band

class Drill extends Verb:
	var marks: Array = []
	var bit: MeshInstance3D
	var depth := 0.0
	var rate := 0.45
	var aim := 1.0
	var drilling := false
	const BAND := Vector2(0.72, 0.86)

	func _build() -> void:
		hint = "Hold the mouse on a mark. Let go in the green."
		var h: float = work.top()
		for i in count:
			var p := Vector3(-0.06 + i * 0.06, h + 0.001, 0.0)
			marks.append(p)
			work.box(Vector3(0.014, 0.002, 0.014), Color(1.0, 0.2, 0.1), p, self, true)
		bit = work.cyl(0.006, 0.12, Color(0.75, 0.75, 0.8), Vector3(0, h + 0.08, 0), self)
		_next_rate()

	func _next_rate() -> void:
		rate = randf_range(0.38, 0.6)
		depth = 0.0

	func moved() -> void:
		if not drilling:
			bit.position = work.hit + Vector3(0, 0.07, 0)

	func press() -> void:
		var i := scores.size()
		if i >= marks.size():
			return
		var d: float = (work.hit - marks[i]).length()
		if d > 0.03:
			work.say("Line it up on the mark", work.hit, false)
			return
		aim = 1.0 - d / 0.03 * 0.35
		drilling = true
		bit.position = marks[i] + Vector3(0, 0.06, 0)

	func release() -> void:
		if not drilling:
			return
		drilling = false
		var i := scores.size()
		work.cyl(0.007, 0.004, Color(0.05, 0.05, 0.05), marks[i] + Vector3(0, 0.001, 0), self)
		var s := band_score(depth, BAND) * aim
		record(s, marks[i])
		_next_rate()
		bit.position = work.hit + Vector3(0, 0.07, 0)

	func _process(delta: float) -> void:
		if drilling:
			depth = minf(1.2, depth + delta * rate)
			bit.rotate_y(delta * 40.0)
			bit.position.y = marks[scores.size()].y + 0.06 - depth * 0.03 + randf_range(-0.001, 0.001)

	func gauge() -> Dictionary:
		return {"value": depth, "band": BAND, "label": "DEPTH"}

	func cue() -> Dictionary:
		var i := scores.size()
		if i >= marks.size():
			return {}
		return {"pos": marks[i], "text": "LET GO IN THE GREEN" if drilling else "HOLD TO DRILL HERE"}


# ---------------------------------------------------------------- file: scrub back and forth, stop in the band

class FileDown extends Verb:
	var excess := 1.0
	var stock: MeshInstance3D
	var file_m: MeshInstance3D
	var _last := Vector3.ZERO
	const BAND := Vector2(0.86, 0.95)          # as "done" (1 - excess)

	func _build() -> void:
		hint = "Hold and scrub left-right on the bright edge. Let go in the green."
		var h: float = work.top()
		stock = work.box(Vector3(0.04, h, 0.08), Color(0.7, 0.71, 0.74), Vector3(0.12, h * 0.5, 0), self)
		work.box(Vector3(0.002, 0.002, 0.09), Color(1.0, 0.2, 0.1), Vector3(0.1 + 0.004, h + 0.001, 0), self, true)
		file_m = work.box(Vector3(0.16, 0.008, 0.022), Color(0.3, 0.3, 0.32), Vector3(0.12, h + 0.03, 0), self)

	func moved() -> void:
		var h: float = work.top()
		file_m.position = Vector3(work.hit.x, h + (0.006 if holding else 0.03), work.hit.z)
		if holding:
			var dx := absf(work.hit.x - _last.x)
			if absf(work.hit.z) < 0.08 and work.hit.x > 0.0:
				excess = maxf(0.0, excess - dx * 1.4)
				stock.scale.x = maxf(0.02, excess)
				stock.position.x = 0.1 + 0.02 * excess
				if dx > 0.002 and randf() < 0.3:
					var g := get_node_or_null("/root/Game")
					if g:
						g.sfx.play("tick_001", randf_range(1.6, 2.2), -18.0, 0.05)
		_last = work.hit

	func press() -> void:
		_last = work.hit

	func release() -> void:
		var done_v := 1.0 - excess
		if done_v < BAND.x:
			work.say("Keep going", work.hit, false)
			return
		record(band_score(done_v, BAND, 0.15), Vector3(0.1, work.top(), 0))

	func gauge() -> Dictionary:
		return {"value": 1.0 - excess, "band": BAND, "label": "FILED"}

	func cue() -> Dictionary:
		var d := 1.0 - excess
		var t := "HOLD + SCRUB LEFT-RIGHT"
		if d >= BAND.x:
			t = "GREEN: LET GO NOW"
		elif holding:
			t = "KEEP SCRUBBING"
		return {"pos": Vector3(0.1 + 0.04 * excess, work.top(), 0), "text": t, "drag": Vector3(0.06, 0, 0), "both": true, "size": 1.4}


# ---------------------------------------------------------------- cut: hold and follow the line

class Cut extends Verb:
	var a := Vector3(-0.12, 0, 0.06)
	var b := Vector3(0.12, 0, -0.05)
	var progress_t := 0.0
	var dev_sum := 0.0
	var dev_n := 0
	var cutting := false
	var blades: MeshInstance3D
	var cut_line: MeshInstance3D

	func _build() -> void:
		hint = "Start at the end of the line. Hold and follow it."
		var h: float = work.top() + 0.001
		a.y = h
		b.y = h
		a.z += randf_range(-0.03, 0.03)
		b.z += randf_range(-0.03, 0.03)
		var n := 16
		for i in n:
			if i % 2 == 0:
				var p := a.lerp(b, (i + 0.5) / n)
				var seg: MeshInstance3D = work.box(Vector3((b - a).length() / n, 0.0015, 0.003), Color(1, 0.85, 0.3), p, self, true)
				seg.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		work.box(Vector3(0.012, 0.002, 0.012), Color(0.3, 1.0, 0.4), a, self, true)
		blades = work.box(Vector3(0.05, 0.006, 0.012), Color(0.7, 0.7, 0.75), a + Vector3(0, 0.03, 0), self)
		cut_line = work.box(Vector3(0.001, 0.002, 0.004), Color(0.05, 0.05, 0.05), a, self)

	func _cur() -> Vector3:
		return a.lerp(b, progress_t)

	func moved() -> void:
		blades.position = work.hit + Vector3(0, 0.01 if cutting else 0.03, 0)
		blades.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		if not cutting:
			return
		var ab := b - a
		var t := clampf((work.hit - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var on := a.lerp(b, t)
		var dev := Vector2(work.hit.x - on.x, work.hit.z - on.z).length()
		if t > progress_t and t - progress_t < 0.15:
			progress_t = t
			dev_sum += dev
			dev_n += 1
			var mid := a.lerp(_cur(), 0.5)
			cut_line.position = mid
			cut_line.scale.x = maxf(0.001, (_cur() - a).length()) / 0.001
			cut_line.rotation.y = -atan2(ab.z, ab.x)
		if progress_t >= 0.98:
			cutting = false
			var avg := dev_sum / maxf(1.0, dev_n)
			record(clampf(1.0 - avg / 0.02, 0.0, 1.0), b)

	func press() -> void:
		if (work.hit - _cur()).length() < 0.035:
			cutting = true
		else:
			work.say("Start where the cut is", _cur(), false)

	func release() -> void:
		cutting = false

	func gauge() -> Dictionary:
		return {"value": progress_t, "band": Vector2(0.98, 1.0), "label": "CUT"}

	func cue() -> Dictionary:
		var to_end := (b - _cur())
		if cutting:
			return {"pos": _cur(), "text": "FOLLOW THE LINE", "drag": to_end.normalized() * minf(0.08, to_end.length())}
		return {"pos": _cur(), "text": "HOLD HERE, DRAG ALONG", "drag": to_end.normalized() * 0.08}


# ---------------------------------------------------------------- sew: the needle travels, click on each mark

class Sew extends Verb:
	var marks: Array = []
	var resolved: Array = []
	var needle: MeshInstance3D
	var x := -0.16
	var started := false
	const SPEED := 0.085
	const X0 := -0.13
	const X1 := 0.13

	func _build() -> void:
		hint = "Click (or Space) as the needle passes each mark."
		var h: float = work.top() + 0.001
		work.box(Vector3(X1 - X0 + 0.02, 0.001, 0.002), Color(0.9, 0.9, 0.9), Vector3(0, h, 0), self, true)
		for i in count:
			var mx := lerpf(X0, X1, (i + 0.5) / count)
			marks.append(mx)
			resolved.append(false)
			work.box(Vector3(0.004, 0.002, 0.014), Color(1, 0.85, 0.3), Vector3(mx, h, 0), self, true)
		needle = work.cyl(0.002, 0.05, Color(0.85, 0.85, 0.9), Vector3(x, h + 0.025, 0), self)
		get_tree().create_timer(0.8).timeout.connect(func() -> void: started = true)

	func _process(delta: float) -> void:
		if not started or _finished:
			return
		x += delta * SPEED
		needle.position.x = x
		for i in marks.size():
			if not resolved[i] and x - float(marks[i]) > 0.02:
				resolved[i] = true
				record(0.0, Vector3(marks[i], work.top(), 0))
		if x > X1 + 0.03 and scores.size() < count:
			finish()

	func press() -> void:
		_stitch()

	func key() -> void:
		_stitch()

	func _stitch() -> void:
		if not started:
			return
		var best := -1
		var bd := 1.0
		for i in marks.size():
			if not resolved[i]:
				var d := absf(x - float(marks[i]))
				if d < bd:
					bd = d
					best = i
		if best < 0 or bd > 0.02:
			work.say("Missed", Vector3(x, work.top(), 0), false)
			return
		resolved[best] = true
		var h: float = work.top() + 0.002
		work.box(Vector3(0.012, 0.002, 0.003), Color(0.1, 0.1, 0.1), Vector3(marks[best], h, 0), self)
		record(1.0 - bd / 0.02 * 0.6, Vector3(marks[best], h, 0))

	func gauge() -> Dictionary:
		return {}

	func cue() -> Dictionary:
		for i in marks.size():
			if not resolved[i]:
				var near := absf(x - float(marks[i])) < 0.02
				return {"pos": Vector3(marks[i], work.top(), 0), "text": "CLICK NOW!" if near else "CLICK WHEN THE NEEDLE HITS", "size": 0.8}
		return {}


# ---------------------------------------------------------------- tear: grab the cloth and yank fast

class Tear extends Verb:
	var grab := Vector3.ZERO
	var t0 := 0.0
	var grabbing := false
	var strips: Array = []

	func _build() -> void:
		hint = "Grab the cloth and yank it toward you, fast."
		var h: float = work.top() + 0.001
		for i in count:
			strips.append(work.box(Vector3(0.28, 0.001, 0.002), Color(1, 0.85, 0.3), Vector3(0, h, -0.08 + i * 0.06), self, true))

	func press() -> void:
		if absf(work.hit.x) < 0.16 and absf(work.hit.z) < 0.12:
			grab = work.hit
			t0 = Time.get_ticks_msec() / 1000.0
			grabbing = true

	func moved() -> void:
		if not grabbing or scores.size() >= count:
			grabbing = false
			return
		var d: float = (work.hit - grab).length()
		if d > 0.12:
			grabbing = false
			var dt := maxf(0.02, Time.get_ticks_msec() / 1000.0 - t0)
			var speed := d / dt
			var i := scores.size()
			var s: MeshInstance3D = strips[i]
			var tw := s.create_tween()
			tw.tween_property(s, "position", s.position + Vector3(0, 0.004, 0.18 + i * 0.012), 0.2)
			s.material_override = work.mat(Color(0.36, 0.42, 0.5))
			s.scale = Vector3(1, 3, 12)
			var g := get_node_or_null("/root/Game")
			if g:
				g.sfx.play("drop_002", 1.4, -6.0)
			record(clampf(speed / 0.9, 0.3, 1.0), grab)

	func release() -> void:
		grabbing = false

	func cue() -> Dictionary:
		var i := scores.size()
		if i >= strips.size():
			return {}
		var p: Vector3 = (strips[i] as Node3D).position
		return {"pos": p, "text": "PULL FAST!" if grabbing else "GRAB HERE, YANK TOWARD YOU", "drag": Vector3(0, 0, 0.12)}


# ---------------------------------------------------------------- pour: hold to pour, stop at the line

class Pour extends Verb:
	var level := 0.0
	var rate := 0.0
	var liquid: MeshInstance3D
	var bottle: MeshInstance3D
	const BAND := Vector2(0.7, 0.8)
	const H := 0.07

	func _build() -> void:
		hint = "Hold to pour. Let go at the line."
		work.cyl(0.06, H, Color(0.7, 0.72, 0.7), Vector3(0, H * 0.5, 0), self)
		liquid = work.cyl(0.055, H, Color(0.75, 0.85, 1.0), Vector3(0, 0.002, 0), self)
		liquid.scale.y = 0.01
		work.cyl(0.062, 0.002, Color(1.0, 0.2, 0.1), Vector3(0, H * 0.75, 0), self, true)
		bottle = work.cyl(0.02, 0.12, Color(0.4, 0.7, 0.5), Vector3(0.08, H + 0.08, 0), self)
		bottle.rotation.z = 0.4

	func press() -> void:
		rate = 0.18

	func release() -> void:
		bottle.rotation.z = 0.4
		record(band_score(level, BAND, 0.3), Vector3(0, H, 0))

	func _process(delta: float) -> void:
		if holding and not _finished:
			rate = minf(0.5, rate + delta * 0.25)
			level = minf(1.05, level + delta * rate)
			bottle.rotation.z = 1.7
			liquid.scale.y = maxf(0.01, level)
			liquid.position.y = H * level * 0.5
			if level >= 1.0:
				holding = false
				work.say("It overflowed", Vector3(0, H, 0), false)
				release()

	func gauge() -> Dictionary:
		return {"value": level, "band": BAND, "label": "LEVEL"}

	func cue() -> Dictionary:
		if holding:
			return {"pos": Vector3(0, H * 0.75, 0), "text": "LET GO AT THE LINE", "size": 3.2}
		return {"pos": Vector3(0.08, H + 0.02, 0), "text": "HOLD TO POUR"}


# ---------------------------------------------------------------- fit: pick a part, put it in the lit slot

class Fit extends Verb:
	var parts: Array = []      # MeshInstance3D
	var slots: Array = []      # Vector3
	var held := -1
	var mistakes := 0
	var marker: MeshInstance3D

	func _build() -> void:
		var names: Array = step.get("parts", ["part"])
		count = names.size()
		hint = "Click a part, then click the lit spot."
		var h: float = work.top()
		for i in count:
			var p: MeshInstance3D = work.box(Vector3(0.03, 0.012, 0.02), Color(0.8, 0.6, 0.3) if i % 2 else Color(0.55, 0.6, 0.65),
				Vector3(-0.2, 0.006, -0.07 + i * 0.045), self)
			parts.append(p)
			slots.append(Vector3(-0.07 + i * (0.14 / maxf(1, count - 1)) if count > 1 else 0.0, h + 0.006, 0.0))
		marker = work.box(Vector3(0.036, 0.002, 0.026), Color(1.0, 0.3, 0.85), slots[0] - Vector3(0, 0.005, 0), self, true)
		marker.visible = false

	func cue() -> Dictionary:
		var i := scores.size()
		if i >= count:
			return {}
		var names: Array = step.get("parts", ["part"])
		var nm := str(names[i]).to_upper()
		if held < 0:
			return {"pos": (parts[i] as Node3D).position, "text": "PICK UP: %s" % nm}
		return {"pos": slots[i], "text": "PUT THE %s HERE" % nm}

	func _process(_delta: float) -> void:
		if marker and not _finished:
			marker.visible = held >= 0 and fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.4
		if held >= 0:
			(parts[held] as MeshInstance3D).position = work.hit + Vector3(0, 0.03, 0)

	func press() -> void:
		var i := scores.size()
		if i >= count:
			return
		if held < 0:
			for k in range(i, count):
				if (work.hit - (parts[k] as MeshInstance3D).position).length() < 0.035:
					if k != i:
						mistakes += 1
						work.say("Not that one yet", work.hit, false)
						return
					held = k
					return
			return
		if (work.hit - slots[i]).length() < 0.035:
			var p: MeshInstance3D = parts[held]
			p.position = slots[i]
			held = -1
			record(maxf(0.4, 1.0 - 0.2 * mistakes), slots[i])
			mistakes = 0
			if scores.size() < count:
				marker.position = slots[scores.size()] - Vector3(0, 0.005, 0)
			else:
				marker.visible = false
		else:
			mistakes += 1
			work.say("Doesn't fit there", work.hit, false)


# ---------------------------------------------------------------- solder: hold the iron on the lit pad, let go when it flows

class Solder extends Verb:
	var pads: Array = []        # Vector3
	var pad_meshes: Array = []  # MeshInstance3D
	var iron: MeshInstance3D
	var blob: MeshInstance3D
	var heat := 0.0
	var rate := 0.6
	var heating := false
	const BAND := Vector2(0.62, 0.84)
	const COPPER := Color(0.95, 0.62, 0.28)
	const DONE := Color(0.88, 0.9, 0.92)

	func _build() -> void:
		hint = "Hold the iron on the lit pad. The solder melts in the green: let go then."
		var h: float = work.top() + 0.001
		for i in count:
			var p := Vector3(-0.06 + i * (0.12 / maxf(1, count - 1)), h, 0.03)
			pads.append(p)
			pad_meshes.append(work.cyl(0.008, 0.003, COPPER, p, self, true))
		iron = work.cyl(0.004, 0.12, Color(0.5, 0.5, 0.55), Vector3(0, h + 0.07, 0), self)
		iron.rotation.x = 0.5
		_next_rate()

	func _next_rate() -> void:
		rate = randf_range(0.5, 0.75)
		heat = 0.0

	func _process(delta: float) -> void:
		if not heating or _finished:
			return
		var i := scores.size()
		heat = minf(1.2, heat + delta * rate)
		iron.position = pads[i] + Vector3(0, 0.058, 0.03)
		if heat >= BAND.x:
			if blob == null:
				blob = work.cyl(0.005, 0.004, DONE, pads[i] + Vector3(0, 0.003, 0), self)
			var k := clampf((heat - BAND.x) / (BAND.y - BAND.x), 0.0, 1.3)
			blob.scale = Vector3(0.6 + k * 0.6, 1.0, 0.6 + k * 0.6)
		if heat >= 1.15:
			work.say("Burnt it", pads[i], false)
			release()

	func moved() -> void:
		if not heating:
			iron.position = work.hit + Vector3(0, 0.06, 0.03)

	func press() -> void:
		var i := scores.size()
		if i >= count:
			return
		if (work.hit - pads[i]).length() > 0.035:
			work.say("Put the iron on the lit pad", work.hit, false)
			return
		heating = true

	func release() -> void:
		if not heating:
			return
		heating = false
		var i := scores.size()
		var s := band_score(heat, BAND, 0.3)
		var col := DONE
		if heat < BAND.x:
			work.say("Cold joint", pads[i], false)
			col = Color(0.45, 0.45, 0.45)
		elif heat > BAND.y:
			col = Color(0.35, 0.22, 0.12)
		if blob == null:
			blob = work.cyl(0.005, 0.004, col, pads[i] + Vector3(0, 0.003, 0), self)
		blob.material_override = work.mat(col)
		(pad_meshes[i] as MeshInstance3D).material_override = work.mat(Color(0.5, 0.36, 0.2))
		blob = null
		record(maxf(0.15, s), pads[i])
		_next_rate()

	func gauge() -> Dictionary:
		return {"value": heat, "band": BAND, "label": "HEAT"}

	func cue() -> Dictionary:
		var i := scores.size()
		if i >= count:
			return {}
		var t := "HOLD THE IRON HERE"
		if heating:
			t = "GREEN: LET GO!" if heat >= BAND.x else "HEATING..."
		return {"pos": pads[i], "text": t}
