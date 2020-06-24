extends KinematicBody

# Member Variables 
var gravity = Vector3.DOWN * 12
var speed = 4
var jump_speed = 6 
var spin = .1 

var velocity = Vector3() 
var jump = false 

func get_input(): 
	
	velocity.x = 0
	velocity.z = 0
	
	# TODO: Ignores camera direction; Fix. 
	if Input.is_action_pressed("move_forward"):
		velocity.z -= speed 
	if Input.is_action_pressed("move_backward"):
		velocity.z += speed
	if Input.is_action_pressed("move_right"): 
		velocity.x += speed
	if Input.is_action_pressed("move_left"):
		velocity.x -= speed
		
func _physics_process(delta): 
	velocity += gravity * delta
	get_input()
	velocity = move_and_slide(velocity, Vector3.UP)
	
func _unhandled_input(event): 
	
	# Handle mouse input 
	if event is InputEventMouseMotion: 
		
		# Rotate around x axis 
		if event.relative.x > 0: 
			rotate_y(-lerp(0, spin, event.relative.x / 10))
		elif event.relative.x < 0: 
			rotate_y(-lerp(0, spin, event.relative.x / 10))
			
		# Rotate around y axis
		if event.relative.y > 0: 
			rotate_z(-lerp(0, spin, event.relative.y / 10))
		elif event.relative.y < 0:
			rotate_z(-lerp(0, spin, event.relative.y / 10))

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
