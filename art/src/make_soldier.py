# The soldier kit for the combat slice (docs/COMBAT_SLICE.md section 6): faceted low-poly body segments
# and gear pieces, each its own object with its pivot at the joint it hangs from (at the world origin).
# Godot (v2/combat/soldier.gd) builds the joint rig in code, hangs these on it, and paints the camo
# per face by material name. Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_soldier.py
# Writes art/src/soldier.blend (for the user to tweak) and art/soldier.glb (what Godot loads).
# Blender coords: X right, Y forward (where the soldier faces), Z up. Limbs hang down -Z from their joint.

import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Euler

random.seed(7)
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)

bpy.ops.wm.read_factory_settings(use_empty=True)

# Flat base colours. Godot repaints by material name ("camo" gets patches), so these are only for Blender.
PAL = {
	"camo": (0.38, 0.37, 0.28), "coyote": (0.47, 0.39, 0.27), "ranger": (0.26, 0.29, 0.21),
	"black": (0.08, 0.08, 0.08), "skin": (0.62, 0.47, 0.37), "glove": (0.16, 0.15, 0.13),
	"lens": (0.85, 0.95, 1.0), "red": (0.65, 0.08, 0.06), "metal": (0.25, 0.26, 0.27),
	"strap": (0.2, 0.2, 0.17), "tan": (0.6, 0.52, 0.38), "wood": (0.36, 0.22, 0.12), "woven": (0.22, 0.38, 0.48),
	"cream": (0.82, 0.77, 0.62), "yellow": (0.82, 0.6, 0.2), "olive": (0.36, 0.36, 0.2), "field": (0.42, 0.38, 0.24), "patch": (0.25, 0.4, 0.5),
}
_mats = {}


def mat(name):
	if name in _mats:
		return _mats[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes.get("Principled BSDF")
	c = PAL[name]
	b.inputs["Base Color"].default_value = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1.0)
	b.inputs["Roughness"].default_value = 0.9
	_mats[name] = m
	return m


class Part:
	"""One object built from faceted chunks; each chunk has its own material."""

	def __init__(self, name):
		self.name = name
		self.bm = bmesh.new()
		self.mats = []

	def _mi(self, m):
		if m not in self.mats:
			self.mats.append(m)
		return self.mats.index(m)

	def _take_new(self, before_v, before_f, m, center, size, rot, rnd, jit, taper):
		newv = [v for v in self.bm.verts if v not in before_v]
		newf = [f for f in self.bm.faces if f not in before_f]
		rm = Euler([math.radians(a) for a in rot]).to_matrix()
		for v in newv:
			co = v.co.copy()
			if rnd > 0.0 and co.length > 0.0:
				co = co.lerp(co.normalized() * 0.55, rnd)
			t = taper[0] + (taper[1] - taper[0]) * (co.z + 0.5)
			co.x *= t
			co.y *= t
			co += Vector((random.uniform(-jit, jit), random.uniform(-jit, jit), random.uniform(-jit, jit)))
			co = Vector((co.x * size[0], co.y * size[1], co.z * size[2]))
			v.co = rm @ co + Vector(center)
		for f in newf:
			f.material_index = self._mi(m)

	def chunk(self, center, size, m, cuts=1, rnd=0.3, jit=0.05, taper=(1.0, 1.0), rot=(0, 0, 0)):
		bv, bf = set(self.bm.verts), set(self.bm.faces)
		ret = bmesh.ops.create_cube(self.bm, size=1.0)
		if cuts:
			edges = list({e for v in ret["verts"] for e in v.link_edges})
			bmesh.ops.subdivide_edges(self.bm, edges=edges, cuts=cuts, use_grid_fill=True)
		self._take_new(bv, bf, m, center, size, rot, rnd, jit, taper)
		return self

	def cyl(self, center, radius, depth, m, segs=6, rot=(0, 0, 0), jit=0.02):
		bv, bf = set(self.bm.verts), set(self.bm.faces)
		bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs, radius1=0.5, radius2=0.5, depth=1.0)
		self._take_new(bv, bf, m, center, (radius * 2, radius * 2, depth), rot, 0.0, jit, (1.0, 1.0))
		return self

	def build(self):
		bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:])
		me = bpy.data.meshes.new(self.name)
		self.bm.to_mesh(me)
		self.bm.free()
		for p in me.polygons:
			p.use_smooth = False
		for m in self.mats:
			me.materials.append(mat(m))
		o = bpy.data.objects.new(self.name, me)
		bpy.context.scene.collection.objects.link(o)
		return o


