extends Spatial

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Set to fullscreen
	OS.window_fullscreen = true
	
	# Captures mouse input to the game window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Spawn instance of the player 
	var player_scene = load("res://Entities/Player/Player.tscn")
	var player = player_scene.instance()
	add_child(player)
