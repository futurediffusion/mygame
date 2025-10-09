extends CharacterBody3D
class_name Player

# ============================================================================
# AUDIO SYSTEM
# ============================================================================
@onready var jump_sfx: AudioStreamPlayer3D = $JumpSFX
@onready var land_sfx: AudioStreamPlayer3D = $LandSFX
@onready var footstep_sfx: AudioStreamPlayer3D = $FootstepSFX

# ============================================================================
# MOVEMENT CONFIGURATION
# ============================================================================
@export_group("Movement")
@export_range(0.1, 10.0, 0.1) var walk_speed: float = 2.5
@export_range(0.1, 15.0, 0.1) var run_speed: float = 6.0
@export_range(0.1, 20.0, 0.1) var sprint_speed: float = 9.5
@export_range(1.0, 15.0, 0.1) var jump_velocity: float = 7.0

@export_group("Physics")
@export_range(1.0, 50.0, 0.5) var accel_ground: float = 22.0
@export_range(1.0, 30.0, 0.5) var accel_air: float = 8.0
@export_range(1.0, 50.0, 0.5) var decel: float = 18.0
@export_range(0.0, 89.0, 1.0) var max_slope_deg: float = 46.0
@export_range(0.0, 2.0, 0.05) var snap_len: float = 0.3

@export_group("Input Buffering")
@export_range(0.0, 0.5, 0.01) var coyote_time: float = 0.12
@export_range(0.0, 0.5, 0.01) var jump_buffer: float = 0.15

@export_group("Sprint Animation")
@export_range(1.0, 2.0, 0.05) var sprint_anim_speed_scale: float = 1.15
@export_range(0.0, 1.0, 0.05) var sprint_blend_bias: float = 0.85

@export_group("Air State")
@export var fall_clip_name: StringName = &"fall air loop"
@export_range(-10.0, 0.0, 0.01) var fall_threshold: float = -0.05
@export_range(0.0, 1.0, 0.01) var fall_ramp_delay: float = 0.10
@export_range(0.0, 1.0, 0.01) var fall_ramp_time: float = 0.20
@export_range(1.0, 30.0, 0.5) var fall_blend_lerp: float = 12.0

@export_group("Model Rotation")
@export_range(0.0, 1.0, 0.01) var face_lerp: float = 0.18
@export_range(-180.0, 180.0, 1.0) var model_forward_correction_deg: float = 0.0

# ============================================================================
# CACHED NODES
# ============================================================================
@onready var yaw: Node3D = $CameraRig/Yaw
@onready var model: Node3D = $Pivot/Model
@onready var anim_tree: AnimationTree = $Pivot/Model/AnimationTree
@onready var anim_player: AnimationPlayer = $Pivot/Model/AnimationPlayer
@onready var stamina: Stamina = $Stamina
@onready var camera_rig: Node = get_node_or_null(^"CameraRig")

# ============================================================================
# ANIMATION TREE PATHS (Constants for performance)
# ============================================================================
const PARAM_LOC: StringName = &"parameters/Locomotion/blend_position"
const PARAM_JUMP: StringName = &"parameters/Jump/request"
const PARAM_AIRBLEND: StringName = &"parameters/AirBlend/blend_amount"
const PARAM_FALLANIM: StringName = &"parameters/FallAnim/animation"
const PARAM_SPRINTSCL: StringName = &"parameters/SprintScale/scale"

# ============================================================================
# INTERNAL STATE
# ============================================================================
var _was_on_floor: bool = true
var _air_time: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _footstep_timer: float = 0.0
var _current_air_blend: float = 0.0

# Cached values
var _gravity: float
var _model_correction_rad: float
var _max_slope_rad: float
var _sprint_threshold: float

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	_initialize_animation_system()
	_cache_constants()
	_configure_physics()
	_was_on_floor = is_on_floor()

func _initialize_animation_system() -> void:
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	anim_tree.set(PARAM_FALLANIM, fall_clip_name)
	anim_tree.set(PARAM_SPRINTSCL, 1.0)
	anim_tree.set(PARAM_AIRBLEND, 0.0)

func _cache_constants() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_model_correction_rad = deg_to_rad(model_forward_correction_deg)
	_max_slope_rad = deg_to_rad(max_slope_deg)
	_sprint_threshold = run_speed * 0.4

