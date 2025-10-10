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
@onready var game_state: GameState = get_node_or_null(^"/root/GameState")

@onready var sim_clock: SimClock = get_node_or_null(^"/root/SimClock")

# --- MÓDULOS (nuevos onready) ---
@onready var m_movement: MovementModule = $Modules/Movement
@onready var m_jump: JumpModule = $Modules/Jump
@onready var m_state: StateModule = $Modules/State
@onready var m_orientation: OrientationModule = $Modules/Orientation
@onready var m_anim: AnimationCtrlModule = $Modules/AnimationCtrl
@onready var m_audio: AudioCtrlModule = $Modules/AudioCtrl

# ============================================================================
# INTERNAL STATE
# ============================================================================
var _sprint_threshold: float
var _use_sim_clock := false
var _skip_module_updates := false
var _block_animation_updates := false
var _pending_move_delta := 0.0
var _pending_move_is_sprinting := false
var _pending_move_ready := false

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	_sprint_threshold = run_speed * 0.4

	# Setup de módulos (simple referencia al player)
	for m in [m_movement, m_jump, m_state, m_orientation, m_anim, m_audio]:
		m.setup(self)

	_use_sim_clock = sim_clock != null and is_instance_valid(sim_clock)
	if _use_sim_clock:
		sim_clock.register(self, "local")
		if not sim_clock.ticked.is_connected(_on_sim_clock_ticked):
			sim_clock.ticked.connect(_on_sim_clock_ticked)
		set_physics_process(false)
	else:
		set_physics_process(true)

func _exit_tree() -> void:
	if not _use_sim_clock:
		return
	if sim_clock and is_instance_valid(sim_clock):
		if sim_clock.ticked.is_connected(_on_sim_clock_ticked):
			sim_clock.ticked.disconnect(_on_sim_clock_ticked)
		sim_clock.unregister(self, "local")

# ============================================================================
# MAIN PHYSICS LOOP
# ============================================================================
func physics_tick(delta: float) -> void:
	var input_dir: Vector3 = _get_camera_relative_input()
	var is_sprinting: bool = _update_sprint_state(delta, input_dir)

	m_movement.set_frame_input(input_dir, is_sprinting)
	m_orientation.set_frame_input(input_dir)
	var air_time := 0.0
	if m_jump and m_jump.has_method("get_air_time"):
		air_time = m_jump.get_air_time()
	m_anim.set_frame_anim_inputs(is_sprinting, air_time)

	_skip_module_updates = (game_state and game_state.is_paused) or false
	_block_animation_updates = (game_state and game_state.is_in_cinematic) or false

	_pending_move_delta = delta
	_pending_move_is_sprinting = is_sprinting
	_pending_move_ready = true

	if not _use_sim_clock:
		_manual_tick_modules(delta)
		_finish_physics_step(delta, is_sprinting)
		_pending_move_ready = false

func _physics_process(delta: float) -> void:
	if _use_sim_clock:
		return
	physics_tick(delta)

func _manual_tick_modules(delta: float) -> void:
	if not _skip_module_updates:
		if m_state:
			m_state.physics_tick(delta)
		if m_jump:
			m_jump.physics_tick(delta)
		if m_movement:
			m_movement.physics_tick(delta)
		if m_orientation:
			m_orientation.physics_tick(delta)
		if not _block_animation_updates and m_anim:
			m_anim.physics_tick(delta)
	if m_audio:
		m_audio.physics_tick(delta)

func _finish_physics_step(delta: float, is_sprinting: bool) -> void:
	move_and_slide()
	_consume_sprint_stamina(delta, is_sprinting)

func _on_sim_clock_ticked(group_name: String, _dt: float) -> void:
	if group_name != "local":
		return
	if not _pending_move_ready:
		return
	_finish_physics_step(_pending_move_delta, _pending_move_is_sprinting)
	_pending_move_ready = false

func should_skip_module_updates() -> bool:
	return _skip_module_updates

func should_block_animation_update() -> bool:
	return _block_animation_updates


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

func _play_footstep_audio() -> void:
	m_audio.play_footstep()

func _play_landing_audio(is_hard: bool) -> void:
	m_audio.play_landing(is_hard)

func _trigger_camera_landing(is_hard: bool) -> void:
	if camera_rig:
		camera_rig.call_deferred("_on_player_landed", is_hard)
