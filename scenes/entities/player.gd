extends CharacterBody3D
class_name Player

# === AUDIO SFX ===
@onready var jump_sfx: AudioStreamPlayer3D = $JumpSFX
@onready var land_sfx: AudioStreamPlayer3D = $LandSFX

# === MOVIMIENTO Y CONTROL ===
@export var move_speed: float = 6.0              # (compatibilidad, no se usa directo)
@export var jump_velocity: float = 7.0
@export var walk_speed: float = 2.5              # velocidad a la que el blend está en "walk"
@export var run_speed: float = 6.0               # velocidad máxima sin sprint
@export var sprint_speed: float = 9.5            # velocidad máxima en sprint

@export var face_lerp: float = 0.18
@export var model_forward_correction_deg: float = 0.0

# === SPRINT: animación ===
@export var sprint_anim_speed_scale: float = 1.15
@export var sprint_blend_bias: float = 0.85

# === ANIMACIONES ===
@export var fall_clip_name := "fall air loop"

# Cuándo empieza a considerarse “caída” y cómo sube el blend
@export var fall_threshold: float = -0.05
@export var fall_ramp_delay: float = 0.10
@export var fall_ramp_time: float = 0.20
@export var fall_blend_lerp: float = 12.0

# === NODOS ===
@onready var yaw: Node3D = $CameraRig/Yaw
@onready var model: Node3D = $Pivot/Model
@onready var anim_tree: AnimationTree = $Pivot/Model/AnimationTree
@onready var anim_player: AnimationPlayer = $Pivot/Model/AnimationPlayer

# === RUTAS EN EL ANIMATION TREE ===
const PARAM_LOC       := "parameters/Locomotion/blend_position"
const PARAM_JUMP      := "parameters/Jump/request"
const PARAM_AIRBLEND  := "parameters/AirBlend/blend_amount"
const PARAM_FALLANIM  := "parameters/FallAnim/animation"
const PARAM_SPRINTSCL := "parameters/SprintScale/scale"

# === VARIABLES INTERNAS ===
var was_on_floor: bool = true
var air_time: float = 0.0

func _ready() -> void:
	# (Se elimina el control del mouse aquí. Lo maneja CameraOrbit.gd)
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	anim_tree.set(PARAM_FALLANIM, fall_clip_name)
	anim_tree.set(PARAM_SPRINTSCL, 1.0)
	anim_tree.set(PARAM_AIRBLEND, 0.0)
	was_on_floor = is_on_floor()

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

	# === SPRINT ON/OFF ===
	var sprinting := Input.is_action_pressed("sprint")
	var max_ground_speed := sprint_speed if sprinting else run_speed

	# === VELOCIDAD (horizontal) ===
	velocity.x = dir.x * max_ground_speed
	velocity.z = dir.z * max_ground_speed

	# === SALTO + SFX ===
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		_play_jump()
		if is_instance_valid(jump_sfx):
			jump_sfx.play()

	move_and_slide()

	# === AIR TIME ===
	if is_on_floor():
		air_time = 0.0
	else:
		air_time += delta

	# === ORIENTACIÓN DEL MESH ===
	if dir.length() > 0.05:
		var target_yaw := atan2(dir.x, dir.z) + deg_to_rad(model_forward_correction_deg)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)

	# === BLEND Idle/Walk/Run ===
	var speed_h: float = Vector2(velocity.x, velocity.z).length()
	var t: float = 0.0
	if speed_h <= walk_speed:
		t = remap(speed_h, 0.0, max(0.01, walk_speed), 0.0, 0.4)
	else:
		t = remap(speed_h, walk_speed, max(walk_speed, max_ground_speed), 0.4, 1.0)
	if sprinting:
		t = pow(clampf(t, 0.0, 1.0), sprint_blend_bias)
	anim_tree.set(PARAM_LOC, clampf(t, 0.0, 1.0))

	# === TimeScale SOLO para locomoción (SprintScale) ===
	var anim_scale := 1.0
	if sprinting:
		anim_scale = lerp(1.0, sprint_anim_speed_scale, t)
	anim_tree.set(PARAM_SPRINTSCL, anim_scale)

	# === FALL / AIRBLEND ===
	var target_air: float = 0.0
	if not is_on_floor() and velocity.y < fall_threshold:
		var ramp := inverse_lerp(fall_ramp_delay, fall_ramp_delay + fall_ramp_time, air_time)
		ramp = clampf(ramp, 0.0, 1.0)
		ramp = ramp * ramp * (3.0 - 2.0 * ramp)
		target_air = ramp

	var current_air: float = anim_tree.get(PARAM_AIRBLEND)
	var step := clampf(delta * fall_blend_lerp, 0.0, 1.0)
	var new_air := lerpf(current_air, target_air, step)
	anim_tree.set(PARAM_AIRBLEND, new_air)

	# === ATERRIZAJE + SFX ===
	if is_on_floor() and not was_on_floor:
		anim_tree.set(PARAM_AIRBLEND, 0.0)
		if is_instance_valid(land_sfx):
			land_sfx.play()

	# actualizar estado de suelo al final del frame
	was_on_floor = is_on_floor()

func _play_jump() -> void:
	anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