# ------------------------------------------------------------------ body (joint at the origin)

Part("Body_Pelvis").chunk((0, 0, -0.07), (0.34, 0.22, 0.2), "camo", taper=(0.88, 1.0)).build()
Part("Body_Chest").chunk((0, 0, 0.23), (0.36, 0.22, 0.46), "camo", taper=(0.82, 1.12)) \
	.chunk((0, 0, 0.5), (0.11, 0.11, 0.08), "skin", cuts=0, rnd=0.2).build()
Part("Body_Head").chunk((0, 0.01, 0.12), (0.17, 0.2, 0.22), "skin", cuts=2, rnd=0.55, jit=0.04) \
	.chunk((0, 0.085, 0.16), (0.11, 0.04, 0.03), "black", cuts=0, rnd=0.0, jit=0.0).build()   # brow shadow / eyes
for side, sx in (("L", -1), ("R", 1)):
	Part("Body_UpperArm_" + side).chunk((0, 0, -0.14), (0.115, 0.115, 0.31), "camo", taper=(0.82, 1.0)).build()
	Part("Body_LowerArm_" + side).chunk((0, 0, -0.13), (0.095, 0.095, 0.27), "camo", taper=(0.78, 1.0)).build()
	Part("Body_Hand_" + side).chunk((0, 0.0, -0.05), (0.075, 0.055, 0.1), "glove", rnd=0.4).build()
	Part("Body_Thigh_" + side).chunk((0, 0, -0.2), (0.16, 0.17, 0.43), "camo", taper=(0.8, 1.0)).build()
	Part("Body_Shin_" + side).chunk((0, 0, -0.19), (0.125, 0.135, 0.41), "camo", taper=(0.78, 1.0)).build()
	Part("Body_Boot_" + side).chunk((0, 0.045, -0.07), (0.115, 0.28, 0.13), "coyote", taper=(1.0, 0.88), rnd=0.2).build()
	Part("Gear_KneePad_" + side).chunk((0, 0.075, 0.0), (0.12, 0.05, 0.12), "black", rnd=0.3).build()

# ------------------------------------------------------------------ head gear (joint = neck)

h = Part("Gear_Helmet")
h.chunk((0, -0.005, 0.2), (0.26, 0.29, 0.17), "coyote", cuts=2, rnd=0.6, taper=(1.06, 0.78))
for sx in (-1, 1):
	h.cyl((sx * 0.125, 0.0, 0.12), 0.048, 0.045, "black", rot=(0, 90, 0))       # comms ear cups
	h.chunk((sx * 0.13, 0.02, 0.21), (0.02, 0.16, 0.025), "black", cuts=0, rnd=0.0, jit=0.0)   # side rails
h.chunk((0, 0.145, 0.22), (0.06, 0.03, 0.05), "black", cuts=0, rnd=0.1)                # NVG shroud
h.chunk((0.145, 0.06, 0.215), (0.03, 0.06, 0.032), "black", cuts=0, rnd=0.0)          # the helmet cam
h.chunk((0.145, 0.093, 0.215), (0.02, 0.006, 0.02), "lens", cuts=0, rnd=0.0, jit=0.0)
h.chunk((0, -0.14, 0.2), (0.1, 0.03, 0.06), "coyote", cuts=0, rnd=0.2)               # counterweight pouch
h.build()

