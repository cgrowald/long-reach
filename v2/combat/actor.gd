extends "res://v2/combat/soldier.gd"
## A person in the fight: the soldier body plus the combat state (docs/COMBAT_SLICE.md section 1):
## stats from their gear, health, open wounds, plate wear, mags, meds, and the low-level doing:
## walk a path, turn, aim (time-to-aim from ergonomics and reactions), fire bursts with recoil, reload
## on their own, bandage themselves. The brains (squad_ai.gd, enemy_ai.gd) decide WHAT; this does HOW.

signal said(who, text: String)
signal hit_taken(who, info: Dictionary)
signal went_down(who)
signal died(who)
signal fired(who, target)

const Rules := preload("res://v2/combat/rules.gd")
const Audio := preload("res://v2/combat/combat_audio.gd")
const WALK := 0.85
const RUN := 1.9

var id := ""
var team := "us"                 # us, them
var kind := "fighter"            # fighter, guard, bureau
var role := ""
var trait_name := ""
var bio := ""
var st: Dictionary = {}          # stats from gear
var hp := Rules.HP
var wounds := 0
var plate_dur := 0.0
var state := "ok"                # ok, down, dead, surrendered, cuffed, fled
var stable := false              # a downed fighter a medic has patched
var bleed_out := Rules.BLEED_OUT
var mag_rounds := 0
var mags := 0
var meds := 0
var flashes := 0
var charges := 0
var stunned := 0.0
var level: Node3D

# doing
var path: Array = []             # Vector3 waypoints
var speed := WALK
var face_yaw := 0.0              # body facing (world yaw)
var target = null                # actor being engaged
var look_at_point = null         # Vector3 to watch when nobody to shoot
var look_order = null            # where YOU told them to look (beats everything but a live target)
var look_order_t := 0.0
var aim_time := 0.0
var burst_left := 0
var shot_t := 0.0
var shot_i := 0
var reloading := 0.0
var bandaging := 0.0
var busy := 0.0                  # doing something with the hands (patching, cuffing, picking up)
var weapons_free := true
var light_wanted := false         # the squad / enemy brain wants the weapon light on (entering, clearing, alert)
var has_light := false
var shots := 0
var last_shot_t := -100.0       # when this person last fired (a muzzle flash gives you away)
var hits := 0
var rng := RandomNumberGenerator.new()
var _say_cd := 0.0


func setup_actor(def: Dictionary, p_team: String, p_level: Node3D) -> void:
	team = p_team
	level = p_level
	id = str(def.get("id", def.get("name", "?")))
	kind = str(def.get("kind", "fighter"))
	role = str(def.get("role", kind))
	trait_name = str(def.get("trait", ""))
	bio = str(def.get("line", ""))
	setup(def)
	fighter_name = str(def.get("name", id))
	st = Rules.stats(def.get("gear", {}), trait_name)
	plate_dur = float(st["plate_dur"])
	mag_rounds = int(st["mag"])
	mags = int(st["mags"]) - 1
	meds = int(st["meds"])
	flashes = int(st["flash"])
	charges = int(st["charges"])
	rng.seed = hash(id)
	has_light = bool(st.get("spot", false))
	if light:
		light.visible = false


func alive() -> bool:
	return state == "ok"


func can_fight() -> bool:
	return state == "ok" and stunned <= 0.0


func eye() -> Vector3:
	return global_position + Vector3(0, 1.55 - crouch * 0.12, 0)


func chest_pos() -> Vector3:
	return global_position + Vector3(0, 1.25 - crouch * 0.1, 0) if state == "ok" or state == "surrendered" else global_position + Vector3(0, 0.25, 0)


func pos2() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func say(text: String, force := false) -> void:
	if _say_cd > 0.0 and not force:
		return
	_say_cd = 1.6
	said.emit(self, text)


func go(points: Array, p_speed := WALK) -> void:
	path = points.duplicate()
	speed = p_speed


