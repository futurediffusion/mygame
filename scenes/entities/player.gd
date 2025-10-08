extends CharacterBody3D
class_name Player

@export var move_speed: float = 6.0
@export var jump_velocity: float = 7.0
@export var mouse_sens: float = 0.003
@export var walk_speed: float = 2.5
@export var run_speed: float = 6.0

@export var face_lerp: float = 0.18
# Si tu GLB mira a +Z en vez de -Z, pon 180. Prueba 0 o 180 según tu modelo.
@export var model_forward_correction_deg: float = 0.0

@onready var yaw: Node3D = $CameraRig/Yaw
@onready var pitch: Node3D = $CameraRig/Yaw/Pitch
@onready var model: Node3D = $Pivot/Model

@onready var anim_tree: AnimationTree = $Pivot/Model/AnimationTree
@onready var anim_player: AnimationPlayer = $Pivot/Model/AnimationPlayer

const PARAM_LOC := "parameters/Locomotion/blend_position"
const PARAM_JUMP := "parameters/Jump/request"

var yaw_angle := 0.0
var pitch_angle := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	# _debug_print_anims() # opcional

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw_angle -= event.relative.x * mouse_sens
		pitch_angle = clamp(pitch_angle - event.relative.y * mouse_sens, deg_to_rad(-60), deg_to_rad(60))
		yaw.rotation.y = yaw_angle
		pitch.rotation.x = pitch_angle

func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Dirección en plano relativa a la cámara
	var iz := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var ix := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var forward: Vector3 = -yaw.global_transform.basis.z
	var right: Vector3 = yaw.global_transform.basis.x
	var dir: Vector3 = (forward * iz + right * ix)
	if dir.length() > 1.0:
		dir = dir.normalized()

	# Velocidad
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		_play_jump()

	move_and_slide()

	# --- ORIENTACIÓN DEL MESH SEGÚN LA DIRECCIÓN ---
	if dir.length() > 0.05:
		var target_yaw := atan2(dir.x, dir.z) + deg_to_rad(model_forward_correction_deg)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)
	# (No tocamos rotation del CharacterBody3D ni la cámara)

	# --- BLEND Idle/Walk/Run (BlendSpace1D "Locomotion") ---
	var speed_h: float = Vector2(velocity.x, velocity.z).length()
	var t: float = 0.0
	if speed_h <= walk_speed:
		t = remap(speed_h, 0.0, max(0.01, walk_speed), 0.0, 0.4)
	else:
		t = remap(speed_h, walk_speed, max(walk_speed, run_speed), 0.4, 1.0)
	anim_tree.set(PARAM_LOC, clampf(t, 0.0, 1.0)) # ✅ usa clampf para floats

func _play_jump() -> void:
	anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
