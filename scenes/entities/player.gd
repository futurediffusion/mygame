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
@export_range(1.0, 15.0, 0.1) var jump_velocity: float = 8.5

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

# --- MÓDULOS (nuevos onready) ---
@onready var m_movement: MovementModule = $Modules/Movement
@onready var m_jump: JumpModule = $Modules/Jump
@onready var m_state: StateModule = $Modules/State
@onready var m_orientation: OrientationModule = $Modules/Orientation
@onready var m_anim: AnimationCtrlModule = $Modules/AnimationCtrl
@onready var m_audio: AudioCtrlModule = $Modules/AudioCtrl

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
var _footstep_timer: float = 0.0

# Cached values
var _gravity: float
var _model_correction_rad: float
var _max_slope_rad: float
var _sprint_threshold: float

# --- Helpers de velocidad horizontal (no cambian lógica) ---
func _h_vec() -> Vector2:
	return Vector2(velocity.x, velocity.z)

func _set_h_vec(v: Vector2) -> void:
	velocity.x = v.x
	velocity.z = v.y

func _h_speed() -> float:
	return _h_vec().length()

func _is_moving_h() -> bool:
	return _h_speed() > 0.001

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	_initialize_animation_system()
	_cache_constants()
	_configure_physics()
	_was_on_floor = is_on_floor()

	# Setup de módulos (simple referencia al player)
	for m in [m_movement, m_jump, m_state, m_orientation, m_anim, m_audio]:
		m.setup(self)

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
	# INPUT
	var input_dir: Vector3 = _get_camera_relative_input()
	var is_sprinting: bool = _update_sprint_state(delta, input_dir)

	# INYECCIONES POR FRAME
	m_movement.set_frame_input(input_dir, is_sprinting)
	var air_time := _air_time
	if "get_air_time" in m_jump:
		air_time = m_jump.get_air_time()
	m_anim.set_frame_anim_inputs(is_sprinting, air_time)

	# FLAGS GLOBALES (en el futuro: GameState.is_paused(), is_in_cinematic())
	var paused := false
	var block_anim := false  # ejemplo: en cinemática, mover pero no animar

	# ORDEN CANÓNICO
	if not paused:
		m_state.physics_tick(delta)
		m_jump.physics_tick(delta)
		m_movement.physics_tick(delta)
		m_orientation.physics_tick(delta)
		if not block_anim:
			m_anim.physics_tick(delta)

	# Audio puede correr incluso si paused (tu decisión)
	m_audio.physics_tick(delta)

	# FÍSICAS
	move_and_slide()

	# POST-MOVE
	_consume_sprint_stamina(delta, is_sprinting)

	# Puentes legacy (inofensivos si quedaron vacíos)
	_update_model_rotation(delta, input_dir)
	_update_animation_state(delta, input_dir, is_sprinting)
	_update_footstep_audio(delta)

	_was_on_floor = is_on_floor()

# ============================================================================
# PHYSICS CALCULATIONS
# ============================================================================
func _apply_gravity(delta: float) -> void:
	var base_gravity: float = m_state.gravity if "gravity" in m_state else _gravity
	if "apply_gravity" in m_state:
		m_state.apply_gravity(delta)
	else:
		velocity.y -= base_gravity * delta


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

func _update_horizontal_velocity(_d: float, _i: Vector3, _s: bool) -> void:
	pass

func _accelerate_towards(current: Vector2, target: Vector2, delta: float) -> Vector2:
	return m_movement.accelerate_towards(current, target, delta)

func _apply_deceleration(current: Vector2, delta: float) -> Vector2:
	return m_movement.apply_deceleration(current, delta)

# ============================================================================
# JUMP SYSTEM
# ============================================================================
func _update_jump_mechanics(delta: float) -> void:
	m_jump.update_jump_mechanics(delta)

	if "get_air_time" in m_jump:
		_air_time = m_jump.get_air_time()
	else:
		if is_on_floor():
			_air_time = 0.0
		else:
			_air_time += delta

func _handle_jump_input() -> void:
	m_jump.handle_jump_input()

func _execute_jump() -> void:
	m_jump.execute_jump()

func _trigger_jump_animation() -> void:
	m_jump.trigger_jump_animation()

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
func _update_model_rotation(delta: float, input_dir: Vector3) -> void:
	m_orientation.update_model_rotation(delta, input_dir)

# ============================================================================
# ANIMATION SYSTEM
# ============================================================================
func _update_animation_state(delta: float, _input_dir: Vector3, _is_sprinting: bool) -> void:
	pass

func _update_locomotion_blend(_is_sprinting: bool) -> void:
	# ya no se usa (quedará como puente vacío o puedes dejarlo como está si nadie lo llama directo)
	pass

func _update_sprint_timescale(_is_sprinting: bool) -> void:
	pass

func _update_air_blend(_delta: float) -> void:
	pass

func _calculate_fall_blend() -> float:
	return 0.0

# ============================================================================
# AUDIO SYSTEM
# ============================================================================
func _update_footstep_audio(_delta: float) -> void:
	# Footsteps are now driven by animation callbacks for perfect sync
	pass

func _play_footstep_audio() -> void:
	m_audio.play_footstep()

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
	m_state.handle_landing()


func _play_landing_audio(is_hard: bool) -> void:
	m_audio.play_landing(is_hard)

func _trigger_camera_landing(is_hard: bool) -> void:
	if camera_rig:
		camera_rig.call_deferred("_on_player_landed", is_hard)

func _play_audio_safe(audio_player: AudioStreamPlayer3D) -> void:
	# lo mantiene por compatibilidad; si quieres llamar, usa m_audio.play_* en su lugar
	if is_instance_valid(audio_player):
		audio_player.play()
