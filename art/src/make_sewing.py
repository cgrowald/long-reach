# The sewing table, three stages (M1b, docs/BENCH_SEWING.md; GPT sheet docs/refs/benches/sewing_stages.png).
# Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_sewing.py
# Writes art/src/sewing.blend (for the user to tweak) and art/sewing.glb (what Godot loads).
# Three roots side by side, like the sheet: Sew_Starter (x = -2.2), Sew_Improved (x = 0), Sew_Upgraded (x = 2.2).
# Godot shows one root at a time and moves it to the origin. Blender coords: X right, Y away, Z up, metres.
# Materials are named <kind>_<colour> (wood_, fabric_, metal_, paint_, plain_): Godot swaps in a grain / weave /
# wear shader by kind, since procedural Blender textures don't survive the .glb export.

import bpy
import bmesh
import math
import os
import random

random.seed(11)
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
if __name__ == "__main__":
	bpy.ops.wm.read_factory_settings(use_empty=True)

PAL = {
	"wood_plank": (0.62, 0.42, 0.24), "wood_plank_l": (0.7, 0.5, 0.3), "wood_plank_d": (0.52, 0.34, 0.19),
	"wood_horse": (0.66, 0.48, 0.3), "wood_crate": (0.62, 0.46, 0.28), "wood_drawer": (0.5, 0.32, 0.18),
	"wood_spool": (0.74, 0.58, 0.38), "wood_peg": (0.42, 0.36, 0.2),
	"paint_veska": (0.28, 0.36, 0.6), "paint_frame": (0.36, 0.4, 0.22), "paint_mint": (0.55, 0.64, 0.52),
	"paint_box": (0.34, 0.38, 0.24), "paint_text": (0.86, 0.84, 0.76), "paint_extension": (0.84, 0.8, 0.7),
	"fabric_cream": (0.82, 0.76, 0.62), "fabric_olive": (0.4, 0.42, 0.24), "fabric_blue": (0.22, 0.28, 0.56),
	"fabric_mustard": (0.84, 0.62, 0.2), "fabric_red": (0.66, 0.16, 0.14), "fabric_purple": (0.46, 0.32, 0.5),
	"fabric_thread": (0.92, 0.88, 0.78), "fabric_pin": (0.86, 0.7, 0.5), "fabric_roll_b": (0.28, 0.36, 0.6),
	"fabric_roll_y": (0.8, 0.58, 0.22), "fabric_jacket": (0.36, 0.38, 0.2),
	"metal_copper": (0.62, 0.34, 0.18), "metal_steel": (0.55, 0.56, 0.58), "metal_dark": (0.12, 0.12, 0.13),
	"metal_bolt": (0.3, 0.3, 0.26), "metal_chrome": (0.75, 0.75, 0.74),
	"plain_bulb": (1.0, 0.82, 0.5), "plain_pinhead": (0.8, 0.15, 0.12),
}
_mats = {}


def _lin(v):
	return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def mat(name, emission=0.0):
	key = (name, emission)
	if key in _mats:
		return _mats[key]
	m = bpy.data.materials.new(name + ("_glow" if emission else ""))
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	c = [_lin(v) for v in PAL[name]]
	b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
	b.inputs["Roughness"].default_value = 0.4 if name.startswith("metal_chrome") else 0.85
	if name.startswith("metal_"):
		b.inputs["Metallic"].default_value = 0.6
	if emission:
		b.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1.0)
		b.inputs["Emission Strength"].default_value = emission
	_mats[key] = m
	return m


ROOT = None


def _finish(o, col, rot, bevel, emission=0.0):
	o.rotation_euler = [math.radians(a) for a in rot]
	o.data.materials.append(mat(col, emission))
	if bevel > 0:
		bv = o.modifiers.new("bevel", "BEVEL")
		bv.width = bevel
		bv.segments = 1
		bv.limit_method = "ANGLE"
	if ROOT is not None:
		o.parent = ROOT
	return o


def box(name, c, s, col, rot=(0, 0, 0), bevel=0.006, emission=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=c)
	o = bpy.context.active_object
	o.name = name
	o.scale = s
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	return _finish(o, col, rot, bevel, emission)


