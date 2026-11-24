# The garage do-over (docs/CONNECTED_LOOP.md section 7; concept docs/refs/Garage/01_overview_labeled.png).
# A wide double garage, ~8 x 10 m, walked around in first person. Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_garage_v3.py
# Writes art/src/garage_v3.blend and art/garage_v3.glb.
# Blender coords: X right, Y toward the back wall (the roller door), Z up; the room spans x -4..4, y -5..5.
# Every station is an empty named St_<station id> (data/v2/stations.json) with its pieces under it, built facing
# its own -Y (toward the room) and turned to its wall. The sewing table comes from make_sewing.py (all three
# stages under St_bench_sew: Godot shows the one you've earned). Other benches: their STARTER from the GPT
# stage sheets (docs/refs/benches/*_stages.png); their upgrades come with their own bench passes.
# Materials are <kind>_<colour> (wood_, fabric_, metal_, paint_, plain_): Godot adds grain/weave/wear (kind_look.gd).
# Lamp bulbs are named *Lamp_Bulb* / *Hang_Bulb*: Godot puts a light in each.

import bpy
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import make_sewing as S    # noqa: E402  (the helpers, materials and the sewing table itself)

random.seed(31)
S.PAL.update({
	"paint_floor": (0.3, 0.27, 0.24), "paint_wall": (0.17, 0.24, 0.25), "paint_wall_low": (0.13, 0.18, 0.19),
	"paint_door": (0.36, 0.38, 0.36), "paint_hazard": (0.85, 0.66, 0.15), "paint_steel_frame": (0.36, 0.38, 0.36),
	"wood_beam": (0.2, 0.13, 0.08), "wood_ceiling": (0.14, 0.1, 0.07), "wood_door": (0.45, 0.3, 0.18), "wood_board": (0.36, 0.24, 0.14),
	"fabric_rug": (0.36, 0.22, 0.16), "fabric_rug_b": (0.5, 0.32, 0.2), "fabric_towel": (0.84, 0.8, 0.7),
	"fabric_band": (0.42, 0.5, 0.36), "fabric_felt": (0.3, 0.3, 0.3), "fabric_pad": (0.6, 0.16, 0.14),
	"fabric_jacket_a": (0.36, 0.38, 0.2), "fabric_jacket_b": (0.26, 0.3, 0.42), "fabric_jacket_c": (0.5, 0.36, 0.2),
	"fabric_jacket_d": (0.42, 0.18, 0.16), "fabric_cork": (0.52, 0.34, 0.2), "fabric_leaf": (0.36, 0.44, 0.16),
	"fabric_leaf_d": (0.26, 0.34, 0.12),
	"metal_mesh": (0.34, 0.34, 0.32), "metal_tin": (0.5, 0.5, 0.46), "metal_tin_g": (0.4, 0.46, 0.3),
	"metal_mug": (0.88, 0.86, 0.8), "metal_crt": (0.72, 0.68, 0.58), "metal_radio": (0.86, 0.8, 0.66),
	"metal_med": (0.62, 0.62, 0.58), "metal_gun": (0.2, 0.2, 0.22),
	"plain_glass": (0.18, 0.22, 0.3), "plain_crt_glow": (0.5, 0.62, 0.68), "plain_led": (0.4, 1.0, 0.45),
	"plain_house": (1.0, 0.72, 0.42), "plain_window": (0.12, 0.18, 0.3), "plain_bottle": (0.36, 0.18, 0.08),
	"plain_talar": (0.72, 0.14, 0.1), "plain_pot": (0.6, 0.32, 0.2), "plain_black": (0.06, 0.06, 0.06),
	"plain_red": (0.72, 0.12, 0.1), "plain_paper": (0.92, 0.88, 0.78), "paint_stain": (0.17, 0.15, 0.13),
})

W, D, H = 8.0, 10.0, 3.0   # room size


def room_root():
	bpy.ops.object.empty_add(location=(0, 0, 0))
	r = bpy.context.active_object
	r.name = "Room"
	S.ROOT = r
	return r


def station(sid, loc, rot_z):
	"""An empty for one station; its pieces are built in its own frame (front = -Y) under it."""
	bpy.ops.object.empty_add(location=(loc[0], loc[1], 0))
	e = bpy.context.active_object
	e.name = "St_" + sid
	e.rotation_euler = (0, 0, math.radians(rot_z))
	S.ROOT = e
	return e


def hang_lamp(pre, x, y, z_top=H, drop=0.9, shade=0.22):
	"""A lamp hanging from the ceiling on a cord: cone shade, glowing bulb."""
	S.seg(pre + "Cord", (x, y, z_top), (x, y, z_top - drop), 0.012, "plain_black", verts=4)
	bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=shade, radius2=0.05, depth=0.16, location=(x, y, z_top - drop - 0.06), end_fill_type="NOTHING")
	o = bpy.context.active_object
	o.name = pre + "Shade"
	sol = o.modifiers.new("thick", "SOLIDIFY")
	sol.thickness = 0.008
	S._finish(o, "metal_copper", (0, 0, 0), 0.0)
	S.ball(pre + "Hang_Bulb", (x, y, z_top - drop - 0.11), 0.045, "plain_bulb", sub=2, emission=7.0)


