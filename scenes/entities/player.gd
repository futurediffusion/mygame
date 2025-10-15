extends CharacterBody3D
class_name Player

enum ContextState {
	DEFAULT,
	SNEAK,
	SWIM,
	TALK,
	SIT
}

signal context_state_changed(new_state: int, previous_state: int)
signal talk_requested()
signal sit_toggled(is_sitting: bool)
signal interact_requested()
signal combat_mode_switched(mode: String)
signal build_mode_toggled(is_building: bool)

const INPUT_ACTIONS := {
	"sprint": ["sprint"],
	"crouch": ["crouch", "sneak"],
	"jump": ["jump", "roll"],
	"talk": ["talk"],
	"sit": ["sit", "sit_toggle", "sit_stand"],
	"interact": ["interact", "use", "action"],
	"combat_switch": ["switch_weapon", "toggle_weapon", "melee_ranged_switch"],
	"build": ["build", "toggle_build", "build_mode"]
}
const INPUT_BOOTSTRAP_SCRIPT := preload("res://scripts/bootstrap/InputSetup.gd")
const TREE_META_INPUT_BOOTSTRAPPED: StringName = &"input_bootstrap_initialized"
const SIMCLOCK_SCRIPT := preload("res://Singletons/SimClock.gd")
const LOGGER_CONTEXT := "Player"

# ============================================================================
# AUDIO SYSTEM
# ============================================================================
@onready var jump_sfx: AudioStreamPlayer3D = get_node_or_null(^"JumpSFX") as AudioStreamPlayer3D
@onready var land_sfx: AudioStreamPlayer3D = get_node_or_null(^"LandSFX") as AudioStreamPlayer3D
@onready var footstep_sfx: AudioStreamPlayer3D = get_node_or_null(^"FootstepSFX") as AudioStreamPlayer3D

@export var stats: AllyStats

@export var sim_group: StringName = SIMCLOCK_SCRIPT.GROUP_LOCAL
@export var priority: int = 10

# ============================================================================
# MOVEMENT CONFIGURATION
# ============================================================================
@export_group("Movement")
@export_range(GameConstants.MIN_WALK_SPEED, 10.0, 0.1) var walk_speed: float = GameConstants.DEFAULT_WALK_SPEED
@export_range(0.1, 15.0, 0.1) var run_speed: float = GameConstants.DEFAULT_RUN_SPEED
@export_range(0.1, 20.0, 0.1) var sprint_speed: float = GameConstants.DEFAULT_SPRINT_SPEED
@export_range(1.0, 15.0, 0.1) var jump_velocity: float = GameConstants.DEFAULT_JUMP_VELOCITY

@export_group("Physics")
@export_range(1.0, 50.0, 0.5) var accel_ground: float = GameConstants.DEFAULT_ACCEL_GROUND
@export_range(1.0, 30.0, 0.5) var accel_air: float = GameConstants.DEFAULT_ACCEL_AIR
@export_range(1.0, 50.0, 0.5) var decel: float = GameConstants.DEFAULT_DECEL
@export_range(0.0, 89.0, 1.0) var max_slope_deg: float = 50.0
@export_range(0.0, 2.0, 0.05) var snap_len: float = 0.3
@export_group("Sneak Collider")
@export_range(0.1, 2.0, 0.01) var sneak_capsule_height: float = 1.65
@export_range(0.1, 1.5, 0.01) var sneak_capsule_radius: float = 0.45
@export_range(0.0, 2.0, 0.01) var sneak_snap_len: float = 0.12

@export_group("Input Buffering")
@export_range(0.0, 0.5, 0.01) var coyote_time: float = GameConstants.DEFAULT_COYOTE_TIME_S
@export_range(0.0, 0.5, 0.01) var jump_buffer: float = GameConstants.DEFAULT_JUMP_BUFFER_S

@export_group("Sprint Animation")
@export_range(1.0, 2.0, 0.05) var sprint_anim_speed_scale: float = GameConstants.DEFAULT_SPRINT_ANIM_SPEED_SCALE
@export_range(0.0, 1.0, 0.05) var sprint_blend_bias: float = GameConstants.DEFAULT_SPRINT_BLEND_BIAS

