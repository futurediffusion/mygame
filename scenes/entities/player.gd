extends CharacterBody3D
class_name Player

# === AUDIO SFX ===
@onready var jump_sfx: AudioStreamPlayer3D = $JumpSFX
@onready var land_sfx: AudioStreamPlayer3D = $LandSFX
@onready var footstep_sfx: AudioStreamPlayer3D = $FootstepSFX

# === MOVIMIENTO Y CONTROL ===
@export var walk_speed: float = 2.5
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var jump_velocity: float = 7.0
@export var accel_ground: float = 22.0
@export var accel_air: float = 8.0
@export var decel: float = 18.0
@export var max_slope_deg: float = 46.0
@export var snap_len: float = 0.3

# === CÓYOTE / BUFFER ===
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.15
var _coyote: float = 0.0
var _jump_buf: float = 0.0

# === SPRINT: animación ===
@export var sprint_anim_speed_scale: float = 1.15
@export var sprint_blend_bias: float = 0.85

# === ANIMACIONES / AIR ===
@export var fall_clip_name: StringName = &"fall air loop"
@export var fall_threshold: float = -0.05
@export var fall_ramp_delay: float = 0.10
@export var fall_ramp_time: float = 0.20
@export var fall_blend_lerp: float = 12.0
@export var face_lerp: float = 0.18
@export var model_forward_correction_deg: float = 0.0

# === NODOS ===
@onready var yaw: Node3D = $CameraRig/Yaw
@onready var model: Node3D = $Pivot/Model
@onready var anim_tree: AnimationTree = $Pivot/Model/AnimationTree
@onready var anim_player: AnimationPlayer = $Pivot/Model/AnimationPlayer
@onready var stamina: Stamina = $Stamina   # hijo con Stamina.gd

# === RUTAS ANIMATION TREE ===
const PARAM_LOC       := "parameters/Locomotion/blend_position"
const PARAM_JUMP      := "parameters/Jump/request"
const PARAM_AIRBLEND  := "parameters/AirBlend/blend_amount"
const PARAM_FALLANIM  := "parameters/FallAnim/animation"
const PARAM_SPRINTSCL := "parameters/SprintScale/scale"

# === INTERNAS ===
var was_on_floor: bool = true
var air_time: float = 0.0
var _foot_timer: float = 0.0

func _ready() -> void:
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	anim_tree.set(PARAM_FALLANIM, fall_clip_name)
	anim_tree.set(PARAM_SPRINTSCL, 1.0)
	anim_tree.set(PARAM_AIRBLEND, 0.0)
	was_on_floor = is_on_floor()

	# Phys settings
	floor_max_angle = deg_to_rad(max_slope_deg)
	floor_snap_length = snap_len

