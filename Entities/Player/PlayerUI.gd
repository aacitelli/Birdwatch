extends CanvasLayer

func _process(_delta):
	$Label.text = str(get_parent().translation)