@export_group("Air State")
@export var fall_clip_name: StringName = GameConstants.DEFAULT_FALL_CLIP_NAME
@export_range(-10.0, 0.0, 0.01) var fall_threshold: float = GameConstants.DEFAULT_FALL_THRESHOLD_V
@export_range(0.0, 1.0, 0.01) var fall_ramp_delay: float = GameConstants.DEFAULT_FALL_RAMP_DELAY_S
@export_range(0.0, 1.0, 0.01) var fall_ramp_time: float = GameConstants.DEFAULT_FALL_RAMP_TIME_S
@export_range(1.0, 30.0, 0.5) var fall_blend_lerp: float = GameConstants.DEFAULT_FALL_BLEND_LERP_SPEED
@export_range(1.0, 3.0, 0.05) var fall_gravity_multiplier: float = GameConstants.DEFAULT_FALL_GRAVITY_MULT
@export_range(1.0, 3.0, 0.05) var fast_fall_speed_multiplier: float = GameConstants.DEFAULT_FAST_FALL_MULT

@export_group("Model Rotation")
@export_range(0.0, 1.0, 0.01) var face_lerp: float = 0.18
@export_range(-180.0, 180.0, 1.0) var model_forward_correction_deg: float = 0.0

# ============================================================================
# CACHED NODES
# ============================================================================
@onready var yaw: Node3D = $CameraRig/Yaw
@onready var model: Node3D = $Pivot/Model
@onready var anim_tree: AnimationTree = get_node_or_null(^"Pivot/Model/StateMachine") as AnimationTree
@onready var anim_player: AnimationPlayer = get_node_or_null(^"Pivot/Model/AnimationPlayer") as AnimationPlayer
@onready var stamina: Stamina = $Stamina
@onready var camera_rig: Node = get_node_or_null(^"CameraRig")
@onready var game_state: GameStateAutoload = get_node_or_null(^"/root/GameState")
@onready var trigger_area: Area3D = get_node_or_null(^"TriggerArea")
@onready var combo: PerfectJumpCombo = $PerfectJumpCombo
@onready var input_handler: PlayerInputHandler = $PlayerInputHandler
@onready var context_detector: PlayerContextDetector = $PlayerContextDetector
@onready var collision_shape: CollisionShape3D = get_node_or_null(^"CollisionShape3D")

# --- MÓDULOS (nuevos onready) ---
@onready var m_movement: MovementModule = $Modules/Movement
@onready var m_jump: JumpModule = $Modules/Jump
@onready var m_state: StateModule = $Modules/State
@onready var m_orientation: OrientationModule = $Modules/Orientation
@onready var m_anim: AnimationCtrlModule = $Modules/AnimationCtrl
@onready var m_audio: AudioCtrlModule = $Modules/AudioCtrl

var input_buffer: InputBuffer

