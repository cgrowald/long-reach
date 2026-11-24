extends RefCounted
## Readable hits (docs/CONNECTED_LOOP.md section 8 and 9, C4): what a round does where it lands, so you can see
## and hear every shot answered. Plaster sheds dust and keeps a mark; metal (doors) sparks; a plate rings
## (Kenney impactPlate) and sparks; flesh sprays blood and leaves a splash on the floor or the wall behind.
## Marks and blood stay for the whole raid. No nodes of its own: everything is added under `parent` (the level).

const Audio := preload("res://v2/combat/combat_audio.gd")
const SND := "kenney_impact/"

## A soft round splat texture (generated once): col with alpha falling off, a few droplets around it.
static func _splat(holder: Node, key: String, col: Color, drops: int, seed_: int) -> Texture2D:
	if holder.has_meta("splat_" + key):            # kept on the level, freed with it
		return holder.get_meta("splat_" + key)
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var blobs: Array = [[Vector2(32, 32), 13.0]]
	for i in drops:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12.0, 27.0)
		blobs.append([Vector2(32, 32) + Vector2(cos(a), sin(a)) * r, rng.randf_range(1.5, 4.5)])
	for y in n:
		for x in n:
			var al := 0.0
			for b in blobs:
				var d := Vector2(x, y).distance_to(b[0])
				al = maxf(al, clampf(1.0 - d / float(b[1]), 0.0, 1.0))
			if al > 0.0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, minf(1.0, al * 1.6) * col.a))
	var t := ImageTexture.create_from_image(img)
	holder.set_meta("splat_" + key, t)
	return t


static func _decal(parent: Node3D, at: Vector3, normal: Vector3, size: float, tex: Texture2D) -> void:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size, 0.12, size)
	d.cull_mask = 1 | 8      # the plain world and the whole walls (level.gd LAYER_FULL)
	parent.add_child(d)
	# a Decal projects along its -Y: point its Y along the surface normal
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	d.global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), at)
	d.rotate_object_local(Vector3.UP, randf() * TAU)


static func _puff(parent: Node3D, at: Vector3, normal: Vector3, col: Color, amount: int, speed: float, life: float, size: float, glow := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -2.5 if not glow else -6.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if glow:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 3.0
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = m
	p.mesh = q
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


## A round that missed and hit the building.
static func wall(parent: Node3D, at: Vector3, normal: Vector3, metal: bool) -> void:
	if metal:
		_puff(parent, at, normal, Color(1.0, 0.8, 0.4), 10, 3.5, 0.25, 0.6, true)
		Audio.play_at(parent, SND + "impactMetal_light_%03d" % (randi() % 5), at, -12.0)
		_decal(parent, at, normal, 0.07, _splat(parent, "dent", Color(0.12, 0.11, 0.1, 0.9), 0, 3))
	else:
		_puff(parent, at, normal, Color(0.72, 0.7, 0.64, 0.8), 14, 1.4, 0.9, 1.0)
		Audio.play_at(parent, SND + "impactGeneric_light_%03d" % (randi() % 5), at, -14.0)
		_decal(parent, at, normal, 0.11, _splat(parent, "hole", Color(0.1, 0.09, 0.08, 0.95), 4, 7))


## A plate stopped it: a ring you learn to love, and sparks off the chest.
static func plate(parent: Node3D, at: Vector3, from_dir: Vector3) -> void:
	_puff(parent, at, -from_dir, Color(1.0, 0.85, 0.5), 12, 3.0, 0.22, 0.6, true)
	Audio.play_at(parent, SND + "impactPlate_heavy_%03d" % (randi() % 5), at, -4.0)


## A round in someone: a spray, a thump, blood on the floor under them and on the wall behind if it's close.
static func flesh(parent: Node3D, level: Node3D, at: Vector3, from_dir: Vector3, heavy: bool) -> void:
	_puff(parent, at, from_dir.normalized(), Color(0.45, 0.03, 0.03, 0.9), 18 if heavy else 10, 2.2, 0.5, 1.2)
	Audio.play_at(parent, SND + ("impactPunch_heavy_%03d" if heavy else "impactPunch_medium_%03d") % (randi() % 5), at, -8.0)
	var floor_at := Vector3(at.x + from_dir.x * 0.4, 0.0, at.z + from_dir.z * 0.4)
	_decal(parent, floor_at, Vector3.UP, 0.5 if heavy else 0.32, _splat(parent, "blood%d" % (randi() % 3), Color(0.32, 0.02, 0.02, 0.92), 9, 11 + randi() % 3))
	# the wall behind, if there is one within a metre and a half
	var space := parent.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at, at + from_dir.normalized() * 1.5)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_decal(parent, hit["position"], hit["normal"], 0.42, _splat(parent, "spatter", Color(0.36, 0.02, 0.02, 0.85), 12, 19))


## A downed or dead person bleeds into a pool that grows a little.
static func pool(parent: Node3D, at: Vector3) -> void:
	_decal(parent, Vector3(at.x, 0.0, at.z), Vector3.UP, 0.9, _splat(parent, "pool", Color(0.26, 0.015, 0.015, 0.95), 5, 23))
