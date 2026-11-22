# The v2 garage (White Knuckle look): low-poly concrete box, one bare bulb, sodium street light.
# Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_garage_v2.py
# Writes art/src/garage_v2.blend (for the user to tweak) and art/garage_v2.glb (what Godot loads).
# Blender coords: X right, Y away from the chair, Z up. The chair is at the origin facing +Y (the desk).
# Object names matter: data/v2/stations.json lists which objects belong to which station.
# Colours are flat here; Godot adds the dithered grit texture by material name (v2/world/garage_world.gd).

import bpy
import math
import os
import random

random.seed(21)
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)

bpy.ops.wm.read_factory_settings(use_empty=True)

# --- palette (screen colours; one place to change every colour) ----------------------------
PAL = {
	"concrete": (0.34, 0.33, 0.33), "concrete_d": (0.22, 0.21, 0.22), "wall": (0.40, 0.38, 0.39),
	"beam": (0.20, 0.19, 0.21), "metal": (0.30, 0.34, 0.32), "metal_d": (0.14, 0.15, 0.15),
	"metal_l": (0.50, 0.53, 0.51), "brass": (0.80, 0.62, 0.30), "wood": (0.38, 0.27, 0.19),
	"wood_d": (0.22, 0.15, 0.11), "cork": (0.62, 0.45, 0.28), "paper": (0.86, 0.82, 0.70),
	"photo": (0.30, 0.28, 0.30), "string": (0.75, 0.10, 0.10), "plastic": (0.70, 0.66, 0.56),
	"plastic_d": (0.12, 0.12, 0.13), "screen": (1.00, 0.36, 0.26), "scope": (0.45, 1.00, 0.40),
	"lamp_red": (1.00, 0.25, 0.18), "lamp_amber": (1.00, 0.70, 0.20), "tarp": (0.20, 0.24, 0.18),
	"cloth": (0.32, 0.20, 0.30), "door": (0.30, 0.26, 0.24), "roller": (0.36, 0.38, 0.40),
	"sodium": (1.00, 0.55, 0.18), "warm": (1.00, 0.78, 0.50), "bulb": (1.00, 0.92, 0.75),
	"cable": (0.06, 0.06, 0.06), "cardboard": (0.55, 0.42, 0.27), "paint_p": (0.42, 0.22, 0.48),
	"rubber": (0.07, 0.07, 0.07), "green_pcb": (0.12, 0.38, 0.20), "mug": (0.68, 0.70, 0.64),
}
_mats = {}


def _lin(v):
	return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def mat(name, emission=0.0):
	key = (name, emission)
	if key in _mats:
		return _mats[key]
	m = bpy.data.materials.new("M_" + name + ("_glow" if emission else ""))
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	c = [_lin(v) for v in PAL[name]]
	bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
	bsdf.inputs["Roughness"].default_value = 0.9
	if emission:
		bsdf.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1.0)
		bsdf.inputs["Emission Strength"].default_value = emission
	_mats[key] = m
	return m


def _finish(o, name, color, rot, emission=0.0):
	o.name = name
	o.rotation_euler = [math.radians(a) for a in rot]
	o.data.materials.clear()
	o.data.materials.append(mat(color, emission))
	return o


def box(name, center, size, color, rot=(0, 0, 0), emission=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=center)
	o = bpy.context.active_object
	o.scale = size
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	return _finish(o, name, color, rot, emission)


def cyl(name, center, radius, depth, color, rot=(0, 0, 0), verts=8, emission=0.0):
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center)
	return _finish(bpy.context.active_object, name, color, rot, emission)


def j(deg=3.0):
	return random.uniform(-deg, deg)