# ============================================================================
# INTERNAL STATE
# ============================================================================
var _sprint_threshold: float
var _skip_module_updates := false
var _block_animation_updates := false
var _input_cache: Dictionary = {}
var _context_state: ContextState = ContextState.DEFAULT
var _talk_active := false
var _is_sitting := false
var _is_build_mode := false
var _using_ranged := false
var _is_sneaking := false
var _stamina_ratio_min := 1.0
var _stamina_ratio_max_since_min := 1.0
var _stamina_cycle_window := 12.0
var _t_stamina_window := 0.0
var _capsule_shape: CapsuleShape3D
var _standing_capsule_height := 0.0
var _standing_capsule_radius := 0.0
var _standing_snap_length := 0.3
var _collider_base_offset := 0.0
var _sneak_collider_active := false

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	if stats == null:
		stats = AllyStats.new()
	_ensure_input_bootstrap()
	_initialize_input_components()
	_sprint_threshold = run_speed * 0.4
	input_buffer = InputBuffer.new()
	input_buffer.name = "InputBuffer"
	input_buffer.jump_buffer_time = jump_buffer
	add_child(input_buffer)

	if m_state:
		m_state.setup(self)
	if m_jump:
		m_jump.setup(self, m_state, input_buffer)
	for m in [m_movement, m_orientation, m_anim, m_audio]:
		m.setup(self)
	_disable_module_clock_subscription()

	if m_state and not m_state.landed.is_connected(_on_state_landed):
		m_state.landed.connect(_on_state_landed)

	if anim_tree == null:
		LoggerService.warn(LOGGER_CONTEXT, "AnimationTree no encontrado; animaciones desactivadas en este modo.")
	if anim_player == null:
		LoggerService.warn(LOGGER_CONTEXT, "AnimationPlayer no encontrado; animaciones desactivadas en este modo.")

	var missing_audio_nodes: Array[String] = []
	if jump_sfx == null:
		missing_audio_nodes.append("JumpSFX")
	if land_sfx == null:
		missing_audio_nodes.append("LandSFX")
	if footstep_sfx == null:
		missing_audio_nodes.append("FootstepSFX")
	if not missing_audio_nodes.is_empty():
		LoggerService.warn(LOGGER_CONTEXT, "Nodos de audio faltantes (%s); SFX de jugador desactivados." % ", ".join(missing_audio_nodes))

	_cache_collider_defaults()

	var clock := _get_simclock()
	if clock:
		clock.register_module(self, sim_group, priority)
	else:
		LoggerService.warn(LOGGER_CONTEXT, "SimClock autoload no disponible; Player no se registró en el scheduler.")

	# ⬇️ CONECTA LAS SEÑALES EN EL Area3D, NO EN EL PLAYER
	if trigger_area and is_instance_valid(trigger_area):
		if not trigger_area.area_entered.is_connected(_on_area_entered):
			trigger_area.area_entered.connect(_on_area_entered)
		if not trigger_area.area_exited.is_connected(_on_area_exited):
			trigger_area.area_exited.connect(_on_area_exited)
	else:
		LoggerService.warn(LOGGER_CONTEXT, "TriggerArea (Area3D) no está presente como hijo del Player; se omiten triggers.")

	_update_module_stats()

	if stamina:
		var ratio: float = 1.0
		if stamina.max_stamina > 0.0:
			ratio = clampf(stamina.value / stamina.max_stamina, 0.0, 1.0)
		_stamina_ratio_min = ratio
		_stamina_ratio_max_since_min = ratio

	_sync_collider_to_context()


func _ensure_input_bootstrap() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.has_meta(TREE_META_INPUT_BOOTSTRAPPED):
		var already_initialized := bool(tree.get_meta(TREE_META_INPUT_BOOTSTRAPPED))
		if already_initialized:
			return
	var root := tree.get_root()
	if root == null:
		return
	var bootstrap: Node = INPUT_BOOTSTRAP_SCRIPT.new()
	root.call_deferred("add_child", bootstrap)
	tree.set_meta(TREE_META_INPUT_BOOTSTRAPPED, true)


func _on_clock_tick(group: StringName, dt: float) -> void:
	if group == sim_group:
		physics_tick(dt)


# ============================================================================
# MAIN PHYSICS LOOP
# ============================================================================
func physics_tick(delta: float) -> void:
	if combo and is_instance_valid(combo):
		combo.physics_tick(delta)
	var is_paused := false
	var in_cinematic := false
	if game_state:
		is_paused = game_state.is_paused
		in_cinematic = game_state.is_in_cinematic
	var allow_input := not is_paused and not in_cinematic
	var input_dir := Vector3.ZERO
	if allow_input:
		input_dir = _get_camera_relative_input()
	if input_handler:
		input_handler.update_input(allow_input, input_dir)
	_update_module_stats()
	var is_sprinting := false
	if allow_input:
		is_sprinting = _update_sprint_state(delta, input_dir)
	m_movement.set_frame_input(input_dir, is_sprinting)
	_sprint_threshold = run_speed * 0.4
	m_orientation.set_frame_input(input_dir)
	var air_time := 0.0
	if m_jump and m_jump.has_method("get_air_time"):
		air_time = m_jump.get_air_time()
	m_anim.set_frame_anim_inputs(is_sprinting, air_time)
	_skip_module_updates = is_paused or in_cinematic
	_block_animation_updates = is_paused or in_cinematic
	if context_detector:
		context_detector.update_frame(_is_sitting, _talk_active, _is_sneaking, is_on_floor())
	if not _skip_module_updates:
		if m_state:
			m_state.pre_move_update(delta)
		if m_jump:
			m_jump.physics_tick(delta)
		if m_movement:
			m_movement.physics_tick(delta)
		if m_orientation:
			m_orientation.physics_tick(delta)
		if not _block_animation_updates and m_anim:
			m_anim.physics_tick(delta)
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	if m_state:
		m_state.post_move_update()
	if m_audio:
		m_audio.physics_tick(delta)
	_consume_sprint_stamina(delta, is_sprinting)
	_track_stamina_cycle(delta, is_sprinting)

