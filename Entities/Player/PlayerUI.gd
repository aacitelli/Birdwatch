extends CanvasLayer

func _process(_delta):
	$Position.text = "Position: " + str(get_parent().translation)
	$Orientation.text = "Rotation: " + str(get_parent().rotation_degrees)
