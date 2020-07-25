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

# Chunk Parameters
var world
var percentiles
var num_vertices_per_chunk

func _init(p_noise_height, p_noise_moisture, p_chunk_key, p_chunk_size, p_max_height):

#	print("p_noise_height: " + str(p_noise_height))
#	print("p_noise_moisture: " + str(p_noise_moisture))
#	print("p_chunk_key: " + str(p_chunk_key))
#	print("p_chunk_size: " + str(p_chunk_size))
#	print("p_max_height: " + str(p_max_height))

	self.noise_height = p_noise_height
	self.noise_moisture = p_noise_moisture

	self.x = p_chunk_key.x * p_chunk_size
	self.x_grid = p_chunk_key.x
	self.z = p_chunk_key.y * p_chunk_size
	self.z_grid = p_chunk_key.y

	self.chunk_size = p_chunk_size
	self.max_height = p_max_height
	self.chunk_key = p_chunk_key

func _ready():

	# We use this reference a lot, helps with readability
	world = get_node("/root/Main/WorldEnvironment/World")

	# Grab values we use frequently here from parent
	self.percentiles = world.percentiles
	self.num_vertices_per_chunk = world.num_vertices_per_chunk
	self.water_level = percentiles[25]

	# Actually start off generation stuff
	generate_water()
	generate_chunk()

func generate_chunk():

	# TODO: Implement biome blending. This will be a lot of easy-to-mix-up math, but I can figure out exact colors for every blended triangle beforehand.

	# Iterate through each vertex, constructing a 2D array that holds the height (in actual height) and moisture (in noise) for each of the vertices in the plot
	# TODO: This data type is passed by value (no idea why); If this takes up a bunch of processing time this is probably something I'll need to fix
	var ocean = []
	var beach = []
	var lowlands = []
	var highlands = []
	var mountains = []

	# I will never choose a chunk_size that isn't cleanly divisible by the number of vertices, so no weird decimal math should happen here
	# This loop inserts triplets of three vertices to make up each "triangle" of the terrain
	var subgrid_unit_size = chunk_size / num_vertices_per_chunk

#	print("subgrid_unit_size: " + str(subgrid_unit_size))
	for local_x in range(0, chunk_size, subgrid_unit_size):
		for local_z in range(0, chunk_size, subgrid_unit_size):

			# TODO: Implement moisture
			# Get the four vertices around this block; They are what we do calculations with
			var tl_height = world.get_height(x + local_x, 0, z + local_z)
			var tl_pos = Vector3(local_x, tl_height, local_z)
			var tr_height = world.get_height(x + local_x + subgrid_unit_size, 0, z + local_z)
			var tr_pos = Vector3(local_x + subgrid_unit_size, tr_height, local_z)
			var bl_height = world.get_height(x + local_x, 0, z + local_z + subgrid_unit_size)
			var bl_pos = Vector3(local_x, bl_height, local_z + subgrid_unit_size)
			var br_height = world.get_height(x + local_x + subgrid_unit_size, 0, z + local_z + subgrid_unit_size)
			var br_pos = Vector3(local_x + subgrid_unit_size, br_height, local_z + subgrid_unit_size)

			# TODO: Make this more modular by having one master data structure that holds all of this. Can figure out the details when I get there; Currently just trying to make it *work*.
			# Top-left triangle of the current block
			var tl_height_average = (tl_height + tr_height + bl_height) / 3.0
			if tl_height_average >= 0 and tl_height_average <= self.water_level:
				ocean.append(tl_pos)
				ocean.append(tr_pos)
				ocean.append(bl_pos)
			elif tl_height_average > self.water_level and tl_height_average <= percentiles[30]:
				beach.append(tl_pos)
				beach.append(tr_pos)
				beach.append(bl_pos)
			elif tl_height_average > percentiles[30] and tl_height_average <= percentiles[65]:
				lowlands.append(tl_pos)
				lowlands.append(tr_pos)
				lowlands.append(bl_pos)
			elif tl_height_average > percentiles[65] and tl_height_average <= percentiles[85]:
				highlands.append(tl_pos)
				highlands.append(tr_pos)
				highlands.append(bl_pos)
			else:
				mountains.append(tl_pos)
				mountains.append(tr_pos)
				mountains.append(bl_pos)

			# Bottom-right triangle of the current block
			var br_height_average = (tr_height + bl_height + br_height) / 3.0
			if br_height_average >= 0 and br_height_average <= self.water_level:
				ocean.append(tr_pos)
				ocean.append(bl_pos)
				ocean.append(br_pos)
			elif br_height_average > self.water_level and br_height_average <= percentiles[30]:
				beach.append(tr_pos)
				beach.append(bl_pos)
				beach.append(br_pos)
			elif br_height_average > percentiles[30] and br_height_average <= percentiles[65]:
				lowlands.append(tr_pos)
				lowlands.append(bl_pos)
				lowlands.append(br_pos)
			elif br_height_average > percentiles[65] and br_height_average <= percentiles[85]:
				highlands.append(tr_pos)
				highlands.append(bl_pos)
				highlands.append(br_pos)
			else:
				mountains.append(tr_pos)
				mountains.append(bl_pos)
				mountains.append(br_pos)

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

# Does exactly what it says it does, shockingly
func render_set_of_vertices_with_material(vertices, material):

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)

	for vertex in vertices:
		st.add_vertex(vertex)

	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = st.commit()
	# mesh_instance.create_trimesh_collision() # Literally just adds collision ezpz
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

# A bunch of saved code incase I need it:
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