func stop() -> void:
	path.clear()


func moving() -> bool:
	return not path.is_empty()


# ------------------------------------------------------------------ the tick

func tick(delta: float) -> void:
	_say_cd = maxf(0.0, _say_cd - delta)
	if look_order != null:
		look_order_t -= delta
		if look_order_t <= 0.0:
			look_order = null
	if state == "dead" or state == "fled" or state == "cuffed":
		move_speed = 0.0
		return
	_bleed(delta)
	if state == "down":
		move_speed = 0.0
		return
	if state == "surrendered":
		move_speed = 0.0
		pose_mode = "hands_up"
		return
	stunned = maxf(0.0, stunned - delta)
	busy = maxf(0.0, busy - delta)
	# walking
	var v := Vector3.ZERO
	if not path.is_empty() and busy <= 0.0:
		var to: Vector3 = path[0]
		var d := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
		var step := speed * delta * (0.55 if target != null else 1.0)
		if d.length() <= step + 0.02:
			if level.walkable(Vector3(to.x, 0, to.z)):
				global_position = Vector3(to.x, 0, to.z)
			path.pop_front()
			_blocked = 0.0
		else:
			var before := global_position
			var next := global_position + d.normalized() * step
			if _crosses_fire(next) and not _crosses_fire(global_position):
				move_speed = 0.0              # don't walk in front of a teammate's muzzle: wait for the gap
				return
			_step_to(next)
			var moved := global_position - before
			v = moved / delta
			var gained := d.length() - Vector3(to.x - global_position.x, 0, to.z - global_position.z).length()
			if gained < step * 0.25:
				_blocked += delta
				if _blocked > 0.8:          # can't get there: skip this waypoint
					path.pop_front()
					_blocked = 0.0
			else:
				_blocked = 0.0
	move_speed = v.length()
	# facing: toward the target, else where we look, else where we walk
	var want := face_yaw
	var look = null
	if target != null and is_instance_valid(target):
		look = target.chest_pos()
	elif look_order != null:
		look = look_order
	elif look_at_point != null:
		look = look_at_point
	if look != null:
		var lv: Vector3 = look - global_position
		want = atan2(-lv.x, -lv.z)
	elif v.length() > 0.05:
		want = atan2(-v.x, -v.z)
	# how fast they come round: quicker hands (reactions) and a handier weapon (ergonomics) turn faster
	var turn_rate := clampf(5.6 - float(st.get("react", 0.5)) * 3.5 - float(st.get("ads", 0.45)) * 2.0, 2.0, 5.0)
	var turn := clampf(wrapf(want - face_yaw, -PI, PI), -delta * turn_rate, delta * turn_rate)
	face_yaw = wrapf(face_yaw + turn, -PI, PI)
	rotation.y = face_yaw
	aim_yaw = clampf(wrapf(want - face_yaw, -PI, PI), -0.6, 0.6)
	# the rifle comes up when there's something to point at
	raised = move_toward(raised, 1.0 if (target != null or look_at_point != null or look_order != null) else 0.55, delta * 3.0)
	_weapon(delta)
	# the weapon light: on to engage or to go into the dark, off again once it's clear (lights give you away)
	if light:
		light.visible = has_light and (target != null or light_wanted or flashing())
	_self_aid(delta)


var _blocked := 0.0


## Move to p if the floor allows it; otherwise slide along whichever axis is free (walls stop you).
func _step_to(p: Vector3) -> void:
	p.y = 0.0
	if level.walkable(p):
		global_position = p
		return
	var px := Vector3(p.x, 0, global_position.z)
	var pz := Vector3(global_position.x, 0, p.z)
	if level.walkable(px):
		global_position = px
	elif level.walkable(pz):
		global_position = pz


## Shoved by someone standing too close.
func nudge(by: Vector3) -> void:
	if state == "ok" or state == "surrendered":
		_step_to(global_position + by)