# --- the room -------------------------------------------------------------------------------
box("Floor", (0, -0.1, -0.05), (5.8, 5.2, 0.1), "concrete")
box("Ceiling", (0, -0.1, 2.7), (5.8, 5.2, 0.1), "concrete_d")
box("Wall_N", (0, 2.5, 1.3), (5.8, 0.1, 2.7), "wall")
box("Wall_S", (0, -2.7, 1.3), (5.8, 0.1, 2.7), "wall")
box("Wall_W", (-2.9, -0.1, 1.3), (0.1, 5.2, 2.7), "wall")
box("Wall_E", (2.9, -0.1, 1.3), (0.1, 5.2, 2.7), "wall")
for i, y in enumerate((-1.8, -0.4, 1.0, 2.0)):
	box("Beam_%d" % i, (0, y, 2.55), (5.8, 0.16, 0.2), "beam")
cyl("Pipe_A", (0, 2.3, 2.42), 0.05, 5.8, "metal_d", rot=(0, 90, 0))
cyl("Pipe_B", (-2.7, -0.1, 2.35), 0.035, 5.2, "metal_d", rot=(90, 0, 0))
box("Floor_Stain", (0.4, -0.6, 0.002), (1.3, 0.9, 0.004), "concrete_d", rot=(0, 0, 17))
box("Skirting_N", (0, 2.43, 0.06), (5.8, 0.04, 0.12), "concrete_d")

# Window above the desk: the sodium street light outside.
box("Window_Frame", (1.45, 2.44, 1.75), (1.0, 0.06, 0.7), "metal_d")
box("Window_Glass", (1.45, 2.42, 1.75), (0.88, 0.03, 0.58), "sodium", emission=0.3)
for i in range(3):
	box("Window_Bar_%d" % i, (1.15 + i * 0.3, 2.40, 1.75), (0.025, 0.03, 0.6), "metal_d")

# The bare bulb.
cyl("Bulb_Cord", (0, 0.35, 2.45), 0.006, 0.45, "cable")
cyl("Bulb", (0, 0.35, 2.18), 0.05, 0.1, "bulb", verts=8, emission=4.0)

# Wall clock (north wall, left of the desk).
cyl("Clock", (-1.25, 2.44, 1.95), 0.17, 0.04, "plastic", rot=(90, 0, 0), verts=12)
box("Clock_Hand_H", (-1.25, 2.41, 1.99), (0.015, 0.01, 0.09), "plastic_d")
box("Clock_Hand_M", (-1.22, 2.41, 1.95), (0.12, 0.01, 0.012), "plastic_d", rot=(0, 30, 0))

# --- the desk (north) -----------------------------------------------------------------------
box("Desk_Top", (0, 1.35, 0.74), (2.1, 0.85, 0.05), "wood")
for x in (-0.98, 0.98):
	for y in (0.98, 1.72):
		box("Desk_Leg", (x, y, 0.36), (0.06, 0.06, 0.72), "wood_d")
box("Desk_Drawer", (-0.7, 1.0, 0.6), (0.5, 0.15, 0.2), "wood_d")

# PC: a heavy CRT.
box("PC_Body", (-0.35, 1.5, 1.0), (0.52, 0.48, 0.46), "plastic")
box("PC_Bezel", (-0.35, 1.25, 1.0), (0.48, 0.02, 0.40), "plastic_d")
box("PC_Screen", (-0.35, 1.235, 1.01), (0.40, 0.01, 0.31), "screen", emission=1.2)
box("PC_Stand", (-0.35, 1.45, 0.79), (0.3, 0.3, 0.05), "plastic")
box("PC_Keyboard", (-0.35, 1.02, 0.778), (0.46, 0.16, 0.025), "plastic", rot=(4, 0, 0))
box("PC_Mouse", (0.02, 1.0, 0.775), (0.06, 0.1, 0.03), "plastic")
box("PC_Tower", (-0.85, 1.45, 0.98), (0.2, 0.45, 0.42), "plastic")
box("PC_Tower_Lamp", (-0.85, 1.225, 1.12), (0.02, 0.01, 0.02), "scope", emission=3.0)

