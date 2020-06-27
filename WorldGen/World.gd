extends Spatial

const chunk_size = 16
const chunk_amount = 16

# Used to generate the height map and all sorts of fun stuff... foundation for everything we're doing
var noise

# Self-explanatory
var chunks = {}
var chunksDistance = {}

# We always start out at the chunk at 0, 0
var currentChunk = Vector2(0, 0)

# Used as a lock system to make sure several threads aren't working on the same chunk at once
var unready_chunks = {}

# We use threading so it doesn't lock up the main thread and actually lag
var thread

func _ready():

	# Define noise parameters
	randomize()
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 4
	noise.period = 2500

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

func _process(_delta):
	update_chunks()

func update_chunks():

	# Getting rid of old chunks
	for key in chunks:
		var chunk = chunks[key]
		if chunk.should_remove:
			chunk.queue_free() # Remove from our tree
			chunks.erase(key) # Remove from map

	# Flag them as all removable
	for key in chunks:
		chunks[key].should_remove = true

	# Getting the position of the player in terms of grid units
	var player_translation = $Player.translation
	var p_x = int(player_translation.x) / chunk_size
	var p_z = int(player_translation.z) / chunk_size

	# TODO: I would call this REALLY REALLY REALLY bad code. Find a better way to do it (ideally as a heap, or make up a data structure that handles it well?)

	# Map with the key being coords and the value being the distance from the player. Needs updated each frame.
	# Instead of iterating through x/z, we pick the minimum out of this map each time.
	chunksDistance = {}
	for x in range(p_x - chunk_amount * .5, p_x + chunk_amount * .5):
		for z in range(p_z - chunk_amount * .5, p_x + chunk_amount * .5):
			var key = str(x) + "," + str(z)
			chunksDistance[key] = sqrt((p_x - x) * (p_x - x) + (p_z - z) * (p_z - z));

	# Each iteration, we pick out the minimum distance
	while chunksDistance.size() > 0:
		var minimum = dict_minimum_value(chunksDistance)
		chunksDistance.erase(minimum);

		# This is messy; We have to extract the coordinates from the key itself
		var x = int(minimum.substr(0, minimum.find(",")))
		var z = int(minimum.substr(minimum.find(",") + 1, -1))

		# Actually add the chunk and make sure it doesn't essentially get garbage collected
		add_chunk(x, z)
		var chunk = get_chunk(x, z)
		if chunk != null:
			chunk.should_remove = false

# Returns the key (or an arbitrary one of them) that has the minimum numerical value associated with it from a dict
func dict_minimum_value(dict):
	var min_value = dict.values().min()
	var keys = dict.keys()
	for key in keys:
		if dict[key] == min_value:
			return key