func _on_state_landed(_is_hard: bool) -> void:
	if combo and is_instance_valid(combo):
		combo.on_landed()


func should_skip_module_updates() -> bool:
	return _skip_module_updates

func should_block_animation_update() -> bool:
	return _block_animation_updates

func get_input_cache() -> Dictionary:
	return _input_cache.duplicate(true)

func get_context_state() -> ContextState:
	return _context_state

func is_sneaking() -> bool:
	return _is_sneaking

func request_exit_sneak() -> bool:
	if not _is_sneaking:
		return true
	return can_exit_sneak()

# ============================================================================
# INPUT PROCESSING
# ============================================================================

func _initialize_input_components() -> void:
	_input_cache.clear()
	if input_handler:
		input_handler.set_input_actions(INPUT_ACTIONS)
		input_handler.initialize_cache()
		_input_cache = input_handler.get_input_cache()
		_is_sneaking = input_handler.is_sneaking()
		_is_sitting = input_handler.is_sitting()
		_is_build_mode = input_handler.is_build_mode()
		_using_ranged = input_handler.is_using_ranged()
		_talk_active = input_handler.is_talk_active()
		if not input_handler.input_updated.is_connected(_on_input_updated):
			input_handler.input_updated.connect(_on_input_updated)
		if not input_handler.talk_requested.is_connected(_on_input_talk_requested):
			input_handler.talk_requested.connect(_on_input_talk_requested)
		if not input_handler.sit_toggled.is_connected(_on_input_sit_toggled):
			input_handler.sit_toggled.connect(_on_input_sit_toggled)
		if not input_handler.interact_requested.is_connected(_on_input_interact_requested):
			input_handler.interact_requested.connect(_on_input_interact_requested)
		if not input_handler.combat_mode_switched.is_connected(_on_input_combat_mode_switched):
			input_handler.combat_mode_switched.connect(_on_input_combat_mode_switched)
		if not input_handler.build_mode_toggled.is_connected(_on_input_build_mode_toggled):
			input_handler.build_mode_toggled.connect(_on_input_build_mode_toggled)
		if input_handler.has_method("set_exit_sneak_callback"):
			input_handler.set_exit_sneak_callback(Callable(self, &"request_exit_sneak"))
	else:
		LoggerService.warn(LOGGER_CONTEXT, "PlayerInputHandler no encontrado; se utilizará un caché de entrada vacío.")
		var move_record := {
			"raw": Vector2.ZERO,
			"camera": Vector3.ZERO,
		}
		_input_cache["move"] = move_record
		_input_cache["context_state"] = ContextState.DEFAULT
	if context_detector:
		context_detector.reset()
		_context_state = context_detector.get_context_state() as ContextState
		if not context_detector.context_changed.is_connected(_on_context_changed):
			context_detector.context_changed.connect(_on_context_changed)
	else:
		LoggerService.warn(LOGGER_CONTEXT, "PlayerContextDetector no encontrado; el estado de contexto no se actualizará.")
	_sync_collider_to_context()

func _disable_module_clock_subscription() -> void:
	for module in [m_state, m_jump, m_movement, m_orientation, m_anim, m_audio]:
		if module == null or not is_instance_valid(module):
			continue
		if module.has_method("set_clock_subscription"):
			module.set_clock_subscription(false)

func _on_input_updated(cache: Dictionary, state: Dictionary) -> void:
	_input_cache = cache
	_is_sneaking = state.get("is_sneaking", false)
	_is_sitting = state.get("is_sitting", false)
	_is_build_mode = state.get("is_build_mode", false)
	_using_ranged = state.get("is_using_ranged", false)
	_talk_active = state.get("talk_active", false)

func _on_input_talk_requested() -> void:
	talk_requested.emit()

func _on_input_sit_toggled(is_sitting: bool) -> void:
	sit_toggled.emit(is_sitting)

func _on_input_interact_requested() -> void:
	interact_requested.emit()

func _on_input_combat_mode_switched(mode: String) -> void:
	combat_mode_switched.emit(mode)