g = Part("Gear_GasMask")
g.chunk((0, 0.095, 0.08), (0.15, 0.1, 0.14), "black", cuts=1, rnd=0.45)
g.cyl((0.045, 0.16, 0.035), 0.035, 0.05, "metal", rot=(80, 0, 20))
g.chunk((0, 0.135, 0.13), (0.12, 0.02, 0.04), "lens", cuts=0, rnd=0.0, jit=0.0)
g.build()

c = Part("Gear_Cap")
c.chunk((0, 0.0, 0.2), (0.22, 0.24, 0.1), "ranger", cuts=1, rnd=0.5, taper=(1.0, 0.85))
c.chunk((0, 0.14, 0.17), (0.18, 0.1, 0.015), "ranger", cuts=0, rnd=0.0)
c.build()

# ------------------------------------------------------------------ torso gear (joint = waist, chest part)

pc = Part("Gear_Carrier")
pc.chunk((0, 0.135, 0.27), (0.33, 0.065, 0.34), "coyote", rnd=0.15, jit=0.03)    # front plate bag
pc.chunk((0, -0.135, 0.28), (0.33, 0.065, 0.36), "coyote", rnd=0.15, jit=0.03)   # back plate bag
for sx in (-1, 1):
	pc.chunk((sx * 0.19, 0, 0.17), (0.045, 0.26, 0.16), "coyote", cuts=0, rnd=0.1)     # cummerbund
	pc.chunk((sx * 0.11, 0, 0.465), (0.075, 0.29, 0.045), "coyote", cuts=0, rnd=0.1)   # shoulder straps
for i in range(3):
	pc.chunk((-0.09 + i * 0.09, 0.185, 0.17), (0.08, 0.055, 0.14), "coyote", cuts=0, rnd=0.15)   # mag pouches
	pc.chunk((-0.09 + i * 0.09, 0.19, 0.25), (0.06, 0.03, 0.02), "black", cuts=0, rnd=0.0)      # mags peeking
pc.chunk((0, 0.18, 0.34), (0.2, 0.04, 0.08), "ranger", cuts=0, rnd=0.1)            # admin pouch
pc.chunk((-0.19, -0.1, 0.26), (0.055, 0.075, 0.16), "ranger", cuts=0, rnd=0.1)     # radio pouch
pc.cyl((-0.19, -0.12, 0.46), 0.007, 0.32, "black", segs=4)                          # antenna
pc.build()

b = Part("Gear_Belt")
b.chunk((0, 0, 0.0), (0.38, 0.27, 0.07), "ranger", cuts=1, rnd=0.35, jit=0.03)
b.chunk((0.2, 0.05, -0.05), (0.055, 0.09, 0.11), "ranger", cuts=0, rnd=0.15)
b.chunk((-0.2, 0.06, -0.03), (0.04, 0.05, 0.09), "red", cuts=0, rnd=0.1)          # tourniquet
b.chunk((0, -0.155, -0.07), (0.22, 0.065, 0.13), "ranger", cuts=0, rnd=0.25)      # dump pouch
b.chunk((0.21, -0.07, -0.08), (0.05, 0.07, 0.15), "black", cuts=0, rnd=0.1)       # pistol holster
b.build()

mb = Part("Gear_MedBag")
mb.chunk((0, -0.215, 0.22), (0.27, 0.13, 0.32), "ranger", rnd=0.25)
mb.chunk((0, -0.285, 0.25), (0.11, 0.008, 0.035), "red", cuts=0, rnd=0.0, jit=0.0)
mb.chunk((0, -0.285, 0.25), (0.035, 0.008, 0.11), "red", cuts=0, rnd=0.0, jit=0.0)
mb.build()

