extends MarginContainer

func _ready():
	pass

func _process(_delta):
	# Handle keyboard input not specific to the player
	if Input.is_action_pressed("exit"):
		get_tree().quit()

func _on_PlayGameButton_pressed():
	print("Button Pressed! Changing scene.")
	get_tree().change_scene("res://Core/Main.tscn")
