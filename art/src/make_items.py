# Crafted items as low-poly models (2026-11-23, from the GPT sheets in docs/refs/polish: ELECTRONICS / TWO TIERS,
# CLOTH / PREPARATION + SUPPLIES, GEAR 01 / RECLAIMED TOTE, GEAR 02 / FIELD HARNESS).
# Each item is one top-level object named Item_*, sitting on the ground plane at the origin, in metres.
# The bench shows the finished item under its lamp (v2/world/bench_work.gd show_item). Run with Blender 5.3:
#   blender --background --factory-startup --python art/src/make_items.py
# Writes art/src/items.blend (for the user to tweak) and art/items.glb (what Godot loads).
# Blender coords: X right, Y away, Z up.

import bpy
import math
import os
import random

random.seed(5)
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)

PAL = {
	"olive": (0.42, 0.44, 0.2), "olive_d": (0.3, 0.32, 0.14), "perf": (0.6, 0.36, 0.17), "pcb_b": (0.14, 0.26, 0.6),
	"pcb_g": (0.12, 0.42, 0.2), "chip": (0.08, 0.08, 0.09), "batt": (0.74, 0.74, 0.76), "batt_y": (0.92, 0.72, 0.22),
	"cap": (0.32, 0.22, 0.5), "res": (0.82, 0.62, 0.38), "wire_r": (0.8, 0.12, 0.08), "wire_k": (0.06, 0.06, 0.06),
	"usb": (0.72, 0.72, 0.74), "led": (0.4, 1.0, 0.35), "lcd": (0.62, 0.8, 0.3), "bezel": (0.1, 0.1, 0.1),
	"plug": (0.9, 0.88, 0.8), "screw": (0.6, 0.6, 0.62), "tape": (0.82, 0.76, 0.58),
	"cloth": (0.86, 0.82, 0.7), "twine": (0.72, 0.55, 0.28), "pouch": (0.62, 0.52, 0.34), "red": (0.72, 0.12, 0.08),
	"strap": (0.32, 0.34, 0.18), "woven": (0.2, 0.44, 0.52), "cream": (0.84, 0.78, 0.62), "yellow": (0.86, 0.62, 0.2),
	"field": (0.42, 0.38, 0.24), "black": (0.1, 0.1, 0.11), "steel": (0.55, 0.57, 0.6),
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
	b = m.node_tree.nodes.get("Principled BSDF")
	c = [_lin(v) for v in PAL[name]]
	b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
	b.inputs["Roughness"].default_value = 0.85
	if emission:
		b.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1.0)
		b.inputs["Emission Strength"].default_value = emission
	_mats[key] = m
	return m


class Item:
	"""Collects boxes and cylinders, then joins them into one object named Item_*."""

	def __init__(self, name):
		self.name = name
		self.parts = []

	def box(self, c, s, col, rot=(0, 0, 0), emission=0.0):
		bpy.ops.mesh.primitive_cube_add(size=1, location=c)
		o = bpy.context.active_object
		o.scale = s
		o.rotation_euler = [math.radians(a) for a in rot]
		o.data.materials.append(mat(col, emission))
		self.parts.append(o)
		return self

	def cyl(self, c, r, d, col, rot=(0, 0, 0), verts=8, emission=0.0):
		bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=c)
		o = bpy.context.active_object
		o.rotation_euler = [math.radians(a) for a in rot]
		o.data.materials.append(mat(col, emission))
		self.parts.append(o)
		return self

	def build(self):
		bpy.ops.object.select_all(action="DESELECT")
		for o in self.parts:
			o.select_set(True)
		bpy.context.view_layer.objects.active = self.parts[0]
		bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
		bpy.ops.object.join()
		o = bpy.context.active_object
		o.name = self.name
		bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
		return o


