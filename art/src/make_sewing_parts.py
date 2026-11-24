# The things you handle at the sewing table (M1b, docs/BENCH_SEWING.md; GPT sheets docs/refs/benches/sewing_steps_*.png).
# Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_sewing_parts.py
# Writes art/src/sewing_parts.blend and art/sewing_parts.glb. Every part is ONE top-level object, origin at its centre,
# lying flat as it would on the table (Z up), so the bench can pick it up and turn it. Detail on every side:
# stitched edges, X-box stitching, snaps, seams and a maker's label underneath.
#   Jacket_Field (+ Jacket_Tear marks where it's torn: a separate object so mending can hide it)
#   RigA_Body, RigA_Strap_L, RigA_Strap_R, RigA_Pocket, RigA_Patch  (the market-bag rig, sheet rig_a)
#   RigB_Body, RigB_Pouches, RigB_Webbing, RigB_Tab_1..4            (the chest rig, sheet rig_b)
#   Patch_Blue, Patch_Mustard, Patch_Red                             (scraps for mending)
#   Hand_R, Hand_L                                                   (low-poly hands with an olive cuff)
# Materials are named <kind>_<colour> like make_sewing.py (Godot: v2/world/kind_look.gd).

import bpy
import bmesh
import math
import os
import random
from mathutils import Vector

random.seed(23)
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)

PAL = {
	"fabric_jacket": (0.36, 0.38, 0.2), "fabric_jacket_d": (0.26, 0.28, 0.14), "fabric_stripe": (0.66, 0.2, 0.14),
	"fabric_tape": (0.72, 0.66, 0.5), "fabric_tear": (0.06, 0.05, 0.04), "fabric_thread": (0.92, 0.88, 0.78),
	"fabric_bag": (0.84, 0.76, 0.58), "fabric_olive": (0.4, 0.42, 0.24), "fabric_webbing": (0.88, 0.84, 0.7),
	"fabric_rig": (0.4, 0.4, 0.22), "fabric_rig_d": (0.32, 0.32, 0.17),
	"fabric_blue": (0.22, 0.28, 0.56), "fabric_mustard": (0.84, 0.62, 0.2), "fabric_red": (0.66, 0.16, 0.14),
	"fabric_label": (0.9, 0.88, 0.8), "fabric_cuff": (0.34, 0.36, 0.2),
	"metal_snap": (0.5, 0.48, 0.42), "metal_buckle": (0.62, 0.6, 0.55), "plain_skin": (0.82, 0.58, 0.42),
	"plain_skin_d": (0.7, 0.47, 0.33), "plain_button": (0.3, 0.26, 0.2), "plain_ink": (0.15, 0.13, 0.12),
}
_mats = {}


