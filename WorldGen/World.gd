extends Spatial

# Chunk-related constants
const chunk_size = 4.0
const chunk_load_radius = 8
const num_vertices_per_chunk = 8.0

# Height & Moisture Map Generation
var height_map_noise
var moisture_map_noise
var scaling_factor # Scale everything up to our max height after noise generation
var MAX_HEIGHT = 100

# Our data structures to keep track of chunks in our game
var chunks = {} # Already loaded, just have to redraw
var unready_chunks = {} # Currently being generated (i.e.) by a thread
var chunks_loading_this_frame # Current system generates n chunks every frame b/c it's not threaded; This will be fixed in a future release

# Dictionary we construct once at the beginning of the game that describes the exact order we iterate over the chunks near the player. This is more efficient and more maintainable than iterating through every one every frame. This also lets us do fancy stuff like starting halfway through because we know we generated everything before it already.
# Potential Chunk Generation Optimizations:
# - Reset a flag when we switch chunks. This signifies to start over searching again from the beginning. When we call generate_n_chunks every frame, we start from the last place we were, because we know we don't need the closer frames.
var chunk_vertex_order = []
var chunk_load_index
var chunks_per_frame = min(pow(chunk_load_radius, 1), 10)
var chunks_need_removed = false

# Vector2 representing player grid position
var player_pos

# Thread used for terrain generation
# Without threads, when we do terrain, we'd basically be locking the main thread everytime we generate a chunk, because we need to go through all of that. With threads, the chunk generation function basically waits until the main thread isn't busy and completes that function. So,
var chunk_load_thread
var chunk_destroy_thread

# TODO: I have a lot of places where I could spread the work of one frame across several for more consistent framerate. Fix these.

# Generated once at the beginning of runtime, which is better for development because I change stuff so much. We make terrain decisions based on percentiles, not percentage of max height, because Simplex noise is normally distributed and would be astronomically unlikely to go anywhere near our max height, especially with a lot of octaves.
# TODO: When ready for an actual release, hardcode an iteration of this that has a ton of iterations in, rather than generating at load time every time.
var percentiles

func _ready():

	# TODO: Introduce a seeding system into the game, so players can get the same worlds.
	randomize()

	# Normal height map
	height_map_noise = OpenSimplexNoise.new()
	height_map_noise.seed = randi()
	height_map_noise.octaves = 4
	height_map_noise.period = 220

	# Completely separate "moisture map" used in conjunction with height map to decide which biome somewhere is
	moisture_map_noise = OpenSimplexNoise.new()
	moisture_map_noise.seed = randi()
	moisture_map_noise.octaves = 4
	moisture_map_noise.period = 220

	# Thread used for terrain generation so we do it during main thread downtime
	chunk_load_thread = Thread.new()
	chunk_destroy_thread = Thread.new()

	# Update our percentiles list on load time
	generate_percentiles()

	# Generate the order we generate chunks in (generated at runtime because chunk_load_radius can be changed at runtime)
	generate_chunk_generation_order()

func add_chunk(chunk_key):

	# If this chunk has already been generated or is currently being generated, don't generate
	# This is O(1) runtime because dictionaries are hash maps behind the scenes
	if chunks.has(chunk_key) or unready_chunks.has(chunk_key):
		return

	# Wait until the thread is done to go ahead and do this
	if chunk_load_thread.is_active():
		chunk_load_thread.wait_to_finish()
	chunks_loading_this_frame += 1
	unready_chunks[chunk_key] = 1
	var _error = chunk_load_thread.start(self, "load_chunk", chunk_key)

# Initialize chunk and add it to the tree when we get idle time
func load_chunk(chunk_key):
	var chunk = Chunk.new(height_map_noise, moisture_map_noise, chunk_key, chunk_size, MAX_HEIGHT)
	chunk.translation = Vector3(chunk.x, 0, chunk.z)
	call_deferred("load_done", chunk)

# Add chunk to tree and move chunk from unready chunks to ready chunks
func load_done(chunk):
	add_child(chunk)
	var chunk_key = Vector2(chunk.x / chunk_size, chunk.z / chunk_size)
	chunks[chunk_key] = chunk
	unready_chunks.erase(chunk_key)

# Retrieve chunk at specified coordinate
func get_chunk(chunk_key):
	if chunks.has(chunk_key):
		return chunks.get(chunk_key)
	else:
		return null

# Tracks frames processed. Used to conditionally run certain things that run regularly, but don't need to run every frame.
var num_process_calls = 0

# Runs every frame
func _process(_delta):

	num_process_calls += 1
	# print("\n-----------------------\n")
	# print("Process call #" + str(num_process_calls))

	# Update player positioning values
	var changed_chunks_this_frame = false
	var new_player_pos = Vector2(floor($Player.translation.x / chunk_size), floor($Player.translation.z / chunk_size))
	if new_player_pos != player_pos:
		changed_chunks_this_frame = true
	player_pos = new_player_pos

	# Terrain generation will go full steam until it hits another
	chunks_loading_this_frame = 0

	# We only ever have chunks out of range the frame we move from one chunk to another
	if changed_chunks_this_frame:

		# Reset generation from right on top of the player again
		chunk_load_index = 0

		# Signifies that we need to wait for the destroy thread to not be busy
		chunks_need_removed = true

	# If the chunk destroy thread isn't active, and we have chunks to remove, get it done
	if chunks_need_removed:
		if not chunk_destroy_thread.is_active():
			var _error = chunk_destroy_thread.start(self, "remove_far_chunks", [])
			chunks_need_removed = false

	# Needs called after our check for chunk changes
	load_closest_n_chunks(chunks_per_frame)

