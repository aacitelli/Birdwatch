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
var water_level

var world_node
var percentiles

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

	# We use this reference a lot, helps with readability
	world_node = get_node("/root/Main/WorldEnvironment/World")

	# Grab values we use frequently here from parent
	self.percentiles = world_node.percentiles
	self.water_level = percentiles[25]

	# Actually start off generation stuff
	generate_water()
	generate_chunk()

func generate_chunk():

	# TODO: Implement biome blending. This will be a lot of easy-to-mix-up math, but I can figure out exact colors for every blended triangle beforehand.

	# Iterate through each vertex, constructing a 2D array that holds the height (in actual height) and moisture (in noise) for each of the vertices in the plot
	# Nothing computationally expensive in this loop, noise is (relatively) super cheap to generate
	var vertex_noise_values = {}
	for local_x in range(0, num_vertices_per_chunk + 1): # One more vertex than face. End of range() is exclusive
		for local_z in range(0, num_vertices_per_chunk + 1):
			var pos = Vector2(local_x, local_z)
			vertex_noise_values[pos] = {}
			vertex_noise_values[pos].height = world_node.noise_to_height(noise_height.get_noise_3d(x + local_x, 0, z + local_z))
			vertex_noise_values[pos].moisture = noise_moisture.get_noise_3d(x + local_x, 0, z + local_z)
			# print("vertex at coords " + str(pos) + " has height " + str(vertex_noise_values[pos].height) + " and moisture " + str(vertex_noise_values[pos].moisture) + ".")

	# Iterate through each "square", appending the coordinates of that square to our records for each biome
	# Nothing computationally expensive in this loop either, dictionary access is constant time
	var ocean = []
	var beach = []
	var lowlands = []
	var highlands = []
	var mountains = []
	for local_x in range(0, num_vertices_per_chunk):
		for local_z in range(0, num_vertices_per_chunk):
			var pos_2d = Vector2(local_x, local_z)
			var pos_3d = Vector3(local_x, vertex_noise_values[pos_2d].height, local_z)

			# Ocean (0 to 25th Percentile)
			if vertex_noise_values[pos_2d].height >= 0 && vertex_noise_values[pos_2d].height <= self.water_level:
				ocean.append(pos_3d)
				continue

			# Beach (25th to 30th Percentile)
			if vertex_noise_values[pos_2d].height > self.water_level && vertex_noise_values[pos_2d].height <= percentiles[30]:
				beach.append(pos_3d)
				continue

			# Lowlands (30th to 65th Percentile)
			if vertex_noise_values[pos_2d].height > percentiles[30] && vertex_noise_values[pos_2d].height <= percentiles[65]:
				lowlands.append(pos_3d)
				continue

			# Highlands (65th to 85th Percentile)
			if vertex_noise_values[pos_2d].height > percentiles[65] && vertex_noise_values[pos_2d].height <= percentiles[85]:
				highlands.append(pos_3d)
				continue

			# Mountains (85th Percentile Up)
			else:
				mountains.append(pos_3d)
				continue

	# Materials for each biome
	var ocean_material = preload("res:///WorldGen/Biomes/OceanMaterial.tres")
	var beach_material = preload("res:///WorldGen/Biomes/BeachMaterial.tres")
	var lowlands_material = preload("res:///WorldGen/Biomes/LowlandsMaterial.tres")
	var highlands_material = preload("res:///WorldGen/Biomes/HighlandsMaterial.tres")
	var mountains_material = preload("res:///WorldGen/Biomes/MountainsMaterial.tres")

	# Take each list of vertices through the function that'll draw them with the specified material
	render_set_of_vertices_with_material(ocean, ocean_material)
	render_set_of_vertices_with_material(beach, beach_material)
	render_set_of_vertices_with_material(lowlands, lowlands_material)
	render_set_of_vertices_with_material(highlands, highlands_material)
	render_set_of_vertices_with_material(mountains, mountains_material)

# Returns [width, depth]
func calc_chunk_subdivide_params(vertices):
	var returnArr

	var min_vertex = vertices[0]
	var max_vertex = vertices[0]
	for vertex in vertices:
		if vertex.x < min_vertex.x:
			min_vertex = vertex
	return min_vertex

func max_x(vertices):
	var max_vertex = vertices[0]
	for vertex in vertices:
		if vertex.x > max_vertex.x:
			max_vertex = vertex
	return max_vertex

func min_z(vertices):
	var min_vertex = vertices[0]
	for vertex in vertices:
		if vertex.z < min_vertex.z:
			min_vertex = vertex
	return min_vertex

func max_z(vertices):
	var max_vertex = vertices[0]
	for vertex in vertices:
		if vertex.z > max_vertex.z:
			max_vertex = vertex
	return max_vertex

# Does exactly what it says it does, shockingly
func render_set_of_vertices_with_material(vertices, material):

	# Specify the size and amount of vertices in each chunk. subdivide_width of 16 means a 16x16 grid in each chunk.
	# Set subdivide width based on the biome size, not full chunk size
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.subdivide_depth = max_x(vertices) - min_x(vertices)
	plane_mesh.subdivide_width = max_z(vertices) - min_z(vertices)
	plane_mesh.material = material

	# Feed through SurfaceTool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	for vertex in vertices:
		st.add_vertex(vertex)

	# Apply to a mesh
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.create_trimesh_collision()
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF # Don't do shadows, fam
	add_child(mesh_instance)

#	# Declaring Godot stuff we're going to use to draw the environment
#	var surface_tool = SurfaceTool.new() # Godot's approach to drawing mesh from code
#	var data_tool = MeshDataTool.new() # Lets us grab vertices from stuff we already generated
#
#	# Links the overall mesh for the chunk to the surface tool
#	surface_tool.create_from(plane_mesh, 0)
#	var array_plane = surface_tool.commit()
#
#	# Lets us get information about the vertex we just
#	var _error = data_tool.create_from_surface(array_plane, 0)
#
#	# Iterate through every vertex that is in the plane
#	for i in range(data_tool.get_vertex_count()):
#		var vertex = data_tool.get_vertex(i)
#		vertex.y = world_node.noise_to_height(noise_height.get_noise_3d(vertex.x + x, vertex.y, vertex.z + z))
#		data_tool.set_vertex(i, vertex)
#
#	# Remove everything from the ArrayMesh
#	for s in range(array_plane.get_surface_count()):
#		array_plane.surface_remove(s)
#
#	# Start actually drawing based on the ArrayMesh we were given
#	data_tool.commit_to_surface(array_plane)
#	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
#	surface_tool.create_from(array_plane, 0)
#	surface_tool.generate_normals() # Used under the hood for collision stuff, presumably
#
#	# MeshInstance is the component actually rendered in the world
#	# var mesh_instance = MeshInstance.new()
#	mesh_instance.mesh = surface_tool.commit() # Set it to whatever's contained in the SurfaceTool
#	mesh_instance.create_trimesh_collision() # Literally just adds collision ezpz
#	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF # Don't do shadows, fam
#	add_child(mesh_instance)

func generate_water():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.material = preload("res:///WorldGen/water.material")
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.translation.y = water_level
	add_child(mesh_instance)