def _lin(v):
	return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def mat(name):
	if name in _mats:
		return _mats[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	c = [_lin(v) for v in PAL[name]]
	b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
	b.inputs["Roughness"].default_value = 0.9
	if name.startswith("metal_"):
		b.inputs["Metallic"].default_value = 0.6
		b.inputs["Roughness"].default_value = 0.45
	_mats[name] = m
	return m


class Part:
	"""Collects pieces, then joins them into one object with its origin at the centre."""

	def __init__(self, name):
		self.name = name
		self.parts = []

	def _add(self, o, col, rot=(0, 0, 0), bevel=0.0):
		o.rotation_euler = [math.radians(a) for a in rot]
		o.data.materials.append(mat(col))
		if bevel > 0:
			bv = o.modifiers.new("bevel", "BEVEL")
			bv.width = bevel
			bv.segments = 1
			bv.limit_method = "ANGLE"
		self.parts.append(o)
		return o

	def box(self, c, s, col, rot=(0, 0, 0), bevel=0.0):
		bpy.ops.mesh.primitive_cube_add(size=1, location=c)
		o = bpy.context.active_object
		o.scale = s
		bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
		return self._add(o, col, rot, bevel)

	def cyl(self, c, r, d, col, rot=(0, 0, 0), verts=10, bevel=0.0):
		bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=c)
		return self._add(bpy.context.active_object, col, rot, bevel)

	def flat(self, pts, z, thick, col, bevel=0.004):
		"""A flat panel cut from a 2D outline (counter-clockwise), given thickness."""
		me = bpy.data.meshes.new("flat")
		bm = bmesh.new()
		vs = [bm.verts.new((p[0], p[1], z - thick / 2)) for p in pts]
		f = bm.faces.new(vs)
		r = bmesh.ops.extrude_face_region(bm, geom=[f])
		for v in r["geom"]:
			if isinstance(v, bmesh.types.BMVert):
				v.co.z += thick
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		bm.to_mesh(me)
		bm.free()
		o = bpy.data.objects.new("flat", me)
		bpy.context.collection.objects.link(o)
		return self._add(o, col, (0, 0, 0), bevel)

	def stitch_line(self, a, b, z, col="fabric_thread", step=0.022, size=(0.012, 0.003, 0.002)):
		a, b = Vector(a), Vector(b)
		d = b - a
		n = max(2, int(d.length / step))
		ang = math.degrees(math.atan2(d.y, d.x))
		for i in range(n):
			p = a + d * ((i + 0.5) / n)
			self.box((p.x, p.y, z), size, col, rot=(0, 0, ang))

	def stitch_outline(self, pts, z, inset=0.012, col="fabric_thread", step=0.022):
		# move every point toward the centroid a little, then dash along the edges
		cx = sum(p[0] for p in pts) / len(pts)
		cy = sum(p[1] for p in pts) / len(pts)
		q = []
		for p in pts:
			v = Vector((cx - p[0], cy - p[1]))
			l = v.length
			q.append((p[0] + v.x / l * inset, p[1] + v.y / l * inset) if l > 0 else p)
		for i in range(len(q)):
			self.stitch_line(q[i], q[(i + 1) % len(q)], z, col, step)

	def xbox(self, c, w, h, z, col="fabric_thread"):
		"""Box-X stitching (where straps are sewn on)."""
		x, y = c
		corners = [(x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2), (x - w / 2, y + h / 2)]
		for i in range(4):
			self.stitch_line(corners[i], corners[(i + 1) % 4], z, col, step=0.012, size=(0.008, 0.0025, 0.002))
		self.stitch_line(corners[0], corners[2], z, col, step=0.012, size=(0.008, 0.0025, 0.002))
		self.stitch_line(corners[1], corners[3], z, col, step=0.012, size=(0.008, 0.0025, 0.002))

	def snap(self, c, z, r=0.012):
		self.cyl((c[0], c[1], z), r, 0.005, "metal_snap", verts=10, bevel=0.0015)
		self.cyl((c[0], c[1], z + 0.003), r * 0.45, 0.003, "metal_buckle", verts=8)

	def label(self, c, z, w=0.07, h=0.035):
		"""A maker's label underneath (detail on the side you only see when you turn it over)."""
		self.box((c[0], c[1], z), (w, h, 0.002), "fabric_label")
		for k in range(3):
			self.box((c[0] - w * 0.25 + k * w * 0.18, c[1], z - 0.0012), (w * 0.12, 0.004, 0.001), "plain_ink")

	def build(self, at=None):
		bpy.ops.object.select_all(action="DESELECT")
		for o in self.parts:
			o.select_set(True)
		bpy.context.view_layer.objects.active = self.parts[0]
		for o in self.parts:
			bpy.context.view_layer.objects.active = o
			for m in list(o.modifiers):
				bpy.ops.object.modifier_apply(modifier=m.name)
		bpy.context.view_layer.objects.active = self.parts[0]
		bpy.ops.object.join()
		o = bpy.context.active_object
		o.name = self.name
		bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
		bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
		if at is not None:
			o.location = at
		return o


def mirror_x(pts):
	"""Half an outline (x >= 0, bottom to top) mirrored into a full counter-clockwise outline."""
	right = list(pts)
	left = [(-p[0], p[1]) for p in reversed(pts)]
	return right + left


# ------------------------------------------------------------------ the field jacket, laid flat, sleeve torn

