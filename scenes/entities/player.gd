extends CharacterBody3D
class_name Player

# === Variables de movimiento ===
@export var move_speed: float = 6.0
@export var jump_velocity: float = 7.0
@export var mouse_sens: float = 0.003

# === Referencias a la cámara ===
@onready var yaw: Node3D = $CameraRig/Yaw
@onready var pitch: Node3D = $CameraRig/Yaw/Pitch

var yaw_angle := 0.0
var pitch_angle := 0.0

func _ready() -> void:
	print("Player listo y en grupo player:", is_in_group("player"))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # el mouse solo se captura cuando haces clic derecho

func _unhandled_input(event: InputEvent) -> void:
	# Captura del mouse al hacer clic derecho
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)

	# Movimiento del mouse para girar cámara
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw_angle -= event.relative.x * mouse_sens
		pitch_angle = clamp(pitch_angle - event.relative.y * mouse_sens, deg_to_rad(-60), deg_to_rad(60))
		yaw.rotation.y = yaw_angle
		pitch.rotation.x = pitch_angle

func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

	# Aplica gravedad si no está en el suelo
	if not is_on_floor():
		velocity.y -= gravity * delta

	# === Movimiento relativo a la cámara ===
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	var forward: Vector3 = -yaw.global_transform.basis.z
	var right: Vector3 =  yaw.global_transform.basis.x
	var dir: Vector3 = (forward * input_z + right * input_x)
	if dir.length() > 1.0:
		dir = dir.normalized()

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Mueve al jugador
	move_and_slide()

	# === Rotar el cuerpo hacia donde mira la cámara ===
	if dir.length() > 0.05:
		var target_yaw := yaw.rotation.y
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.18)
