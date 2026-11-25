# The depot kit (docs/CONNECTED_LOOP.md section 9, C1): furniture for the Dobrev depot in the garage's style.
# Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_depot_kit.py
# Writes art/src/depot_kit.blend and art/depot_kit.glb. Every piece is an empty named Kit_<name> with its meshes
# under it, built at the origin facing -Y (its front looks into the room), back against +Y (the wall), then the
# empties are laid out in a row so the .blend is easy to look at. Godot (v2/combat/level.gd) duplicates pieces
# into the rooms. Materials are <kind>_<colour> like the garage, so kind_look.gd gives them grain and wear.
# Lamps: *Hang_Bulb* (Godot puts a light in each).

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

random.seed(23)
S.PAL.update({
	"paint_locker": (0.3, 0.38, 0.4), "paint_cabinet": (0.42, 0.44, 0.38), "paint_fridge": (0.82, 0.8, 0.72),
	"paint_desk": (0.36, 0.38, 0.34), "paint_shelf": (0.3, 0.34, 0.36), "paint_board": (0.5, 0.33, 0.2),
	"paint_red": (0.62, 0.12, 0.1), "paint_bureau": (0.16, 0.2, 0.3), "paint_pallet": (0.55, 0.42, 0.26),
	"wood_crate": (0.62, 0.46, 0.28), "wood_table": (0.48, 0.34, 0.2), "wood_crate_d": (0.45, 0.32, 0.18),
	"fabric_seat": (0.22, 0.24, 0.3), "fabric_tarp": (0.3, 0.36, 0.26), "metal_steel": (0.55, 0.56, 0.58),
	"metal_dark": (0.12, 0.12, 0.13), "metal_tin": (0.5, 0.5, 0.46), "metal_copper": (0.62, 0.34, 0.18),
	"metal_mug": (0.88, 0.86, 0.8), "plain_black": (0.06, 0.06, 0.06), "plain_paper": (0.92, 0.88, 0.78),
	"plain_screen": (0.4, 0.62, 0.66), "plain_bulb": (1.0, 0.9, 0.7), "plain_led": (0.4, 1.0, 0.45),
	"plain_red": (0.72, 0.12, 0.1), "plain_glass": (0.2, 0.26, 0.3),
})

PIECES = []


def piece(name):
	bpy.ops.object.empty_add(location=(0, 0, 0))
	e = bpy.context.active_object
	e.name = "Kit_" + name
	S.ROOT = e
	PIECES.append(e)
	return e


def boxes_row(pre, x0, x1, z, depth, y=0.0):
	x = x0
	i = 0
	while x < x1 - 0.12:
		w = random.uniform(0.2, 0.36)
		h = random.uniform(0.14, 0.3)
		S.box(pre + "Box_%d" % i, (x + w / 2, y, z + h / 2), (w - 0.02, depth * random.uniform(0.7, 0.95), h),
			random.choice(["wood_crate", "wood_crate_d", "paint_cabinet", "metal_tin", "wood_crate"]), rot=(0, 0, random.uniform(-4, 4)), bevel=0.006)
		x += w + 0.02
		i += 1


# ------------------------------------------------------------------ pieces

def crate():
	piece("crate")
	s = 0.6
	S.box("Crate_Body", (0, 0, s / 2), (s, s, s), "wood_crate", bevel=0.012)
	for z in (0.06, s - 0.06):
		S.box("Crate_Band_%d" % int(z * 100), (0, 0, z), (s + 0.012, s + 0.012, 0.06), "wood_crate_d", bevel=0.004)
	S.text("Crate_Text", "DOBREV", (0, -s / 2 - 0.007, s * 0.55), 0.08, "plain_black", rot=(90, 0, 0))


def crate_stack():
	piece("crate_stack")
	S.box("Pallet", (0, 0, 0.07), (1.2, 1.0, 0.14), "paint_pallet", bevel=0.006)
	for k, (x, y, z, s) in enumerate(((-0.3, 0.0, 0.14, 0.58), (0.3, 0.05, 0.14, 0.58), (-0.05, 0.0, 0.72, 0.5))):
		S.box("Stack_Crate_%d" % k, (x, y, z + s / 2), (s, s * 0.9, s), "wood_crate" if k % 2 == 0 else "wood_crate_d", rot=(0, 0, random.uniform(-6, 6)), bevel=0.01)
	S.box("Stack_Tarp", (0.3, 0.05, 0.725), (0.62, 0.58, 0.02), "fabric_tarp", bevel=0.01)


