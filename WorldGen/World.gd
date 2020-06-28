extends Spatial

const chunk_size = 16
const chunk_load_radius = 16

# Used to generate the height map and all sorts of fun stuff... foundation for everything we're doing
var noise

# Self-explanatory
var chunks = {}

# Used as a lock system to make sure several threads aren't working on the same chunk at once
var unready_chunks = {}

# We use threading so it doesn't lock up the main thread and actually lag
var thread

# Holds grid position of player; Updated every frame
var p_x
var p_z

func _ready():

	# Define noise parameters
	randomize()
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 6
	noise.period = 1200

	# We don't generate this on the main thread or else it would lock up all the time
	thread = Thread.new()

func add_chunk(chunk_key):

	# If this chunk has already been generated or is currently being generated, don't generate
	if chunks.has(chunk_key) or unready_chunks.has(chunk_key):
		return

	if not thread.is_active():
		var error = thread.start(self, "load_chunk", [thread, chunk_key.x, chunk_key.y])
		unready_chunks[chunk_key] = 1

	else:
		# print("Thread was active when trying to add chunk " + str(chunk_key))
		pass

func load_chunk(arr):

	# When you give a thread a function to run, is passed in as array
	var thread = arr[0]
	var x = arr[1]
	var z = arr[2]

	# x,z are used as key but to interface with the map we need an actual position, so we multiply by chunk size
	var chunk = Chunk.new(noise, x * chunk_size, z * chunk_size, chunk_size)
	chunk.translation = Vector3(x * chunk_size, 0, z * chunk_size)

	# Signify that it's done whenever the chunk isn't busy
	call_deferred("load_done", chunk, thread)

func load_done(chunk, thread):
	add_child(chunk)
	var chunk_key = Vector2(chunk.x / chunk_size, chunk.z / chunk_size)
	chunks[chunk_key] = chunk
	unready_chunks.erase(chunk_key)
	thread.wait_to_finish()

func get_chunk(chunk_key):
	if chunks.has(chunk_key):
		return chunks.get(chunk_key)
	else:
		return null

func _process(_delta):

	# Need updated player positioning values
	p_x = int($Player.translation.x) / chunk_size
	p_z = int($Player.translation.z) / chunk_size

	# Update which chunks are and aren't loaded
	load_closest_unloaded_chunk()
	remove_far_chunks()

# TODO: Modify to prioritize circularly instead of in a square, because the user sees circularly.
func load_closest_unloaded_chunk():

	# Basically select a spiral of grid coordinates around us until we get all the way to the outside.
	# Call add_chunk on top right -> bottom right -> bottom left -> top left -> top right (exclusive) of each "ring"
	# Makes it so we don't have to figure out which are closest every frame by doing actual math - big performance boost
	var current_radius = 0
	while current_radius < chunk_load_radius:
		add_chunk(Vector2(p_x + current_radius, p_z + current_radius))
		for i in range(1, 2 * current_radius + 1):
			add_chunk(Vector2(p_x + current_radius, p_z + current_radius - i))
		for i in range(1, 2 * current_radius + 1):
			add_chunk(Vector2(p_x + current_radius - i, p_z - current_radius))
		for i in range(1, 2 * current_radius + 1):
			add_chunk(Vector2(p_x - current_radius, p_z - current_radius + i))
		for i in range(1, 2 * current_radius):
			add_chunk(Vector2(p_x - current_radius + i, p_z + current_radius))
		current_radius += 1

func remove_far_chunks():

	# Set them all as needing removal
	for chunk in chunks.values():
		chunk.should_remove = true

	# Iterate through the close ones and flag them as not needing removed
	var player_translation = $Player.translation
	var p_x = int(player_translation.x) / chunk_size
	var p_z = int(player_translation.z) / chunk_size
	for x in range(p_x - chunk_load_radius, p_x + chunk_load_radius):
		for z in range(p_z - chunk_load_radius, p_z + chunk_load_radius):
			if chunks.has(Vector2(x, z)):
				chunks[Vector2(x, z)].should_remove = false

	# Remove anything that doesn't have that flag set
	for key in chunks:
		var chunk = chunks[key]
		if chunk.should_remove:
			chunk.queue_free() # Removes from tree as soon as nothing needs its information (i.e. end of frame)
			chunks.erase(key)
