extends Spatial
class_name Chunk

# TODO: Figure out what this all does, commenting it all out

# World gen overall variables
var mesh_instance
var noise
var x
var z
var chunk_size

func _init(noise, x, z, chunk_size):

	self.noise = noise
	self.x = x
	self.z = z
	self.chunk_size = chunk_size

func _ready():
	generate_chunk()

func generate_chunk():

	# TODO: Need another once-over to figure out how this all works.

	# Create the mesh along with its fundamental characteristics
	# TODO: Docs aren't very helpful as to what some of these characteristics mean, figure them out
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.subdivide_depth = chunk_size * .5
	plane_mesh.subdivide_width = chunk_size * .5

	# Declaring Godot stuff we're going to use to draw the environment
	var surface_tool = SurfaceTool.new() # Godot's approach to drawing mesh from code
	var data_tool = MeshDataTool.new() # Lets us grab vertices from stuff we already generated

	# Links the overall mesh for the chunk to the surface tool
	surface_tool.create_from(plane_mesh, 0)
	var array_plane = surface_tool.commit()

	# Lets us get information about the vertex we just
	var error = data_tool.create_from_surface(array_plane, 0)

	# Iterate through every vertex that is in the plane
	for i in range(data_tool.get_vertex_count()):

		# Get the vertex, set its height to the noise's generated value for that vertex, then save the changes
		# 80 is a magic number representing how "spiky" our terrain is
		var vertex = data_tool.get_vertex(i)
		vertex.y = noise.get_noise_3d(vertex.x + x, vertex.y, vertex.z + z) * 30
		data_tool.set_vertex(i, vertex)

	# Remove everything from the ArrayMesh
	for s in range(array_plane.get_surface_count()):
		array_plane.surface_remove(s)

	# Start actually drrawingawing based on the ArrayMesh we were given
	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals() # Presumably used for collision stuff; Generates what's 90deg from our plane.

	# MeshInstance is the component actually rendered in the world
	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = surface_tool.commit() # Set it to whatever's contained in the SurfaceTool
	mesh_instance.create_trimesh_collision() # Creates a node that is essentially a different representation of we have
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF # Don't do shadows, fam
	add_child(mesh_instance)