def shelf():
	piece("shelf")
	w, d, h = 1.4, 0.5, 2.0
	for sx in (-1, 1):
		for sy in (-1, 1):
			S.box("Shelf_Post_%d_%d" % (sx, sy), (sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), h / 2), (0.04, 0.04, h), "paint_shelf", bevel=0.004)
	for i in range(4):
		z = 0.12 + i * (h - 0.25) / 3
		S.box("Shelf_Plank_%d" % i, (0, 0, z), (w, d, 0.03), "paint_shelf", bevel=0.004)
		boxes_row("Shelf_L%d_" % i, -w / 2 + 0.04, w / 2 - 0.04, z + 0.015, d * 0.85)


def desk():
	piece("desk")
	w, d, top = 1.3, 0.7, 0.76
	S.box("Desk_Top", (0, 0, top - 0.02), (w, d, 0.04), "paint_desk", bevel=0.006)
	S.box("Desk_Drawers", (w / 2 - 0.25, 0, (top - 0.04) / 2), (0.45, d - 0.06, top - 0.04), "paint_cabinet", bevel=0.008)
	for k in range(3):
		S.box("Desk_Drawer_%d" % k, (w / 2 - 0.25, -d / 2 + 0.02, 0.14 + k * 0.22), (0.4, 0.02, 0.18), "paint_cabinet", bevel=0.004)
		S.box("Desk_Pull_%d" % k, (w / 2 - 0.25, -d / 2 + 0.005, 0.18 + k * 0.22), (0.1, 0.015, 0.02), "metal_steel", bevel=0.002)
	S.box("Desk_LegL", (-w / 2 + 0.04, 0, (top - 0.04) / 2), (0.05, d - 0.06, top - 0.04), "paint_desk", bevel=0.004)
	S.box("Desk_Paper", (-0.2, -0.05, top + 0.005), (0.24, 0.32, 0.01), "plain_paper", rot=(0, 0, 8), bevel=0)
	S.cyl("Desk_Mug", (0.35, 0.15, top + 0.05), 0.04, 0.1, "metal_mug", verts=10)


def desk_pc():
	"""A desk with a beige monitor and a keyboard (a PC your people can exploit)."""
	piece("desk_pc")
	w, d, top = 1.3, 0.7, 0.76
	S.box("DeskPC_Top", (0, 0, top - 0.02), (w, d, 0.04), "paint_desk", bevel=0.006)
	for sx in (-1, 1):
		S.box("DeskPC_Leg_%d" % sx, (sx * (w / 2 - 0.04), 0, (top - 0.04) / 2), (0.05, d - 0.06, top - 0.04), "paint_desk", bevel=0.004)
	S.box("DeskPC_Monitor", (0, 0.12, top + 0.2), (0.42, 0.38, 0.36), "paint_fridge", bevel=0.03)
	S.box("DeskPC_Screen", (0, -0.075, top + 0.22), (0.32, 0.01, 0.24), "plain_screen", bevel=0, emission=1.4)
	S.box("DeskPC_Keys", (0, -0.2, top + 0.015), (0.42, 0.14, 0.025), "paint_fridge", rot=(4, 0, 0), bevel=0.006)
	S.box("DeskPC_Tower", (0.48, 0.05, top + 0.2), (0.18, 0.4, 0.38), "paint_fridge", bevel=0.01)
	S.ball("DeskPC_Led", (0.48, -0.155, top + 0.08), 0.008, "plain_led", emission=4.0)