def cyl(name, c, r, d, col, rot=(0, 0, 0), verts=12, bevel=0.004, emission=0.0, r2=None):
	if r2 is None:
		bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=c)
	else:
		bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=d, location=c)
	o = bpy.context.active_object
	o.name = name
	return _finish(o, col, rot, bevel, emission)


def ball(name, c, r, col, sub=1, squash=(1, 1, 1), lumpy=0.0, emission=0.0):
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=c)
	o = bpy.context.active_object
	o.name = name
	o.scale = squash
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	if lumpy > 0:
		for v in o.data.vertices:
			v.co *= 1.0 + random.uniform(-lumpy, lumpy)
	return _finish(o, col, (0, 0, 0), 0.0, emission)


def seg(name, p0, p1, thick, col, verts=6):
	"""A round rod from p0 to p1."""
	dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
	ln = math.sqrt(dx * dx + dy * dy + dz * dz)
	c = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=thick / 2, depth=ln, location=c)
	o = bpy.context.active_object
	o.name = name
	o.rotation_mode = "QUATERNION"
	from mathutils import Vector
	o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector((dx, dy, dz)).normalized())
	o.data.materials.append(mat(col))
	if ROOT is not None:
		o.parent = ROOT
	return o


def beam(name, p0, p1, w, h, col, bevel=0.005):
	"""A square timber from p0 to p1 (w across, h tall, in its own frame)."""
	from mathutils import Vector
	a, b = Vector(p0), Vector(p1)
	d = b - a
	bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2)
	o = bpy.context.active_object
	o.name = name
	o.scale = (w, h, d.length)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	o.rotation_mode = "QUATERNION"
	o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
	o.data.materials.append(mat(col))
	bv = o.modifiers.new("bevel", "BEVEL")
	bv.width = bevel
	bv.segments = 1
	if ROOT is not None:
		o.parent = ROOT
	return o


def text(name, s, c, size, col, rot=(90, 0, 0), extrude=0.002):
	bpy.ops.object.text_add(location=c)
	o = bpy.context.active_object
	o.name = name
	o.data.body = s
	o.data.size = size
	o.data.extrude = extrude
	o.data.align_x = "CENTER"
	o.data.align_y = "CENTER"
	bpy.ops.object.convert(target="MESH")
	o = bpy.context.active_object
	return _finish(o, col, rot, 0.0)


def root(name, x):
	global ROOT
	bpy.ops.object.empty_add(location=(x, 0, 0))
	ROOT = bpy.context.active_object
	ROOT.name = name
	return ROOT


def at(x, y, z):
	"""A point relative to the current root (children are parented without offset compensation)."""
	return (x, y, z)


# ------------------------------------------------------------------ pieces

TOP_Z = 0.78          # the work surface height
W, D = 1.5, 0.72      # table top size


def plank_top(pre, z, w=W, d=D, n=5, thick=0.04, cols=("wood_plank", "wood_plank_l", "wood_plank_d")):
	pw = d / n
	for i in range(n):
		y = -d / 2 + pw * (i + 0.5)
		dz = random.uniform(-0.003, 0.003)
		box(pre + "Plank_%d" % i, at(0, y, z - thick / 2 + dz), (w + random.uniform(-0.02, 0.02), pw - 0.006, thick), cols[i % len(cols)], bevel=0.008)
		for sx in (-1, 1):
			for k in (-1, 1):
				cyl(pre + "Nail_%d_%d_%d" % (i, sx, k), at(sx * (w / 2 - 0.06), y + k * pw * 0.22, z + 0.001), 0.006, 0.004, "metal_bolt", verts=6, bevel=0)


def sawhorse(pre, x):
	h = TOP_Z - 0.04
	beam(pre + "Top", (x, -0.3, h - 0.03), (x, 0.3, h - 0.03), 0.09, 0.06, "wood_horse")
	for sy in (-1, 1):
		for sx in (-1, 1):
			beam(pre + "Leg_%d_%d" % (sx, sy), (x + sx * 0.03, sy * 0.24, h - 0.06), (x + sx * 0.2, sy * 0.3, 0.0), 0.055, 0.04, "wood_horse")
		beam(pre + "Brace_%d" % sy, (x - 0.14, sy * 0.28, 0.2), (x + 0.14, sy * 0.28, 0.2), 0.04, 0.05, "wood_horse")
	beam(pre + "Rail", (x, -0.28, 0.2), (x, 0.28, 0.2), 0.04, 0.04, "wood_horse")