def plant(pre, x, y, z, s=1.0):
	S.cyl(pre + "Pot", (x, y, z + 0.08 * s), 0.09 * s, 0.16 * s, "plain_pot", verts=10)
	for k in range(7):
		a = k / 7.0 * math.tau
		S.ball(pre + "Leaf_%d" % k, (x + math.cos(a) * 0.1 * s, y + math.sin(a) * 0.1 * s, z + (0.22 + random.uniform(0, 0.12)) * s), 0.09 * s,
			"fabric_leaf" if k % 2 else "fabric_leaf_d", sub=1, squash=(1, 1, 0.6), lumpy=0.25)
	for k in range(4):   # trailing vines
		a = k / 4.0 * math.tau + 0.4
		S.ball(pre + "Vine_%d" % k, (x + math.cos(a) * 0.16 * s, y + math.sin(a) * 0.16 * s, z + 0.02 * s - k * 0.04), 0.06 * s, "fabric_leaf", sub=1, squash=(1, 1, 0.7), lumpy=0.3)


def boxes_on(pre, x0, x1, y, z, depth=0.32):
	"""A row of cardboard boxes and tins along a shelf."""
	x = x0
	i = 0
	while x < x1 - 0.12:
		w = random.uniform(0.18, 0.32)
		h = random.uniform(0.12, 0.24)
		col = random.choice(["wood_crate", "wood_spool", "paint_box", "metal_tin", "wood_crate"])
		S.box(pre + "Box_%d" % i, (x + w / 2, y, z + h / 2), (w - 0.02, depth * random.uniform(0.7, 0.95), h), col, rot=(0, 0, random.uniform(-4, 4)), bevel=0.006)
		x += w + 0.02
		i += 1


def shelf_unit(pre, x, y, w, d, h, levels, rot=0.0, fill=True):
	"""A steel shelf unit with planks; boxes on the shelves."""
	for sx in (-1, 1):
		for sy in (-1, 1):
			S.box(pre + "Post_%d_%d" % (sx, sy), (x + sx * (w / 2 - 0.02), y + sy * (d / 2 - 0.02), h / 2), (0.035, 0.035, h), "paint_steel_frame", bevel=0.004)
	for i in range(levels):
		z = 0.12 + i * (h - 0.2) / max(1, levels - 1)
		S.box(pre + "Plank_%d" % i, (x, y, z), (w, d, 0.025), "wood_board", bevel=0.004)
		if fill and i > 0:
			boxes_on(pre + "L%d_" % i, x - w / 2 + 0.04, x + w / 2 - 0.04, y, z + 0.013, d * 0.85)


# ------------------------------------------------------------------ the room