func _weapon(delta: float) -> void:
	shot_t = maxf(0.0, shot_t - delta)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			mag_rounds = int(st["mag"])
		return
	if target == null or not is_instance_valid(target) or not target.alive() or not weapons_free or stunned > 0.0 or busy > 0.0:
		aim_time = 0.0
		burst_left = 0
		if target != null and (not is_instance_valid(target) or not target.alive()):
			target = null
		# top up between fights
		if target == null and mag_rounds < int(st["mag"]) * 0.35 and mags > 0:
			start_reload()
		return
	if not level.clear_line(eye(), target.chest_pos()):
		aim_time = maxf(0.0, aim_time - delta * 2.0)
		return
	aim_time += delta
	var ready_at := float(st["ads"]) + float(st.get("react", 0.5))
	if aim_time < ready_at:
		return
	if mag_rounds <= 0:
		start_reload()
		return
	if _friend_in_line():
		burst_left = 0           # muzzle discipline: never fire past a teammate
		return
	if burst_left <= 0 and shot_t <= 0.0:
		burst_left = int(st["burst"])
		shot_i = 0
	if burst_left > 0 and shot_t <= 0.0:
		_shoot()
		burst_left -= 1
		shot_i += 1
		shot_t = float(st["rate"]) if burst_left > 0 else rng.randf_range(0.35, 0.8)


## Would standing at p put me in front of a teammate who is shooting (or about to)?
func _crosses_fire(p: Vector3) -> bool:
	if get_parent() == null:
		return false
	var me := p + Vector3(0, 1.2, 0)
	for n in get_parent().get_children():
		if n == self or not n.has_method("can_fight") or n.team != team or n.state != "ok":
			continue
		if n.target == null or not is_instance_valid(n.target) or n.aim_time <= 0.0:
			continue
		var a: Vector3 = n.eye()
		var ab: Vector3 = n.target.chest_pos() - a
		var t := clampf((me - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if t > 0.03 and t < 0.97 and (a + ab * t).distance_to(me) < 0.5:
			return true
	return false


## Is one of our own standing in the line of fire between me and my target?
func _friend_in_line() -> bool:
	if target == null or get_parent() == null:
		return false
	var a := eye()
	var b: Vector3 = target.chest_pos()
	var ab := b - a
	var len2 := ab.length_squared()
	for n in get_parent().get_children():
		if n == self or not n.has_method("can_fight") or n.team != team or n.state == "dead":
			continue
		var p: Vector3 = n.global_position + Vector3(0, 1.2, 0)
		var t := clampf((p - a).dot(ab) / maxf(len2, 0.001), 0.0, 1.0)
		if t > 0.02 and t < 0.98 and (a + ab * t).distance_to(p) < 0.45:
			return true
	return false


func start_reload() -> void:
	if reloading > 0.0 or mags <= 0:
		return
	mags -= 1
	reloading = float(st["reload"])
	if team == "us":
		say(_pick("reload"))


func _shoot() -> void:
	mag_rounds -= 1
	shots += 1
	last_shot_t = Time.get_ticks_msec() / 1000.0
	if rng.randf() < float(st["jam"]):
		reloading = 1.5          # clearing a jam
		mag_rounds += 1
		return
	fire(1)
	var snd := "rifle"
	var w: String = st.get("weapon", "")
	if w.contains("pistol"):
		snd = "pistol"
	elif w.contains("SMG"):
		snd = "smg"
	elif w.contains("carbine"):
		snd = "carbine"
	Audio.play_at(self, snd, eye(), -2.0)
	var t = target
	var dist := eye().distance_to(t.chest_pos())
	var cover := 0.25 if t.crouch > 0.5 else 0.0
	var p := Rules.hit_chance(st, dist, moving(), t.moving(), cover, shot_i)
	var hit := rng.randf() < p
	var end: Vector3 = t.chest_pos() + (Vector3.ZERO if hit else Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.5, 0.6), rng.randf_range(-0.7, 0.7)))
	_tracer(rifle.to_global(Vector3(0, 0, -0.95)), end)
	fired.emit(self, t)
	if hit:
		hits += 1
		t.take_hit(self)


