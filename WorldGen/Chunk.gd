extends Spatial
class_name Chunk

# TODO: Figure out what this all does, commenting it all out

# Constructor variables
var x
var x_grid
var z
var z_grid
var chunk_size
var max_height
var chunk_key

var noise_height
var noise_moisture
var should_remove
var percentiles
var water_level

const num_vertices_per_chunk = 4

func _init(noise_height, noise_moisture, chunk_key, chunk_size, max_height):

	self.noise_height = noise_height
	self.noise_moisture = noise_moisture

	self.x = chunk_key.x
	self.x_grid = chunk_key.x / chunk_size
	self.z = chunk_key.y
	self.z_grid = chunk_key.y / chunk_size

	self.chunk_size = chunk_size
	self.max_height = max_height
	self.chunk_key = chunk_key

func _ready():

	# Grab this value from the parent (ready function ensures parent is also ready)
	self.water_level = get_node("/root/Main/WorldEnvironment/World").percentiles[25]

	# Actually start off generation stuff
	generate_water()
	generate_chunk()

# var time_before = OS.get_ticks_usec()
# var total_time = OS.get_ticks_usec() - time_before
# print("generate_chunk(): plane_mesh time taken: " + str(total_time))

func generate_chunk():

	# TODO: Implement biome blending. This will be a lot of easy-to-mix-up math, but I can figure out exact colors for every blended triangle beforehand.

	# Iterate through each vertex, constructing a 2D array that holds the height (in actual height) and moisture (in noise) for each of the vertices in the plot
	var vertex_noise_values = []
	for local_x in range(0, num_vertices_per_chunk + 1): # One more vertex than face. End of range() is exclusive
		for local_z in range(0, num_vertices_per_chunk + 1):
			vertex_noise_values = [
				get_node("/root/Main/WorldEnvironment/World").noise_to_height(noise_height.get_noise_3d(x + local_x, 0, z + local_z)),
				noise_moisture.get_noise_3d(x + local_x, 0, z + local_z)
			]
			print(vertex_noise_values)

	# Iterate through each "square", appending the coordinates of that square to our records for each biome
	var ocean = []
	var beach = []
	var lowlands = []
	var highlands = []
	var mountains = []

	# Iterate through each biome, making one big PlaneMesh for the entire biome and assigning that biome's material all in one go

	# Specify the size and amount of vertices in each chunk. subdivide_width of 16 means a 16x16 grid in each chunk.
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.subdivide_depth = chunk_size * (1.0 / num_vertices_per_chunk)
	plane_mesh.subdivide_width = chunk_size * (1.0 / num_vertices_per_chunk)

	# Well, Godot doesn't support passing arrays into shaders, so this is the hacky approach...
	# See issue here https://github.com/godotengine/godot/issues/10751
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
		vertex.y = get_node("/root/Main/WorldEnvironment/World").noise_to_height(noise_height.get_noise_3d(vertex.x + x, vertex.y, vertex.z + z))
		data_tool.set_vertex(i, vertex)

	# Remove everything from the ArrayMesh
	for s in range(array_plane.get_surface_count()):
		array_plane.surface_remove(s)

	# Start actually drawing based on the ArrayMesh we were given
	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals() # Used under the hood for collision stuff, presumably

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