def jacket():
	p = Part("Jacket_Field")
	T = 0.03
	# laid-flat outline: hem, side, armpit, sleeve out to the cuff, shoulder, collar
	half = [(0.0, -0.32), (0.23, -0.32), (0.24, 0.08), (0.5, -0.05), (0.56, 0.05), (0.27, 0.27), (0.12, 0.3), (0.06, 0.26)]
	outline = [(0.0, -0.32)] + half[1:] + [(-x, y) for (x, y) in reversed(half[1:])]
	p.flat(outline, 0.0, T, "fabric_jacket", bevel=0.008)
	top = T / 2
	# collar, placket, buttons
	p.flat([(-0.13, 0.25), (-0.06, 0.2), (0.0, 0.25), (0.06, 0.2), (0.13, 0.25), (0.12, 0.32), (-0.12, 0.32)], top + 0.006, 0.012, "fabric_jacket_d", bevel=0.003)
	p.box((0.0, -0.03, top + 0.003), (0.035, 0.56, 0.006), "fabric_jacket_d")
	for k in range(5):
		p.cyl((0.0, 0.2 - k * 0.11, top + 0.009), 0.011, 0.006, "plain_button", verts=8)
	# two chest pockets with flaps and buttons
	for sx in (-1, 1):
		x = sx * 0.12
		p.box((x, 0.08, top + 0.004), (0.12, 0.12, 0.008), "fabric_jacket")
		p.box((x, 0.135, top + 0.01), (0.13, 0.04, 0.008), "fabric_jacket_d", bevel=0.003)
		p.cyl((x, 0.13, top + 0.016), 0.008, 0.005, "plain_button", verts=8)
		p.stitch_outline([(x - 0.06, 0.02), (x + 0.06, 0.02), (x + 0.06, 0.14), (x - 0.06, 0.14)], top + 0.009, inset=0.006, step=0.016)
	# name tape over the right pocket, the red stripe along the left shoulder
	p.box((-0.12, 0.19, top + 0.005), (0.11, 0.025, 0.004), "fabric_tape")
	for k in range(6):
		p.box((-0.155 + k * 0.014, 0.19, top + 0.0075), (0.008, 0.012, 0.001), "plain_ink")
	p.box((0.4, 0.15, top + 0.004), (0.26, 0.03, 0.004), "fabric_stripe", rot=(0, 0, -37))
	# seams: down the sleeves, along the shoulders; cuffs
	for sx in (-1, 1):
		p.stitch_line((sx * 0.26, 0.24), (sx * 0.52, 0.0), top + 0.002, step=0.03)
		p.box((sx * 0.525, 0.0, top + 0.004), (0.035, 0.12, 0.006), "fabric_jacket_d", rot=(0, 0, -37 * sx))
	# hem band and its stitching
	p.box((0.0, -0.305, top + 0.003), (0.46, 0.03, 0.006), "fabric_jacket_d")
	p.stitch_line((-0.22, -0.29), (0.22, -0.29), top + 0.007, step=0.025)
	# underneath: the back seam, a yoke seam and the maker's label inside the collar
	p.stitch_line((0.0, -0.31), (0.0, 0.2), -top - 0.001, step=0.03)
	p.stitch_line((-0.22, 0.2), (0.22, 0.2), -top - 0.001, step=0.03)
	p.label((0.0, 0.26), -top - 0.0015)
	j = p.build()

	# the tear: a ragged dark slit with frayed threads, on the right sleeve (its own object so mending can hide it)
	t = Part("Jacket_Tear")
	cx, cy, ang = 0.38, 0.06, -37 + 90
	t.box((cx, cy, top + 0.002), (0.13, 0.022, 0.004), "fabric_tear", rot=(0, 0, ang))
	r = math.radians(ang)
	for k in range(12):
		u = -0.06 + k * 0.011
		side = 1 if k % 2 else -1
		px = cx + math.cos(r) * u - math.sin(r) * side * 0.012
		py = cy + math.sin(r) * u + math.cos(r) * side * 0.012
		t.box((px, py, top + 0.004), (0.004, 0.012 + random.uniform(0, 0.006), 0.002), "fabric_thread", rot=(0, 0, ang + random.uniform(-30, 30)))
	t.build()
	return j


# ------------------------------------------------------------------ rig A: the market-bag rig (sheet rig_a)