def build_room():
	room_root()
	# floor: worn concrete, with a few painted lines and stains
	S.box("Floor", (0, 0, -0.05), (W, D, 0.1), "paint_floor", bevel=0)
	# walls: a darker band low down, conduit and pipes
	t = 0.2
	for name, c, s in [("Wall_Back", (0, D / 2 + t / 2, H / 2), (W + 2 * t, t, H)), ("Wall_Front", (0, -D / 2 - t / 2, H / 2), (W + 2 * t, t, H)),
			("Wall_Left", (-W / 2 - t / 2, 0, H / 2), (t, D, H)), ("Wall_Right", (W / 2 + t / 2, 0, H / 2), (t, D, H))]:
		S.box(name, c, s, "paint_wall", bevel=0)
	for name, c, s in [("Band_Back", (0, D / 2 - 0.005, 0.55), (W, 0.01, 1.1)), ("Band_Front", (0, -D / 2 + 0.005, 0.55), (W, 0.01, 1.1)),
			("Band_Left", (-W / 2 + 0.005, 0, 0.55), (0.01, D, 1.1)), ("Band_Right", (W / 2 - 0.005, 0, 0.55), (0.01, D, 1.1))]:
		S.box(name, c, s, "paint_wall_low", bevel=0)
	S.box("Ceiling", (0, 0, H + 0.05), (W, D, 0.1), "wood_ceiling", bevel=0)
	for k in range(6):
		S.box("Beam_%d" % k, (0, -D / 2 + 0.8 + k * 1.7, H - 0.12), (W, 0.16, 0.24), "wood_beam", bevel=0.01)
	S.box("Beam_Long", (0, 0, H - 0.3), (0.2, D, 0.12), "wood_beam", bevel=0.01)
	S.seg("Pipe_Back", (-3.9, D / 2 - 0.08, 2.6), (3.9, D / 2 - 0.08, 2.6), 0.06, "metal_steel")
	S.seg("Pipe_Right", (W / 2 - 0.08, -4.9, 2.45), (W / 2 - 0.08, 4.9, 2.45), 0.05, "metal_steel")
	S.seg("Conduit", (1.9, D / 2 - 0.04, 2.6), (1.9, D / 2 - 0.04, 1.2), 0.03, "metal_steel")
	S.box("Switchbox", (1.9, D / 2 - 0.05, 1.15), (0.14, 0.05, 0.2), "metal_tin", bevel=0.005)
	# windows on the left wall: frames, mullions, the night outside
	for k, wy in enumerate((0.0, 2.6)):
		S.box("Window_%d" % k, (-W / 2 + 0.02, wy, 2.0), (0.04, 0.9, 0.7), "plain_window", bevel=0, emission=0.6)
		for j in range(3):
			S.box("Window_%d_MV_%d" % (k, j), (-W / 2 + 0.05, wy - 0.45 + j * 0.45, 2.0), (0.04, 0.04, 0.72), "wood_door", bevel=0)
		for j in range(3):
			S.box("Window_%d_MH_%d" % (k, j), (-W / 2 + 0.05, wy, 1.65 + j * 0.35), (0.04, 0.92, 0.04), "wood_door", bevel=0)
	# the house door on the left wall, open: the warm kitchen beyond
	dy = -4.2
	S.box("House_Frame_T", (-W / 2 + 0.02, dy, 2.12), (0.1, 1.04, 0.08), "wood_door", bevel=0.005)
	for sy in (-1, 1):
		S.box("House_Frame_%d" % sy, (-W / 2 + 0.02, dy + sy * 0.5, 1.04), (0.1, 0.06, 2.1), "wood_door", bevel=0.005)
	S.box("House_Gap", (-W / 2 - 0.02, dy, 1.04), (0.24, 0.94, 2.08), "plain_house", bevel=0, emission=1.2)
	leaf = S.box("House_Door_Leaf", (-W / 2 + 0.47, dy - 0.47 + 0.02, 1.04), (0.9, 0.05, 2.06), "wood_door", rot=(0, 0, -78), bevel=0.008)
	S.box("House_Mat", (-W / 2 + 0.45, dy, 0.006), (0.6, 0.8, 0.012), "fabric_rug_b", bevel=0.004)
	for k in range(2):
		S.cyl("Boot_%d" % k, (-W / 2 + 0.3, dy + 0.6 + k * 0.14, 0.15), 0.05, 0.3, "fabric_jacket_a" if k == 0 else "plain_black", verts=8)
	# the rug down the middle
	S.box("Rug", (0, 0.2, 0.006), (1.6, 4.4, 0.012), "fabric_rug", bevel=0.004)
	for k in range(9):
		S.box("Rug_Stripe_%d" % k, (0, -1.8 + k * 0.5, 0.0125), (1.5, 0.08, 0.002), "fabric_rug_b", bevel=0)
	S.box("Mat_Right", (2.2, 0.4, 0.006), (0.9, 1.4, 0.012), "fabric_rug_b", bevel=0.004)
	# shelves with boxes, back left; plants on top; a Talar crate of bottles by the door
	shelf_unit("ShelfBL_", -2.6, D / 2 - 0.25, 1.4, 0.4, 2.2, 4)
	plant("PlantBL_", -2.2, D / 2 - 0.25, 2.2, 1.3)
	plant("PlantTR_", 3.5, D / 2 - 0.25, 2.25, 1.2)
	S.box("Talar_Crate", (2.0, D / 2 - 0.35, 0.16), (0.4, 0.28, 0.32), "plain_talar", bevel=0.01)
	for k in range(6):
		S.cyl("Talar_Bottle_%d" % k, (1.86 + (k % 3) * 0.14, D / 2 - 0.41 + (k // 3) * 0.12, 0.42), 0.03, 0.2, "plain_bottle", verts=8)
	S.text("Talar_Text", "Talar", (2.0, D / 2 - 0.5, 0.18), 0.1, "plain_paper", rot=(90, 0, 0))
	# hanging lamps: one over each station, one in the middle
	hang_lamp("Mid_", 0, 0.5)
	hang_lamp("Door_", 0, D / 2 - 1.2, drop=0.7)


def build_roller_door():
	station("roller_door", (0, D / 2 - 0.12), 0)
	w = 3.2
	S.box("RD_Housing", (0, 0, 2.6), (w + 0.3, 0.3, 0.32), "paint_door", bevel=0.02)
	for sx in (-1, 1):
		S.box("RD_Rail_%d" % sx, (sx * (w / 2 + 0.06), -0.02, 1.25), (0.1, 0.12, 2.5), "paint_steel_frame", bevel=0.01)
		S.box("RD_Hazard_%d" % sx, (sx * (w / 2 - 0.4), -0.12, 0.004), (0.6, 0.18, 0.006), "paint_hazard", bevel=0)
	for i in range(18):
		S.box("RD_Slat_%d" % i, (0, -0.02, 0.07 + i * 0.137), (w, 0.04, 0.13), "paint_door", bevel=0.006)
	S.box("RD_Handle", (0, -0.07, 0.3), (0.34, 0.04, 0.04), "metal_steel", bevel=0.004)
	S.box("RD_Gap", (0, 0.0, 0.006), (w - 0.1, 0.05, 0.012), "plain_house", bevel=0, emission=0.6)


def build_board():
	"""The TONIGHT board (concept 05): a corkboard beside the roller door. Its face (Board_Face) shows the cards."""
	station("board", (2.55, D / 2 - 0.05), 0)
	S.box("Board_Frame", (0, 0, 1.55), (1.25, 0.06, 0.95), "wood_board", bevel=0.01)
	S.box("Board_Face", (0, -0.035, 1.55), (1.13, 0.01, 0.83), "fabric_cork", bevel=0)
	S.box("Board_Clip", (0, -0.05, 2.0), (0.14, 0.03, 0.06), "metal_steel", bevel=0.004)
	hang_lamp("Board_", 0, -0.45, z_top=H, drop=0.55, shade=0.18)


def build_sewing():
	e = station("bench_sew", (-W / 2 + 0.42, -2.55), 90)
	for name, fn in (("Sew_Starter", S.build_starter), ("Sew_Improved", S.build_improved), ("Sew_Upgraded", S.build_upgraded)):
		fn(0.0)
		r = bpy.data.objects[name]
		r.parent = e
		r.location = (0, 0, 0)
	S.ROOT = e
	hang_lamp("Sew_", 0, 0.1, drop=0.95)


def build_med():
	"""Starter med table (med_stages.png): an olive metal frame, a steel top, dressings, a NEMRA pack, an enamel tray."""
	station("bench_med", (-W / 2 + 0.42, 1.0), 90)
	w, d, top = 1.4, 0.7, 0.8
	S.box("Med_Top", (0, 0, top - 0.02), (w, d, 0.04), "metal_med", bevel=0.008)
	for sx in (-1, 1):
		for sy in (-1, 1):
			S.box("Med_Leg_%d_%d" % (sx, sy), (sx * (w / 2 - 0.05), sy * (d / 2 - 0.05), (top - 0.04) / 2), (0.04, 0.04, top - 0.04), "paint_frame", bevel=0.004)
		S.box("Med_Rail_%d" % sx, (sx * (w / 2 - 0.05), 0, 0.15), (0.03, d - 0.1, 0.03), "paint_frame", bevel=0.003)
	S.box("Med_RailLong", (0, d / 2 - 0.05, 0.15), (w - 0.1, 0.03, 0.03), "paint_frame", bevel=0.003)
	for k in range(4):   # folded dressings with a green band
		S.box("Med_Dress_%d" % k, (-0.25, 0.05, top + 0.018 + k * 0.032), (0.18, 0.14, 0.03), "fabric_towel", rot=(0, 0, random.uniform(-4, 4)), bevel=0.008)
		S.box("Med_Band_%d" % k, (-0.25, 0.05, top + 0.018 + k * 0.032), (0.04, 0.145, 0.031), "fabric_band", bevel=0)
	S.box("Med_Pack", (0.05, -0.02, top + 0.015), (0.22, 0.13, 0.03), "plain_paper", rot=(0, 0, 12), bevel=0.01)
	S.box("Med_PackBand", (0.05, -0.02, top + 0.031), (0.04, 0.135, 0.002), "fabric_band", rot=(0, 0, 12), bevel=0)
	S.box("Med_Tray", (0.42, 0.1, top + 0.02), (0.28, 0.2, 0.04), "metal_mug", bevel=0.01)
	S.box("Med_Towel", (0.5, -d / 2 - 0.005, top - 0.12), (0.16, 0.01, 0.26), "fabric_towel", bevel=0.002)
	S.cyl("Med_Mug", (-0.52, 0.22, top + 0.05), 0.04, 0.1, "metal_mug", verts=10)
	S.cyl("Med_Cup", (-0.4, 0.26, top + 0.06), 0.045, 0.12, "metal_tin", verts=10)
	S.box("Med_Screwdriver", (-0.41, 0.26, top + 0.15), (0.015, 0.015, 0.12), "plain_red", rot=(8, 0, 0), bevel=0)
	S.cyl("Med_NemraTin", (0.2, 0.24, top + 0.08), 0.1, 0.16, "metal_tin_g", verts=14)
	S.text("Med_NemraText", "NEMRA", (0.2, 0.135, top + 0.09), 0.035, "plain_paper", rot=(90, 0, 0))
	S.lamp("Med_", (-0.6, 0.25, top), (-0.64, 0.24, top + 0.28), (-0.48, 0.2, top + 0.44), (-0.2, 0.0, top))
	hang_lamp("MedH_", 0, 0.1, drop=1.0)


def build_gun():
	"""Starter gun bench (gun_stages.png): planks on sawhorses, a felt mat, the blocky stylised pistol, crates under."""
	station("bench_gun", (W / 2 - 0.42, 0.4), -90)
	S.plank_top("Gun_Top_", 0.82, w=1.6, d=0.72)
	S.sawhorse("Gun_HL_", -0.55)
	S.sawhorse("Gun_HR_", 0.55)
	S.box("Gun_Mat", (0, 0.0, 0.825), (0.8, 0.45, 0.008), "fabric_felt", bevel=0.003)
	# the stylised pistol (gun_steps.png): a blocky slide, a green side panel, a wooden grip
	S.box("Gun_Body", (0.12, 0.02, 0.87), (0.3, 0.1, 0.07), "metal_gun", bevel=0.012)
	S.box("Gun_Panel", (0.12, -0.03, 0.87), (0.2, 0.012, 0.045), "paint_frame", bevel=0.004)
	S.box("Gun_Grip", (0.24, 0.02, 0.82), (0.06, 0.08, 0.1), "wood_door", rot=(0, 15, 0), bevel=0.008)
	S.box("Gun_Barrel", (-0.06, 0.02, 0.885), (0.08, 0.06, 0.04), "metal_gun", bevel=0.008)
	S.cyl("Gun_Mug", (-0.55, 0.22, 0.87), 0.04, 0.1, "metal_mug", verts=10)
	S.box("Gun_Tray", (-0.3, 0.22, 0.85), (0.22, 0.14, 0.05), "wood_crate", bevel=0.006)
	S.box("Gun_Driver", (0.42, -0.2, 0.83), (0.18, 0.02, 0.02), "plain_red", rot=(0, 0, 20), bevel=0)
	S.metal_box("Gun_Under_", (-0.4, 0.0), 0.0, s=(0.38, 0.3, 0.24))
	S.metal_box("Gun_Under2_", (0.45, 0.05), 0.0, s=(0.3, 0.28, 0.2), col="paint_box")
	S.lamp("Gun_", (-0.65, 0.25, 0.82), (-0.68, 0.24, 1.12), (-0.5, 0.18, 1.26), (0.1, 0.0, 0.82))
	hang_lamp("GunH_", 0, 0.1, drop=0.95)


def build_electronics():
	"""The electronics desk in the back-right corner (tech_stages.png starter + concept 01): the PC (the Veltin CRT,
	keyboard, the phone) on its left half; the hacking bench (the Veltin radio, a rubber mat, the red pad, a lamp) and
	the box on its right half. Three stations share the desk: pc, rig (the box), bench_hack."""
	base = station("desk", (W / 2 - 0.42, 3.4), -90)
	w, d, top = 2.4, 0.72, 0.78
	S.plank_top("Desk_Top_", top, w=w, d=d)
	for sx in (-1, 1):
		S.box("Desk_Leg_%d" % sx, (sx * (w / 2 - 0.05), -d / 2 + 0.06, (top - 0.04) / 2), (0.06, 0.06, top - 0.04), "wood_horse", bevel=0.006)
	S.box("Desk_Drawers", (0.85, 0.0, (top - 0.04) / 2), (0.5, d - 0.08, top - 0.04), "paint_frame", bevel=0.01)
	for k in range(2):
		S.box("Desk_Drawer_%d" % k, (0.85, -d / 2 + 0.03, 0.2 + k * 0.3), (0.44, 0.02, 0.24), "paint_box", bevel=0.005)
		S.box("Desk_Pull_%d" % k, (0.85, -d / 2 + 0.015, 0.25 + k * 0.3), (0.1, 0.02, 0.025), "metal_steel", bevel=0.003)
	S.box("Desk_LegBackL", (-w / 2 + 0.05, d / 2 - 0.06, (top - 0.04) / 2), (0.06, 0.06, top - 0.04), "wood_horse", bevel=0.006)
	# shelves above the desk with boxes and books, a plant
	for k, z in enumerate((1.45, 1.95)):
		S.box("Desk_Shelf_%d" % k, (0, d / 2 - 0.15, z), (w, 0.28, 0.03), "wood_board", bevel=0.004)
		boxes_on("Desk_S%d_" % k, -w / 2 + 0.05, w / 2 - 0.05, d / 2 - 0.15, z + 0.015, 0.24)
	# the PC: the Veltin CRT, a keyboard, the phone (station pc)
	pc = station("pc", (0, 0), 0)
	pc.parent = base
	pc.location = (-0.6, 0, 0)
	S.box("PC_CRT", (0, 0.1, top + 0.21), (0.46, 0.42, 0.38), "metal_crt", bevel=0.03)
	S.box("PC_Screen", (0, -0.115, top + 0.23), (0.34, 0.01, 0.26), "plain_crt_glow", bevel=0, emission=1.6)
	S.text("PC_Brand", "Veltin", (0.0, -0.118, top + 0.07), 0.035, "plain_black", rot=(90, 0, 0))
	S.ball("PC_Led", (0.16, -0.115, top + 0.07), 0.008, "plain_led", sub=1, emission=4.0)
	S.box("PC_Keyboard", (0, -0.24, top + 0.015), (0.4, 0.14, 0.025), "metal_crt", rot=(4, 0, 0), bevel=0.006)
	S.box("PC_Phone", (0.36, -0.18, top + 0.03), (0.08, 0.16, 0.05), "plain_black", rot=(0, 0, -12), bevel=0.01)
	S.cyl("PC_Mug", (-0.34, -0.2, top + 0.05), 0.04, 0.1, "metal_mug", verts=10)
	# the box (station rig): the gadget box beside the PC
	bx = station("rig", (0, 0), 0)
	bx.parent = base
	bx.location = (0.05, 0, 0)
	S.box("Box_Case", (0, 0.08, top + 0.07), (0.3, 0.24, 0.14), "paint_box", bevel=0.012)
	for k in range(3):
		S.box("Box_Slot_%d" % k, (-0.08 + k * 0.08, -0.04, top + 0.1), (0.05, 0.01, 0.06), "plain_black", bevel=0)
	S.ball("Box_Led", (0.12, -0.045, top + 0.12), 0.008, "plain_led", sub=1, emission=4.0)
	# the hacking bench (station bench_hack): the Veltin radio on a rubber mat, the red pad with a knob, a lamp
	hk = station("bench_hack", (0, 0), 0)
	hk.parent = base
	hk.location = (0.75, 0, 0)
	S.box("Hack_Mat", (0, -0.05, top + 0.004), (0.55, 0.42, 0.008), "plain_black", bevel=0.002)
	S.box("Hack_Radio", (-0.08, 0.04, top + 0.11), (0.32, 0.18, 0.2), "metal_radio", bevel=0.02)
	for k in range(7):
		S.box("Hack_Grille_%d" % k, (-0.15, -0.052, top + 0.05 + k * 0.022), (0.14, 0.008, 0.008), "wood_drawer", bevel=0)
	S.cyl("Hack_Dial", (0.02, -0.055, top + 0.09), 0.025, 0.02, "plain_black", rot=(90, 0, 0), verts=10)
	S.box("Hack_LCD", (0.02, -0.052, top + 0.16), (0.07, 0.006, 0.035), "plain_led", bevel=0, emission=1.0)
	S.box("Hack_Pad", (0.18, -0.12, top + 0.01), (0.16, 0.14, 0.012), "fabric_pad", bevel=0.002)
	S.cyl("Hack_Knob", (0.18, -0.12, top + 0.035), 0.03, 0.035, "plain_black", verts=12)
	S.lamp("Hack_", (0.32, 0.2, top), (0.36, 0.2, top + 0.28), (0.2, 0.12, top + 0.42), (0.0, 0.0, top))
	S.ROOT = base
	hang_lamp("DeskH_", 0, 0.0, drop=0.85)


def build_cage():
	"""The gear cage, front right (concept 01): a mesh cage with jackets on a rail, folded clothes, boxes on top."""
	station("cage", (W / 2 - 0.55, -3.3), -90)
	w, d, h = 1.4, 0.8, 1.9
	for sx in (-1, 1):
		for sy in (-1, 1):
			S.box("Cage_Post_%d_%d" % (sx, sy), (sx * w / 2, sy * d / 2, h / 2), (0.04, 0.04, h), "paint_steel_frame", bevel=0.004)
	for z in (0.05, h):
		S.box("Cage_RimF_%d" % int(z * 10), (0, -d / 2, z), (w, 0.03, 0.03), "paint_steel_frame", bevel=0)
		S.box("Cage_RimB_%d" % int(z * 10), (0, d / 2, z), (w, 0.03, 0.03), "paint_steel_frame", bevel=0)
	for sx in (-1, 1):   # wire mesh on the sides
		for k in range(10):
			S.box("Cage_WireV_%d_%d" % (sx, k), (sx * w / 2, -d / 2 + 0.04 + k * (d - 0.08) / 9, h / 2), (0.006, 0.006, h), "metal_mesh", bevel=0)
		for k in range(12):
			S.box("Cage_WireH_%d_%d" % (sx, k), (sx * w / 2, 0, 0.1 + k * 0.155), (0.006, d, 0.006), "metal_mesh", bevel=0)
	for k in range(14):   # front mesh, a door-width gap in the middle left open
		x = -w / 2 + 0.05 + k * (w - 0.1) / 13
		if abs(x) < 0.3:
			continue
		S.box("Cage_WireF_%d" % k, (x, -d / 2, h / 2), (0.006, 0.006, h), "metal_mesh", bevel=0)
	S.seg("Cage_Rail", (-w / 2 + 0.05, 0.05, h - 0.2), (w / 2 - 0.05, 0.05, h - 0.2), 0.02, "metal_steel")
	cols = ["fabric_jacket_a", "fabric_jacket_b", "fabric_jacket_c", "fabric_jacket_a", "fabric_jacket_d"]
	for k, col in enumerate(cols):
		x = -0.5 + k * 0.25
		S.box("Cage_Hanger_%d" % k, (x, 0.05, h - 0.24), (0.2, 0.01, 0.02), "wood_spool", bevel=0)
		S.box("Cage_Jacket_%d" % k, (x, 0.05, h - 0.62), (0.22, 0.08, 0.72), col, bevel=0.02)
		S.box("Cage_Sleeve_%d" % k, (x + 0.12, 0.05, h - 0.66), (0.05, 0.07, 0.6), col, rot=(0, -8, 0), bevel=0.01)
		if k % 2 == 0:
			S.box("Cage_Patch_%d" % k, (x - 0.05, 0.005, h - 0.55), (0.07, 0.01, 0.07), ["fabric_blue", "fabric_mustard", "fabric_red"][k // 2 % 3], bevel=0)
	S.cloth_stack("Cage_", (0.0, 0.0), 0.06, layers=(("fabric_jacket_b", 0.05), ("fabric_red", 0.05), ("fabric_cream", 0.05)))
	S.metal_box("Cage_Top_", (-0.25, 0.0), h + 0.02, s=(0.4, 0.3, 0.22))
	S.box("Cage_TopBox", (0.3, 0.0, h + 0.13), (0.4, 0.32, 0.22), "wood_crate", bevel=0.008)
	hang_lamp("CageH_", 0, -0.4, drop=0.6)


def build_stash():
	"""The shelves (stash) beside the cage: a steel unit of tins, boxes and kit."""
	station("stash", (W / 2 - 0.3, -1.85), -90)
	shelf_unit("Stash_", 0, 0, 1.2, 0.45, 1.5, 4)
	for k in range(4):
		S.cyl("Stash_Tin_%d" % k, (-0.45 + k * 0.12, 0.0, 0.2), 0.05, 0.12, "metal_tin" if k % 2 else "metal_tin_g", verts=10)


def build_chair():
	"""The prisoner's chair in the back-left corner, under its own bulb."""
	station("prisoner", (-3.1, 3.7), 45)   # faces the room
	S.box("Chair_Seat", (0, 0, 0.45), (0.44, 0.42, 0.04), "wood_door", bevel=0.006)
	for sx in (-1, 1):
		for sy in (-1, 1):
			S.box("Chair_Leg_%d_%d" % (sx, sy), (sx * 0.19, sy * 0.18, 0.22), (0.035, 0.035, 0.45), "wood_door", bevel=0.004)
	S.box("Chair_Back", (0, 0.19, 0.75), (0.44, 0.03, 0.5), "wood_door", bevel=0.006)
	S.seg("Chair_Rope", (-0.2, 0.15, 0.6), (0.2, 0.15, 0.62), 0.015, "fabric_towel")
	S.seg("Chair_BulbCord", (0, 0, H), (0, 0, 1.9), 0.01, "plain_black", verts=4)
	S.ball("Chair_Hang_Bulb", (0, 0, 1.86), 0.04, "plain_bulb", sub=2, emission=5.0)


# ------------------------------------------------------------------ B4: clutter (concepts 01 and 02)

def jars(pre, x0, x1, y, z, depth_axis="y"):
	"""A row of jars and tins along a shelf (x0..x1 along X, or along Y if depth_axis is "x")."""
	cols = ["metal_tin", "plain_bottle", "metal_tin_g", "plain_paper", "metal_copper", "fabric_cream"]
	n = int((x1 - x0) / 0.11)
	for k in range(n):
		t = x0 + 0.06 + k * 0.11
		h = random.uniform(0.08, 0.16)
		p = (t, y, z + h / 2) if depth_axis == "y" else (y, t, z + h / 2)
		S.cyl(pre + "Jar_%d" % k, p, random.uniform(0.03, 0.045), h, random.choice(cols), verts=10)


def crate(pre, x, y, z, s=0.45, rot=0.0, col="wood_crate"):
	S.box(pre + "Crate", (x, y, z + s * 0.35), (s, s * 0.8, s * 0.7), col, rot=(0, 0, rot), bevel=0.01)
	S.box(pre + "Slat", (x, y, z + s * 0.62), (s + 0.01, s * 0.81, 0.04), "wood_drawer", rot=(0, 0, rot), bevel=0.004)


def build_clutter():
	S.ROOT = bpy.data.objects["Room"]
	# left wall, above the med table: a pegboard with tools (concept 01 "MEDICAL")
	S.box("Peg_Board", (-W / 2 + 0.02, 0.85, 1.3), (0.02, 1.0, 0.62), "wood_board", bevel=0.004)
	for k in range(5):
		y = 0.45 + k * 0.2
		S.cyl("Peg_Pin_%d" % k, (-W / 2 + 0.06, y, 1.5), 0.008, 0.06, "metal_steel", rot=(0, 90, 0), verts=6)
	S.box("Peg_Scissors", (-W / 2 + 0.06, 0.45, 1.36), (0.02, 0.06, 0.2), "metal_steel", rot=(12, 0, 0), bevel=0.003)
	S.cyl("Peg_Coil", (-W / 2 + 0.06, 0.65, 1.38), 0.08, 0.02, "fabric_band", rot=(0, 90, 0), verts=12)
	S.box("Peg_Brush", (-W / 2 + 0.06, 0.85, 1.36), (0.03, 0.05, 0.22), "wood_drawer", bevel=0.004)
	S.box("Peg_Tongs", (-W / 2 + 0.06, 1.05, 1.36), (0.02, 0.04, 0.24), "metal_steel", rot=(-8, 0, 0), bevel=0.003)
	S.cyl("Peg_Rope", (-W / 2 + 0.06, 1.25, 1.36), 0.07, 0.03, "fabric_cream", rot=(0, 90, 0), verts=12)
	# left wall, high above the sewing table: a shelf of jars, folded cloth and a trailing plant
	S.box("ShelfSew_Plank", (-W / 2 + 0.14, -2.85, 1.9), (0.26, 1.0, 0.03), "wood_board", bevel=0.004)
	for sy in (-1, 1):
		S.box("ShelfSew_Bracket_%d" % sy, (-W / 2 + 0.06, -2.85 + sy * 0.42, 1.82), (0.1, 0.03, 0.14), "metal_dark", bevel=0.003)
	jars("ShelfSew_", -3.3, -2.9, -W / 2 + 0.14, 1.915, depth_axis="x")
	S.cloth_stack("ShelfSew_", (-W / 2 + 0.14, -2.58), 1.915, layers=(("fabric_cream", 0.04), ("fabric_olive", 0.04)))
	plant("ShelfSewP_", -W / 2 + 0.14, -2.42, 1.915, 0.9)
	# the medicine trolley between the sewing and med tables
	tx, ty = -W / 2 + 0.36, -0.75
	for sx in (-1, 1):
		for sy in (-1, 1):
			S.box("Trolley_Leg_%d_%d" % (sx, sy), (tx + sx * 0.18, ty + sy * 0.36, 0.42), (0.03, 0.03, 0.84), "paint_mint", bevel=0.003)
			S.cyl("Trolley_Wheel_%d_%d" % (sx, sy), (tx + sx * 0.18, ty + sy * 0.36, 0.03), 0.03, 0.025, "plain_black", rot=(90, 0, 0), verts=8)
	for k, z in enumerate((0.25, 0.82)):
		S.box("Trolley_Shelf_%d" % k, (tx, ty, z), (0.42, 0.8, 0.025), "paint_mint", bevel=0.004)
	S.box("Trolley_Pot", (tx, ty - 0.15, 0.92), (0.22, 0.2, 0.18), "metal_mug", bevel=0.02)
	S.box("Trolley_Cross_V", (tx + 0.111, ty - 0.15, 0.94), (0.002, 0.03, 0.09), "plain_red", bevel=0)
	S.box("Trolley_Cross_H", (tx + 0.111, ty - 0.15, 0.94), (0.002, 0.09, 0.03), "plain_red", bevel=0)
	jars("Trolley_", ty + 0.0, ty + 0.36, tx, 0.835, depth_axis="x")
	for k in range(3):
		S.box("Trolley_Towel_%d" % k, (tx, ty + 0.1, 0.28 + k * 0.04), (0.3, 0.3, 0.035), "fabric_towel", bevel=0.01)
	# a stool at the sewing table
	S.cyl("Stool_Seat", (-2.95, -2.05, 0.5), 0.17, 0.04, "wood_door", verts=12)
	for k in range(3):
		a = k / 3.0 * math.tau
		S.seg("Stool_Leg_%d" % k, (-2.95 + math.cos(a) * 0.12, -2.05 + math.sin(a) * 0.12, 0.48), (-2.95 + math.cos(a) * 0.18, -2.05 + math.sin(a) * 0.18, 0.0), 0.02, "wood_horse", verts=5)
	# front wall: two shelf units of boxes and tins, a coat rack by the house door, crates
	shelf_unit("ShelfF1_", 1.35, -D / 2 + 0.25, 1.4, 0.4, 2.0, 4)
	plant("ShelfF1P_", 1.75, -D / 2 + 0.25, 2.0, 1.1)
	shelf_unit("ShelfF2_", -0.6, -D / 2 + 0.25, 1.2, 0.4, 1.6, 3)
	crate("CrateF1_", -2.0, -D / 2 + 0.35, 0.0)
	crate("CrateF2_", -2.0, -D / 2 + 0.35, 0.33, s=0.38, rot=8, col="paint_box")
	S.box("Coat_Rail", (-2.7, -D / 2 + 0.06, 1.75), (0.8, 0.04, 0.05), "wood_door", bevel=0.004)
	for k, col in enumerate(("fabric_jacket_c", "fabric_jacket_b")):
		S.box("Coat_%d" % k, (-2.92 + k * 0.42, -D / 2 + 0.12, 1.38), (0.34, 0.1, 0.7), col, rot=(0, 0, 4 - k * 8), bevel=0.02)
	S.box("Cal_Paper", (-1.55, -D / 2 + 0.008, 1.5), (0.3, 0.006, 0.4), "plain_paper", bevel=0)
	# back wall: crates at the roller door, a hanging plant
	crate("CrateB1_", -1.95, D / 2 - 0.75, 0.0, rot=-6)
	crate("CrateB2_", -1.95, D / 2 - 0.75, 0.32, s=0.36, rot=10, col="paint_box")
	# right wall: a red tool chest between the stash and the gun bench, a bucket, a tall corner shelf
	cx, cy = W / 2 - 0.3, -0.82
	S.box("Chest_Body", (cx, cy, 0.5), (0.5, 0.66, 1.0), "plain_red", bevel=0.012)
	for k in range(5):
		S.box("Chest_Drawer_%d" % k, (cx - 0.252, cy, 0.14 + k * 0.18), (0.005, 0.6, 0.15), "plain_red", bevel=0.004)
		S.box("Chest_Pull_%d" % k, (cx - 0.262, cy, 0.18 + k * 0.18), (0.012, 0.22, 0.02), "metal_steel", bevel=0.002)
	S.box("Chest_Vise", (cx - 0.05, cy, 1.06), (0.2, 0.14, 0.12), "metal_dark", bevel=0.01)
	S.cyl("Bucket", (W / 2 - 0.35, 1.55, 0.17), 0.15, 0.34, "metal_tin", verts=12, r2=0.12)
	shelf_unit("ShelfFR_", W / 2 - 0.3, -4.55, 0.5, 0.8, 2.2, 5)
	plant("ShelfFRP_", W / 2 - 0.3, -4.55, 2.2, 1.0)
	# books on the desk shelves (the electronics corner)
	for k in range(9):
		S.box("Book_%d" % k, (W / 2 - 0.2, 4.45 - k * 0.05, 1.56), (0.18, 0.04, random.uniform(0.18, 0.24)),
			random.choice(["fabric_jacket_b", "fabric_red", "fabric_mustard", "fabric_olive", "fabric_cream"]), bevel=0.004)
	# hanging plants from the beams, an extension cable along the floor
	for k, (x, y) in enumerate(((-1.6, 3.0), (1.7, -2.0), (-2.4, -0.6))):
		S.seg("HangPlant_Cord_%d" % k, (x, y, H - 0.24), (x, y, 2.25), 0.008, "plain_black", verts=4)
		plant("HangPlant_%d_" % k, x, y, 2.05, 0.8)
	S.seg("Cable_A", (W / 2 - 0.8, 2.6, 0.015), (W / 2 - 0.9, 0.0, 0.015), 0.012, "plain_black", verts=5)
	S.seg("Cable_B", (W / 2 - 0.9, 0.0, 0.015), (W / 2 - 1.2, -1.2, 0.015), 0.012, "plain_black", verts=5)
	# oil stains on the floor
	for k, (x, y, s) in enumerate(((0.6, 3.6, 0.9), (-0.4, 2.8, 0.5), (1.2, -1.5, 0.6), (-1.3, -3.6, 0.45))):
		S.cyl("Stain_%d" % k, (x, y, 0.002), s * 0.5, 0.002, "paint_stain", verts=14)
	# conduit along the left wall, a fuse box
	S.seg("Conduit_L", (-W / 2 + 0.04, -4.9, 2.4), (-W / 2 + 0.04, 4.9, 2.4), 0.025, "metal_steel")
	S.box("Fusebox", (-W / 2 + 0.05, -3.4, 2.1), (0.08, 0.3, 0.4), "metal_tin", bevel=0.008)


# ------------------------------------------------------------------ run

build_room()
build_roller_door()
build_board()
build_sewing()
build_med()
build_gun()
build_electronics()
build_cage()
build_stash()
build_chair()
build_clutter()
S.ROOT = None

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "garage_v3.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "garage_v3.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("GARAGE V3 OK", len(bpy.data.objects), "objects")