func _on_input_build_mode_toggled(is_building: bool) -> void:
	build_mode_toggled.emit(is_building)

func _on_context_changed(new_state: int, previous_state: int) -> void:
	_context_state = new_state as ContextState
	if input_handler:
		input_handler.set_context_state(new_state)
		_input_cache = input_handler.get_input_cache()
	else:
		_input_cache["context_state"] = _context_state
	context_state_changed.emit(new_state, previous_state)
	_sync_collider_to_context()


# ============================================================================
# MOVEMENT & SPRINT
# ============================================================================
func _get_camera_relative_input() -> Vector3:
	var input_z := Input.get_axis("move_back", "move_forward")
	var input_x := Input.get_axis("move_left", "move_right")
	if input_z == 0.0 and input_x == 0.0:
		return Vector3.ZERO
	var cam_basis := yaw.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	var direction := forward * input_z + right * input_x
	if direction.length_squared() > 1.0:
		return direction.normalized()
	return direction

func _update_module_stats() -> void:
	if input_buffer:
		input_buffer.jump_buffer_time = jump_buffer
	if m_jump:
		m_jump.jump_speed = jump_velocity
		m_jump.coyote_time = coyote_time
	if m_movement:
		m_movement.max_speed_ground = run_speed
		m_movement.max_speed_air = run_speed
		m_movement.accel_ground = accel_ground
		m_movement.accel_air = accel_air
		m_movement.ground_friction = decel
		m_movement.sprint_speed = sprint_speed
		m_movement.fast_fall_speed_multiplier = max(fast_fall_speed_multiplier, 1.0)
	if m_movement and m_movement.has_method("set_speed_multiplier"):
		m_movement.set_speed_multiplier(1.0)
	if stats:
		var effective_sprint := sprint_speed
		effective_sprint = stats.sprint_speed(effective_sprint)
		if m_movement:
			m_movement.sprint_speed = effective_sprint
	if m_state:
		m_state.fall_gravity_scale = max(fall_gravity_multiplier, 1.0)

func _update_sprint_state(delta: float, input_dir: Vector3) -> bool:
	if stamina == null:
		return false
	stamina.tick(delta)
	var sprint_record: Dictionary = _input_cache.get("sprint", {})
	var wants_sprint := false
	if sprint_record.has("pressed"):
		wants_sprint = sprint_record["pressed"]
	if not wants_sprint:
		return false
	if _is_sneaking:
		return false
	if input_dir.length_squared() <= 0.0001:
		return false
	return stamina.can_sprint()

func _consume_sprint_stamina(delta: float, is_sprinting: bool) -> void:
	if not is_sprinting:
		return
	if stamina == null:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed <= _sprint_threshold:
		return
	var drain_rate := stamina.sprint_drain_per_s
	if stats:
		drain_rate = stats.sprint_stamina_cost(drain_rate)
	stamina.consume_for_sprint(delta, drain_rate)

# ============================================================================
# STAMINA CYCLE TRACKING
# ============================================================================
func _track_stamina_cycle(delta: float, is_sprinting: bool) -> void:
	if stamina == null:
		return
	if stats == null:
		return
	if stamina.max_stamina <= 0.0:
		return
	_t_stamina_window += delta
	var ratio := clampf(stamina.value / stamina.max_stamina, 0.0, 1.0)
	if ratio < _stamina_ratio_min:
		_stamina_ratio_min = ratio
	if ratio > _stamina_ratio_max_since_min:
		_stamina_ratio_max_since_min = ratio
	if _t_stamina_window >= _stamina_cycle_window:
		var consumed := 1.0 - _stamina_ratio_min
		var recovered := _stamina_ratio_max_since_min
		stats.note_stamina_cycle(consumed, recovered, _t_stamina_window)
		_stamina_ratio_min = ratio
		_stamina_ratio_max_since_min = ratio
		_t_stamina_window = 0.0
	elif not is_sprinting:
		_stamina_ratio_max_since_min = max(_stamina_ratio_max_since_min, ratio)

# ============================================================================
# WATER STATE HANDLERS
# ============================================================================
func _on_area_entered(area: Area3D) -> void:
	if context_detector:
		context_detector.mark_water_area(area, true)

func _on_area_exited(area: Area3D) -> void:
	if context_detector:
		context_detector.mark_water_area(area, false)


