extends RefCounted
## Bakes a navigation mesh at runtime from the static colliders of a level,
## so maps (hand-made now, generated later) never need a pre-baked navmesh.

const CELL := 0.1
const AGENT_RADIUS := 0.3
const AGENT_HEIGHT := 1.8
const AGENT_MAX_CLIMB := 0.2  # must be a multiple of CELL


static func bake(level: Node3D, bounds: AABB) -> NavigationRegion3D:
	var nav := NavigationMesh.new()
	nav.cell_size = CELL
	nav.cell_height = CELL
	nav.agent_radius = AGENT_RADIUS
	nav.agent_height = AGENT_HEIGHT
	nav.agent_max_climb = AGENT_MAX_CLIMB
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.filter_baking_aabb = bounds

	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, level)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)

	var map: RID = level.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL)

	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	region.navigation_mesh = nav
	level.add_child(region)
	return region
