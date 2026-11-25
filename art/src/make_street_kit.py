# The street kit (docs/M4_VARIETY.md V2): cover pieces for outdoor fights in the garage's style.
# Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_street_kit.py
# Writes art/src/street_kit.blend and art/street_kit.glb. Every piece is an empty Kit_<kind> (the kinds in
# v2/combat/cover.gd) with its meshes under it, centred at the origin, bottom at z = 0, length along X, depth
# along Y. Godot scales a piece to the size the level asks for. Materials are <kind>_<colour> (kind_look.gd).

import bpy
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import make_sewing as S    # noqa: E402  (helpers and materials)

random.seed(41)
S.PAL.update({
	"fabric_sack": (0.52, 0.47, 0.33), "fabric_sack_d": (0.43, 0.38, 0.26), "fabric_sack_l": (0.58, 0.53, 0.38),
	"paint_concrete": (0.6, 0.58, 0.53), "paint_stripe": (0.82, 0.62, 0.14), "paint_stripe_w": (0.85, 0.84, 0.78),
	"paint_car": (0.33, 0.4, 0.36), "paint_car_d": (0.24, 0.3, 0.27), "paint_booth": (0.36, 0.4, 0.33),
	"paint_booth_d": (0.22, 0.25, 0.2), "paint_barrel": (0.26, 0.32, 0.42), "paint_barrel_r": (0.55, 0.2, 0.12),
	"paint_brick": (0.55, 0.36, 0.27), "paint_brick_d": (0.45, 0.29, 0.22), "paint_cap": (0.5, 0.48, 0.44),
	"wood_crate": (0.6, 0.45, 0.28), "wood_crate_d": (0.44, 0.31, 0.18),
	"metal_dark": (0.1, 0.1, 0.11), "metal_steel": (0.55, 0.56, 0.58), "plain_black": (0.05, 0.05, 0.05),
	"plain_glass": (0.18, 0.24, 0.28), "plain_lamp": (0.95, 0.9, 0.7), "plain_tail": (0.7, 0.1, 0.08),
	"rubber_tyre": (0.07, 0.07, 0.07), "plain_paper": (0.9, 0.86, 0.75),
})

PIECES = []


def piece(name):
	bpy.ops.object.empty_add(location=(0, 0, 0))
	e = bpy.context.active_object
	e.name = "Kit_" + name
	S.ROOT = e
	PIECES.append(e)
	return e


def sandbags():
	"""Three staggered courses of lumpy bags, 1.8 x 0.65 x 0.95."""
	piece("sandbags")
	L, D, H = 1.8, 0.65, 0.95
	rows = 4
	for r in range(rows):
		z = r * (H / rows)
		n = 4 if r % 2 == 0 else 3
		w = L / 4.0
		x0 = -L / 2 + w / 2 + (0 if r % 2 == 0 else w / 2)
		for k in range(n):
			x = x0 + k * w
			S.ball("Bag_%d_%d" % (r, k), (x + random.uniform(-0.02, 0.02), random.uniform(-0.03, 0.03), z + H / rows * 0.5),
				1.0, random.choice(["fabric_sack", "fabric_sack_d", "fabric_sack_l"]), sub=2,
				squash=(w * 0.56, D * (0.5 - 0.04 * r), H / rows * 0.62), lumpy=0.02)


def barrier():
	"""A concrete jersey barrier with a yellow-and-white band, 2.0 x 0.6 x 0.85."""
	piece("barrier")
	S.box("Barrier_Foot", (0, 0, 0.14), (2.0, 0.6, 0.28), "paint_concrete", bevel=0.03)
	S.box("Barrier_Mid", (0, 0, 0.4), (2.0, 0.42, 0.26), "paint_concrete", bevel=0.03)
	S.box("Barrier_Top", (0, 0, 0.7), (2.0, 0.26, 0.3), "paint_concrete", bevel=0.03)
	for i in range(6):
		S.box("Barrier_Band_%d" % i, (-0.833 + i * 0.333, -0.132, 0.72), (0.33, 0.01, 0.12), "paint_stripe" if i % 2 == 0 else "paint_stripe_w", bevel=0.0)
	S.box("Barrier_Lift", (0, 0, 0.86), (0.3, 0.04, 0.03), "metal_steel", bevel=0.005)


def car():
	"""A boxy old saloon, 4.2 x 1.8 x 1.45 (front at -X)."""
	piece("car")
	S.box("Car_Body", (0, 0, 0.6), (4.2, 1.76, 0.62), "paint_car", bevel=0.06)
	S.box("Car_Sill", (0, 0, 0.3), (3.9, 1.8, 0.14), "paint_car_d", bevel=0.03)
	S.box("Car_Cabin", (0.15, 0, 1.15), (2.1, 1.56, 0.56), "paint_car", bevel=0.08)
	S.box("Car_Windscreen", (-0.92, 0, 1.15), (0.06, 1.44, 0.46), "plain_glass", rot=(0, -28, 0), bevel=0.01)
	S.box("Car_Rear_Glass", (1.22, 0, 1.15), (0.06, 1.44, 0.44), "plain_glass", rot=(0, 30, 0), bevel=0.01)
	for s in (-1, 1):
		S.box("Car_Side_Glass_%d" % s, (0.15, s * 0.79, 1.18), (1.8, 0.02, 0.38), "plain_glass", bevel=0.0)
		for x in (-1.35, 1.35):
			S.cyl("Car_Tyre_%d_%d" % (s, int(x * 10)), (x, s * 0.78, 0.32), 0.32, 0.22, "rubber_tyre", rot=(90, 0, 0), verts=14)
			S.cyl("Car_Hub_%d_%d" % (s, int(x * 10)), (x, s * 0.9, 0.32), 0.14, 0.02, "metal_steel", rot=(90, 0, 0), verts=10)
		S.box("Car_Lamp_%d" % s, (-2.1, s * 0.6, 0.72), (0.03, 0.26, 0.14), "plain_lamp", bevel=0.01)
		S.box("Car_Tail_%d" % s, (2.1, s * 0.62, 0.72), (0.03, 0.22, 0.12), "plain_tail", bevel=0.01)
	S.box("Car_Bumper_F", (-2.14, 0, 0.42), (0.1, 1.7, 0.12), "metal_steel", bevel=0.02)
	S.box("Car_Bumper_R", (2.14, 0, 0.42), (0.1, 1.7, 0.12), "metal_steel", bevel=0.02)
	S.box("Car_Grille", (-2.11, 0, 0.62), (0.03, 0.8, 0.2), "metal_dark", bevel=0.01)
	S.box("Car_Plate", (2.12, 0, 0.5), (0.02, 0.4, 0.1), "plain_paper", bevel=0.0)


