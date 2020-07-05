extends Spatial

# Constants we pass into each chunk
const chunk_size = 16
const chunk_load_radius = 16

# Height & Moisture Map Generation
var height_map_noise
var moisture_map_noise
var scaling_factor # Scale everything up to our max height after noise generation
var MAX_HEIGHT = 100

# Our data structures to keep track of chunks in our game
var chunks = {} # Already loaded, just have to redraw
var unready_chunks = {} # Currently being generated (i.e.) by a thread
var chunks_loading_this_frame # Current system generates n chunks every frame b/c it's not threaded; This will be fixed in a future release

# Vector2 representing player grid position
var player_pos

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

	# Update our percentiles list on load time
	generate_percentiles()

func add_chunk(chunk_key):

	# If this chunk has already been generated or is currently being generated, don't generate
	if chunks.has(chunk_key) or unready_chunks.has(chunk_key):
		return

	chunks_loading_this_frame += 1
	unready_chunks[chunk_key] = 1
	load_chunk(chunk_key)

# Initialize chunk and add it to the tree when we get idle time
func load_chunk(chunk_key):
	var chunk = Chunk.new(height_map_noise, chunk_key.x * chunk_size, chunk_key.y * chunk_size, chunk_size, MAX_HEIGHT)
	chunk.translation = Vector3(chunk_key.x * chunk_size, 0, chunk_key.y * chunk_size)
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

	# This value needs to scale with the chunks in a circle. A circle adds more chunks every ring, so a linear term isn't enough to stay caught up. However, if we let it go pure exponential without any sort of cap, this quickly gets REALLY laggy.
	var chunks_per_frame = min(pow(chunk_load_radius, 1.1), 20)
	load_closest_n_chunks(chunks_per_frame)

	# Call this whenever we change chunks, and no more frequently. This is the mathematical maximum number of times we can call it without having any redundant calls, which is what we're going for.
	if changed_chunks_this_frame:
		remove_far_chunks()

func load_closest_n_chunks(num_chunks_to_load):

	# Basically select a spiral of grid coordinates around us until we get all the way to the outside.
	# Call add_chunk on top right -> bottom right -> bottom left -> top left -> top right (exclusive) of each "ring"
	var current_radius = 0
	while current_radius < chunk_load_radius:

		# Top-right spot; If we include this as part of the last loop there's a weird edge case at (0, 0) so this is separate
		if Vector2(player_pos.x + current_radius, player_pos.y + current_radius).distance_to(player_pos) <= chunk_load_radius:
			add_chunk(Vector2(player_pos.x + current_radius, player_pos.y + current_radius))
			if chunks_loading_this_frame >= num_chunks_to_load:
				return

		# Down the right edge (not including the top-right corner, which is included in the last of these loops)
		for i in range(1, 2 * current_radius + 1):
			if Vector2(player_pos.x + current_radius, player_pos.y + current_radius - i).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(player_pos.x + current_radius, player_pos.y + current_radius - i))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Left across the bottom edge
		for i in range(1, 2 * current_radius + 1):
			if Vector2(player_pos.x + current_radius - i, player_pos.y - current_radius).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(player_pos.x + current_radius - i, player_pos.y - current_radius))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Up the left edge
		for i in range(1, 2 * current_radius + 1):
			if Vector2(player_pos.x - current_radius, player_pos.y - current_radius + i).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(player_pos.x - current_radius, player_pos.y - current_radius + i))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Right across the top edge (excluding top-right)
		for i in range(1, 2 * current_radius):
			if Vector2(player_pos.x - current_radius + i, player_pos.y + current_radius).distance_to(player_pos) <= chunk_load_radius:
				add_chunk(Vector2(player_pos.x - current_radius + i, player_pos.y + current_radius))
				if chunks_loading_this_frame >= num_chunks_to_load:
					return

		# Move on to the next ring of the "spiral"
		current_radius += 1

# Removes any chunks deemed too far away from the scene
func remove_far_chunks():
	for chunk in chunks.values():
		if Vector2(chunk.x_grid, chunk.z_grid).distance_to(Vector2(player_pos.x, player_pos.y)) > chunk_load_radius:
			chunk.call_deferred("free") # .queue_free() works here too
			chunks.erase(chunk.key)

# Master function that takes noise in range [-1, 1] and spits out its exact height in the world. Located here for SpoC
func noise_to_height(noise):
	noise = noise_to_height_no_scaling(noise) # Let other function do all the work up to scaling for SpoC reasons
	noise *= scaling_factor # Scale so that mountains are near 100 height
	if noise > MAX_HEIGHT:
		print("Generated something above max height; Fix the noise function!")
	return floor(noise)

# Used to generate the percentiles (b/c normal generation scales BY the percentiles)
func noise_to_height_no_scaling(noise):
	noise = (noise + 1) / 2 # Transform [-1, 1] to [0, 1]
	noise = pow(noise, 3) # Accentuates mountains and makes flat areas more common
	noise *= MAX_HEIGHT # Convert noise to an actual height
	return noise

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
				height_map.append(noise_to_height_no_scaling(height_map_noise.get_noise_3d(x, y, z)))
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

	print("scaling_factor: " + str(scaling_factor))
	print("percentiles: " + str(percentiles))