pk = Part("Gear_Pack")               # GEAR 02 / UTILITY PACK: flap, two buckle straps, front pocket, a bottle
pk.chunk((0, -0.215, 0.24), (0.28, 0.13, 0.35), "field", rnd=0.25, taper=(1.05, 0.9))
pk.chunk((0, -0.255, 0.38), (0.27, 0.1, 0.1), "field", cuts=0, rnd=0.2)                   # top flap
pk.chunk((0, -0.29, 0.14), (0.18, 0.04, 0.12), "field", cuts=0, rnd=0.2)                  # front pocket
for sx in (-1, 1):
	pk.chunk((sx * 0.07, -0.288, 0.29), (0.03, 0.012, 0.2), "field", cuts=0, rnd=0.0)
	pk.chunk((sx * 0.07, -0.296, 0.25), (0.034, 0.012, 0.03), "black", cuts=0, rnd=0.0)
pk.chunk((0.05, -0.3, 0.405), (0.06, 0.006, 0.04), "yellow", cuts=0, rnd=0.0, jit=0.0)    # patch on the flap
pk.chunk((0.07, -0.312, 0.11), (0.04, 0.006, 0.03), "patch", cuts=0, rnd=0.0, jit=0.0)
pk.chunk((0.155, -0.2, 0.16), (0.04, 0.08, 0.12), "field", cuts=0, rnd=0.15)              # bottle pocket
pk.cyl((0.16, -0.2, 0.26), 0.026, 0.1, "metal")
pk.chunk((0.17, -0.25, 0.25), (0.01, 0.025, 0.045), "red", cuts=0, rnd=0.1)
pk.build()

hy = Part("Gear_Hydration")
hy.chunk((0, -0.19, 0.3), (0.2, 0.06, 0.28), "ranger", rnd=0.2)
hy.build()

# ------------------------------------------------------------------ rifle (origin = stock butt, forward +Y)

r = Part("Gear_Rifle")
r.chunk((0, 0.11, -0.025), (0.045, 0.22, 0.085), "coyote", cuts=0, rnd=0.1, taper=(0.8, 1.0))   # stock
r.cyl((0, 0.24, 0.0), 0.017, 0.12, "black", rot=(90, 0, 0))                                    # buffer tube
r.chunk((0, 0.38, 0.0), (0.05, 0.27, 0.075), "black", cuts=0, rnd=0.05, jit=0.02)              # receiver
r.chunk((0, 0.415, -0.1), (0.03, 0.07, 0.15), "black", cuts=0, rnd=0.05, rot=(-14, 0, 0))     # mag
r.chunk((0, 0.31, -0.075), (0.03, 0.04, 0.09), "black", cuts=0, rnd=0.1, rot=(22, 0, 0))      # pistol grip
r.chunk((0, 0.64, 0.0), (0.062, 0.27, 0.066), "black", cuts=0, rnd=0.05, jit=0.02)            # handguard
r.cyl((0, 0.84, 0.0), 0.012, 0.16, "black", rot=(90, 0, 0))                                    # barrel
r.cyl((0, 0.935, 0.0), 0.017, 0.05, "black", rot=(90, 0, 0))                                   # muzzle device
r.chunk((0, 0.4, 0.068), (0.042, 0.075, 0.052), "black", cuts=0, rnd=0.1)                     # optic
r.chunk((0, 0.44, 0.07), (0.03, 0.005, 0.03), "lens", cuts=0, rnd=0.0, jit=0.0)
r.cyl((0.042, 0.69, -0.01), 0.017, 0.09, "black", rot=(90, 0, 0))                              # weapon light
r.cyl((0.042, 0.737, -0.01), 0.015, 0.008, "lens", rot=(90, 0, 0))
r.chunk((0, 0.62, -0.065), (0.026, 0.032, 0.075), "black", cuts=0, rnd=0.15)                  # vertical grip
r.build()

# ------------------------------------------------------------------ starter weapons (origin = butt, forward +Y)

