# Placeholder garage for the room (T2a). Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_garage.py
# Writes art/src/garage.blend (for the user to tweak) and art/garage.glb (what Godot loads).
# Blender coords: X right, Y away from the player, Z up. The player sits near the origin facing +Y.
# Object names matter: terminal/room3d.gd looks them up (Screen, Laptop_Lid, Notebook, ...).

import bpy
import math
import os
import random

random.seed(7)
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)

bpy.ops.wm.read_factory_settings(use_empty=True)

# --- palette (one place to change every color) --------------------------------------------
PAL = {
	"concrete": (0.30, 0.29, 0.27), "wall": (0.36, 0.34, 0.30), "board": (0.28, 0.24, 0.19),
	"bench": (0.42, 0.29, 0.18), "bench_dark": (0.26, 0.18, 0.11), "metal": (0.38, 0.40, 0.42),
	"metal_dark": (0.16, 0.17, 0.18), "red": (0.55, 0.12, 0.10), "laptop": (0.10, 0.10, 0.11),
	"screen": (0.05, 0.08, 0.10), "cardboard": (0.62, 0.46, 0.28), "paper": (0.88, 0.85, 0.75),
	"sticky": (0.95, 0.85, 0.30), "mug": (0.70, 0.72, 0.65), "lamp": (0.20, 0.32, 0.28),
	"shade_in": (1.0, 0.9, 0.7), "door": (0.33, 0.27, 0.22), "glass": (0.10, 0.16, 0.24),
	"jacket": (0.16, 0.20, 0.17), "bike": (0.65, 0.20, 0.45), "tire": (0.06, 0.06, 0.06),
	"calendar": (0.85, 0.82, 0.70), "marshal": (0.45, 0.20, 0.18), "street": (0.08, 0.09, 0.12),
	"house": (0.20, 0.20, 0.22), "warm_window": (1.0, 0.75, 0.35), "can": (0.30, 0.45, 0.55),
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
	c = [_lin(v) for v in PAL[name]]   # palette is written in screen (sRGB) colors; Blender wants linear
	bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
	bsdf.inputs["Roughness"].default_value = 0.85
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


def cone(name, center, r1, r2, depth, color, rot=(0, 0, 0), verts=8):
	bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=center)
	return _finish(bpy.context.active_object, name, color, rot)


def jitter(deg=4.0):
	return random.uniform(-deg, deg)


# --- the room shell ------------------------------------------------------------------------
box("Floor", (0, -0.6, -0.05), (5.2, 4.0, 0.1), "concrete")
# Front wall in four pieces around the window opening (x 1.35..2.25, z 1.25..1.95).
box("Wall_Front", (-0.625, 1.25, 1.3), (3.95, 0.1, 2.6), "wall")
box("Wall_Front_R", (2.425, 1.25, 1.3), (0.35, 0.1, 2.6), "wall")
box("Wall_Front_Top", (1.8, 1.25, 2.275), (0.9, 0.1, 0.65), "wall")
box("Wall_Front_Low", (1.8, 1.25, 0.625), (0.9, 0.1, 1.25), "wall")
box("Wall_Left", (-2.55, -0.6, 1.3), (0.1, 4.0, 2.6), "wall")
box("Wall_Right", (2.55, -0.6, 1.3), (0.1, 4.0, 2.6), "wall")
box("Wall_Back", (0, -2.6, 1.3), (5.2, 0.1, 2.6), "wall")
box("Ceiling", (0, -0.6, 2.65), (5.2, 4.0, 0.1), "board")
for i in range(6):   # wall boards (vertical battens)
	box("Batten_%d" % i, (-2.2 + i * 0.85, 1.19, 1.3), (0.06, 0.03, 2.6), "board")
for i in range(3):   # roof beams
	box("Beam_%d" % i, (0, -1.8 + i * 1.3, 2.52), (5.2, 0.12, 0.16), "board")

# --- the bench -----------------------------------------------------------------------------
box("Bench_Top", (-0.2, 0.85, 0.88), (2.9, 0.62, 0.06), "bench")
box("Bench_Shelf", (-0.2, 0.9, 0.25), (2.8, 0.55, 0.04), "bench_dark")
for x in (-1.55, 1.15):
	for y in (0.6, 1.1):
		box("Bench_Leg", (x, y, 0.43), (0.07, 0.07, 0.86), "bench_dark", rot=(0, jitter(1.5), 0))