func _configure_physics() -> void:
	floor_max_angle = _max_slope_rad
	floor_snap_length = snap_len

# ============================================================================
# MAIN PHYSICS LOOP
# ============================================================================
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	
	var input_dir: Vector3 = _get_camera_relative_input()
	var is_sprinting: bool = _update_sprint_state(delta, input_dir)
	
	_update_horizontal_velocity(delta, input_dir, is_sprinting)
	_update_jump_mechanics(delta)
	_handle_jump_input()
	
	move_and_slide()
	
	_consume_sprint_stamina(delta, is_sprinting)
	_update_model_rotation(delta, input_dir)
	_update_animation_state(delta, input_dir, is_sprinting)
	_update_footstep_audio(delta)
	_handle_landing()
	
	_was_on_floor = is_on_floor()

# ============================================================================
# PHYSICS CALCULATIONS
# ============================================================================
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

func _get_camera_relative_input() -> Vector3:
	var input_z: float = Input.get_axis("move_back", "move_forward")
	var input_x: float = Input.get_axis("move_left", "move_right")
	
	if input_z == 0.0 and input_x == 0.0:
		return Vector3.ZERO
	
	var cam_basis: Basis = yaw.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	var right: Vector3 = cam_basis.x
	
	var direction: Vector3 = (forward * input_z + right * input_x)
	return direction.normalized() if direction.length_squared() > 1.0 else direction

func _update_horizontal_velocity(delta: float, input_dir: Vector3, is_sprinting: bool) -> void:
	var target_speed: float = sprint_speed if is_sprinting else run_speed
	var current_horiz: Vector2 = Vector2(velocity.x, velocity.z)
	
	if input_dir != Vector3.ZERO:
		var target_horiz: Vector2 = Vector2(input_dir.x, input_dir.z) * target_speed
		current_horiz = _accelerate_towards(current_horiz, target_horiz, delta)
	else:
		current_horiz = _apply_deceleration(current_horiz, delta)
	
	velocity.x = current_horiz.x
	velocity.z = current_horiz.y

func _accelerate_towards(current: Vector2, target: Vector2, delta: float) -> Vector2:
	var accel_rate: float = accel_ground if is_on_floor() else accel_air
	var difference: Vector2 = target - current
	var distance: float = difference.length()
	
	if distance < 0.001:
		return target
	
	var change_amount: float = min(accel_rate * delta, distance)
	return current + difference.normalized() * change_amount

func _apply_deceleration(current: Vector2, delta: float) -> Vector2:
	var speed: float = current.length()
	if speed < 0.001:
		return Vector2.ZERO
	
	var drop: float = min(speed, decel * delta)
	return current.normalized() * (speed - drop)

# ============================================================================
# JUMP SYSTEM
# ============================================================================
func _update_jump_mechanics(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_air_time = 0.0
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)
		_air_time += delta
	
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)

func _handle_jump_input() -> void:
	var can_jump: bool = _jump_buffer_timer > 0.0 and (is_on_floor() or _coyote_timer > 0.0)
	
	if can_jump:
		_execute_jump()

func _execute_jump() -> void:
	velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	
	_trigger_jump_animation()
	_play_audio_safe(jump_sfx)
	
	if camera_rig:
		camera_rig.call_deferred("_play_jump_kick")

func _trigger_jump_animation() -> void:
	anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# ============================================================================
# SPRINT & STAMINA
# ============================================================================
func _update_sprint_state(delta: float, input_dir: Vector3) -> bool:
	stamina.tick(delta)
	
	var wants_sprint: bool = Input.is_action_pressed("sprint") and input_dir != Vector3.ZERO
	return wants_sprint and stamina.can_sprint()

func _consume_sprint_stamina(delta: float, is_sprinting: bool) -> void:
	if not is_sprinting:
		return
	
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > _sprint_threshold:
		stamina.consume_for_sprint(delta)

# ============================================================================
# MODEL ORIENTATION
# ============================================================================
func _update_model_rotation(_delta: float, input_dir: Vector3) -> void:
	if input_dir.length_squared() < 0.0025:  # 0.05^2
		return
	
	var target_yaw: float = atan2(input_dir.x, input_dir.z) + _model_correction_rad
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)

