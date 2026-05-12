extends Camera3D

@export var move_speed: float = 20.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.002

var yaw: float = 0.0
var pitch: float = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	rotation_order = EULER_ORDER_YXZ
	yaw = rotation.y
	pitch = rotation.x

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		rotation = Vector3(pitch, yaw, 0.0)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	var move_dir := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		move_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_dir += transform.basis.z

	if Input.is_key_pressed(KEY_A):
		move_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_dir += transform.basis.x

	if Input.is_key_pressed(KEY_Q):
		move_dir += Vector3.UP
	if Input.is_key_pressed(KEY_E):
		move_dir += Vector3.DOWN

	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()

	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier

	global_position += move_dir * speed * delta