def rig_a():
	b = Part("RigA_Body")
	# the cut bag: a tank shape (two handle straps, a scooped top)
	half = [(0.0, -0.22), (0.2, -0.22), (0.22, 0.08), (0.17, 0.14), (0.15, 0.27), (0.09, 0.27), (0.08, 0.14), (0.0, 0.1)]
	outline = [(0.0, -0.22)] + half[1:-1] + [(0.0, 0.1)] + [(-x, y) for (x, y) in reversed(half[1:-1])]
	b.flat(outline, 0.0, 0.01, "fabric_bag", bevel=0.004)
	b.stitch_outline(outline, 0.006, inset=0.01, step=0.024)
	# a woven look: a few darker bands across, and wrinkles
	for k in range(4):
		b.box((0.0, -0.17 + k * 0.08, 0.0055), (0.38, 0.006, 0.001), "fabric_tape")
	b.label((0.0, -0.15), -0.006)
	b.build()
	for i, sx in enumerate((-1, 1)):
		s = Part("RigA_Strap_" + ("L" if sx < 0 else "R"))
		s.box((0.0, 0.0, 0.0), (0.05, 0.24, 0.008), "fabric_olive", bevel=0.002)
		s.stitch_line((-0.02, -0.11), (-0.02, 0.11), 0.0045, step=0.02)
		s.stitch_line((0.02, -0.11), (0.02, 0.11), 0.0045, step=0.02)
		s.xbox((0.0, 0.08), 0.03, 0.04, 0.0055)
		s.xbox((0.0, -0.08), 0.03, 0.04, 0.0055)
		s.build()
	pk = Part("RigA_Pocket")
	pk.box((0.0, 0.0, 0.0), (0.16, 0.1, 0.03), "fabric_bag", bevel=0.006)
	pk.box((0.0, 0.03, 0.018), (0.165, 0.05, 0.008), "fabric_bag", bevel=0.004)
	pk.snap((0.0, 0.025), 0.024)
	pk.stitch_outline([(-0.08, -0.05), (0.08, -0.05), (0.08, 0.05), (-0.08, 0.05)], 0.0155, inset=0.008, step=0.018)
	pk.build()
	pt = Part("RigA_Patch")
	pts = [(-0.1, -0.06), (0.1, -0.06), (0.1, 0.06), (-0.1, 0.06)]
	pt.flat(pts, 0.0, 0.004, "fabric_blue", bevel=0.001)
	pt.stitch_outline(pts, 0.0025, inset=0.008, step=0.02)
	pt.build()


# ------------------------------------------------------------------ rig B: the chest rig (sheet rig_b)

def rig_b():
	b = Part("RigB_Body")
	half = [(0.0, -0.17), (0.25, -0.17), (0.26, 0.06), (0.2, 0.12), (0.19, 0.3), (0.12, 0.3), (0.1, 0.13), (0.0, 0.1)]
	outline = [(0.0, -0.17)] + half[1:-1] + [(0.0, 0.1)] + [(-x, y) for (x, y) in reversed(half[1:-1])]
	b.flat(outline, 0.0, 0.016, "fabric_rig", bevel=0.005)
	b.stitch_outline(outline, 0.009, inset=0.012, step=0.024)
	for sx in (-1, 1):
		b.xbox((sx * 0.155, 0.22), 0.05, 0.05, 0.0095)
		for k in range(2):
			b.box((sx * 0.27, -0.1 + k * 0.1, 0.0), (0.04, 0.03, 0.012), "fabric_webbing", bevel=0.002)
	# underneath: a seam down the middle and a label
	b.stitch_line((0.0, -0.15), (0.0, 0.08), -0.0085, step=0.025)
	b.label((0.0, -0.1), -0.0085)
	b.build()
	p = Part("RigB_Pouches")
	p.box((0.0, 0.0, 0.0), (0.42, 0.18, 0.01), "fabric_rig_d", bevel=0.003)
	for k in range(3):
		x = -0.135 + k * 0.135
		p.box((x, -0.01, 0.025), (0.12, 0.15, 0.04), "fabric_rig", bevel=0.008)
		p.box((x, 0.045, 0.048), (0.125, 0.06, 0.01), "fabric_rig", bevel=0.004)
		p.snap((x, 0.04), 0.054)
		p.stitch_outline([(x - 0.06, -0.085), (x + 0.06, -0.085), (x + 0.06, 0.065), (x - 0.06, 0.065)], 0.0455, inset=0.006, step=0.018)
	p.stitch_outline([(-0.21, -0.09), (0.21, -0.09), (0.21, 0.09), (-0.21, 0.09)], 0.0055, inset=0.008, step=0.024)
	p.label((0.0, 0.0), -0.006)
	p.build()
	w = Part("RigB_Webbing")
	bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.014, major_segments=18, minor_segments=4)
	o = bpy.context.active_object
	o.scale = (1.0, 1.0, 1.4)
	w._add(o, "fabric_webbing")
	w.box((0.11, -0.05, 0.0), (0.12, 0.035, 0.004), "fabric_webbing", rot=(0, 0, -20))
	w.build()
	for i in range(4):
		t = Part("RigB_Tab_%d" % (i + 1))
		t.box((0.0, 0.0, 0.0), (0.035, 0.05, 0.006), "fabric_webbing", bevel=0.0015)
		t.box((0.0, 0.0, 0.0045), (0.026, 0.008, 0.003), "metal_buckle")
		t.build()


