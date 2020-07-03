extends Spatial
class_name Chunk

# TODO: Figure out what this all does, commenting it all out

# Constructor variables
var x
var x_grid
var z
var z_grid
var chunk_size

var noise
var should_remove

var MAX_HEIGHT = 100

var percentiles = [0.001057, 0.008088, 0.010338, 0.012135, 0.013732, 0.015131, 0.01646, 0.017676, 0.018841, 0.019951, 0.021039, 0.022101, 0.023146, 0.024159, 0.02517, 0.026147, 0.02711, 0.028079, 0.02904, 0.030011, 0.030972, 0.031912, 0.032867, 0.033849, 0.034809, 0.035771, 0.036741, 0.037725, 0.038678, 0.039667, 0.040655, 0.041656, 0.042654, 0.043652, 0.044664, 0.045688, 0.046708, 0.047756, 0.04881, 0.049903, 0.050983, 0.052092, 0.053199, 0.054321, 0.055455, 0.056596, 0.057775, 0.058943, 0.060132, 0.061369, 0.062587, 0.063858, 0.06509, 0.06636, 0.067674, 0.069017, 0.070371, 0.071751, 0.073142, 0.07454, 0.076022, 0.077472, 0.078988, 0.080557, 0.082137, 0.083753, 0.085412, 0.087121, 0.088838, 0.090614, 0.092422, 0.094282, 0.096227, 0.098192, 0.100241, 0.102328, 0.104462, 0.106729, 0.109017, 0.111405, 0.113932, 0.11662, 0.11942, 0.122348, 0.125397, 0.128583, 0.132017, 0.135558, 0.13936, 0.143527, 0.14786, 0.152622, 0.157969, 0.163815, 0.170531, 0.178214, 0.187366, 0.198929, 0.214234, 0.240133];
var water_level = MAX_HEIGHT * percentiles[25]

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
		vertex.y = noise_transform(noise.get_noise_3d(vertex.x + x, vertex.y, vertex.z + z)) * MAX_HEIGHT / percentiles[99]
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

func noise_transform(noise):
	noise = (noise + 1) / 2 # Transform [-1, 1] to [0, 1]
	noise = pow(noise, 3) # Mountains a little sharper, and more flat ground
	return noise

func generate_water():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.material = preload("res:///WorldGen/water.material")
	var mesh_instance = MeshInstance.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.translation.y = water_level
	add_child(mesh_instance)


