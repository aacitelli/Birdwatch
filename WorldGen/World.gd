extends Spatial

const chunk_size = 16
const chunk_load_radius = 16

var noise
var counter = 0

var fps_count = 0
var fps_measurements = 0

# Self-explanatory
var chunks = {}

# Used as a lock system to make sure several threads aren't working on the same chunk at once
var unready_chunks = {}

# We use threading so it doesn't lock up the main thread and actually lag
# Increasing number of threads speeds it up (more chunks being generated each _process call), but means each _process call takes a little longer (i.e. less framerate). 4 seems to be a good middle ground of reasonably fast loading while leaving reasonably good performance.
var threads = []
var num_threads = 4
var num_busy_threads_this_frame # Used to stop our chunk draw calls after we use up all the threads, rather than looping through the rest

# Holds grid position of player; Updated every frame
var p_x
var p_z
var player_pos

func _ready():

	randomize()
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 6
	noise.period = 220

	# Instantiate threads
	for i in range(num_threads):
		threads.append(Thread.new())

func add_chunk(chunk_key):

	# If this chunk has already been generated or is currently being generated, don't generate
	if chunks.has(chunk_key) or unready_chunks.has(chunk_key):
		return

	# Only need to reset everything once per process call, not every time we run a thread
	for thread in threads:
		if not thread.is_active():
			remove_far_chunks()
			var error = thread.start(self, "load_chunk", [thread, chunk_key.x, chunk_key.y])
			num_busy_threads_this_frame += 1
			unready_chunks[chunk_key] = 1
			break

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

	# Don't want to overflow the terminal, keep this to being output every second or two
	fps_count += Engine.get_frames_per_second()
	fps_measurements += 1
	if fps_measurements % 300 == 0:
		print("fps: " + str(fps_count / fps_measurements))

	# var time_before = OS.get_ticks_usec()

	# Need updated player positioning values
	p_x = int($Player.translation.x) / chunk_size
	p_z = int($Player.translation.z) / chunk_size
	player_pos = Vector2(p_x, p_z)

	# Update which chunks are and aren't loaded
	num_busy_threads_this_frame = 0
	remove_far_chunks()
	load_closest_unloaded_chunk()

	# var total_time = OS.get_ticks_usec() - time_before
	# print("_process() time taken (us): " + str(total_time))

# var time_before = OS.get_ticks_msec()
# var total_time = OS.get_ticks_msec() - time_before
# print("Time taken: " + str(total_time))

# TODO: Modify to prioritize circularly instead of in a square, because the user sees circularly.
func load_closest_unloaded_chunk():

	# var time_before = OS.get_ticks_usec()

	# Basically select a spiral of grid coordinates around us until we get all the way to the outside.
	# Call add_chunk on top right -> bottom right -> bottom left -> top left -> top right (exclusive) of each "ring"
	var current_radius = 0
	while current_radius < chunk_load_radius:

		# If we're full on threads, none of these calls will amount to everything, check before we g
		if num_busy_threads_this_frame >= num_threads:
			return

		# Top-right box
		if Vector2(p_x + current_radius, p_z + current_radius).distance_to(player_pos) <= chunk_load_radius:
			add_chunk(Vector2(p_x + current_radius, p_z + current_radius))

		# Down the right edge
		for i in range(1, 2 * current_radius + 1):
			if num_busy_threads_this_frame >= num_threads:
				return
			if Vector2(p_x + current_radius, p_z + current_radius - i).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x + current_radius, p_z + current_radius - i))

		# Left across the bottom edge
		for i in range(1, 2 * current_radius + 1):
			if num_busy_threads_this_frame >= num_threads:
				return
			if Vector2(p_x + current_radius - i, p_z - current_radius).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x + current_radius - i, p_z - current_radius))

		# Up the left edge
		for i in range(1, 2 * current_radius + 1):
			if num_busy_threads_this_frame >= num_threads:
				return
			if Vector2(p_x - current_radius, p_z - current_radius + i).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x - current_radius, p_z - current_radius + i))

		# Right across the top edge (excluding where we started)
		for i in range(1, 2 * current_radius):
			if num_busy_threads_this_frame >= num_threads:
				return
			if Vector2(p_x - current_radius + i, p_z + current_radius).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x - current_radius + i, p_z + current_radius))

		current_radius += 1

	# var total_time = OS.get_ticks_usec() - time_before
	# print("load_closest_unloaded_chunk() time taken (us): " + str(total_time))

func remove_far_chunks():

	# var time_before = OS.get_ticks_usec()

	# Set them all as needing removal
	for chunk in chunks.values():
		chunk.should_remove = true

	# Iterate through every chunk in our list, setting the flag if it's within range
	# More efficient than iterating row by row through n^2 elements, especially if most won't be loaded
	for chunk in chunks.values():
		if Vector2(chunk.x_grid, chunk.z_grid).distance_to(Vector2(p_x, p_z)) <= chunk_load_radius:
			chunk.should_remove = false

	# Remove anything that doesn't have that flag set
	for key in chunks:
		var chunk = chunks[key]
		if chunk.should_remove:
			chunk.queue_free() # Removes from tree as soon as nothing needs its information (i.e. end of frame)
			chunks.erase(key)

	# var total_time = OS.get_ticks_usec() - time_before
	# print("remove_far_chunks() time taken (us): " + str(total_time))