def stitches(pre, x0, y0, x1, y1, z, n, col="fabric_thread", rot_z=0.0):
	for i in range(n):
		t = (i + 0.5) / n
		box(pre + "_St%d" % i, at(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z), (0.012, 0.004, 0.002), col, rot=(0, 0, rot_z + 90 * (i % 2 == 0) * 0 + random.uniform(-25, 25)), bevel=0)


def patch(pre, c, w, d, col, z, rot_z=0.0):
	box(pre, at(c[0], c[1], z), (w, d, 0.004), col, rot=(0, 0, rot_z), bevel=0.002)
	for side, (a, b) in enumerate([((-w / 2, -d / 2), (w / 2, -d / 2)), ((w / 2, -d / 2), (w / 2, d / 2)), ((w / 2, d / 2), (-w / 2, d / 2)), ((-w / 2, d / 2), (-w / 2, -d / 2))]):
		r = math.radians(rot_z)
		ax, ay = a[0] * math.cos(r) - a[1] * math.sin(r), a[0] * math.sin(r) + a[1] * math.cos(r)
		bx, by = b[0] * math.cos(r) - b[1] * math.sin(r), b[0] * math.sin(r) + b[1] * math.cos(r)
		n = max(3, int(math.hypot(bx - ax, by - ay) / 0.025))
		stitches(pre + "_S%d" % side, c[0] + ax, c[1] + ay, c[0] + bx, c[1] + by, z + 0.003, n)


def runner(pre, x, z):
	"""The patched cloth runner across the table, hanging over the front edge (sheet: cream with an olive patch)."""
	w = 0.42
	box(pre + "Runner", at(x, 0.02, z + 0.003), (w, D - 0.06, 0.004), "fabric_cream", bevel=0.002)
	box(pre + "Runner_Hang", at(x, -D / 2 - 0.004, z - 0.11), (w, 0.006, 0.22), "fabric_cream", rot=(4, 0, 0), bevel=0.002)
	box(pre + "Runner_Fold", at(x, -D / 2 + 0.002, z - 0.002), (w, 0.012, 0.012), "fabric_cream", bevel=0.004)
	box(pre + "Runner_Patch", at(x + 0.04, -D / 2 - 0.011, z - 0.11), (0.14, 0.004, 0.11), "fabric_olive", rot=(4, 0, 0), bevel=0.001)
	for k in range(9):
		zz = z - 0.215 + random.uniform(-0.004, 0.004)
		box(pre + "Runner_Fray_%d" % k, at(x - w / 2 + 0.02 + k * (w - 0.04) / 8, -D / 2 - 0.01, zz), (0.004, 0.003, 0.02), "fabric_thread", bevel=0)
	for side in range(2):
		for k in range(7):
			xx = x + 0.04 + (-0.07 if side == 0 else 0.07)
			box(pre + "Runner_PSt_%d_%d" % (side, k), at(xx, -D / 2 - 0.014, z - 0.06 - k * 0.016), (0.003, 0.003, 0.01), "fabric_thread", bevel=0)


def cloth_stack(pre, c, z, layers=(("fabric_cream", 0.035), ("fabric_cream", 0.03), ("fabric_olive", 0.035))):
	zz = z
	for i, (col, t) in enumerate(reversed(layers)):
		box(pre + "Cloth_%d" % i, at(c[0] + random.uniform(-0.006, 0.006), c[1] + random.uniform(-0.006, 0.006), zz + t / 2), (0.26, 0.18, t), col, rot=(0, 0, random.uniform(-3, 3)), bevel=0.012)
		zz += t
	return zz