def booth():
	"""A guard booth with a window, an overhanging roof and a door, 2.0 x 2.0 x 2.4."""
	piece("booth")
	S.box("Booth_Base", (0, 0, 0.1), (2.0, 2.0, 0.2), "paint_concrete", bevel=0.02)
	S.box("Booth_Low", (0, 0, 0.6), (1.9, 1.9, 0.8), "paint_booth", bevel=0.02)
	for s in (-1, 1):
		S.box("Booth_Post_%d" % s, (s * 0.9, -0.9, 1.6), (0.1, 0.1, 1.2), "paint_booth_d", bevel=0.01)
		S.box("Booth_PostB_%d" % s, (s * 0.9, 0.9, 1.6), (0.1, 0.1, 1.2), "paint_booth_d", bevel=0.01)
	S.box("Booth_Glass_F", (0, -0.94, 1.55), (1.7, 0.02, 0.9), "plain_glass", bevel=0.0)
	S.box("Booth_Glass_L", (-0.94, 0, 1.55), (0.02, 1.7, 0.9), "plain_glass", bevel=0.0)
	S.box("Booth_Wall_R", (0.92, 0, 1.6), (0.06, 1.8, 1.2), "paint_booth", bevel=0.01)
	S.box("Booth_Wall_B", (0, 0.92, 1.6), (1.8, 0.06, 1.2), "paint_booth", bevel=0.01)
	S.box("Booth_Roof", (0, 0, 2.3), (2.3, 2.3, 0.14), "paint_booth_d", bevel=0.02)
	S.box("Booth_Sign", (0, -1.0, 2.05), (1.0, 0.03, 0.22), "paint_stripe_w", bevel=0.0)
	S.text("Booth_Sign_Text", "CONTROL", (0, -1.02, 2.0), 0.13, "plain_black", rot=(90, 0, 0))
	S.box("Booth_Shelf", (0, -0.85, 1.05), (1.7, 0.25, 0.04), "paint_booth_d", bevel=0.005)


def barrel():
	"""An oil drum, 0.62 across, 1.0 tall, a red band."""
	piece("barrel")
	S.cyl("Barrel_Body", (0, 0, 0.5), 0.31, 1.0, "paint_barrel", verts=16)
	for z in (0.33, 0.66):
		S.cyl("Barrel_Rib_%d" % int(z * 100), (0, 0, z), 0.316, 0.03, "paint_barrel_r", verts=16)
	S.cyl("Barrel_Lid", (0, 0, 1.0), 0.29, 0.02, "metal_dark", verts=16)


def low_wall():
	"""A low brick wall with a concrete cap, 3.0 x 0.3 x 1.0 (Godot stretches its length)."""
	piece("low_wall")
	S.box("Wall_Core", (0, 0, 0.47), (3.0, 0.28, 0.94), "paint_brick", bevel=0.01)
	for r in range(6):
		for k in range(7):
			x = -1.5 + 0.2 + k * 0.43 + (0.21 if r % 2 else 0.0)
			if x > 1.42:
				continue
			S.box("Wall_Brick_%d_%d" % (r, k), (x, -0.142, 0.08 + r * 0.155), (0.4, 0.01, 0.13), random.choice(["paint_brick", "paint_brick_d"]), bevel=0.0)
	S.box("Wall_Cap", (0, 0, 0.97), (3.06, 0.34, 0.07), "paint_cap", bevel=0.01)


def crate():
	"""A big wooden crate, 0.9 a side."""
	piece("crate")
	s = 0.9
	S.box("Crate_Body", (0, 0, s / 2), (s, s, s), "wood_crate", bevel=0.015)
	for z in (0.08, s - 0.08):
		S.box("Crate_Band_%d" % int(z * 100), (0, 0, z), (s + 0.014, s + 0.014, 0.08), "wood_crate_d", bevel=0.005)
	S.box("Crate_Slat", (0, -s / 2 - 0.006, s / 2), (0.08, 0.012, s * 0.8), "wood_crate_d", rot=(0, 45, 0), bevel=0.0)


for fn in (sandbags, barrier, car, booth, barrel, low_wall, crate):
	fn()
S.ROOT = None
for i, e in enumerate(PIECES):
	e.location = (i * 5.0, 0, 0)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "street_kit.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "street_kit.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("STREET KIT OK", len(PIECES), "pieces")