def chair():
	piece("chair")
	S.box("Chair_Seat", (0, 0, 0.46), (0.44, 0.42, 0.06), "fabric_seat", bevel=0.012)
	S.box("Chair_Back", (0, 0.2, 0.75), (0.42, 0.05, 0.42), "fabric_seat", rot=(-6, 0, 0), bevel=0.012)
	S.cyl("Chair_Post", (0, 0, 0.25), 0.025, 0.4, "metal_dark", verts=8)
	for k in range(5):
		a = k / 5 * math.tau
		S.box("Chair_Foot_%d" % k, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.04), (0.3, 0.04, 0.03), "metal_dark", rot=(0, 0, math.degrees(a)), bevel=0)


def lockers():
	piece("lockers")
	for k in range(3):
		x = -0.5 + k * 0.5
		S.box("Locker_%d" % k, (x, 0, 0.95), (0.48, 0.5, 1.9), "paint_locker", bevel=0.008)
		for j in range(4):
			S.box("Locker_Vent_%d_%d" % (k, j), (x, -0.252, 1.65 - j * 0.05), (0.26, 0.006, 0.015), "metal_dark", bevel=0)
		S.box("Locker_Handle_%d" % k, (x + 0.15, -0.258, 1.0), (0.02, 0.02, 0.12), "metal_steel", bevel=0.002)


def cabinet():
	piece("cabinet")
	S.box("Cab_Body", (0, 0, 0.66), (0.48, 0.62, 1.32), "paint_cabinet", bevel=0.01)
	for k in range(4):
		S.box("Cab_Drawer_%d" % k, (0, -0.312, 0.18 + k * 0.31), (0.42, 0.006, 0.27), "paint_cabinet", bevel=0.004)
		S.box("Cab_Pull_%d" % k, (0, -0.322, 0.26 + k * 0.31), (0.12, 0.015, 0.02), "metal_steel", bevel=0.002)
		S.box("Cab_Label_%d" % k, (0, -0.318, 0.21 + k * 0.31), (0.08, 0.004, 0.04), "plain_paper", bevel=0)


def fridge():
	piece("fridge")
	S.box("Fridge_Body", (0, 0, 0.85), (0.62, 0.62, 1.7), "paint_fridge", bevel=0.03)
	S.box("Fridge_Split", (0, -0.312, 1.15), (0.6, 0.006, 0.015), "metal_dark", bevel=0)
	S.box("Fridge_Handle", (0.24, -0.33, 1.35), (0.025, 0.03, 0.3), "metal_steel", bevel=0.004)
	S.box("Fridge_Note", (-0.1, -0.313, 1.45), (0.12, 0.003, 0.15), "plain_paper", rot=(0, 6, 0), bevel=0)


def break_table():
	piece("break_table")
	S.box("BT_Top", (0, 0, 0.74), (1.2, 0.8, 0.04), "wood_table", bevel=0.008)
	for sx in (-1, 1):
		for sy in (-1, 1):
			S.box("BT_Leg_%d_%d" % (sx, sy), (sx * 0.54, sy * 0.34, 0.36), (0.04, 0.04, 0.72), "metal_dark", bevel=0.003)
	for sy in (-1, 1):
		S.box("BT_Stool_%d" % sy, (0.2 * sy, sy * 0.62, 0.45), (0.36, 0.36, 0.04), "wood_table", bevel=0.006)
		for lx in (-1, 1):
			S.box("BT_StoolLeg_%d_%d" % (sy, lx), (0.2 * sy + lx * 0.14, sy * 0.62, 0.22), (0.03, 0.03, 0.44), "metal_dark", bevel=0)
	S.cyl("BT_Mug_A", (-0.3, 0.1, 0.81), 0.04, 0.1, "metal_mug", verts=10)
	S.cyl("BT_Mug_B", (0.25, -0.15, 0.81), 0.04, 0.1, "paint_red", verts=10)
	S.box("BT_Cards", (0.0, 0.05, 0.765), (0.1, 0.14, 0.01), "plain_paper", rot=(0, 0, 20), bevel=0)
	S.box("BT_Ashtray", (0.4, 0.2, 0.77), (0.12, 0.12, 0.02), "plain_glass", bevel=0.01)


