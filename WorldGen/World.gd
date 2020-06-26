extends Spatial

const chunk_size = 64
const chunk_amount = 16

# Used to generate the height map and all sorts of fun stuff... foundation for everything we're doing
var noise

# Self-explanatory
var chunks = {}

# Used as a lock system to make sure several threads aren't working on the same chunk at once
var unready_chunks = {}

# We use threading so it doesn't lock up the main thread and actually lag
var thread

func _ready():

	# Define noise parameters
	randomize()
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 6
	noise.period = 80

	# We don't generate this on the main thread or else it would lock up all the time
	thread = Thread.new()

func add_chunk(x, z):

	# Key we use for the chunks map
	var key = str(x) + "," + str(z)

	# If this chunk has already been generated or is currently being generated, don't generate
	if chunks.has(key) or unready_chunks.has(key):
		return

	if not thread.is_active():
		thread.start(self, "load_chunk", [thread, x, z])
		unready_chunks[key] = 1

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
	var key = str(chunk.x / chunk_size) + "," + str(chunk.z / chunk_size)
	chunks[key] = chunk
	unready_chunks.erase(key)
	thread.wait_to_finish()

func get_chunk(x, z):
	var key = str(x) + "," + str(z)
	if chunks.has(key):
		return chunks.get(key)
	else:
		return null

func _process(delta):
	update_chunks()
	clean_up_chunks()
	reset_chunks()

func update_chunks():

	# Getting the position of the player in terms of grid units
	var player_translation = $Player.translation
	var p_x = int(player_translation.x) / chunk_size
	var p_z = int(player_translation.z) / chunk_size

	# Only display the chunks that are near the player
	for x in range(p_x - chunk_amount * .5, p_x + chunk_amount * .5):
		for z in range(p_z - chunk_amount * .5, p_x + chunk_amount * .5):
			add_chunk(x, z) # This function handles correctly if we've already created that one

func clean_up_chunks():
	pass

func reset_chunks():
	pass
