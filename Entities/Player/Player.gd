extends KinematicBody

const GRAVITY = -24.8
var vel = Vector3()
const MAX_SPEED = 500
const VERTICAL_SPEED = 40
const JUMP_SPEED = 10
const ACCEL = 4.5

var dir = Vector3()

const DEACCEL= 16
const MAX_SLOPE_ANGLE = 40

var camera
var rotation_helper
var MOUSE_SENSITIVITY = .1;

func _ready():
	rotation_helper = $Rotation_Helper
	camera = $Rotation_Helper/Camera

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)

func _process(_delta):
	$CanvasLayer/Position.text = "Position: " + str(self.translation)
	$CanvasLayer/FPS.text = "FPS: " + str(Engine.get_frames_per_second())

func process_input(_delta):

	# Mapping key presses to what direction we should be going
	var input_movement_vector = Vector2()
	vel = Vector3()
	if Input.is_action_pressed("move_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("move_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("move_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_movement_vector.x += 1
	if Input.is_action_pressed("move_up"):
		vel.y += 1 * MAX_SPEED
	if Input.is_action_pressed("move_down"):
		vel.y -= 1 * MAX_SPEED
	input_movement_vector = input_movement_vector.normalized()

	# Transforming player movement to the player's reference frame
	# Basis vectors are already normalized.
	var cam_xform = camera.get_global_transform()
	dir = Vector3()
	dir += -input_movement_vector.y * cam_xform.basis.z
	dir += input_movement_vector.x * cam_xform.basis.x

	# Jumping
	#if is_on_floor():
		#if Input.is_action_just_pressed("jump"):
			#vel.y = JUMP_SPEED

func process_movement(delta):

	# We only care about pure horizontal here, get rid of the vertical component
	# dir.y = 0
	dir = dir.normalized()

	# Start out with gravity being the only downward force
	# vel.y += delta * GRAVITY

	var hvel = vel
	hvel.y = 0

	var target = dir
	target *= MAX_SPEED

	var accel
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL

	hvel = target;
	# hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0, 1, 0))

# Works like a dream, never touch again
func _input(event):

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:

		# Rotate up/down (around the rotation helper's axis system)
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * -1))

		# Rotate side to side (around y axis), scaling by 2d x-coord
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))

		# Clamps -90deg to 90deg so the user can't look more than straight up or down
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -90, 90)
		rotation_helper.rotation_degrees = camera_rot
