extends Spatial
class_name Chunk

# TODO: Figure out what this all does, commenting it all out

# World gen overall variables
var x
var x_grid
var z
var z_grid
var chunk_size

var noise
var should_remove

var MAX_HEIGHT = 100
var water_level = MAX_HEIGHT * .245

# warning-ignore:shadowed_variable
# warning-ignore:shadowed_variable
# warning-ignore:shadowed_variable
# warning-ignore:shadowed_variable
func _init(noise, x, z, chunk_size):
	self.noise = noise
	self.x = x
	self.x_grid = x / chunk_size
	self.z = z
	self.z_grid = z / chunk_size
	self.chunk_size = chunk_size

func _ready():
	generate_water()
	generate_chunk()

# var time_before = OS.get_ticks_usec()
# var total_time = OS.get_ticks_usec() - time_before
# print("generate_chunk(): plane_mesh time taken: " + str(total_time))

func generate_chunk():

	# Create the mesh along with its fundamental characteristics
	# TODO: Docs aren't very helpful as to what some of these characteristics mean, figure them out
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.subdivide_depth = chunk_size * .5
	plane_mesh.subdivide_width = chunk_size * .5
	plane_mesh.material = preload("res://WorldGen/terrain.material")

	# Declaring Godot stuff we're going to use to draw the environment
	var surface_tool = SurfaceTool.new() # Godot's approach to drawing mesh from code
	var data_tool = MeshDataTool.new() # Lets us grab vertices from stuff we already generated

	# Links the overall mesh for the chunk to the surface tool
	surface_tool.create_from(plane_mesh, 0)
	var array_plane = surface_tool.commit()

	# Lets us get information about the vertex we just
	var _error = data_tool.create_from_surface(array_plane, 0)

	# Iterate through every vertex that is in the plane
	for i in range(data_tool.get_vertex_count()):
		var vertex = data_tool.get_vertex(i)
		var noise_value = noise.get_noise_3d(vertex.x + x, vertex.y, vertex.z + z) # Generate noise
		noise_value *= 1.2
		var normalized_noise_value = (noise_value + 1) / 2 # Transform range from [-1, 1] to [0, 1]
		var height_map = pow(normalized_noise_value, 1.6)
		var height_value = height_map * MAX_HEIGHT
		vertex.y = floor(height_value)
		data_tool.set_vertex(i, vertex)

	# Remove everything from the ArrayMesh
	for s in range(array_plane.get_surface_count()):
		array_plane.surface_remove(s)

	# Start actually drawing based on the ArrayMesh we were given
	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals() # Presumably used for collision stuff; Generates what's 90deg from our plane.

	# MeshInstance is the component actually rendered in the world
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = surface_tool.commit() # Set it to whatever's contained in the SurfaceTool
	mesh_instance.create_trimesh_collision() # Literally just adds collision ezpz
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF # Don't do shadows, fam
	add_child(mesh_instance)

func generate_water():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.material = preload("res:///WorldGen/water.material")
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.translation.y = water_level
	add_child(mesh_instance)