func _physics_process(delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if not is_on_floor():
		velocity.y -= gravity * delta

	# === INPUT PLANO RELATIVO A CÁMARA ===
	var iz: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var ix: float = Input.get_action_strength("move_right")  - Input.get_action_strength("move_left")
	var forward: Vector3 = -yaw.global_transform.basis.z
	var right:   Vector3 =  yaw.global_transform.basis.x
	var dir: Vector3 = (forward * iz + right * ix)
	if dir.length() > 1.0:
		dir = dir.normalized()

	# === SPRINT + STAMINA ===
	var wants_sprint: bool = Input.is_action_pressed("sprint")
	stamina.tick(delta)
	var sprinting: bool = wants_sprint and stamina.can_sprint()
	var target_max: float = sprint_speed if sprinting else run_speed

	# === ACEL/DECEL HORIZONTAL ===
	var horiz: Vector2 = Vector2(velocity.x, velocity.z)
	var target_h: Vector2 = Vector2.ZERO
	if dir != Vector3.ZERO:
		target_h = Vector2(dir.x, dir.z) * target_max

	var accel: float = accel_ground if is_on_floor() else accel_air
	var to_target: Vector2 = (target_h - horiz)
	var change: Vector2 = to_target.normalized() * accel * delta if to_target.length() > 0.0 else Vector2.ZERO
	if change.length() > to_target.length():
		change = to_target
	horiz += change

	# Desaceleración si no hay input
	if dir == Vector3.ZERO and horiz.length() > 0.0:
		var drop: float = min(horiz.length(), decel * delta)
		horiz = horiz.normalized() * (horiz.length() - drop) if horiz.length() > 0.0 else Vector2.ZERO

	velocity.x = horiz.x
	velocity.z = horiz.y

	# === CÓYOTE / BUFFER ===
	if is_on_floor():
		_coyote = coyote_time
		air_time = 0.0
	else:
		_coyote = max(0.0, _coyote - delta)
		air_time += delta

	if Input.is_action_just_pressed("jump"):
		_jump_buf = jump_buffer
	else:
		_jump_buf = max(0.0, _jump_buf - delta)

	# === SALTO (usa coyote o buffer) ===
	var do_jump: bool = (_jump_buf > 0.0) and (is_on_floor() or _coyote > 0.0)
	if do_jump:
		velocity.y = jump_velocity
		_coyote = 0.0
		_jump_buf = 0.0
		_play_jump()
		if is_instance_valid(jump_sfx):
			jump_sfx.play()
		if has_node(^"CameraRig"):
			get_node(^"CameraRig").call_deferred("_play_jump_kick")

	move_and_slide()

	# === Sprint drena ===
	if sprinting and Vector2(velocity.x, velocity.z).length() > run_speed * 0.4:
		stamina.consume_for_sprint(delta)

	# === ORIENTACIÓN DEL MESH ===
	if dir.length() > 0.05:
		var target_yaw: float = atan2(dir.x, dir.z) + deg_to_rad(model_forward_correction_deg)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)

	# === BLEND Idle/Walk/Run ===
	var speed_h: float = Vector2(velocity.x, velocity.z).length()
	var t: float = 0.0
	if speed_h <= walk_speed:
		t = remap(speed_h, 0.0, max(0.01, walk_speed), 0.0, 0.4)
	else:
		t = remap(speed_h, walk_speed, max(walk_speed, target_max), 0.4, 1.0)
	if sprinting:
		t = pow(clampf(t, 0.0, 1.0), sprint_blend_bias)
	anim_tree.set(PARAM_LOC, clampf(t, 0.0, 1.0))

	# === TimeScale solo locomoción (SprintScale) ===
	var anim_scale: float = 1.0
	if sprinting:
		anim_scale = lerp(1.0, sprint_anim_speed_scale, t)
	anim_tree.set(PARAM_SPRINTSCL, anim_scale)

	# === FALL / AIRBLEND ===
	var target_air: float = 0.0
	if not is_on_floor() and velocity.y < fall_threshold:
		var ramp: float = inverse_lerp(fall_ramp_delay, fall_ramp_delay + fall_ramp_time, air_time)
		ramp = clampf(ramp, 0.0, 1.0)
		ramp = ramp * ramp * (3.0 - 2.0 * ramp) # S-curve
		target_air = ramp
	var current_air: float = float(anim_tree.get(PARAM_AIRBLEND)) # cast para evitar Variant
	var step: float = clampf(delta * fall_blend_lerp, 0.0, 1.0)
	var new_air: float = lerpf(current_air, target_air, step)
	anim_tree.set(PARAM_AIRBLEND, new_air)

	# === FOOTSTEPS (cadencia) ===
	_update_footsteps(delta, speed_h)

	# === ATERRIZAJE + SFX (duro/suave) ===
	if is_on_floor() and not was_on_floor:
		var hard: bool = abs(velocity.y) > 10.0
		if is_instance_valid(land_sfx) and land_sfx.stream != null:
			land_sfx.volume_db = -6.0 if hard else -12.0   # ← antes era unit_db
			land_sfx.pitch_scale = 0.95 if hard else 1.05
			land_sfx.play()
		if has_node(^"CameraRig"):
			get_node(^"CameraRig").call_deferred("_on_player_landed", hard)
	was_on_floor = is_on_floor()
func _play_jump() -> void:
	anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _update_footsteps(delta: float, speed_h: float) -> void:
	if not is_on_floor() or speed_h < 0.5:
		_foot_timer = 0.0
		return
	var step_period: float = lerpf(0.5, 0.28, clampf(speed_h / sprint_speed, 0.0, 1.0))
	_foot_timer += delta
	if _foot_timer >= step_period:
		_foot_timer -= step_period
		if is_instance_valid(footstep_sfx):
			footstep_sfx.pitch_scale = randf_range(0.95, 1.05)
			footstep_sfx.play()