# ============================================================================
# ANIMATION SYSTEM
# ============================================================================
func _update_animation_state(delta: float, _input_dir: Vector3, is_sprinting: bool) -> void:
	_update_locomotion_blend(is_sprinting)
	_update_sprint_timescale(is_sprinting)
	_update_air_blend(delta)

func _update_locomotion_blend(is_sprinting: bool) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var target_max: float = sprint_speed if is_sprinting else run_speed
	
	var blend_value: float
	if horizontal_speed <= walk_speed:
		blend_value = remap(horizontal_speed, 0.0, walk_speed, 0.0, 0.4)
	else:
		blend_value = remap(horizontal_speed, walk_speed, target_max, 0.4, 1.0)
	
	if is_sprinting:
		blend_value = pow(clampf(blend_value, 0.0, 1.0), sprint_blend_bias)
	
	anim_tree.set(PARAM_LOC, clampf(blend_value, 0.0, 1.0))

func _update_sprint_timescale(is_sprinting: bool) -> void:
	if not is_sprinting:
		anim_tree.set(PARAM_SPRINTSCL, 1.0)
		return
	
	var blend_pos: float = float(anim_tree.get(PARAM_LOC))
	var scale_factor: float = lerp(1.0, sprint_anim_speed_scale, blend_pos)
	anim_tree.set(PARAM_SPRINTSCL, scale_factor)

func _update_air_blend(delta: float) -> void:
	var target_blend: float = _calculate_fall_blend()
	var lerp_speed: float = clampf(delta * fall_blend_lerp, 0.0, 1.0)
	_current_air_blend = lerpf(_current_air_blend, target_blend, lerp_speed)
	anim_tree.set(PARAM_AIRBLEND, _current_air_blend)

func _calculate_fall_blend() -> float:
	if is_on_floor() or velocity.y >= fall_threshold:
		return 0.0
	
	var elapsed: float = _air_time - fall_ramp_delay
	if elapsed <= 0.0:
		return 0.0
	
	var ramp_progress: float = clampf(elapsed / fall_ramp_time, 0.0, 1.0)
	return smoothstep(0.0, 1.0, ramp_progress)

# ============================================================================
# AUDIO SYSTEM
# ============================================================================
func _update_footstep_audio(_delta: float) -> void:
	# Footsteps are now driven by animation callbacks for perfect sync
	pass

func _play_footstep_audio() -> void:
	"""Called by animation track when foot touches ground"""
	if not is_instance_valid(footstep_sfx) or not is_on_floor():
		return
	
	footstep_sfx.pitch_scale = randf_range(0.95, 1.05)
	footstep_sfx.play()

# ============================================================================
# ALTERNATIVE: Timer-based footsteps (less accurate, use if no anim callbacks)
# ============================================================================
func _update_footstep_audio_timer(delta: float) -> void:
	"""Timer-based footsteps - adjust step_period_multiplier to sync with animation"""
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	
	if not is_on_floor() or horizontal_speed < 0.5:
		_footstep_timer = 0.0
		return
	
	# Adjust this multiplier to match your animation timing
	const STEP_PERIOD_MULTIPLIER: float = 1.05  # Increase if sounds are too fast
	var speed_ratio: float = clampf(horizontal_speed / sprint_speed, 0.0, 1.0)
	var step_period: float = lerpf(0.5, 0.28, speed_ratio) * STEP_PERIOD_MULTIPLIER
	
	_footstep_timer += delta
	if _footstep_timer >= step_period:
		_footstep_timer -= step_period
		_play_footstep_audio()

func _handle_landing() -> void:
	if not is_on_floor() or _was_on_floor:
		return
	
	var impact_velocity: float = abs(velocity.y)
	var is_hard_landing: bool = impact_velocity > 10.0
	
	_play_landing_audio(is_hard_landing)
	_trigger_camera_landing(is_hard_landing)

func _play_landing_audio(is_hard: bool) -> void:
	if not is_instance_valid(land_sfx) or land_sfx.stream == null:
		return
	
	land_sfx.volume_db = -6.0 if is_hard else -12.0
	land_sfx.pitch_scale = 0.95 if is_hard else 1.05
	land_sfx.play()

func _trigger_camera_landing(is_hard: bool) -> void:
	if camera_rig:
		camera_rig.call_deferred("_on_player_landed", is_hard)

func _play_audio_safe(audio_player: AudioStreamPlayer3D) -> void:
	if is_instance_valid(audio_player):
		audio_player.play()
