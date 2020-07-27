extends Node

var definitions

# TODO: More biomes
# TODO: Actually use the moisture
func _ready():

	definitions = []

	# Ocean
	definitions[0] = {}
	definitions[0].min_height = 0
	definitions[0].max_height = 25
	definitions[0].min_moisture = -1
	definitions[0].max_moisture = -1
	definitions[0].material = preload("res:///WorldGen/Biomes/OceanMaterial.tres")

	# Beach
	definitions[1] = {}
	definitions[1].min_height = 25
	definitions[1].max_height = 30
	definitions[1].min_moisture = -1
	definitions[1].max_moisture = -1
	definitions[1].material = preload("res:///WorldGen/Biomes/BeachMaterial.tres")

	# Lowlands
	definitions[2] = {}
	definitions[2].min_height = 30
	definitions[2].max_height = 65
	definitions[2].min_moisture = -1
	definitions[2].max_moisture = -1
	definitions[2].material = preload("res:///WorldGen/Biomes/LowlandsMaterial.tres")

	# Highlands
	definitions[3] = {}
	definitions[3].min_height = 65
	definitions[3].max_height = 85
	definitions[3].min_moisture = -1
	definitions[3].max_moisture = -1
	definitions[3].material = preload("res:///WorldGen/Biomes/HighlandsMaterial.tres")

	# Mountains
	definitions[4] = {}
	definitions[4].min_height = 85
	definitions[4].max_height = 999999 # We can theoretically generate noise above 100; It's just stupidly unlikely
	definitions[4].min_moisture = -1
	definitions[4].max_moisture = -1
	definitions[4].material = preload("res:///WorldGen/Biomes/MountainsMaterial.tres")
