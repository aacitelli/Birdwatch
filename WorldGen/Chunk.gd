extends Spatial
class_name Chunk

# Constructor variables
var x
var x_grid
var z
var z_grid
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
var chunk_size

var color_black = Color(0, 0, 0)
var color_dark_gray = Color(64, 64, 64)
var color_gray = Color(128, 128, 128)
var color_light_gray = Color(196, 196, 196)
var color_white = Color(240, 240, 240)

func _init(p_noise_height, p_noise_moisture, p_chunk_key, p_chunk_size, p_max_height):

	self.noise_height = p_noise_height
	self.noise_moisture = p_noise_moisture
	self.chunk_size = p_chunk_size

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
	var ocean_colors = PoolColorArray()
	var beach_colors = PoolColorArray()
	var lowlands_colors = PoolColorArray()
	var highlands_colors = PoolColorArray()
	var mountains_colors = PoolColorArray()

	# The amount of width/depth that is in between each actual vertex. Basically a grid inside the main chunk grid, hence "subgrid"
	var subgrid_unit_size = 1.0 * chunk_size / num_vertices_per_chunk

	# TODO: This chunk shares edge vertices with other chunks. Don't do the noise calculation twice for these. (This can be done way down the road b/c the performance increase is small and it requires a little bit of work across Chunk instances)

	# Construct a dictionary to hold vertex heights so we only have to calculate them once for each vertex rather than four times (for anything that isn't an edge) like we'd otherwise do below
	var vertex_heights = {}
	var local_x = 0
	while local_x <= chunk_size + subgrid_unit_size:
		var local_z = 0
		while local_z <= chunk_size + subgrid_unit_size:
			vertex_heights[Vector2(local_x, local_z)] = world.get_height(x + local_x, 0, z + local_z)
			local_z += subgrid_unit_size
		local_x += subgrid_unit_size

	local_x = 0
	while local_x <= chunk_size:
		var local_z = 0
		while local_z <= chunk_size:

			# Get positions (including heights) of the cour corners, and average heights of the triangles formed at them
			var tl_height = vertex_heights[Vector2(local_x, local_z)]
			var tr_height = vertex_heights[Vector2(local_x + subgrid_unit_size, local_z)]
			var bl_height = vertex_heights[Vector2(local_x, local_z + subgrid_unit_size)]
			var br_height = vertex_heights[Vector2(local_x + subgrid_unit_size, local_z + subgrid_unit_size)]
			var tl_pos = Vector3(local_x, tl_height, local_z)
			var tr_pos = Vector3(local_x + subgrid_unit_size, tr_height, local_z)
			var bl_pos = Vector3(local_x, bl_height, local_z + subgrid_unit_size)
			var br_pos = Vector3(local_x + subgrid_unit_size, br_height, local_z + subgrid_unit_size)
			var tl_height_average = (tl_height + tr_height + bl_height) / 3.0
			var tr_height_average = (tl_height + tr_height + br_height) / 3.0
			var bl_height_average = (tl_height + bl_height + br_height) / 3.0
			var br_height_average = (tr_height + bl_height + br_height) / 3.0

			# Always choose the triangle with the highest average and its complement
			if tl_height_average >= tr_height_average and tl_height_average >= bl_height_average and tl_height_average >= br_height_average or br_height_average >= tl_height_average and br_height_average >= tr_height_average and br_height_average >= bl_height_average:

				# Top-Left
				if tl_height_average >= 0 and tl_height_average <= self.water_level:
					ocean.append_array([tl_pos, tr_pos, bl_pos])
					ocean_colors.append_array([color_black, color_black, color_black])
				elif tl_height_average > self.water_level and tl_height_average <= percentiles[30]:
					beach.append_array([tl_pos, tr_pos, bl_pos])
					beach_colors.append_array([color_dark_gray, color_dark_gray, color_dark_gray])
				elif tl_height_average > percentiles[30] and tl_height_average <= percentiles[65]:
					lowlands.append_array([tl_pos, tr_pos, bl_pos])
					lowlands_colors.append_array([color_gray, color_gray, color_gray])
				elif tl_height_average > percentiles[65] and tl_height_average <= percentiles[85]:
					highlands.append_array([tl_pos, tr_pos, bl_pos])
					highlands_colors.append_array([color_light_gray, color_light_gray, color_light_gray])
				else:
					mountains.append_array([tl_pos, tr_pos, bl_pos])
					mountains_colors.append_array([color_white, color_white, color_white])

				# Bottom-Right
				if br_height_average >= 0 and br_height_average <= self.water_level:
					ocean.append_array([br_pos, bl_pos, tr_pos])
					ocean_colors.append_array([color_black, color_black, color_black])
				elif br_height_average > self.water_level and br_height_average <= percentiles[30]:
					beach.append_array([br_pos, bl_pos, tr_pos])
					beach_colors.append_array([color_dark_gray, color_dark_gray, color_dark_gray])
				elif br_height_average > percentiles[30] and br_height_average <= percentiles[65]:
					lowlands.append_array([br_pos, bl_pos, tr_pos])
					lowlands_colors.append_array([color_gray, color_gray, color_gray])
				elif br_height_average > percentiles[65] and br_height_average <= percentiles[85]:
					highlands.append_array([br_pos, bl_pos, tr_pos])
					highlands_colors.append_array([color_light_gray, color_light_gray, color_light_gray])
				else:
					mountains.append_array([br_pos, bl_pos, tr_pos])
					mountains_colors.append_array([color_white, color_white, color_white])

			else:

				# Top-Right
				if tr_height_average >= 0 and tr_height_average <= self.water_level:
					ocean.append_array([tl_pos, tr_pos, br_pos])
					ocean_colors.append_array([color_black, color_black, color_black])
				elif tr_height_average > self.water_level and tr_height_average <= percentiles[30]:
					beach.append_array([tl_pos, tr_pos, br_pos])
					beach_colors.append_array([color_dark_gray, color_dark_gray, color_dark_gray])
				elif tr_height_average > percentiles[30] and tr_height_average <= percentiles[65]:
					lowlands.append_array([tl_pos, tr_pos, br_pos])
					lowlands_colors.append_array([color_gray, color_gray, color_gray])
				elif tr_height_average > percentiles[65] and tr_height_average <= percentiles[85]:
					highlands.append_array([tl_pos, tr_pos, br_pos])
					highlands_colors.append_array([color_light_gray, color_light_gray, color_light_gray])
				else:
					mountains.append_array([tl_pos, tr_pos, br_pos])
					mountains_colors.append_array([color_white, color_white, color_white])

				# Bottom-Left
				if bl_height_average >= 0 and bl_height_average <= self.water_level:
					ocean.append_array([br_pos, bl_pos, tl_pos])
					ocean_colors.append_array([color_black, color_black, color_black])
				elif bl_height_average > self.water_level and bl_height_average <= percentiles[30]:
					beach.append_array([br_pos, bl_pos, tl_pos])
					beach_colors.append_array([color_dark_gray, color_dark_gray, color_dark_gray])
				elif bl_height_average > percentiles[30] and bl_height_average <= percentiles[65]:
					lowlands.append_array([br_pos, bl_pos, tl_pos])
					lowlands_colors.append_array([color_gray, color_gray, color_gray])
				elif bl_height_average > percentiles[65] and bl_height_average <= percentiles[85]:
					highlands.append_array([br_pos, bl_pos, tl_pos])
					highlands_colors.append_array([color_light_gray, color_light_gray, color_light_gray])
				else:
					mountains.append_array([br_pos, bl_pos, tl_pos])
					mountains_colors.append_array([color_white, color_white, color_white])

			local_z += subgrid_unit_size
		local_x += subgrid_unit_size

	# Take each list of vertices through the function that'll draw them with the specified material
	render_set_of_vertices_with_material(ocean, ocean_colors)
	render_set_of_vertices_with_material(beach, beach_colors)
	render_set_of_vertices_with_material(lowlands, lowlands_colors)
	render_set_of_vertices_with_material(highlands, highlands_colors)
	render_set_of_vertices_with_material(mountains, mountains_colors)

# TODO: These vector arrays are passed by value, *not* by reference; Can I modify this accordingly?
func render_set_of_vertices_with_material(vertices: PoolVector3Array, colors: PoolColorArray):

	# Edge case for if there were zero vertices contained in the chunk we tried to render
	if vertices.size() == 0:
		return

	# Debug case for if we don't have a color for each vertex
	if vertices.size() != colors.size():
		print("render_set_of_vertices_with_material: vertices.size() != colors.size()!")

	# Create mesh from arrays
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrays[ArrayMesh.ARRAY_COLOR] = colors
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Apply mesh to scene tree as a MeshInstance
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = arr_mesh
	mesh_instance.create_trimesh_collision() # Literally just adds collision ezpz
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF # Don't cast shadows
	add_child(mesh_instance)

func generate_water():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.material = preload("res:///WorldGen/water.material")
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.translation.y = water_level
	add_child(mesh_instance)