# The hack rig: a metal case with lamps, dials, a cartridge slot and the SEND lever.
box("Rig_Body", (0.5, 1.38, 0.88), (0.6, 0.42, 0.24), "metal", rot=(0, 0, j(2)))
box("Rig_Panel", (0.5, 1.165, 0.9), (0.54, 0.01, 0.18), "metal_d")
for i in range(5):
	box("Rig_Lamp_%d" % i, (0.29 + i * 0.07, 1.155, 0.96), (0.03, 0.01, 0.03),
		"lamp_red" if i < 2 else "lamp_amber", emission=2.5 if i == 0 else 0.0)
for i in range(3):
	cyl("Rig_Dial_%d" % i, (0.34 + i * 0.12, 1.155, 0.86), 0.025, 0.02, "brass", rot=(90, 0, 0), verts=10)
box("Rig_Slot", (0.5, 1.3, 1.0), (0.3, 0.05, 0.02), "metal_d")
box("Rig_Cartridge", (0.42, 1.3, 1.03), (0.1, 0.03, 0.06), "lamp_amber")
cyl("Rig_Lever", (0.86, 1.3, 1.05), 0.012, 0.3, "metal_l", rot=(-20, 0, 0))
cyl("Rig_Lever_Knob", (0.86, 1.25, 1.19), 0.03, 0.05, "lamp_red", verts=10)

# Phone: old desk phone with a cord.
box("Phone_Base", (0.92, 0.98, 0.8), (0.2, 0.18, 0.07), "plastic_d", rot=(0, 0, j(8)))
box("Phone_Handset", (0.92, 0.98, 0.85), (0.22, 0.05, 0.04), "plastic_d", rot=(0, 0, j(8)))

# Desk clutter.
cyl("Mug", (0.15, 1.2, 0.81), 0.04, 0.1, "mug", verts=10)
box("Papers", (-0.95, 1.05, 0.77), (0.22, 0.3, 0.01), "paper", rot=(0, 0, 12))
box("Desk_Lamp_Base", (-0.95, 1.6, 0.78), (0.14, 0.14, 0.03), "metal_d")
cyl("Desk_Lamp_Arm", (-0.95, 1.55, 0.98), 0.01, 0.4, "metal_d", rot=(15, 0, 0))
cyl("Desk_Lamp_Shade", (-0.95, 1.45, 1.16), 0.08, 0.1, "metal", rot=(40, 0, 0), verts=8)

# --- east wall: the benches -----------------------------------------------------------------
# Hacking bench.
box("Bench_Hack_Top", (2.4, 0.9, 0.9), (0.85, 1.4, 0.06), "wood")
for y in (0.28, 1.52):
	box("Bench_Hack_Leg", (2.4, y, 0.44), (0.7, 0.06, 0.88), "wood_d")
box("Bench_Hack_Board", (2.84, 0.9, 1.5), (0.03, 1.4, 0.9), "cardboard")
for i in range(6):
	box("Bench_Hack_Tool_%d" % i, (2.81, 0.35 + i * 0.22, 1.5 + j(0.1) * 0.5), (0.02, 0.03, 0.2 + random.random() * 0.15), "metal_d")
box("Bench_Hack_Scope", (2.5, 1.35, 1.05), (0.35, 0.3, 0.24), "metal")
box("Bench_Hack_Scope_Screen", (2.32, 1.35, 1.07), (0.01, 0.2, 0.14), "scope", emission=1.5)
box("Bench_Hack_Iron", (2.4, 0.5, 0.97), (0.18, 0.14, 0.09), "metal_d")
box("Bench_Hack_PCB", (2.3, 0.9, 0.94), (0.22, 0.16, 0.01), "green_pcb", rot=(0, 0, 10))
box("Bench_Hack_Parts", (2.55, 0.85, 0.95), (0.16, 0.24, 0.04), "plastic_d")

# Gun bench: covered with a tarp until you buy the kit.
box("Bench_Gun_Top", (2.4, -0.95, 0.9), (0.85, 1.4, 0.06), "wood")
for y in (-1.6, -0.3):
	box("Bench_Gun_Leg", (2.4, y, 0.44), (0.7, 0.06, 0.88), "wood_d")
