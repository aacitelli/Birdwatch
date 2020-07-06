extends Control

var main_menu_bp
var options_menu_bp

func _ready():
	main_menu_bp = "MainMenuBackground/MainMenu"
	options_menu_bp = "MainMenuBackground/OptionsMenuContainer/OptionsMenu/"
	get_node(main_menu_bp).show()
	get_node("MainMenuBackground/OptionsMenuContainer").hide()

func _process(_delta):
	if Input.is_action_pressed("exit"):
		get_tree().quit()

func _on_PlayGameButton_pressed():
	get_tree().change_scene("res://Core/Main.tscn")

func _on_OptionsButton_pressed():

	# Hide Main Menu
	get_node(main_menu_bp).hide()

	# Make everything but the options section we want invisible
	get_node(options_menu_bp + "Audio").hide()
	get_node(options_menu_bp + "Video").hide()
	get_node(options_menu_bp + "Graphics").hide()
	get_node(options_menu_bp + "Controls").hide()
	get_node(options_menu_bp + "Gameplay").show()

	# Make the overall options menu visible
	get_node("MainMenuBackground/OptionsMenuContainer").show()

func _on_GameplaySectionButton_pressed():
	get_node(options_menu_bp + "Audio").hide()
	get_node(options_menu_bp + "Video").hide()
	get_node(options_menu_bp + "Graphics").hide()
	get_node(options_menu_bp + "Controls").hide()
	get_node(options_menu_bp + "Gameplay").show()

func _on_AudioSectionButton_pressed():
	get_node(options_menu_bp + "Video").hide()
	get_node(options_menu_bp + "Graphics").hide()
	get_node(options_menu_bp + "Controls").hide()
	get_node(options_menu_bp + "Gameplay").hide()
	get_node(options_menu_bp + "Audio").show()

func _on_VideoSectionButton_pressed():
	get_node(options_menu_bp + "Audio").hide()
	get_node(options_menu_bp + "Graphics").hide()
	get_node(options_menu_bp + "Controls").hide()
	get_node(options_menu_bp + "Gameplay").hide()
	get_node(options_menu_bp + "Video").show()

func _on_GraphicsSectionButton_pressed():
	get_node(options_menu_bp + "Audio").hide()
	get_node(options_menu_bp + "Video").hide()
	get_node(options_menu_bp + "Controls").hide()
	get_node(options_menu_bp + "Gameplay").hide()
	get_node(options_menu_bp + "Graphics").show()

func _on_ControlsSectionButton_pressed():
	get_node(options_menu_bp + "Audio").hide()
	get_node(options_menu_bp + "Video").hide()
	get_node(options_menu_bp + "Graphics").hide()
	get_node(options_menu_bp + "Gameplay").hide()
	get_node(options_menu_bp + "Controls").show()