box("Bench_Backboard", (-0.2, 1.17, 1.0), (2.9, 0.04, 0.2), "bench_dark")

# --- the laptop (hinged at the back of the base, lid tilted back 15 degrees) ---------------
LX, LY, LZ = 0.0, 0.74, 0.92
box("Laptop_Base", (LX, LY, LZ), (0.34, 0.23, 0.018), "laptop", rot=(0, 0, jitter(2)))
box("Laptop_Keys", (LX, LY - 0.02, LZ + 0.01), (0.29, 0.11, 0.004), "metal_dark")
hinge_y, hinge_z = LY + 0.115, LZ + 0.009
tilt = 75.0
up = (0.0, math.cos(math.radians(tilt)), math.sin(math.radians(tilt)))
nrm = (0.0, -math.sin(math.radians(tilt)), math.cos(math.radians(tilt)))
lid_h = 0.235
cy, cz = hinge_y + up[1] * lid_h / 2, hinge_z + up[2] * lid_h / 2
# The lid box: local Y is its height, local Z its thickness. Rotating X by the tilt stands it up, leaning back.
box("Laptop_Lid", (LX, cy - nrm[1] * 0.004, cz - nrm[2] * 0.004), (0.34, lid_h, 0.012), "laptop", rot=(tilt, 0, 0))
# Screen quad: 16:9, in front of the lid face (towards the player).
bpy.ops.mesh.primitive_plane_add(size=1, location=(LX + nrm[0] * 0.0, cy + nrm[1] * 0.0075, cz + nrm[2] * 0.0075))
scr = bpy.context.active_object
scr.scale = (0.30, 0.169, 1.0)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
scr.name = "Screen"
scr.rotation_euler = (math.radians(tilt), 0, 0)
sm = bpy.data.materials.new("ScreenMat")
sm.use_nodes = True
sm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.05, 0.08, 0.1, 1)
scr.data.materials.append(sm)

# --- things on the bench -------------------------------------------------------------------
# Lamp (right of the laptop): base, arm, shade pointing down at the work area.
cyl("Lamp_Base", (0.48, 0.98, 0.93), 0.07, 0.03, "lamp")
box("Lamp_Arm", (0.45, 0.9, 1.18), (0.02, 0.02, 0.5), "lamp", rot=(-20, 0, 8))
cone("Lamp_Shade", (0.38, 0.76, 1.38), 0.11, 0.04, 0.14, "lamp", rot=(-25, 0, 0))
cyl("Mug", (-0.32, 0.66, 0.96), 0.04, 0.09, "mug", verts=10)
box("Notebook", (-0.36, 0.6, 0.918), (0.15, 0.21, 0.015), "paper", rot=(0, 0, 12 + jitter(3)))
box("Notebook_Cover", (-0.36, 0.6, 0.927), (0.152, 0.212, 0.003), "red", rot=(0, 0, 12 + jitter(3)))
box("StickyNote", (0.24, 0.6, 0.913), (0.07, 0.07, 0.003), "sticky", rot=(0, 0, -8))
box("Charger", (0.3, 1.04, 0.935), (0.1, 0.06, 0.03), "laptop", rot=(0, 0, 20))
box("Charger_Cable", (0.16, 0.95, 0.915), (0.22, 0.012, 0.01), "laptop", rot=(0, 0, 35))
# Pavel's box (left on the bench), flaps open.
box("PavelsBox", (-0.95, 0.82, 1.06), (0.42, 0.32, 0.3), "cardboard", rot=(0, 0, 6))
box("PavelsBox_Flap1", (-0.95, 0.62, 1.25), (0.42, 0.02, 0.16), "cardboard", rot=(-35, 0, 6))
box("PavelsBox_Flap2", (-0.95, 1.02, 1.25), (0.42, 0.02, 0.16), "cardboard", rot=(35, 0, 6))
box("PavelsPhone", (-0.62, 0.62, 0.918), (0.07, 0.14, 0.01), "metal_dark", rot=(0, 0, -20))
# Toolbox and vise on the far left.
box("Toolbox", (-1.42, 0.85, 1.0), (0.36, 0.2, 0.18), "red", rot=(0, 0, -4))
box("Toolbox_Handle", (-1.42, 0.85, 1.13), (0.22, 0.02, 0.03), "metal_dark", rot=(0, 0, -4))
box("Vise", (-1.62, 0.65, 0.97), (0.12, 0.16, 0.12), "metal", rot=(0, 0, 3))