# ============================================================================
# AUDIO & CAMERA HOOKS
# ============================================================================
func _play_footstep_audio() -> void:
	m_audio.play_footstep()

func _play_landing_audio(is_hard: bool) -> void:
	m_audio.play_landing(is_hard)

func _trigger_camera_landing(is_hard: bool) -> void:
	if camera_rig:
		camera_rig.call_deferred("_on_player_landed", is_hard)

func _cache_collider_defaults() -> void:
	if collision_shape == null or not is_instance_valid(collision_shape):
		return
	if not (collision_shape.shape is CapsuleShape3D):
		return
	_capsule_shape = collision_shape.shape as CapsuleShape3D
	_standing_capsule_height = maxf(_capsule_shape.height, 0.0)
	_standing_capsule_radius = maxf(_capsule_shape.radius, 0.0)
	_standing_snap_length = maxf(snap_len, 0.0)
	if m_state:
		_standing_snap_length = maxf(m_state.floor_snap_length, 0.0)
	var origin := collision_shape.transform.origin
	_collider_base_offset = origin.y - (_standing_capsule_radius + _standing_capsule_height * 0.5)

func _sync_collider_to_context() -> void:
	var wants_sneak := _context_state == ContextState.SNEAK
	_apply_sneak_collider(wants_sneak)

func _apply_sneak_collider(enable: bool) -> void:
	if _capsule_shape == null:
		return
	if enable == _sneak_collider_active:
		return
	_sneak_collider_active = enable
	if enable:
		_set_capsule_dimensions(sneak_capsule_height, sneak_capsule_radius)
		_apply_floor_snap_length(sneak_snap_len, false)
	else:
		_set_capsule_dimensions(_standing_capsule_height, _standing_capsule_radius)
		_apply_floor_snap_length(_standing_snap_length, true)

func can_exit_sneak() -> bool:
	if not _sneak_collider_active:
		return true
	if _capsule_shape == null or collision_shape == null or not is_inside_tree():
		return true
	var world := get_world_3d()
	if world == null:
		return true
	var space_state := world.direct_space_state
	if space_state == null:
		return true
	var stand_shape := _capsule_shape.duplicate(true) as CapsuleShape3D
	if stand_shape == null:
		return true
	stand_shape.height = maxf(_standing_capsule_height, 0.01)
	stand_shape.radius = maxf(_standing_capsule_radius, 0.01)
	var local_transform := collision_shape.transform
	var local_origin := local_transform.origin
	local_origin.y = _collider_base_offset + stand_shape.radius + stand_shape.height * 0.5
	local_transform.origin = local_origin
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = stand_shape
	params.transform = global_transform * local_transform
	params.margin = 0.001
	params.collision_mask = collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var exclude: Array[RID] = []
	exclude.append(get_rid())
	params.exclude = exclude
	var hits := space_state.intersect_shape(params, 1)
	return hits.is_empty()

func _set_capsule_dimensions(height: float, radius: float) -> void:
	if _capsule_shape == null:
		return

	var clamped_height := maxf(height, 0.01)
	var clamped_radius := maxf(radius, 0.01)

	var base_y := _collider_base_offset
	if collision_shape and is_instance_valid(collision_shape):
		var origin := collision_shape.transform.origin
		base_y = origin.y - (_capsule_shape.radius + _capsule_shape.height * 0.5)

	_capsule_shape.height = clamped_height
	_capsule_shape.radius = clamped_radius

	if collision_shape and is_instance_valid(collision_shape):
		var shape_basis := collision_shape.transform.basis
		var origin := collision_shape.transform.origin
		origin.y = base_y + clamped_radius + clamped_height * 0.5
		collision_shape.transform = Transform3D(shape_basis, origin)

	_collider_base_offset = base_y

func _apply_floor_snap_length(value: float, update_default: bool) -> void:
	var clamped := maxf(value, 0.0)
	self.floor_snap_length = clamped
	if update_default:
		snap_len = clamped
		_standing_snap_length = clamped
	if m_state:
		m_state.set_floor_snap_length(clamped)

func _get_simclock() -> SimClockAutoload:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var autoload: Node = tree.get_root().get_node_or_null(^"/root/SimClock")
	if autoload == null:
		return null
	if autoload is SIMCLOCK_SCRIPT:
		return autoload as SimClockAutoload
	return null