box("Bench_Gun_Tarp", (2.4, -0.95, 1.02), (0.9, 1.45, 0.2), "tarp", rot=(j(2), j(2), j(2)))
box("Bench_Gun_Tarp_Lump", (2.35, -0.7, 1.15), (0.4, 0.5, 0.12), "tarp", rot=(0, 0, 14))
box("Bench_Gun_Crate", (2.4, -1.4, 0.2), (0.6, 0.5, 0.4), "wood_d")
box("Bench_Gun_Lock", (2.09, -1.4, 0.3), (0.02, 0.06, 0.08), "brass")

# Sewing table (armor) against the south wall, between the two doors.
box("Bench_Sew_Top", (-0.82, -2.28, 0.76), (0.8, 0.6, 0.04), "wood")
for x in (-1.17, -0.47):
	box("Bench_Sew_Leg", (x, -2.28, 0.37), (0.04, 0.55, 0.74), "metal_d")
box("Bench_Sew_Spool", (-0.5, -2.45, 0.82), (0.05, 0.05, 0.08), "lamp_red")
box("Bench_Sew_Scraps", (-1.05, -2.42, 0.79), (0.25, 0.15, 0.03), "tarp", rot=(0, 0, 12))
box("Bench_Sew_Lamp", (-1.12, -2.5, 1.05), (0.08, 0.08, 0.5), "metal_d")

# Med table (meds) against the north wall, left of the desk, under the clock.
box("Bench_Med_Top", (-1.65, 2.08, 0.8), (0.95, 0.6, 0.04), "metal_l")
for x in (-2.07, -1.23):
	box("Bench_Med_Leg", (x, 2.08, 0.39), (0.04, 0.5, 0.78), "metal_d")
box("Bench_Med_Bottle", (-1.95, 2.25, 0.92), (0.07, 0.07, 0.2), "scope", emission=0.3)
box("Bench_Med_Box", (-1.4, 2.28, 0.86), (0.25, 0.14, 0.08), "paper")
box("Bench_Med_Cross", (-1.4, 2.2, 0.87), (0.06, 0.01, 0.05), "lamp_red")

# Boxes and junk in the south-east corner.
for i in range(4):
	box("Junk_Box_%d" % i, (2.3 + j(0.1) * 0.05, -2.1 + j(0.1) * 0.1, 0.18 + i * 0.32),
		(0.55 - i * 0.05, 0.45, 0.32), "cardboard", rot=(0, 0, j(10)))
cyl("Junk_Tire_A", (1.7, -2.3, 0.1), 0.3, 0.2, "rubber", verts=12)
cyl("Junk_Tire_B", (1.7, -2.3, 0.3), 0.3, 0.2, "rubber", verts=12, rot=(0, 0, 10))
cyl("Junk_Paint", (1.25, -2.35, 0.15), 0.13, 0.3, "paint_p", verts=10)

# --- west wall: the hunt, the plan, the forgery desk, the hatch -----------------------------
box("Corkboard", (-2.83, 0.3, 1.5), (0.04, 1.5, 0.95), "cork")
box("Corkboard_Frame", (-2.84, 0.3, 1.5), (0.03, 1.58, 1.03), "wood_d")
pins = [(-0.4, 0.25), (0.2, 0.3), (0.55, -0.1), (-0.1, -0.2), (-0.55, -0.25), (0.35, 0.05)]
for i, (dy, dz) in enumerate(pins):
	box("Corkboard_Note_%d" % i, (-2.80, 0.3 + dy, 1.5 + dz), (0.01, 0.2, 0.15 if i % 2 else 0.2),
		"photo" if i == 0 else "paper", rot=(j(6), 0, 0))
for i in range(4):
	a, b = pins[i], pins[i + 1]
	mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
	length = math.hypot(b[0] - a[0], b[1] - a[1])
	ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
	box("Corkboard_String_%d" % i, (-2.79, 0.3 + mid[0], 1.5 + mid[1]), (0.004, length, 0.006), "string", rot=(ang, 0, 0))

