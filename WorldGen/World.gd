extends Spatial

const chunk_size = 16
const chunk_amount = 16

# Used to generate the height map and all sorts of fun stuff... foundation for everything we're doing
var noise

# Self-explanatory
var chunks = {}
var chunksDistance = {}

# Used as a lock system to make sure several threads aren't working on the same chunk at once
var unready_chunks = {}

# We use threading so it doesn't lock up the main thread and actually lag
var thread

func _ready():

	# Define noise parameters
	randomize()
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 3
	noise.period = 2500

	# We don't generate this on the main thread or else it would lock up all the time
	thread = Thread.new()

func add_chunk(chunk_key):

	# If this chunk has already been generated or is currently being generated, don't generate
	if chunks.has(chunk_key) or unready_chunks.has(chunk_key):
		# print("Chunk " + str(chunk_key) + " has already been created or is currently being created. Skipping.")
		return

	if not thread.is_active():
		print("Chunk " + str(chunk_key) + " has NOT already been created. Starting thread on it.")
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

	print("load_chunk called with coords " + str(Vector2(x, z)))

	# x,z are used as key but to interface with the map we need an actual position, so we multiply by chunk size
	var chunk = Chunk.new(noise, x * chunk_size, z * chunk_size, chunk_size)
	chunk.translation = Vector3(x * chunk_size, 0, z * chunk_size)

	print("Created the chunk and set translation. Calling load_done deferred.")

	# Signify that it's done whenever the chunk isn't busy
	call_deferred("load_done", chunk, thread)

func load_done(chunk, thread):

	print("load_done called.")
	# print("Chunk: " + str(chunk))

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
	load_closest_unloaded_chunk()
	remove_far_chunks()

func load_closest_unloaded_chunk():

	# Build a map of every chunk and its distance from the player
	var player_translation = $Player.translation
	var p_x = int(player_translation.x) / chunk_size
	var p_z = int(player_translation.z) / chunk_size

	# Building a map of every chunk within our distance this frame
	chunksDistance = {}
	for x in range(p_x - chunk_amount * .5, p_x + chunk_amount * .5):
		for z in range(p_z - chunk_amount * .5, p_x + chunk_amount * .5):
			chunksDistance[Vector2(x, z)] = sqrt((p_x - x) * (p_x - x) + (p_z - z) * (p_z - z)); # Save its distance

	# TODO: Instead of getting min every time (O(n^2)), sort then always take first element (O(n*logn))
	# Actually add whatever the minimum distance one was
	while chunksDistance.size() > 0:

		# Pick out the minimum distance key, then try it. If it does successfully take the thread, the other ones
		# will be blocked off from taking the thread and they'll essentially be skipped regardless this frame.
		var min_chunk_key = dict_minimum_value(chunksDistance)
		add_chunk(min_chunk_key)

		chunksDistance.erase(min_chunk_key)

func remove_far_chunks():

	# Set them all as needing removal
	for chunk in chunks.values():
		chunk.should_remove = true

	# Iterate through the close ones and flag them as not needing removed
	var player_translation = $Player.translation
	var p_x = int(player_translation.x) / chunk_size
	var p_z = int(player_translation.z) / chunk_size
	for x in range(p_x - chunk_amount * .5, p_x + chunk_amount * .5):
		for z in range(p_z - chunk_amount * .5, p_x + chunk_amount * .5):
			if chunks.has(Vector2(x, z)):
				chunks[Vector2(x, z)].should_remove = false

	# Remove the far ones alllll the way
	for key in chunks:
		var chunk = chunks[key]
		if chunk.should_remove:
			chunk.queue_free()
			chunks.erase(key)

# Returns the key (or an arbitrary one of them) that has the minimum numerical value associated with it from a dict
func dict_minimum_value(dict):
	var min_value = dict.values().min()
	var keys = dict.keys()
	for key in keys:
		if dict[key] == min_value:
			return key



