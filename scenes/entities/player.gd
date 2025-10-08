extends CharacterBody3D
class_name Player

# === MOVIMIENTO Y CONTROL ===
@export var move_speed: float = 6.0
@export var jump_velocity: float = 7.0
@export var mouse_sens: float = 0.003
@export var walk_speed: float = 2.5
@export var run_speed: float = 6.0

@export var face_lerp: float = 0.18
@export var model_forward_correction_deg: float = 0.0

# === ANIMACIONES ===
@export var fall_clip_name := "fall air loop"  # clip exacto de caída
@export var fall_threshold: float = -0.2       # empieza “fall” si vel.y < esto
@export var fall_blend_lerp: float = 12.0      # rapidez de mezcla 0↔1

# === NODOS ===
@onready var yaw: Node3D = $CameraRig/Yaw
@onready var pitch: Node3D = $CameraRig/Yaw/Pitch
@onready var model: Node3D = $Pivot/Model
@onready var anim_tree: AnimationTree = $Pivot/Model/AnimationTree
@onready var anim_player: AnimationPlayer = $Pivot/Model/AnimationPlayer

# === RUTAS EN EL ANIMATION TREE ===
const PARAM_LOC       := "parameters/Locomotion/blend_position"
const PARAM_JUMP      := "parameters/Jump/request"
const PARAM_AIRBLEND  := "parameters/AirBlend/blend_amount"
const PARAM_FALLANIM  := "parameters/FallAnim/animation"

# === VARIABLES INTERNAS ===
var yaw_angle := 0.0
var pitch_angle := 0.0
var was_on_floor := true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true

	# Linkea el clip de caída al nodo Animation "FallAnim"
	anim_tree.set(PARAM_FALLANIM, fall_clip_name)
	print("✅ FallAnim clip asignado:", anim_tree.get(PARAM_FALLANIM))

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

	# === DIRECCIÓN EN PLANO RELATIVA A LA CÁMARA ===
	var iz := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var ix := Input.get_action_strength("move_right")  - Input.get_action_strength("move_left")
	var forward: Vector3 = -yaw.global_transform.basis.z
	var right:   Vector3 =  yaw.global_transform.basis.x
	var dir: Vector3 = (forward * iz + right * ix)
	if dir.length() > 1.0:
		dir = dir.normalized()

	# === VELOCIDAD ===
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	# === SALTO ===
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		_play_jump()

	move_and_slide()

	# === ORIENTACIÓN DEL MESH SEGÚN DIRECCIÓN ===
	if dir.length() > 0.05:
		var target_yaw := atan2(dir.x, dir.z) + deg_to_rad(model_forward_correction_deg)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)

	# === BLEND Idle/Walk/Run ===
	var speed_h: float = Vector2(velocity.x, velocity.z).length()
	var t: float = 0.0
	if speed_h <= walk_speed:
		t = remap(speed_h, 0.0, max(0.01, walk_speed), 0.0, 0.4)
	else:
		t = remap(speed_h, walk_speed, max(walk_speed, run_speed), 0.4, 1.0)
	anim_tree.set(PARAM_LOC, clampf(t, 0.0, 1.0))

	# === FALL / AIRBLEND ===
	var target_air: float = 1.0 if (not is_on_floor() and velocity.y < fall_threshold) else 0.0
	var current_air := float(anim_tree.get(PARAM_AIRBLEND))
	var step := clampf(delta * fall_blend_lerp, 0.0, 1.0)
	var new_air := lerpf(current_air, target_air, step)
	anim_tree.set(PARAM_AIRBLEND, new_air)

	# === ATERRIZAJE ===
	if is_on_floor() and not was_on_floor:
		anim_tree.set(PARAM_AIRBLEND, 0.0)
		anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

	was_on_floor = is_on_floor()

func _play_jump() -> void:
	anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
