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

	self.x = chunk_key.x * chunk_size
	self.x_grid = chunk_key.x
	self.z = chunk_key.y * chunk_size
	self.z_grid = chunk_key.y

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
	# generate_water()
	generate_chunk()

func generate_chunk():

	# TODO: Implement biome blending. This will be a lot of easy-to-mix-up math, but I can figure out exact colors for every blended triangle beforehand.

	# Iterate through each vertex, constructing a 2D array that holds the height (in actual height) and moisture (in noise) for each of the vertices in the plot
	# TODO: This data type is passed by value (no idea why); If this takes up a bunch of processing time this is probably something I'll need to fix
	var ocean = PoolVector3Array()
	var beach = PoolVector3Array()
	var lowlands = PoolVector3Array()
	var highlands = PoolVector3Array()
	var mountains = PoolVector3Array()

	var vertex_noise_values = {}
	for local_x in range(0, num_vertices_per_chunk + 1):
		for local_z in range(0, num_vertices_per_chunk + 1):

			# Get it's width and height
			var vertex_height = world_node.noise_to_height(noise_height.get_noise_3d(x + local_x, 0, z + local_z))
			var vertex_moisture = noise_moisture.get_noise_3d(x + local_x, 0, z + local_z)
			var pos_3d = Vector3(local_x, vertex_height, local_z)

			# Ocean (0 to 25th Percentile)
			if vertex_height >= 0 && vertex_height <= self.water_level:
				ocean.append(pos_3d)
				continue

			# Beach (25th to 30th Percentile)
			if vertex_height > self.water_level && vertex_height <= percentiles[30]:
				beach.append(pos_3d)
				continue

			# Lowlands (30th to 65th Percentile)
			if vertex_height > percentiles[30] && vertex_height <= percentiles[65]:
				lowlands.append(pos_3d)
				continue

			# Highlands (65th to 85th Percentile)
			if vertex_height > percentiles[65] && vertex_height <= percentiles[85]:
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

	print("Ocean Vertices: " + str(ocean))
	print("Beach Vertices: " + str(beach))
	print("Lowlands Vertices: " + str(lowlands))
	print("Highlands Vertices: " + str(highlands))
	print("Mountains Vertices: " + str(mountains))

	# Take each list of vertices through the function that'll draw them with the specified material
	render_set_of_vertices_with_material(ocean, ocean_material)
	render_set_of_vertices_with_material(beach, beach_material)
	render_set_of_vertices_with_material(lowlands, lowlands_material)
	render_set_of_vertices_with_material(highlands, highlands_material)
	render_set_of_vertices_with_material(mountains, mountains_material)

# Returns [subdivide_width, subdivide_depth]
func calc_subchunk_dimensions(vertices):

	# First vertex is always our max and min
	var min_x = vertices[0].x
	var max_x = vertices[0].x
	var min_z = vertices[0].z
	var max_z = vertices[0].z

	# Iterate through and find the corners of the smallest square that circles all of them
	for vertex in vertices:
		if vertex.x < min_x:
			min_x = vertex.x
		if vertex.x > max_x:
			max_x = vertex.x
		if vertex.z < min_z:
			min_z = vertex.z
		if vertex.z > max_z:
			max_z = vertex.z

	# Calculate actual subdivide width/depth
	var width = max_x - min_x
	var depth = max_z - min_z
	return Vector2(width, depth)

# Does exactly what it says it does, shockingly
func render_set_of_vertices_with_material(vertices, material):

	print("Material: " + str(material))

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)

	for vertex in vertices:
		print("Adding vertex " + str(vertex) + " to Surface Tool.")
		st.add_uv(Vector2(0, 1))
		st.add_vertex(vertex)
	st.generate_normals()

	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.create_trimesh_collision() # Literally just adds collision ezpz
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF # Don't do shadows, fam
	add_child(mesh_instance)

	# Initialize PlaneMesh to intended values
	# This is like the "prototype" that we can just edit vertex values of to get what we want
#	var plane_mesh = PlaneMesh.new()
#	plane_mesh.size = calc_subchunk_dimensions(vertices)
#	plane_mesh.subdivide_width = chunk_size * (1.0 / num_vertices_per_chunk)
#	plane_mesh.subdivide_depth = chunk_size * (1.0 / num_vertices_per_chunk)
#	plane_mesh.material = material

	# Turn the mesh into something can dan use
#	var surface_tool = SurfaceTool.new() # Godot's approach to drawing mesh from code
#	var data_tool = MeshDataTool.new() # Lets us grab vertices from stuff we already generated
#	surface_tool.create_from(plane_mesh, 0)
#	var array_plane = surface_tool.commit()
#	var _error = data_tool.create_from_surface(array_plane, 0)
#
#	# Feed through SurfaceTool
#	var st = SurfaceTool.new()
#	st.begin(Mesh.PRIMITIVE_TRIANGLES)
#	st.set_material(material)
#	for vertex in vertices:
#		st.add_vertex(vertex)
#
#	# Apply to a mesh
#	var mesh_instance = MeshInstance.new()
#	mesh_instance.mesh = st.commit()
#	mesh_instance.create_trimesh_collision()
#	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF # Don't do shadows, fam
#	add_child(mesh_instance)

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


