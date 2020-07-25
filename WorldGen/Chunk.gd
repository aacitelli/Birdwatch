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

			# Calculate the average height of each triangle
			var tl_height_average = (tl_height + tr_height + bl_height) / 3.0
			var tr_height_average = (tl_height + tr_height + br_height) / 3.0
			var bl_height_average = (tl_height + bl_height + br_height) / 3.0
			var br_height_average = (tr_height + bl_height + br_height) / 3.0

			# Always choose the triangle with the highest average and its complement
			# Top-Left and Bottom-Right (drawn if either of the two is the max)
			if tl_height_average >= tr_height_average and tl_height_average >= bl_height_average and tl_height_average >= br_height_average or br_height_average >= tl_height_average and br_height_average >= tr_height_average and br_height_average >= bl_height_average:

				# Top-Left
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

				# Bottom-Right
				if br_height_average >= 0 and br_height_average <= self.water_level:
					ocean.append(br_pos)
					ocean.append(bl_pos)
					ocean.append(tr_pos)
				elif br_height_average > self.water_level and br_height_average <= percentiles[30]:
					beach.append(br_pos)
					beach.append(bl_pos)
					beach.append(tr_pos)
				elif br_height_average > percentiles[30] and br_height_average <= percentiles[65]:
					lowlands.append(br_pos)
					lowlands.append(bl_pos)
					lowlands.append(tr_pos)
				elif br_height_average > percentiles[65] and br_height_average <= percentiles[85]:
					highlands.append(br_pos)
					highlands.append(bl_pos)
					highlands.append(tr_pos)
				else:
					mountains.append(br_pos)
					mountains.append(bl_pos)
					mountains.append(tr_pos)

			# Top-Right and Bottom Left
			else:

				# Top-Right
				if tr_height_average >= 0 and tr_height_average <= self.water_level:
					ocean.append(tl_pos)
					ocean.append(tr_pos)
					ocean.append(br_pos)
				elif tr_height_average > self.water_level and tr_height_average <= percentiles[30]:
					beach.append(tl_pos)
					beach.append(tr_pos)
					beach.append(br_pos)
				elif tr_height_average > percentiles[30] and tr_height_average <= percentiles[65]:
					lowlands.append(tl_pos)
					lowlands.append(tr_pos)
					lowlands.append(br_pos)
				elif tr_height_average > percentiles[65] and tr_height_average <= percentiles[85]:
					highlands.append(tl_pos)
					highlands.append(tr_pos)
					highlands.append(br_pos)
				else:
					mountains.append(tl_pos)
					mountains.append(tr_pos)
					mountains.append(br_pos)

				# Bottom-Left
				if bl_height_average >= 0 and bl_height_average <= self.water_level:
					ocean.append(br_pos)
					ocean.append(bl_pos)
					ocean.append(tl_pos)
				elif bl_height_average > self.water_level and bl_height_average <= percentiles[30]:
					beach.append(br_pos)
					beach.append(bl_pos)
					beach.append(tl_pos)
				elif bl_height_average > percentiles[30] and bl_height_average <= percentiles[65]:
					lowlands.append(br_pos)
					lowlands.append(bl_pos)
					lowlands.append(tl_pos)
				elif bl_height_average > percentiles[65] and bl_height_average <= percentiles[85]:
					highlands.append(br_pos)
					highlands.append(bl_pos)
					highlands.append(tl_pos)
				else:
					mountains.append(br_pos)
					mountains.append(bl_pos)
					mountains.append(tl_pos)

	# Materials for each biome
	var ocean_material = preload("res:///WorldGen/Biomes/OceanMaterial.tres")
	var beach_material = preload("res:///WorldGen/Biomes/BeachMaterial.tres")
	var lowlands_material = preload("res:///WorldGen/Biomes/LowlandsMaterial.tres")
	var highlands_material = preload("res:///WorldGen/Biomes/HighlandsMaterial.tres")
	var mountains_material = preload("res:///WorldGen/Biomes/MountainsMaterial.tres")

#	print("Ocean Vertices: " + str(ocean))
#	print("Beach Vertices: " + str(beach))
#	print("Lowlands Vertices: " + str(lowlands))
#	print("Highlands Vertices: " + str(highlands))
#	print("Mountains Vertices: " + str(mountains))

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