# Pegboard with tool silhouettes above the left of the bench.
box("Pegboard", (-1.0, 1.17, 1.55), (1.2, 0.02, 0.7), "board")
for i, (w, h, c) in enumerate([(0.05, 0.3, "metal"), (0.04, 0.25, "red"), (0.22, 0.04, "metal"), (0.06, 0.34, "metal_dark"), (0.03, 0.2, "red")]):
	box("Tool_%d" % i, (-1.45 + i * 0.22, 1.15, 1.6 + jitter(0.02) * 3), (w, 0.02, h), c, rot=(0, jitter(8), 0))

# Calendar with the Marshal's face, right of the laptop.
box("Calendar", (0.85, 1.19, 1.5), (0.32, 0.01, 0.42), "calendar", rot=(0, jitter(3), 0))
box("Calendar_Marshal", (0.85, 1.18, 1.6), (0.18, 0.01, 0.16), "marshal", rot=(0, jitter(3), 0))

# --- window (front wall, right) with the street and Bruno's lit window behind it ----------
for nm, c, s in [("Window_Frame_T", (1.8, 1.2, 1.93), (0.92, 0.08, 0.05)), ("Window_Frame_B", (1.8, 1.2, 1.27), (0.92, 0.1, 0.05)),
		("Window_Frame_L", (1.37, 1.2, 1.6), (0.05, 0.08, 0.7)), ("Window_Frame_R", (2.23, 1.2, 1.6), (0.05, 0.08, 0.7)),
		("Window_Frame_M", (1.8, 1.2, 1.6), (0.03, 0.06, 0.66))]:
	box(nm, c, s, "door")
box("Window_Glass", (1.8, 1.22, 1.6), (0.86, 0.01, 0.66), "glass")
box("Street", (1.8, 2.6, 1.3), (3.0, 0.1, 2.6), "street")
box("BrunosHouse", (1.6, 2.5, 1.2), (1.4, 0.1, 1.2), "house")
box("BrunosWindow", (1.9, 2.44, 1.45), (0.3, 0.02, 0.25), "warm_window", emission=3.0)

# --- right wall: the door to the house, the coat hook, Lena's bike -------------------------
box("Door", (2.49, -0.6, 1.0), (0.05, 0.9, 2.0), "door")
box("Door_Frame", (2.5, -0.6, 1.02), (0.04, 1.0, 2.08), "board")
cyl("Door_Knob", (2.45, -0.25, 1.0), 0.03, 0.06, "metal", rot=(0, 90, 0))
box("Coat_Hook", (2.5, 0.25, 1.75), (0.04, 0.3, 0.03), "metal_dark")
box("PavelsJacket", (2.45, 0.25, 1.4), (0.1, 0.42, 0.65), "jacket", rot=(jitter(4), 0, 0))
for i, y in enumerate((-1.6, -2.3)):
	cyl("Bike_Wheel_%d" % i, (2.35, y, 0.33), 0.3, 0.04, "tire", rot=(0, 90, 0), verts=12)
box("Bike_Frame", (2.35, -1.95, 0.55), (0.04, 0.75, 0.05), "bike", rot=(20, 0, 0))
box("Bike_Seat", (2.35, -2.05, 0.85), (0.08, 0.2, 0.04), "tire")

# --- left wall: shelves with paint cans ----------------------------------------------------
for s in range(3):
	z = 0.6 + s * 0.55
	box("Shelf_%d" % s, (-2.35, -0.8, z), (0.35, 1.4, 0.03), "board")
	for c in range(4):
		cyl("Can_%d_%d" % (s, c), (-2.35, -1.3 + c * 0.32 + jitter(0.03), z + 0.1), 0.07, 0.17, "can" if (s + c) % 2 else "red", verts=10)

# --- save -----------------------------------------------------------------------------------
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "garage.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "garage.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("GARAGE OK")