def notice_board():
	piece("notice_board")
	S.box("NB_Frame", (0, 0.02, 1.5), (1.0, 0.03, 0.7), "wood_crate_d", bevel=0.006)
	S.box("NB_Cork", (0, 0.0, 1.5), (0.92, 0.01, 0.62), "paint_board", bevel=0)
	for k in range(6):
		S.box("NB_Paper_%d" % k, (-0.32 + (k % 3) * 0.3, -0.008, 1.66 - (k // 3) * 0.3), (0.2, 0.004, 0.24), "plain_paper",
			rot=(0, random.uniform(-6, 6), 0), bevel=0)
	S.box("NB_Bureau", (0.0, -0.01, 1.72), (0.18, 0.004, 0.12), "paint_bureau", bevel=0)


def extinguisher():
	piece("extinguisher")
	S.cyl("Ext_Body", (0, -0.1, 0.55), 0.08, 0.5, "plain_red", verts=12)
	S.cyl("Ext_Top", (0, -0.1, 0.84), 0.03, 0.08, "metal_dark", verts=8)
	S.box("Ext_Bracket", (0, -0.02, 0.6), (0.12, 0.03, 0.3), "metal_dark", bevel=0.003)
	S.box("Ext_Sign", (0, -0.005, 1.05), (0.18, 0.006, 0.18), "plain_red", bevel=0)


def pipes():
	"""Pipes running along a wall near the ceiling, 3 m long, with a valve."""
	piece("pipes")
	S.seg("Pipe_A", (-1.5, -0.1, 2.5), (1.5, -0.1, 2.5), 0.06, "metal_steel")
	S.seg("Pipe_B", (-1.5, -0.08, 2.32), (1.5, -0.08, 2.32), 0.035, "metal_copper")
	S.cyl("Pipe_Valve", (0.4, -0.2, 2.5), 0.07, 0.02, "plain_red", rot=(90, 0, 0), verts=10)


def bin_():
	piece("bin")
	S.cyl("Bin_Body", (0, 0, 0.22), 0.17, 0.44, "metal_tin", verts=12, r2=0.15)
	S.box("Bin_Paper", (0.02, 0.0, 0.46), (0.14, 0.12, 0.06), "plain_paper", rot=(10, 20, 0), bevel=0.02)


def lamp():
	"""A shaded hanging lamp on a cord, 0.7 m drop from a 2.8 m ceiling."""
	piece("lamp")
	S.seg("Lamp_Cord", (0, 0, 2.8), (0, 0, 2.15), 0.01, "plain_black", verts=4)
	bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.24, radius2=0.05, depth=0.16, location=(0, 0, 2.09), end_fill_type="NOTHING")
	o = bpy.context.active_object
	o.name = "Lamp_Shade"
	sol = o.modifiers.new("thick", "SOLIDIFY")
	sol.thickness = 0.008
	S._finish(o, "paint_shelf", (0, 0, 0), 0.0)
	S.ball("Lamp_Hang_Bulb", (0, 0, 2.03), 0.045, "plain_bulb", sub=2, emission=7.0)


# ------------------------------------------------------------------ M4 V3: pieces for generated buildings
# (bar, shop, office, clinic, gun shop, police post)

def counter():
	"""A long serving counter (bar, shop, front desk), 2.4 x 0.62 x 1.05, a till and a few things on top."""
	piece("counter")
	w, d, top = 2.4, 0.62, 1.05
	S.box("Counter_Body", (0, 0.03, top / 2 - 0.02), (w, d - 0.06, top - 0.04), "wood_table", bevel=0.01)
	S.box("Counter_Kick", (0, -0.25, 0.06), (w - 0.04, 0.04, 0.12), "metal_dark", bevel=0)
	S.box("Counter_Top", (0, 0, top - 0.02), (w + 0.06, d + 0.04, 0.05), "wood_crate_d", bevel=0.008)
	for k in range(4):
		S.box("Counter_Panel_%d" % k, (-0.9 + k * 0.6, -0.27, top / 2), (0.5, 0.01, top - 0.3), "wood_crate", bevel=0)
	S.box("Counter_Till", (0.7, 0.05, top + 0.1), (0.32, 0.3, 0.16), "metal_dark", rot=(0, 0, 8), bevel=0.01)
	S.box("Counter_TillTop", (0.7, -0.02, top + 0.2), (0.26, 0.12, 0.04), "plain_screen", bevel=0, emission=0.6)
	for k in range(3):
		S.cyl("Counter_Glass_%d" % k, (-0.6 + k * 0.14, -0.05, top + 0.06), 0.035, 0.12, "plain_glass", verts=8)
	S.box("Counter_Paper", (0.1, 0.0, top + 0.005), (0.22, 0.3, 0.005), "plain_paper", rot=(0, 0, -12), bevel=0)


def bottle_shelf():
	"""A wall of shelves with bottles behind a bar, 2.0 wide, 0.3 deep."""
	piece("bottle_shelf")
	w = 2.0
	S.box("BShelf_Back", (0, 0.13, 1.25), (w, 0.03, 1.5), "wood_crate_d", bevel=0)
	for k in range(3):
		z = 0.75 + k * 0.45
		S.box("BShelf_Board_%d" % k, (0, 0.0, z), (w, 0.28, 0.03), "wood_table", bevel=0.004)
		x = -w / 2 + 0.1
		i = 0
		while x < w / 2 - 0.1:
			col = random.choice(["plain_glass", "paint_red", "paint_fridge", "metal_copper", "plain_glass", "wood_crate"])
			h = random.uniform(0.2, 0.32)
			S.cyl("BShelf_Bottle_%d_%d" % (k, i), (x, random.uniform(-0.05, 0.05), z + 0.015 + h / 2), 0.04, h, col, verts=8)
			x += random.uniform(0.1, 0.17)
			i += 1


def cafe_table():
	"""A small square table with two chairs pulled up (bar, waiting room), about 1.6 x 0.7."""
	piece("cafe_table")
	S.box("CT_Top", (0, 0, 0.74), (0.7, 0.7, 0.04), "wood_table", bevel=0.008)
	S.cyl("CT_Post", (0, 0, 0.37), 0.04, 0.72, "metal_dark", verts=8)
	S.cyl("CT_Foot", (0, 0, 0.02), 0.26, 0.04, "metal_dark", verts=12)
	for sx in (-1, 1):
		S.box("CT_Seat_%d" % sx, (sx * 0.58, 0, 0.45), (0.4, 0.4, 0.04), "wood_table", bevel=0.006)
		S.box("CT_Back_%d" % sx, (sx * 0.78, 0, 0.72), (0.04, 0.38, 0.5), "wood_table", rot=(0, sx * -6, 0), bevel=0.006)
		for lx in (-1, 1):
			for ly in (-1, 1):
				S.box("CT_Leg_%d_%d_%d" % (sx, lx, ly), (sx * 0.58 + lx * 0.17, ly * 0.17, 0.22), (0.03, 0.03, 0.44), "metal_dark", bevel=0)
	S.cyl("CT_Glass", (0.12, 0.1, 0.81), 0.035, 0.1, "plain_glass", verts=8)
	S.box("CT_Ashtray", (-0.15, -0.12, 0.77), (0.1, 0.1, 0.02), "metal_tin", bevel=0.01)


def bed():
	"""A steel-frame clinic bed against the wall (head at the wall), 0.9 x 2.0."""
	piece("bed")
	S.box("Bed_Mattress", (0, 0.0, 0.56), (0.86, 1.9, 0.14), "paint_fridge", bevel=0.03)
	S.box("Bed_Sheet", (0, -0.25, 0.64), (0.88, 1.2, 0.04), "fabric_tarp", bevel=0.02)
	S.box("Bed_Pillow", (0, 0.75, 0.67), (0.6, 0.3, 0.1), "plain_paper", bevel=0.04)
	S.box("Bed_Frame", (0, 0.0, 0.45), (0.9, 1.96, 0.06), "metal_steel", bevel=0.004)
	for y in (0.93, -0.95):
		S.box("Bed_End_%d" % int(y * 10 + 20), (0, y, 0.55), (0.9, 0.04, 0.5), "metal_steel", bevel=0.004)
	for sx in (-1, 1):
		for y in (0.9, -0.93):
			S.cyl("Bed_Leg_%d_%d" % (sx, int(y * 10 + 20)), (sx * 0.42, y, 0.22), 0.02, 0.44, "metal_steel", verts=6)
	S.box("Bed_Chart", (0.0, -0.98, 0.7), (0.24, 0.01, 0.3), "plain_paper", bevel=0)


def gun_rack():
	"""A wall rack of long guns with a chain through the guards, 1.6 wide."""
	piece("gun_rack")
	S.box("GR_Back", (0, 0.1, 1.2), (1.6, 0.04, 1.6), "wood_crate_d", bevel=0.004)
	S.box("GR_Foot", (0, -0.05, 0.25), (1.6, 0.3, 0.06), "wood_table", bevel=0.004)
	S.box("GR_Top", (0, 0.0, 1.55), (1.6, 0.18, 0.06), "wood_table", bevel=0.004)
	for k in range(6):
		x = -0.62 + k * 0.25
		S.box("GR_Stock_%d" % k, (x, -0.05, 0.42), (0.06, 0.16, 0.34), "wood_table", rot=(6, 0, 0), bevel=0.008)
		S.box("GR_Body_%d" % k, (x, -0.04, 0.82), (0.05, 0.08, 0.5), "metal_dark", bevel=0.004)
		S.cyl("GR_Barrel_%d" % k, (x, -0.04, 1.3), 0.012, 0.5, "metal_dark", verts=6)
		S.box("GR_Mag_%d" % k, (x, -0.12, 0.9), (0.04, 0.08, 0.16), "metal_dark", rot=(12, 0, 0), bevel=0.003)
	S.seg("GR_Chain", (-0.75, -0.12, 0.95), (0.75, -0.12, 0.95), 0.012, "metal_steel")
	S.box("GR_Lock", (0.78, -0.12, 0.92), (0.06, 0.04, 0.08), "metal_copper", bevel=0.004)


def bench():
	"""A waiting-room bench of plastic seats on a rail, 1.8 wide."""
	piece("bench")
	S.box("Bench_Rail", (0, 0.0, 0.3), (1.8, 0.06, 0.06), "metal_dark", bevel=0.004)
	for sx in (-1, 1):
		S.box("Bench_Leg_%d" % sx, (sx * 0.8, 0.0, 0.15), (0.06, 0.4, 0.3), "metal_dark", bevel=0.004)
	for k in range(4):
		x = -0.66 + k * 0.44
		S.box("Bench_Seat_%d" % k, (x, -0.02, 0.44), (0.4, 0.4, 0.05), "paint_locker", bevel=0.02)
		S.box("Bench_Back_%d" % k, (x, 0.18, 0.7), (0.4, 0.05, 0.42), "paint_locker", rot=(-8, 0, 0), bevel=0.02)


def pallet():
	"""A loaded pallet: boxes under stretch wrap, 1.2 x 1.0."""
	piece("pallet")
	for k in range(3):
		S.box("Pal_Board_%d" % k, (0, -0.45 + k * 0.45, 0.06), (1.2, 0.12, 0.12), "paint_pallet", bevel=0.004)
	S.box("Pal_Deck", (0, 0, 0.135), (1.2, 1.0, 0.03), "paint_pallet", bevel=0.004)
	S.box("Pal_Load", (0, 0, 0.62), (1.1, 0.92, 0.94), "wood_crate", bevel=0.01)
	S.box("Pal_Wrap", (0, 0, 0.62), (1.13, 0.95, 0.9), "plain_glass", bevel=0.02)
	S.box("Pal_Label", (0.2, -0.48, 0.8), (0.2, 0.005, 0.14), "plain_paper", bevel=0)


for fn in (crate, crate_stack, shelf, desk, desk_pc, chair, lockers, cabinet, fridge, break_table, notice_board,
		extinguisher, pipes, bin_, lamp, counter, bottle_shelf, cafe_table, bed, gun_rack, bench, pallet):
	fn()
S.ROOT = None
for i, e in enumerate(PIECES):
	e.location = (i * 2.0, 0, 0)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "depot_kit.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "depot_kit.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("DEPOT KIT OK", len(PIECES), "pieces")
