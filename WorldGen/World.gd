extends Spatial

const chunk_size = 16

# Having this too high then actually loading that many makes the game HELLA LAGGY
const chunk_load_radius = 32

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
var thread

# Holds grid position of player; Updated every frame
var p_x
var p_z
var player_pos
var MAX_HEIGHT = 100

var chunks_loading_this_frame

signal loaded_chunk

# Percentiles are used for stuff like biome selection and shading b/c perlin noise is (close to) a normal distribution
# This scales by (MAX_HEIGHT) / 100th percentiles so stuff like mountains are at the highest peak
# TODO: Change this so higher elevations are more affected by this factor than lower elevations; This encourages flat valley
var percentiles = [0.0, 1.505341, 7.632018, 9.185752, 10.364989, 11.342104, 12.216771, 13.003863, 13.721631, 14.40905, 15.052256, 15.658445, 16.250783, 16.842891, 17.400959, 17.955556, 18.492428, 19.01891, 19.537059, 20.045917, 20.55768, 21.066959, 21.555269, 22.049592, 22.533336, 23.017872, 23.496444, 23.982136, 24.460706, 24.942196, 25.419172, 25.894695, 26.380204, 26.866319, 27.357257, 27.842024, 28.333987, 28.816342, 29.307511, 29.802381, 30.297803, 30.802878, 31.30655, 31.817094, 32.322951, 32.836693, 33.349779, 33.869027, 34.397418, 34.931128, 35.457711, 36.005438, 36.540574, 37.088591, 37.646806, 38.210823, 38.775153, 39.345643, 39.93007, 40.528796, 41.123418, 41.734075, 42.353434, 42.982263, 43.620069, 44.266529, 44.942727, 45.611715, 46.282505, 46.970884, 47.68845, 48.409852, 49.144643, 49.902491, 50.659014, 51.452725, 52.283618, 53.124894, 53.97159, 54.874522, 55.801324, 56.770306, 57.763231, 58.80663, 59.889991, 61.034863, 62.21576, 63.451532, 64.766405, 66.133401, 67.58048, 69.161084, 70.865986, 72.706889, 74.712174, 76.949105, 79.592078, 82.782598, 86.640221, 91.827476, 100]
var scaling_factor = 2.888948 # Factor that we ended up scaling the above array by to get mountains to 100

func _ready():

	randomize()
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 6
	noise.period = 220

	# Instantiate threads we use for terrain generation
	thread = Thread.new()

func add_chunk(chunk_key):

	# If this chunk has already been generated or is currently being generated, don't generate
	if chunks.has(chunk_key) or unready_chunks.has(chunk_key):
		return

	chunks_loading_this_frame += 1
	load_chunk([thread, chunk_key.x, chunk_key.y])
	unready_chunks[chunk_key] = 1

func load_chunk(arr):

	# When you give a thread a function to run, is passed in as array
	var thread = arr[0]
	var x = arr[1]
	var z = arr[2]

	# x,z are used as key but to interface with the map we need an actual position, so we multiply by chunk size
	var chunk = Chunk.new(noise, x * chunk_size, z * chunk_size, chunk_size, MAX_HEIGHT)
	chunk.translation = Vector3(x * chunk_size, 0, z * chunk_size)

	# Wait until the main thread isn't busy to go ahead and add this one to the tree
	call_deferred("load_done", chunk, thread)

# Adds the chunk to the tree whenever the main thread isn't busy
func load_done(chunk, thread):
	add_child(chunk)
	var chunk_key = Vector2(chunk.x / chunk_size, chunk.z / chunk_size)
	chunks[chunk_key] = chunk
	unready_chunks.erase(chunk_key)

func get_chunk(chunk_key):
	if chunks.has(chunk_key):
		return chunks.get(chunk_key)
	else:
		return null

var num_process_calls = 0
func _process(_delta):

	# num_process_calls += 1
	# print("\n-----------------------\n")
	# print("Process call #" + str(num_process_calls))

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

	# First, the thread removes chunks that are too far away
	#if not thread.is_active():
	#	print("Thread wasn't busy; calling remove_far_chunks.")
	#	var error = remove_chunks_thread.start(self, "remove_far_chunks")
	#	print(error)

	# Terrain generation will go full steam until it hits another
	chunks_loading_this_frame = 0

	# Will be a more thought-out system in the future (and probably be on a different thread), but this is a basic
	# implementation of loading a little quicker when you want to render more chunks overall
	var chunks_per_frame = floor(chunk_load_radius * (5.0 / 7))
	load_closest_n_chunks(chunks_per_frame)

	# Remove everything further than our "draw distance"
	# The most we ever have to remove per frame is the max we can ever generate per frame, so we use the same number
	remove_far_chunks(chunks_per_frame)