func take_hit(from) -> void:
	if state == "dead":
		return
	var res := Rules.resolve_hit(rng, from.st, {"plate": st["plate"], "plate_dur": plate_dur})
	plate_dur = float(res["plate_dur"])
	hp -= float(res["dmg"])
	if res["bleed"]:
		wounds += 1
	_kick = 1.0
	hit_taken.emit(self, res)
	if res["zone"] == "head" and not res["blocked"] and hp <= 0.0:
		_die()
		return
	if hp <= 0.0:
		if hp < -45.0:
			_die()
		else:
			_go_down()


func _bleed(delta: float) -> void:
	if wounds > 0 and not stable:
		hp -= wounds * Rules.BLEED_RATE * delta
		if state == "ok" and hp <= 0.0:
			_go_down()
	if state == "down" and not stable:
		bleed_out -= delta
		if bleed_out <= 0.0:
			_die()


func _go_down() -> void:
	state = "down"
	hp = 0.0
	target = null
	stop()
	pose_mode = "down"
	went_down.emit(self)


func _die() -> void:
	state = "dead"
	hp = 0.0
	target = null
	stop()
	pose_mode = "dead"
	died.emit(self)


## Self aid: bandage your own wound when nobody is shooting at you right now.
func _self_aid(delta: float) -> void:
	if bandaging > 0.0:
		bandaging -= delta
		if bandaging <= 0.0:
			wounds = 0
			hp = maxf(hp, 20.0)
		return
	if wounds > 0 and target == null and meds > 0 and busy <= 0.0:
		meds -= 1
		bandaging = 3.5
		busy = 3.5
		if team == "us":
			say(_pick("heal"))
	elif wounds > 0 and meds <= 0 and team == "us" and target == null:
		if not has_meta("said_nomeds"):
			set_meta("said_nomeds", true)
			say(_pick("nomeds"))


## A medic (or anyone) patching this person. Downed + patched = stable (out of the fight, not dying).
func get_patched() -> void:
	wounds = 0
	if state == "down":
		stable = true
	else:
		hp = maxf(hp, 35.0)


func surrender() -> void:
	if state != "ok":
		return
	state = "surrendered"
	target = null
	stop()
	pose_mode = "hands_up"


func stun(t: float) -> void:
	stunned = maxf(stunned, t)
	target = null
	aim_time = 0.0


# ------------------------------------------------------------------ bits

func _pick(key: String, fill := {}) -> String:
	var lines: Array = Rules.Content.get_file("combat/depot").get("barks", {}).get(key, ["..."])
	var s: String = lines[rng.randi() % lines.size()]
	for k in fill:
		s = s.replace("{%s}" % k, str(fill[k]))
	return s


func bark(key: String, fill := {}, force := false) -> void:
	say(_pick(key, fill), force)


func _tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var ln := a.distance_to(b)
	bm.size = Vector3(0.012, 0.012, ln)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5)
	get_tree().create_timer(0.045).timeout.connect(mi.queue_free)


## A line in their own words (enemies use this; their lines aren't in the bark table).
func bark_custom(text: String) -> void:
	say(text, true)


## Fired in the last two seconds: the muzzle flash shows where you are.
func flashing() -> bool:
	return Time.get_ticks_msec() / 1000.0 - last_shot_t < 2.0 / maxf(Engine.time_scale, 0.01)


## You asked them to look somewhere. Turning speed is their own (it's in the tick: training, ergonomics).
func order_look(p: Vector3) -> void:
	look_order = p + Vector3(0, 1.2, 0)
	look_order_t = 7.0
	say(["Checking.", "Eyes on it.", "Looking."][rng.randi() % 3], true)
