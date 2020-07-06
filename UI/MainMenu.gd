extends MarginContainer

func _ready():
	pass

func _on_PlayGameButton_pressed():
	print("Button Pressed! Changing scene.")
	get_tree().change_scene("res://Core/Main.tscn")