# var time_before = OS.get_ticks_msec()c
# var total_time = OS.get_ticks_msec() - time_before
# print("Time taken: " + str(total_time))
func load_closest_n_chunks(num_chunks_to_load):

	# Basically select a spiral of grid coordinates around us until we get all the way to the outside.
	# Call add_chunk on top right -> bottom right -> bottom left -> top left -> top right (exclusive) of each "ring"
	var current_radius = 0
	while current_radius < chunk_load_radius:

		# Top-right spot; If we include this as part of the last loop there's a weird edge case at (0, 0) so this is separate
		if Vector2(p_x + current_radius, p_z + current_radius).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x + current_radius, p_z + current_radius))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Down the right edge (not including the top-right corner, which is included in the last of these loops)
		for i in range(1, 2 * current_radius + 1):
			if Vector2(p_x + current_radius, p_z + current_radius - i).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x + current_radius, p_z + current_radius - i))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Left across the bottom edge
		for i in range(1, 2 * current_radius + 1):
			if Vector2(p_x + current_radius - i, p_z - current_radius).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x + current_radius - i, p_z - current_radius))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Up the left edge
		for i in range(1, 2 * current_radius + 1):
			if Vector2(p_x - current_radius, p_z - current_radius + i).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x - current_radius, p_z - current_radius + i))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Right across the top edge (excluding top-right)
		for i in range(1, 2 * current_radius):
			if Vector2(p_x - current_radius + i, p_z + current_radius).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(p_x - current_radius + i, p_z + current_radius))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Move on to the next ring of the "spiral"
		current_radius += 1

func remove_far_chunks(max_chunks_removed):

	# Set them all as needing removal
	for chunk in chunks.values():
		chunk.should_remove = true

	# Iterate through every chunk in our list, setting the flag if it's within range
	# More efficient than iterating row by row through n^2 elements, especially if most won't be loaded
	for chunk in chunks.values():
		if Vector2(chunk.x_grid, chunk.z_grid).distance_to(Vector2(p_x, p_z)) <= chunk_load_radius:
			chunk.should_remove = false

	# Get rid of everything that's outside chunk removal range. We need to do this because chunks take memory and it won't take us long to hit memory cap.
	for chunk in chunks.values():
		if chunk.should_remove:
			chunk.call_deferred("free") # .queue_free() works here too
			chunks.erase(chunk.key)

# Master function that takes noise in range [-1, 1] and spits out its exact height in the world. Located here for SpoC
func noise_to_height(noise):
	noise = noise_to_height_no_scaling(noise) # Let other function do all the work up to scaling for SpoC reasons
	noise *= scaling_factor # Scale so that mountains are near 100 height
	return noise

# Used to generate the percentiles (b/c normal generation scales BY the percentiles)
func noise_to_height_no_scaling(noise):
	noise = (noise + 1) / 2 # Transform [-1, 1] to [0, 1]
	noise = pow(noise, 3) # Accentuates mountains and makes flat areas more common
	noise *= MAX_HEIGHT # Convert noise to an actual height
	return noise

# Perlin noise is essentially a random distribution. So, it's best to use *percentiles*, not actual heights relative to the max. I regenerate these and hardcode them in whenever I change my height map at all, and just put the hardcoded numbers into shader and chunk classes.
func generate_percentiles():

	var horiz_lower = -10000000
	var horiz_upper = 10000000
	var horiz_step = 100000
	var y_lower = 0
	var y_upper = 100
	var y_step = 5

	var height_map = []
	for x in range(horiz_lower, horiz_upper, horiz_step):
		for y in range(y_lower, y_upper, y_step):
			for z in range(horiz_lower, horiz_upper, horiz_step):
				height_map.append(noise_to_height_no_scaling(noise.get_noise_3d(x, y, z)))
	height_map.sort()

	percentiles = []
	percentiles.append(0)
	for percentile in range(0, 100, 1):
		percentiles.append(height_map[floor(height_map.size() * percentile * .01)])

	# print("Pre-scaling: " + str(percentiles))

	# Go through and scale them by the largest value
	var scaling_factor = MAX_HEIGHT / percentiles.max()
	for i in range(0, percentiles.size()):
		percentiles[i] *= scaling_factor

	print("Percentiles: " + str(percentiles))
	print("Scaling Factor: " + str(scaling_factor))