def scraps():
	for col in ("blue", "mustard", "red"):
		p = Part("Patch_" + col.capitalize())
		pts = [(-0.07, -0.05), (0.07, -0.05), (0.072, 0.05), (-0.068, 0.052)]
		p.flat(pts, 0.0, 0.004, "fabric_" + col, bevel=0.001)
		for k in range(10):   # frayed edges
			p.box((-0.07 + k * 0.0155, -0.052, 0.0), (0.003, 0.008, 0.002), "fabric_thread")
		p.build()


# ------------------------------------------------------------------ hands (sheet: chunky low-poly, olive cuffs)

def hand(name, sx):
	h = Part(name)
	h.box((0.0, 0.0, 0.0), (0.085, 0.095, 0.028), "plain_skin", bevel=0.008)                 # palm, back up
	for i in range(4):
		x = -0.032 + i * 0.022
		ln = [0.07, 0.08, 0.076, 0.062][i]
		h.box((x * sx, 0.047 + ln * 0.3, -0.002), (0.019, ln * 0.6, 0.018), "plain_skin", rot=(-6, 0, 0), bevel=0.004)
		h.box((x * sx, 0.047 + ln * 0.78, -0.009), (0.018, ln * 0.42, 0.016), "plain_skin_d", rot=(-22, 0, 0), bevel=0.004)
	h.box((0.055 * sx, 0.012, -0.004), (0.022, 0.05, 0.02), "plain_skin", rot=(0, 0, -40 * sx), bevel=0.005)
	h.box((0.075 * sx, 0.045, -0.01), (0.018, 0.035, 0.018), "plain_skin_d", rot=(-20, 0, -25 * sx), bevel=0.004)
	h.box((0.0, -0.07, 0.0), (0.07, 0.05, 0.034), "plain_skin", bevel=0.008)                 # wrist
	h.cyl((0.0, -0.13, 0.002), 0.052, 0.09, "fabric_cuff", rot=(90, 0, 0), verts=8, bevel=0.006)   # sleeve
	h.cyl((0.0, -0.085, 0.002), 0.056, 0.016, "fabric_cuff", rot=(90, 0, 0), verts=8, bevel=0.003)
	h.build()


# ------------------------------------------------------------------ run, laid out in a row for the preview

jacket()
rig_a()
rig_b()
scraps()
hand("Hand_R", 1)
hand("Hand_L", -1)

layout = [("Jacket_Field", (0.0, 0.0)), ("Jacket_Tear", None),
	("RigA_Body", (1.4, 0.15)), ("RigA_Strap_L", (1.15, -0.3)), ("RigA_Strap_R", (1.25, -0.3)), ("RigA_Pocket", (1.55, -0.3)), ("RigA_Patch", (1.8, -0.3)),
	("RigB_Body", (2.6, 0.15)), ("RigB_Pouches", (2.6, -0.32)), ("RigB_Webbing", (3.1, 0.1)),
	("RigB_Tab_1", (3.05, -0.25)), ("RigB_Tab_2", (3.1, -0.25)), ("RigB_Tab_3", (3.15, -0.25)), ("RigB_Tab_4", (3.2, -0.25)),
	("Patch_Blue", (0.75, -0.3)), ("Patch_Mustard", (0.75, -0.15)), ("Patch_Red", (0.75, 0.0)),
	("Hand_R", (3.6, 0.0)), ("Hand_L", (3.85, 0.0))]
jx = bpy.data.objects["Jacket_Field"].location.copy()
for name, at in layout:
	o = bpy.data.objects[name]
	if at is None:
		# the tear keeps its place on the jacket: shift it by however the jacket moved
		continue
	o.location = (at[0], at[1], o.dimensions.z / 2)
tear = bpy.data.objects["Jacket_Tear"]
jac = bpy.data.objects["Jacket_Field"]
tear.location = tear.location - jx + jac.location

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sewing_parts.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "sewing_parts.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("PARTS OK", [o.name for o in bpy.data.objects])
