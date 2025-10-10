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
@onready var game_state: Node = get_node(^"/root/GameState")

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

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	_sprint_threshold = run_speed * 0.4

	# Setup de módulos (simple referencia al player)
	for m in [m_movement, m_jump, m_state, m_orientation, m_anim, m_audio]:
		m.setup(self)

# ============================================================================
# MAIN PHYSICS LOOP
# ============================================================================
func _physics_process(delta: float) -> void:
	# INPUT
	var input_dir: Vector3 = _get_camera_relative_input()
	var is_sprinting: bool = _update_sprint_state(delta, input_dir)

	# INYECCIONES POR FRAME
	m_movement.set_frame_input(input_dir, is_sprinting)
	m_orientation.set_frame_input(input_dir)
	var air_time := 0.0
	if "get_air_time" in m_jump:
		air_time = m_jump.get_air_time()
	m_anim.set_frame_anim_inputs(is_sprinting, air_time)

	# FLAGS GLOBALES
	var paused: bool = game_state.is_paused
	var block_anim: bool = game_state.is_in_cinematic  # ejemplo: en cinemática, mover pero no animar

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