box("Clipboard", (-2.83, 1.35, 1.45), (0.02, 0.26, 0.36), "wood_d")
box("Clipboard_Paper", (-2.815, 1.35, 1.43), (0.01, 0.22, 0.28), "paper")
box("Clipboard_Clip", (-2.81, 1.35, 1.6), (0.02, 0.1, 0.04), "metal_l")

box("Desk_Forgery_Top", (-2.45, -1.4, 0.75), (0.75, 1.0, 0.05), "wood")
for y in (-1.85, -0.95):
	box("Desk_Forgery_Leg", (-2.45, y, 0.37), (0.6, 0.05, 0.74), "wood_d")
box("Desk_Forgery_Cloth", (-2.45, -1.4, 0.82), (0.7, 0.9, 0.1), "cloth", rot=(j(2), j(2), 0))

box("Hatch", (-1.85, 0.35, 0.006), (0.9, 0.9, 0.02), "metal_d")
box("Hatch_Rim", (-1.85, 0.35, 0.003), (0.98, 0.98, 0.01), "metal")
box("Hatch_Handle", (-1.45, 0.35, 0.03), (0.03, 0.2, 0.03), "metal_l")
box("Hatch_Lock", (-1.42, 0.5, 0.05), (0.03, 0.06, 0.07), "brass")

# Shelves in the north-west corner.
for i in range(4):
	box("Shelf_%d" % i, (-2.55, 1.9, 0.3 + i * 0.5), (0.6, 0.9, 0.03), "metal_d")
for x in (-2.83, -2.27):
	box("Shelf_Post", (x, 1.9, 1.05), (0.03, 0.03, 1.8), "metal_d")
for i in range(7):
	box("Shelf_Box_%d" % i, (-2.55 + j(0.1) * 0.2, 1.65 + (i % 3) * 0.28, 0.42 + (i // 3) * 0.5),
		(0.4, 0.22, 0.2 + random.random() * 0.08), "cardboard" if i % 2 else "plastic_d", rot=(0, 0, j(6)))

# --- south wall: the roller door (going out) and the door into the house (sleep) -------------
box("Roller_Door", (0.9, -2.62, 1.1), (2.5, 0.06, 2.2), "roller")
for i in range(9):
	box("Roller_Door_Rib_%d" % i, (0.9, -2.58, 0.15 + i * 0.24), (2.5, 0.03, 0.03), "metal_d")
box("Roller_Door_Handle", (0.9, -2.56, 0.25), (0.3, 0.04, 0.04), "metal_l")
box("Roller_Door_Gap", (0.9, -2.6, 0.01), (2.4, 0.05, 0.02), "sodium", emission=1.5)

box("House_Door", (-1.7, -2.62, 1.0), (0.85, 0.06, 2.0), "door")
box("House_Door_Frame", (-1.7, -2.64, 1.02), (0.97, 0.04, 2.08), "wood_d")
cyl("House_Door_Knob", (-1.38, -2.57, 0.98), 0.03, 0.06, "brass", rot=(90, 0, 0), verts=10)
box("House_Door_Gap", (-1.7, -2.6, 0.01), (0.8, 0.05, 0.02), "warm", emission=2.0)
box("Coat_Hook", (-2.3, -2.62, 1.6), (0.3, 0.04, 0.04), "metal_d")
box("Coat", (-2.3, -2.58, 1.25), (0.32, 0.12, 0.65), "tarp", rot=(0, j(3), 0))

# The swivel chair base under you (visible when you look down).
cyl("Chair_Base", (0, 0, 0.05), 0.3, 0.04, "metal_d", verts=5)
cyl("Chair_Post", (0, 0, 0.25), 0.03, 0.4, "metal_d")

# --- export ---------------------------------------------------------------------------------
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "garage_v2.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "garage_v2.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("garage_v2 written")