b = Part("Gear_BoltRifle")
b.chunk((0, 0.16, -0.035), (0.045, 0.34, 0.09), "wood", cuts=0, rnd=0.1, taper=(0.75, 1.0))       # wooden stock
b.chunk((0, 0.48, -0.01), (0.05, 0.34, 0.06), "wood", cuts=0, rnd=0.1)                            # fore-end
b.cyl((0, 0.47, 0.025), 0.016, 0.36, "metal", rot=(90, 0, 0))                                      # receiver tube
b.cyl((0, 0.84, 0.02), 0.011, 0.42, "metal", rot=(90, 0, 0))                                       # long barrel
b.chunk((0.035, 0.42, 0.03), (0.04, 0.012, 0.012), "metal", cuts=0, rnd=0.0)                      # bolt handle
b.chunk((0, 0.4, 0.07), (0.03, 0.14, 0.035), "black", cuts=0, rnd=0.1)                            # old scope
b.chunk((0, 0.38, -0.06), (0.025, 0.05, 0.04), "metal", cuts=0, rnd=0.0)                          # trigger guard
b.build()

s = Part("Gear_Shotgun")
s.chunk((0, 0.14, -0.03), (0.045, 0.28, 0.085), "black", cuts=0, rnd=0.1, taper=(0.8, 1.0))      # polymer stock
s.chunk((0, 0.4, 0.0), (0.05, 0.24, 0.07), "metal", cuts=0, rnd=0.05)                             # receiver
s.cyl((0, 0.72, 0.018), 0.014, 0.48, "metal", rot=(90, 0, 0))                                      # barrel
s.cyl((0, 0.66, -0.018), 0.015, 0.34, "metal", rot=(90, 0, 0))                                     # tube under it
s.chunk((0, 0.64, -0.02), (0.05, 0.14, 0.05), "black", cuts=0, rnd=0.2)                           # the pump
s.chunk((0, 0.33, -0.07), (0.03, 0.04, 0.08), "black", cuts=0, rnd=0.1, rot=(22, 0, 0))          # grip
s.build()

# ------------------------------------------------------------------ rigs (joint = waist, on the chest part)

m = Part("Gear_RigMarket")           # GEAR 01 / RECLAIMED TOTE (starter rig): woven blue bag with a cream stripe,
                                     # three pouches, a side pouch with a red loop, olive straps, yellow tabs, X back
m.chunk((0, 0.165, 0.2), (0.34, 0.09, 0.2), "woven", cuts=1, rnd=0.12, jit=0.03)
for i, (x, w, h) in enumerate(((-0.12, 0.085, 0.12), (0.0, 0.115, 0.14), (0.12, 0.085, 0.12))):
	m.chunk((x, 0.218, 0.16), (w, 0.045, h), "woven", cuts=0, rnd=0.12)                 # pouches
	m.chunk((x, 0.24, 0.225), (w * 0.95, 0.014, 0.045), "woven", cuts=0, rnd=0.0)       # flaps
	m.chunk((x, 0.242, 0.15), (w * 1.01, 0.006, 0.028), "cream", cuts=0, rnd=0.0, jit=0.0)   # the stripe
m.chunk((0.195, 0.17, 0.17), (0.05, 0.07, 0.12), "woven", cuts=0, rnd=0.15)               # side pouch
m.chunk((0.225, 0.17, 0.25), (0.012, 0.03, 0.05), "red", cuts=0, rnd=0.1)                  # pull loop
m.chunk((0, 0.245, 0.095), (0.05, 0.006, 0.035), "yellow", cuts=0, rnd=0.0, jit=0.0)       # patch
for sx in (-1, 1):
	m.chunk((sx * 0.11, 0.06, 0.4), (0.05, 0.3, 0.025), "olive", cuts=0, rnd=0.0)          # salvaged straps
	m.chunk((sx * 0.11, 0.2, 0.3), (0.05, 0.018, 0.05), "olive", cuts=0, rnd=0.0)
	m.chunk((sx * 0.11, 0.212, 0.335), (0.052, 0.016, 0.03), "black", cuts=0, rnd=0.0)     # buckles
	m.chunk((sx * 0.11, 0.21, 0.29), (0.045, 0.014, 0.04), "yellow", cuts=0, rnd=0.0)      # tote handle tabs
	m.chunk((sx * 0.06, -0.13, 0.25), (0.045, 0.022, 0.36), "olive", cuts=0, rnd=0.0, rot=(0, sx * 32, 0))   # X on the back