def veska_crate(pre, c, z):
	w, d, h = 0.36, 0.2, 0.13
	cx, cy = c
	box(pre + "Crate_Floor", at(cx, cy, z + 0.006), (w, d, 0.012), "wood_crate", bevel=0.003)
	for sy in (-1, 1):
		for k in range(2):
			box(pre + "Crate_Side_%d_%d" % (sy, k), at(cx, cy + sy * (d / 2 - 0.006), z + 0.012 + 0.03 + k * 0.062), (w, 0.012, 0.058), "paint_veska", bevel=0.003)
	for sx in (-1, 1):
		box(pre + "Crate_End_%d" % sx, at(cx + sx * (w / 2 - 0.006), cy, z + h / 2 + 0.006), (0.012, d - 0.024, h), "paint_veska", bevel=0.003)
		for sy in (-1, 1):
			box(pre + "Crate_Post_%d_%d" % (sx, sy), at(cx + sx * (w / 2 - 0.016), cy + sy * (d / 2 - 0.016), z + h / 2 + 0.006), (0.018, 0.018, h), "wood_crate", bevel=0.003)
	text(pre + "Crate_Text", "VESKA", at(cx, cy - d / 2 - 0.001, z + 0.07), 0.065, "paint_text", rot=(90, 0, 0), extrude=0.0012)
	# coloured scraps heaped in it
	cols = ["fabric_mustard", "fabric_blue", "fabric_red", "fabric_purple", "fabric_mustard", "fabric_blue", "fabric_red"]
	for i, col in enumerate(cols):
		sx = cx - w / 2 + 0.06 + (i % 4) * 0.08 + random.uniform(-0.015, 0.015)
		sy = cy + random.uniform(-0.04, 0.04)
		ball(pre + "Scrap_%d" % i, at(sx, sy, z + h - 0.01 + (i // 4) * 0.02), 0.055, col, sub=1, squash=(1.0, 0.8, 0.55), lumpy=0.18)


def pincushion(pre, c, z):
	cyl(pre + "Pin_Base", at(c[0], c[1], z + 0.012), 0.05, 0.024, "wood_spool", verts=14)
	ball(pre + "Pin_Cushion", at(c[0], c[1], z + 0.03), 0.048, "fabric_pin", sub=2, squash=(1, 1, 0.55))
	for i, (dx, dy, tilt) in enumerate([(-0.015, 0.0, -14), (0.01, 0.012, 8), (0.016, -0.01, 18)]):
		seg(pre + "Pin_%d" % i, (c[0] + dx, c[1] + dy, z + 0.045), (c[0] + dx + math.sin(math.radians(tilt)) * 0.05, c[1] + dy, z + 0.095), 0.003, "metal_chrome", verts=5)
		ball(pre + "Pin_Head_%d" % i, at(c[0] + dx + math.sin(math.radians(tilt)) * 0.05, c[1] + dy, z + 0.097), 0.006, "plain_pinhead", sub=1)


def spool(pre, c, z, h=0.07):
	cyl(pre + "Spool_Bot", at(c[0], c[1], z + 0.006), 0.026, 0.012, "wood_spool", verts=12)
	cyl(pre + "Spool_Thread", at(c[0], c[1], z + h / 2), 0.021, h - 0.02, "fabric_thread", verts=12)
	cyl(pre + "Spool_Top", at(c[0], c[1], z + h - 0.006), 0.026, 0.012, "wood_spool", verts=12)


def scissors(pre, c, z, rot_z=-25.0):
	r = math.radians(rot_z)
	ux, uy = math.cos(r), math.sin(r)
	for k, open_a in enumerate((-9, 9)):
		a = r + math.radians(open_a)
		bx, by = math.cos(a), math.sin(a)
		box(pre + "Sc_Blade_%d" % k, at(c[0] + bx * 0.06, c[1] + by * 0.06, z + 0.004 + k * 0.003), (0.13, 0.014, 0.004), "metal_dark", rot=(0, 0, math.degrees(a)), bevel=0.002)
		hx, hy = c[0] - math.cos(a) * 0.035 + (-uy if k == 0 else uy) * 0.012, c[1] - math.sin(a) * 0.035 + (ux if k == 0 else -ux) * 0.012
		bpy.ops.mesh.primitive_torus_add(major_radius=0.022, minor_radius=0.006, major_segments=12, minor_segments=5, location=(hx, hy, z + 0.006))
		o = bpy.context.active_object
		o.name = pre + "Sc_Loop_%d" % k
		o.scale = (1.0, 0.7, 1.0)
		_finish(o, "metal_dark", (0, 0, math.degrees(a)), 0.0)
	cyl(pre + "Sc_Pivot", at(c[0], c[1], z + 0.009), 0.006, 0.004, "metal_steel", verts=8, bevel=0)


def lamp(pre, base, elbow, head, target, col="metal_copper", shade_r=0.11, clamp=False):
	if clamp:
		box(pre + "Lamp_Clamp", at(base[0], base[1], base[2] + 0.02), (0.05, 0.08, 0.05), "metal_dark", bevel=0.004)
	else:
		cyl(pre + "Lamp_Base", at(base[0], base[1], base[2] + 0.015), 0.075, 0.03, col, verts=10, bevel=0.006)
	cyl(pre + "Lamp_Knuckle0", at(base[0], base[1], base[2] + 0.045), 0.018, 0.03, "wood_drawer", verts=8)
	beam(pre + "Lamp_Arm0", (base[0], base[1], base[2] + 0.05), elbow, 0.024, 0.024, "wood_drawer", bevel=0.004)
	ball(pre + "Lamp_Elbow", elbow, 0.02, "metal_bolt")
	beam(pre + "Lamp_Arm1", elbow, head, 0.02, 0.02, "wood_drawer", bevel=0.004)
	from mathutils import Vector
	h, t = Vector(head), Vector(target)
	dirv = (t - h).normalized()
	c = h + dirv * 0.06
	bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=shade_r, radius2=0.035, depth=0.12, location=c, end_fill_type="NOTHING")
	o = bpy.context.active_object
	o.name = pre + "Lamp_Shade"
	o.rotation_mode = "QUATERNION"
	o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(dirv)
	sol = o.modifiers.new("thick", "SOLIDIFY")
	sol.thickness = 0.006
	_finish(o, col, (0, 0, 0), 0.0)
	o.rotation_mode = "QUATERNION"
	o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(dirv)
	ball(pre + "Lamp_Bulb", tuple(h + dirv * 0.1), 0.035, "plain_bulb", sub=2, emission=6.0)


def sewing_machine(pre, c, z):
	x, y = c
	box(pre + "SM_Bed", at(x, y, z + 0.035), (0.42, 0.2, 0.07), "paint_mint", bevel=0.012)
	box(pre + "SM_Plinth", at(x, y + 0.005, z + 0.004), (0.46, 0.22, 0.008), "wood_drawer", bevel=0.003)
	box(pre + "SM_Pillar", at(x + 0.13, y + 0.02, z + 0.15), (0.1, 0.12, 0.17), "paint_mint", bevel=0.015)
	box(pre + "SM_Arm", at(x - 0.01, y + 0.02, z + 0.22), (0.38, 0.1, 0.07), "paint_mint", bevel=0.02)
	box(pre + "SM_Head", at(x - 0.17, y + 0.015, z + 0.17), (0.06, 0.09, 0.14), "paint_mint", bevel=0.012)
	seg(pre + "SM_Needle", (x - 0.17, y - 0.01, z + 0.1), (x - 0.17, y - 0.01, z + 0.075), 0.004, "metal_chrome", verts=5)
	box(pre + "SM_Foot", at(x - 0.17, y - 0.012, z + 0.074), (0.03, 0.018, 0.006), "metal_chrome", bevel=0.001)
	cyl(pre + "SM_Wheel", at(x + 0.2, y + 0.02, z + 0.19), 0.06, 0.03, "paint_mint", rot=(0, 90, 0), verts=16, bevel=0.004)
	cyl(pre + "SM_Hub", at(x + 0.218, y + 0.02, z + 0.19), 0.02, 0.012, "metal_chrome", rot=(0, 90, 0), verts=10, bevel=0)
	seg(pre + "SM_SpoolPin", (x + 0.05, y + 0.03, z + 0.255), (x + 0.05, y + 0.03, z + 0.31), 0.006, "metal_chrome", verts=5)
	cyl(pre + "SM_Spool", at(x + 0.05, y + 0.03, z + 0.29), 0.016, 0.04, "fabric_thread", verts=10, bevel=0.002)
	cyl(pre + "SM_Knob", at(x + 0.13, y - 0.045, z + 0.18), 0.018, 0.012, "metal_chrome", rot=(90, 0, 0), verts=10, bevel=0)


def drawer_cabinet(pre, c, z, cols=2, rows=3):
	w, d, h = 0.26, 0.2, 0.2
	box(pre + "DC_Body", at(c[0], c[1], z + h / 2), (w, d, h), "wood_drawer", bevel=0.006)
	for r in range(rows):
		for k in range(cols):
			dx = -w / 2 + w / cols * (k + 0.5)
			dz = z + h / rows * (r + 0.5)
			box(pre + "DC_Front_%d_%d" % (r, k), at(c[0] + dx, c[1] - d / 2 - 0.004, dz), (w / cols - 0.016, 0.008, h / rows - 0.014), "wood_plank_l", bevel=0.003)
			box(pre + "DC_Pull_%d_%d" % (r, k), at(c[0] + dx, c[1] - d / 2 - 0.011, dz), (0.03, 0.006, 0.008), "metal_steel", bevel=0.001)


def metal_box(pre, c, z, s=(0.28, 0.2, 0.15), col="paint_box"):
	box(pre + "MB_Body", at(c[0], c[1], z + s[2] / 2), s, col, bevel=0.008)
	box(pre + "MB_Lid", at(c[0], c[1], z + s[2] + 0.008), (s[0] + 0.012, s[1] + 0.012, 0.016), col, bevel=0.005)
	box(pre + "MB_Latch", at(c[0], c[1] - s[1] / 2 - 0.004, z + s[2] - 0.012), (0.03, 0.008, 0.035), "metal_steel", bevel=0.002)


def frame_table(pre, w=W, d=D):
	"""The improved table: an olive-painted timber frame with bolted corners and a lower shelf (sheet: IMPROVED)."""
	h = TOP_Z - 0.04
	for sx in (-1, 1):
		for sy in (-1, 1):
			px, py = sx * (w / 2 - 0.06), sy * (d / 2 - 0.06)
			box(pre + "Post_%d_%d" % (sx, sy), at(px, py, h / 2), (0.075, 0.075, h), "paint_frame", bevel=0.01)
			box(pre + "Foot_%d_%d" % (sx, sy), at(px, py, 0.02), (0.1, 0.1, 0.04), "paint_frame", bevel=0.008)
			for zz in (h - 0.05, 0.2):
				for k, (ox, oy) in enumerate([(sx * 0.04, 0), (0, sy * 0.04)]):
					cyl(pre + "Bolt_%d_%d_%d_%d" % (sx, sy, int(zz * 100), k), at(px + ox * 0.98, py + oy * 0.98, zz), 0.012, 0.012, "metal_bolt", rot=(90, 0, 0) if oy else (0, 90, 0), verts=6, bevel=0)
	for sy in (-1, 1):
		box(pre + "Apron_%d" % sy, at(0, sy * (d / 2 - 0.06), h - 0.05), (w - 0.12, 0.05, 0.09), "paint_frame", bevel=0.006)
		box(pre + "Rail_%d" % sy, at(0, sy * (d / 2 - 0.06), 0.2), (w - 0.12, 0.05, 0.06), "paint_frame", bevel=0.006)
		for sx in (-1, 1):
			beam(pre + "Strut_%d_%d" % (sx, sy), (sx * (w / 2 - 0.1), sy * (d / 2 - 0.06), h - 0.12), (sx * (w / 2 - 0.3), sy * (d / 2 - 0.06), h - 0.03), 0.04, 0.04, "paint_frame")
	for sx in (-1, 1):
		box(pre + "Apron_End_%d" % sx, at(sx * (w / 2 - 0.06), 0, h - 0.05), (0.05, d - 0.12, 0.09), "paint_frame", bevel=0.006)
	box(pre + "Shelf", at(0, 0, 0.24), (w - 0.14, d - 0.14, 0.025), "wood_plank_d", bevel=0.004)


def tabletop_props(pre, upgraded=False, improved=False):
	"""What sits on the top at every stage (sheet: cloth stack left, runner, blue patch, crate, pincushion, spool, scissors, lamp)."""
	z = TOP_Z
	cloth_stack(pre, (-0.6, -0.16) if (improved or upgraded) else (-0.56, 0.12), z)
	runner(pre, -0.18, z)
	patch(pre + "BluePatch", (0.08, -0.04), 0.2, 0.14, "fabric_blue", z + 0.004, rot_z=-4)
	veska_crate(pre, (-0.04 if improved or upgraded else -0.05, 0.22), z)
	pincushion(pre, (0.26, 0.1), z)
	spool(pre, (0.38, 0.08), z)
	scissors(pre, (0.36, -0.12), z)


def build_starter(x):
	root("Sew_Starter", x)
	plank_top("Top_", TOP_Z)
	sawhorse("HorseL_", -0.5)
	sawhorse("HorseR_", 0.5)
	tabletop_props("")
	lamp("", (0.56, 0.2, TOP_Z), (0.62, 0.22, TOP_Z + 0.24), (0.46, 0.2, TOP_Z + 0.4), (0.2, 0.0, TOP_Z))


def build_improved(x):
	root("Sew_Improved", x)
	plank_top("Top_", TOP_Z)
	frame_table("Frame_")
	tabletop_props("", improved=True)
	sewing_machine("", (-0.48, 0.18), TOP_Z)
	drawer_cabinet("", (0.24, 0.24), TOP_Z)
	lamp("", (0.6, 0.22, TOP_Z), (0.66, 0.24, TOP_Z + 0.26), (0.5, 0.2, TOP_Z + 0.42), (0.2, 0.0, TOP_Z))
	metal_box("Under_", (-0.36, 0.0), 0.252)


def build_upgraded(x):
	root("Sew_Upgraded", x)
	plank_top("Top_", TOP_Z)
	frame_table("Frame_")
	tabletop_props("", upgraded=True)
	sewing_machine("", (-0.48, 0.18), TOP_Z)
	drawer_cabinet("", (0.24, 0.24), TOP_Z)
	# the cutting extension on the right: a cream gridded board on its own legs
	ext_x = W / 2 + 0.3
	box("Ext_Top", at(ext_x, 0, TOP_Z - 0.02), (0.6, D, 0.035), "paint_extension", bevel=0.006)
	for i in range(1, 6):
		box("Ext_GridX_%d" % i, at(ext_x - 0.3 + i * 0.1, 0, TOP_Z - 0.002), (0.003, D - 0.02, 0.001), "wood_plank_d", bevel=0)
	for i in range(1, 7):
		box("Ext_GridY_%d" % i, at(ext_x, -D / 2 + i * 0.1, TOP_Z - 0.002), (0.58, 0.003, 0.001), "wood_plank_d", bevel=0)
	for sx in (-1, 1):
		for sy in (-1, 1):
			box("Ext_Leg_%d_%d" % (sx, sy), at(ext_x + sx * 0.25, sy * (D / 2 - 0.06), (TOP_Z - 0.04) / 2), (0.06, 0.06, TOP_Z - 0.04), "paint_frame", bevel=0.008)
	box("Ext_Rail", at(ext_x, 0, 0.2), (0.5, 0.05, 0.05), "paint_frame", bevel=0.006)
	# the jacket laid out on it (placeholder lump until the jacket model; then the real one)
	box("Ext_Jacket", at(ext_x, -0.02, TOP_Z + 0.02), (0.46, 0.5, 0.04), "fabric_jacket", rot=(0, 0, -8), bevel=0.02)
	patch("Ext_JacketPatch", (ext_x + 0.06, -0.14), 0.1, 0.08, "fabric_blue", TOP_Z + 0.042, rot_z=10)
	# pegboard back with a shelf of boxes, spools and cloth; hanging tools; its own small lamp
	pb_y = D / 2 + 0.03
	for sx in (-1, 1):
		box("PB_Post_%d" % sx, at(sx * (W / 2 - 0.04), pb_y, TOP_Z + 0.42), (0.07, 0.07, 0.84), "paint_frame", bevel=0.01)
	box("PB_Board", at(0, pb_y, TOP_Z + 0.36), (W - 0.12, 0.025, 0.56), "wood_peg", bevel=0.004)
	for i in range(14):
		for k in range(5):
			cyl("PB_Hole_%d_%d" % (i, k), at(-W / 2 + 0.14 + i * 0.09, pb_y - 0.013, TOP_Z + 0.16 + k * 0.1), 0.006, 0.004, "metal_dark", rot=(90, 0, 0), verts=6, bevel=0)
	box("PB_Shelf", at(0, pb_y - 0.06, TOP_Z + 0.66), (W - 0.04, 0.18, 0.03), "paint_frame", bevel=0.006)
	box("PB_Cap", at(0, pb_y, TOP_Z + 0.85), (W + 0.04, 0.09, 0.05), "paint_frame", bevel=0.008)
	metal_box("Shelf_", (-0.52, pb_y - 0.06), TOP_Z + 0.675, s=(0.22, 0.15, 0.1))
	box("Shelf_Box", at(-0.22, pb_y - 0.06, TOP_Z + 0.725), (0.15, 0.12, 0.09), "wood_crate", bevel=0.006)
	for i in range(3):
		spool("Shelf_%d_" % i, (0.04 + i * 0.07, pb_y - 0.06), TOP_Z + 0.675, h=0.08)
	cloth_stack("Shelf_", (0.5, pb_y - 0.06), TOP_Z + 0.675, layers=(("fabric_cream", 0.03), ("fabric_olive", 0.03)))
	# hanging tools: shears, a coiled tape measure, a brush, a seam ripper
	for i, hx in enumerate((-0.48, -0.32)):
		seg("PB_Hook_%d" % i, (hx, pb_y - 0.013, TOP_Z + 0.5), (hx, pb_y - 0.05, TOP_Z + 0.52), 0.006, "metal_steel")
	bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.008, major_segments=16, minor_segments=5, location=(-0.12, pb_y - 0.03, TOP_Z + 0.42))
	o = bpy.context.active_object
	o.name = "PB_Tape"
	o.scale = (0.75, 1.0, 1.25)
	_finish(o, "fabric_thread", (90, 0, 0), 0.0)
	box("PB_Brush_Handle", at(0.12, pb_y - 0.03, TOP_Z + 0.46), (0.025, 0.02, 0.1), "wood_spool", bevel=0.004)
	box("PB_Brush_Head", at(0.12, pb_y - 0.035, TOP_Z + 0.38), (0.08, 0.03, 0.06), "wood_drawer", bevel=0.004)
	for k in range(2):
		box("PB_Shears_%d" % k, at(-0.48 + k * 0.012, pb_y - 0.04, TOP_Z + 0.42), (0.016, 0.006, 0.16), "metal_dark", rot=(0, (k - 0.5) * 12, 0), bevel=0.002)
	lamp("", (W / 2 - 0.04, pb_y - 0.06, TOP_Z + 0.5), (W / 2 - 0.1, pb_y - 0.12, TOP_Z + 0.56), (W / 2 - 0.2, pb_y - 0.2, TOP_Z + 0.55), (0.3, 0.0, TOP_Z), col="metal_steel", shade_r=0.07, clamp=True)
	# fabric rolls and a box on the lower shelf
	cyl("Roll_Blue", at(-0.28, -0.08, 0.31), 0.075, 0.66, "fabric_roll_b", rot=(0, 90, 0), verts=14, bevel=0.006)
	cyl("Roll_Mustard", at(-0.28, 0.1, 0.31), 0.075, 0.62, "fabric_roll_y", rot=(0, 90, 0), verts=14, bevel=0.006)
	metal_box("Under_", (0.42, 0.0), 0.252)


if __name__ == "__main__":         # run directly: build the three stages side by side; imported (make_garage_v3.py): just the pieces
	build_starter(-2.2)
	build_improved(0.0)
	build_upgraded(2.5)
	ROOT = None
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sewing.blend"))
	bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "sewing.glb"), export_format="GLB", export_apply=True, export_yup=True)
	print("SEWING OK", len(bpy.data.objects), "objects")