# Generates an array of Vector2 like [(0, 0), (0, 1), (0, 2), (0, 3), etc.), all in relative chunks coordinates, and stores it in the chunk_vertex_order variable
func generate_chunk_generation_order():

	for current_radius in range(chunk_load_radius + 1):
		if Vector2(current_radius, current_radius).length() <= chunk_load_radius:
			chunk_vertex_order.append(Vector2(current_radius, current_radius)) # Top-Right Spot (Edge Case)
		for i in range(1, 2 * current_radius + 1): # Right
			if Vector2(current_radius, current_radius - i).length() <= chunk_load_radius:
				chunk_vertex_order.append(Vector2(current_radius, current_radius - i))
		for i in range(1, 2 * current_radius + 1): # Bottom
			if Vector2(current_radius - i, -1 * current_radius).length() <= chunk_load_radius:
				chunk_vertex_order.append(Vector2(current_radius - i, -1 * current_radius))
		for i in range(1, 2 * current_radius + 1): # Left
			if Vector2(-1 * current_radius, -1 * current_radius + i).length() <= chunk_load_radius:
				chunk_vertex_order.append(Vector2(-1 * current_radius, -1 * current_radius + i))
		for i in range(1, 2 * current_radius): # Top
			if Vector2(-1 * current_radius + i, current_radius).length() <= chunk_load_radius:
				chunk_vertex_order.append(Vector2(-1 * current_radius + i, current_radius))

func load_closest_n_chunks(num_chunks_to_load):

	# Start from the beginning. Once we get through them all, it'll skip this loop entirely.
	while chunk_load_index < chunk_vertex_order.size():
		add_chunk(Vector2(player_pos.x + chunk_vertex_order[chunk_load_index].x, player_pos.y + chunk_vertex_order[chunk_load_index].y))
		chunk_load_index += 1
		if chunks_loading_this_frame >= num_chunks_to_load:
			return

# Removes any chunks deemed too far away from the scene
# We don't actually use this argument; The Thread API doesn't let us call it otherwise though, for some reason
# See here: https://github.com/godotengine/godot/issues/9924
func remove_far_chunks(_dummy_thread_arg):

	# Note: You need to use chunks.values() here because if you use anything else Godot immediately gets out of the loop if you modify it during (from what I can tell)
	for chunk in chunks.values():
		var chunk_key = chunk.chunk_key
		if chunk_key.distance_to(player_pos) > chunk_load_radius:
			chunk.call_deferred("free") # .queue_free() works here too
			chunks.erase(chunk_key)

# Master function that takes noise in range [-1, 1] and spits out its exact height in the world. Located here for SpoC
func get_height(x, y, z):
	var noise = get_height_no_scaling(x, y, z) # Let other function do all the work up to scaling for SpoC reasons
	noise *= scaling_factor # Scale so that mountains are near 100 height
	if noise > MAX_HEIGHT:
		print("Generated something above max height; Fix the noise function!")
	return noise

# Used to generate the percentiles (b/c normal generation scales BY the percentiles)
func get_height_no_scaling(x, y, z):
	var noise = height_map_noise.get_noise_3d(x, y, z)
	noise = (noise + 1) / 2 # Transform [-1, 1] to [0, 1]
	noise = pow(noise, 3) # Accentuates mountains and makes flat areas more common
	noise *= MAX_HEIGHT # Convert noise to an actual height
	return noise

func get_moisture(x, y, z):
	return moisture_map_noise.get_noise_3d(x, y, z)

# Perlin noise is essentially a random distribution. So, it's best to use *percentiles*, not actual heights relative to the max. I regenerate these and hardcode them in whenever I change my height map at all, and just put the hardcoded numbers into shader and chunk classes.
func generate_percentiles():

	# These numbers take like half a second at load time, it's cool
	var horiz_lower = -10000000000
	var horiz_upper = 10000000000
	var horiz_step = 100000000
	var y_lower = 0
	var y_upper = 101
	var y_step = 20

	# warning-ignore:shadowed_variable
	var height_map = []
	for x in range(horiz_lower, horiz_upper, horiz_step):
		for y in range(y_lower, y_upper, y_step):
			for z in range(horiz_lower, horiz_upper, horiz_step):
				height_map.append(get_height_no_scaling(x, y, z))
	height_map.sort()

	percentiles = []
	percentiles.append(0.0) # 0th percentile is minimum possible value
	for percentile in range(1, 100): # Figure out 1st through 99th percentile
		percentiles.append(height_map[floor(height_map.size() * percentile * .01)])
	percentiles.append(height_map[height_map.size() - 1]) # 100th percentile handled uniquely to be last element. If included in the loop above, requires an edge case check every time, otherwise will go one over the last element.

	# Go through and scale them by the largest value
	scaling_factor = MAX_HEIGHT / percentiles[100] # Calculate from the second highest value, NOT the highest, which is always 100
	for i in range(0, percentiles.size()):
		percentiles[i] *= scaling_factor

	# print("scaling_factor: " + str(scaling_factor))
	# print("percentiles: " + str(percentiles))