m.chunk((0, -0.12, 0.08), (0.34, 0.025, 0.04), "olive", cuts=0, rnd=0.0)                   # waist strap
m.chunk((0, -0.135, 0.08), (0.05, 0.012, 0.035), "black", cuts=0, rnd=0.0)
m.build()

w = Part("Gear_RigChest")            # GEAR 02 / FIELD HARNESS: three mag pouches, radio left, med pouch right
w.chunk((0, 0.16, 0.2), (0.36, 0.08, 0.18), "field", cuts=1, rnd=0.12, jit=0.03)
for i in range(3):
	x = -0.09 + i * 0.09
	w.chunk((x, 0.212, 0.165), (0.08, 0.05, 0.13), "field", cuts=0, rnd=0.12)
	w.chunk((x, 0.214, 0.255), (0.06, 0.035, 0.05), "black", cuts=0, rnd=0.05)            # mags out the top
	w.chunk((x, 0.24, 0.2), (0.025, 0.008, 0.06), "field", cuts=0, rnd=0.0)               # retention tab
w.chunk((0.06, 0.24, 0.13), (0.045, 0.006, 0.035), "patch", cuts=0, rnd=0.0, jit=0.0)     # blue patch
w.chunk((-0.19, 0.19, 0.17), (0.05, 0.06, 0.13), "field", cuts=0, rnd=0.1)               # radio pouch
w.chunk((-0.19, 0.19, 0.26), (0.035, 0.04, 0.07), "black", cuts=0, rnd=0.05)
w.cyl((-0.2, 0.19, 0.33), 0.006, 0.1, "black")                                            # antenna
w.chunk((0.19, 0.19, 0.17), (0.06, 0.07, 0.12), "field", cuts=0, rnd=0.12)               # med pouch
w.chunk((0.19, 0.228, 0.18), (0.035, 0.006, 0.012), "tan", cuts=0, rnd=0.0, jit=0.0)     # the cross
w.chunk((0.19, 0.228, 0.18), (0.012, 0.006, 0.035), "tan", cuts=0, rnd=0.0, jit=0.0)
w.chunk((0.225, 0.19, 0.26), (0.012, 0.03, 0.05), "red", cuts=0, rnd=0.1)
for sx in (-1, 1):
	w.chunk((sx * 0.12, 0.0, 0.41), (0.055, 0.32, 0.03), "field", cuts=0, rnd=0.0)
	w.chunk((sx * 0.12, -0.14, 0.24), (0.055, 0.03, 0.34), "field", cuts=0, rnd=0.0)
	w.chunk((sx * 0.12, 0.2, 0.3), (0.05, 0.02, 0.04), "black", cuts=0, rnd=0.0)            # buckles
	w.chunk((sx * 0.12, 0.2, 0.26), (0.05, 0.012, 0.04), "tan", cuts=0, rnd=0.0)           # stitched X tabs
w.chunk((0, 0.21, 0.31), (0.24, 0.016, 0.03), "field", cuts=0, rnd=0.0)                   # chest strap
w.chunk((0, 0.222, 0.31), (0.05, 0.012, 0.035), "black", cuts=0, rnd=0.0)
w.chunk((0, -0.15, 0.34), (0.26, 0.022, 0.04), "field", cuts=0, rnd=0.0)                  # back yoke
w.build()

bn = Part("Gear_Beanie")
bn.chunk((0, -0.005, 0.18), (0.21, 0.23, 0.13), "black", cuts=2, rnd=0.6, taper=(1.03, 0.75))
bn.chunk((0, -0.005, 0.12), (0.215, 0.235, 0.04), "black", cuts=1, rnd=0.5)
bn.build()

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "soldier.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "soldier.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("soldier written")