def case(it, w, d, h, lid_angle, col="olive"):
	"""The olive hard case from the sheet: a tray with walls, screws, a lid hinged at the back."""
	t = 0.006
	it.box((0, 0, t / 2), (w, d, t), col)
	for sx in (-1, 1):
		it.box((sx * (w / 2 - t / 2), 0, h / 2), (t, d, h), col)
	for sy in (-1, 1):
		it.box((0, sy * (d / 2 - t / 2), h / 2), (w, t, h), col)
	it.box((0, -d / 2 - 0.002, h * 0.5), (0.03, 0.006, h * 0.5), "olive_d")          # latch
	it.box((w * 0.32, -d / 2 - 0.001, h * 0.45), (0.04, 0.003, 0.025), "tape", rot=(0, 18, 0))   # worn tape
	a = math.radians(lid_angle)
	lh = 0.012
	cy = d / 2 + math.sin(a) * 0  # hinge at the back top edge
	it.box((0, d / 2 - math.cos(a) * d / 2, h + math.sin(a) * d / 2), (w, d, lh), col, rot=(lid_angle, 0, 0))
	for sx in (-1, 1):
		for sy in (-1, 1):
			it.cyl((sx * (w / 2 - 0.012), sy * (d / 2 - 0.012), h * 0.3), 0.004, 0.003, "screw", verts=6)


# --- electronics: the gadget box, two tiers ----------------------------------------------------------
it = Item("Item_Gadget_Starter")
case(it, 0.15, 0.09, 0.03, 70)
it.box((-0.02, 0.0, 0.012), (0.09, 0.07, 0.003), "perf")                                     # perfboard
it.box((-0.02, -0.008, 0.017), (0.055, 0.022, 0.006), "pcb_b")                               # the controller
it.box((-0.02, -0.008, 0.021), (0.012, 0.012, 0.003), "chip")
it.box((-0.06, -0.008, 0.017), (0.012, 0.012, 0.007), "usb")                                 # usb socket
for k in range(3):
	it.cyl((-0.045 + k * 0.012, 0.022, 0.017), 0.003, 0.012, "res", rot=(0, 90, 0), verts=6)    # resistors
it.cyl((0.0, 0.025, 0.022), 0.007, 0.016, "cap", verts=8)                                    # capacitor
it.cyl((0.01, -0.025, 0.017), 0.003, 0.002, "led", verts=6, emission=3.0)                    # status led
it.box((0.045, 0.0, 0.02), (0.035, 0.06, 0.022), "batt")                                     # battery pack
it.box((0.045, 0.026, 0.02), (0.037, 0.012, 0.024), "batt_y")
it.box((0.022, 0.012, 0.019), (0.02, 0.003, 0.003), "wire_r", rot=(0, 0, 30))
it.box((0.022, 0.004, 0.019), (0.02, 0.003, 0.003), "wire_k", rot=(0, 0, 20))
it.build()

it = Item("Item_Gadget_Upgraded")
case(it, 0.15, 0.09, 0.03, 70)
it.box((0.0, 0.0, 0.012), (0.13, 0.075, 0.003), "pcb_g")                                     # proper board
it.box((0.0, 0.0, 0.016), (0.03, 0.03, 0.005), "chip")                                       # the controller
for k in range(2):
	it.box((-0.04, -0.015 + k * 0.03, 0.016), (0.014, 0.012, 0.004), "chip")
for k in range(2):
	it.box((0.055, -0.015 + k * 0.03, 0.018), (0.012, 0.016, 0.009), "plug")                   # connectors
it.box((0.025, -0.025, 0.015), (0.012, 0.006, 0.004), "screw")                               # crystal
it.cyl((0.04, 0.028, 0.016), 0.003, 0.003, "led", verts=6, emission=3.0)
it.box((0.0, -0.049, 0.018), (0.02, 0.006, 0.01), "usb")                                     # usb out the front
# the screen in the lid, with its ribbon
a = math.radians(70)
it.box((0, 0.045 - math.cos(a) * 0.045, 0.03 + math.sin(a) * 0.045 + 0.001), (0.07, 0.036, 0.008), "bezel", rot=(70, 0, 0))
it.box((0, 0.045 - math.cos(a) * 0.045 - 0.005, 0.03 + math.sin(a) * 0.045 + 0.002), (0.055, 0.024, 0.004), "lcd", rot=(70, 0, 0), emission=1.5)
for k, c in enumerate(("wire_r", "batt_y", "wire_k")):
	it.box((-0.006 + k * 0.006, 0.035, 0.03), (0.005, 0.003, 0.03), c, rot=(-20, 0, 0))
it.build()

# --- the drop stick: a USB stick wrapped in tape ------------------------------------------------------
it = Item("Item_Drop_Stick")
it.box((0, 0, 0.006), (0.055, 0.02, 0.01), "black")
it.box((0.034, 0, 0.006), (0.014, 0.012, 0.005), "usb")
it.box((-0.005, 0, 0.0115), (0.03, 0.021, 0.002), "tape", rot=(0, 0, 4))
it.build()

# --- cloth: a tied roll, strips, a med pouch (starter and upgraded) -----------------------------------
it = Item("Item_Roll_Tied")
it.cyl((0, 0, 0.03), 0.03, 0.09, "cloth", rot=(0, 90, 0), verts=10)
it.cyl((0.0, 0, 0.03), 0.018, 0.092, "cloth", rot=(0, 90, 0), verts=8)
for x in (-0.025, 0.025):
	it.cyl((x, 0, 0.03), 0.032, 0.006, "twine", rot=(0, 90, 0), verts=10)
it.box((0.0, -0.035, 0.004), (0.05, 0.03, 0.002), "cloth", rot=(0, 0, 8))                    # loose tail
it.build()

it = Item("Item_Strips")
for k in range(3):
	it.box((0, -0.03 + k * 0.03, 0.002 + k * 0.001), (0.16, 0.024, 0.002), "cloth", rot=(0, 0, random.uniform(-6, 6)))
it.build()

it = Item("Item_MedPouch")
it.box((0, 0, 0.04), (0.12, 0.05, 0.08), "pouch")
it.box((0, -0.004, 0.083), (0.122, 0.055, 0.012), "pouch")                                    # flap
it.box((0, -0.026, 0.06), (0.024, 0.004, 0.05), "strap")                                      # olive strap
it.box((0, -0.029, 0.048), (0.018, 0.004, 0.016), "red")                                      # red tab
it.build()

it = Item("Item_MedPouch_Upgraded")
it.box((0, 0, 0.045), (0.14, 0.06, 0.09), "pouch")
it.box((0, -0.004, 0.093), (0.142, 0.066, 0.012), "pouch")
for x in (-0.035, 0.035):
	it.box((x, -0.031, 0.06), (0.018, 0.004, 0.07), "strap")
it.box((0, -0.032, 0.07), (0.022, 0.004, 0.022), "red")
it.build()

# --- gear: the tote rig and the field harness as flat bench pieces ------------------------------------
it = Item("Item_Tote_Rig")
it.box((0, 0, 0.03), (0.3, 0.09, 0.06), "woven")
for k, (x, w) in enumerate(((-0.1, 0.075), (0.0, 0.1), (0.1, 0.075))):
	it.box((x, -0.05, 0.03), (w, 0.02, 0.055), "woven")
	it.box((x, -0.061, 0.03), (w, 0.003, 0.012), "cream")
	it.box((x, -0.052, 0.058), (w * 0.95, 0.025, 0.006), "woven")
for x in (-0.09, 0.09):
	it.box((x, 0.12, 0.004), (0.04, 0.18, 0.004), "strap")
	it.box((x, 0.035, 0.064), (0.04, 0.02, 0.008), "yellow")
it.box((0.16, 0, 0.04), (0.012, 0.025, 0.04), "red")
it.build()

it = Item("Item_Harness")
it.box((0, 0, 0.03), (0.32, 0.08, 0.06), "field")
for k in range(3):
	x = -0.08 + k * 0.08
	it.box((x, -0.05, 0.03), (0.07, 0.02, 0.055), "field")
	it.box((x, -0.05, 0.07), (0.05, 0.016, 0.03), "black")
for x in (-0.1, 0.1):
	it.box((x, 0.13, 0.004), (0.045, 0.2, 0.004), "field")
it.build()

# --- the gun bench: a rough upper ---------------------------------------------------------------------
it = Item("Item_Upper")
it.box((0, 0, 0.025), (0.22, 0.045, 0.05), "steel")
it.box((0.02, -0.0235, 0.03), (0.07, 0.002, 0.018), "black")                                  # ejection port
it.cyl((0.13, 0, 0.03), 0.009, 0.06, "steel", rot=(0, 90, 0), verts=8)
it.build()

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "items.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(ART, "items.glb"), export_format="GLB", export_apply=True, export_yup=True)
print("items written")
