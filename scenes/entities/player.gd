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
	"crouch": ["crouch", "sneak", "toggle_sneak"],
	"toggle_sneak": ["toggle_sneak"],
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
@export_range(0.1, 10.0, 0.1) var walk_speed: float = 2.5
@export_range(0.1, 15.0, 0.1) var run_speed: float = 6.0
@export_range(0.1, 20.0, 0.1) var sprint_speed: float = 9.5
@export_range(1.0, 15.0, 0.1) var jump_velocity: float = 8.2

@export_group("Physics")
@export_range(1.0, 50.0, 0.5) var accel_ground: float = 26.0
@export_range(1.0, 30.0, 0.5) var accel_air: float = 9.5
@export_range(1.0, 50.0, 0.5) var decel: float = 10.0
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
@export_range(1.0, 3.0, 0.05) var fall_gravity_multiplier: float = 1.5
@export_range(1.0, 3.0, 0.05) var fast_fall_speed_multiplier: float = 1.5

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
@onready var sneak_ctrl: SneakAnimController = $SneakAnimController

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
var _is_in_water := false
var _water_areas: Array = []
var _talk_active := false
var _is_sitting := false
var _is_build_mode := false
var _using_ranged := false
var _is_sneaking := false
var _stamina_ratio_min := 1.0
var _stamina_ratio_max_since_min := 1.0
var _stamina_cycle_window := 12.0
var _t_stamina_window := 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	if stats == null:
		stats = AllyStats.new()
	_ensure_input_bootstrap()
	_initialize_input_cache()
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

	if m_state and not m_state.landed.is_connected(_on_state_landed):
		m_state.landed.connect(_on_state_landed)

	if anim_tree == null:
		push_warning("AnimationTree no encontrado; animaciones desactivadas en este modo.")
	if anim_player == null:
		push_warning("AnimationPlayer no encontrado; animaciones desactivadas en este modo.")

	var missing_audio_nodes: Array[String] = []
	if jump_sfx == null:
		missing_audio_nodes.append("JumpSFX")
	if land_sfx == null:
		missing_audio_nodes.append("LandSFX")
	if footstep_sfx == null:
		missing_audio_nodes.append("FootstepSFX")
	if not missing_audio_nodes.is_empty():
		push_warning("Nodos de audio faltantes (%s); SFX de jugador desactivados." % ", ".join(missing_audio_nodes))

	var clock := _get_simclock()
	if clock:
		clock.register_module(self, sim_group, priority)
	else:
		push_warning("SimClock autoload no disponible; Player no se registró en el scheduler.")

	# ⬇️ CONECTA LAS SEÑALES EN EL Area3D, NO EN EL PLAYER
	if trigger_area and is_instance_valid(trigger_area):
		if not trigger_area.area_entered.is_connected(_on_area_entered):
			trigger_area.area_entered.connect(_on_area_entered)
		if not trigger_area.area_exited.is_connected(_on_area_exited):
			trigger_area.area_exited.connect(_on_area_exited)
	else:
		push_warning("TriggerArea (Area3D) no está presente como hijo del Player; se omiten triggers.")

	_update_module_stats()

	if stamina:
		var ratio: float = 1.0
		if stamina.max_stamina > 0.0:
			ratio = clampf(stamina.value / stamina.max_stamina, 0.0, 1.0)
		_stamina_ratio_min = ratio
		_stamina_ratio_max_since_min = ratio
	if sneak_ctrl != null and is_instance_valid(sneak_ctrl):
		sneak_ctrl.set_sneak_enabled(_is_sneaking)


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
	root.add_child(bootstrap)
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
	_cache_input_states(allow_input, input_dir)
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
	_evaluate_context_state(input_dir)
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
	if sneak_ctrl != null and is_instance_valid(sneak_ctrl):
		sneak_ctrl.update_sneak_speed(velocity.length())
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

func _set_sneak_state(enable: bool) -> void:
	if _is_sneaking == enable:
		return
	_is_sneaking = enable
	if sneak_ctrl != null and is_instance_valid(sneak_ctrl):
		sneak_ctrl.set_sneak_enabled(enable)

# ============================================================================
# INPUT PROCESSING
# ============================================================================
func _initialize_input_cache() -> void:
	_input_cache.clear()
	var move_record := {
		"raw": Vector2.ZERO,
		"camera": Vector3.ZERO
	}
	_input_cache["move"] = move_record
	for key in INPUT_ACTIONS.keys():
		_input_cache[key] = {
			"pressed": false,
			"just_pressed": false,
			"just_released": false
		}
	_input_cache["context_state"] = ContextState.DEFAULT

func _cache_input_states(allow_input: bool, move_dir: Vector3) -> void:
	var raw_axes := Vector2.ZERO
	if allow_input:
		raw_axes.x = Input.get_axis("move_left", "move_right")
		raw_axes.y = Input.get_axis("move_back", "move_forward")
	var move_record: Dictionary = _input_cache.get("move", {})
	move_record["raw"] = raw_axes
	move_record["camera"] = move_dir
	_input_cache["move"] = move_record
	var sprint_record := _update_action_cache("sprint", INPUT_ACTIONS.get("sprint", []), allow_input)
	var crouch_record := _update_action_cache("crouch", INPUT_ACTIONS.get("crouch", []), allow_input)
	var toggle_record := _update_action_cache("toggle_sneak", INPUT_ACTIONS.get("toggle_sneak", []), allow_input)
	var jump_record := _update_action_cache("jump", INPUT_ACTIONS.get("jump", []), allow_input)
	var talk_record := _update_action_cache("talk", INPUT_ACTIONS.get("talk", []), allow_input)
	var sit_record := _update_action_cache("sit", INPUT_ACTIONS.get("sit", []), allow_input)
	var interact_record := _update_action_cache("interact", INPUT_ACTIONS.get("interact", []), allow_input)
	var combat_record := _update_action_cache("combat_switch", INPUT_ACTIONS.get("combat_switch", []), allow_input)
	var build_record := _update_action_cache("build", INPUT_ACTIONS.get("build", []), allow_input)
	if allow_input:
		if talk_record.get("just_pressed", false):
			talk_requested.emit()
		_talk_active = talk_record.get("pressed", false)
	else:
		_talk_active = false
	talk_record["active"] = _talk_active
	_input_cache["talk"] = talk_record
	if allow_input and toggle_record.get("just_pressed", false):
		_set_sneak_state(not _is_sneaking)
	crouch_record["active"] = _is_sneaking
	toggle_record["active"] = _is_sneaking
	if allow_input and sit_record.get("just_pressed", false):
		var previous := _is_sitting
		_is_sitting = not _is_sitting
		if previous != _is_sitting:
			sit_toggled.emit(_is_sitting)
	sit_record["active"] = _is_sitting
	_input_cache["sit"] = sit_record
	if allow_input and interact_record.get("just_pressed", false):
		interact_requested.emit()
	if allow_input and combat_record.get("just_pressed", false):
		_using_ranged = not _using_ranged
		var new_mode := "melee"
		if _using_ranged:
			new_mode = "ranged"
		combat_mode_switched.emit(new_mode)
	var combat_mode := "melee"
	if _using_ranged:
		combat_mode = "ranged"
	combat_record["mode"] = combat_mode
	_input_cache["combat_switch"] = combat_record
	if allow_input and build_record.get("just_pressed", false):
		var was_building := _is_build_mode
		_is_build_mode = not _is_build_mode
		if was_building != _is_build_mode:
			build_mode_toggled.emit(_is_build_mode)
	build_record["active"] = _is_build_mode
	_input_cache["build"] = build_record
	_input_cache["sprint"] = sprint_record
	_input_cache["crouch"] = crouch_record
	_input_cache["toggle_sneak"] = toggle_record
	_input_cache["jump"] = jump_record
	_input_cache["interact"] = interact_record

func _update_action_cache(key: String, action_names: Array, allow_input: bool) -> Dictionary:
	var record: Dictionary = _input_cache.get(key, {
		"pressed": false,
		"just_pressed": false,
		"just_released": false
	})
	var pressed := false
	var just_pressed := false
	var just_released := false
	if allow_input:
		pressed = _action_pressed(action_names)
		just_pressed = _action_just_pressed(action_names)
		just_released = _action_just_released(action_names)
	record["pressed"] = pressed
	record["just_pressed"] = just_pressed
	record["just_released"] = just_released
	_input_cache[key] = record
	return record

func _action_pressed(action_names: Array) -> bool:
	for action_name in action_names:
		if typeof(action_name) == TYPE_STRING and InputMap.has_action(action_name):
			if Input.is_action_pressed(action_name):
				return true
	return false

func _action_just_pressed(action_names: Array) -> bool:
	for action_name in action_names:
		if typeof(action_name) == TYPE_STRING and InputMap.has_action(action_name):
			if Input.is_action_just_pressed(action_name):
				return true
	return false

func _action_just_released(action_names: Array) -> bool:
	for action_name in action_names:
		if typeof(action_name) == TYPE_STRING and InputMap.has_action(action_name):
			if Input.is_action_just_released(action_name):
				return true
	return false

func _evaluate_context_state(move_dir: Vector3) -> void:
	var desired: ContextState = ContextState.DEFAULT
	if _is_sitting:
		desired = ContextState.SIT
	elif _talk_active:
		desired = ContextState.TALK
	elif _is_in_water:
		desired = ContextState.SWIM
	else:
		var can_sneak := _is_sneaking and is_on_floor()
		if can_sneak:
			desired = ContextState.SNEAK
	_set_context_state(desired)

func _set_context_state(state: ContextState) -> void:
	if _context_state == state:
		return
	var previous := _context_state
	_context_state = state
	_input_cache["context_state"] = _context_state
	context_state_changed.emit(state, previous)

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
	_mark_water_area(area, true)

func _on_area_exited(area: Area3D) -> void:
	_mark_water_area(area, false)

func _mark_water_area(area: Area3D, entered: bool) -> void:
	if area == null or not is_instance_valid(area):
		return

	var is_water: bool = false

	# 1) Grupo "water" tiene prioridad
	if area.is_in_group("water"):
		is_water = true
	# 2) O usa el meta "is_water" (puede venir como bool o cualquier cosa casteable)
	elif area.has_meta("is_water"):
		var meta_value: Variant = area.get_meta("is_water")  # evitar Variant implícito
		if meta_value is bool:
			is_water = meta_value
		else:
			is_water = bool(meta_value)

	if not is_water:
		return

	# Mantén el set de áreas de agua
	if entered:
		if not _water_areas.has(area):
			_water_areas.append(area)
	else:
		_water_areas.erase(area)

	# Actualiza estado global y reevalúa contexto si cambió
	var was_in_water: bool = _is_in_water
	_is_in_water = _water_areas.size() > 0

	if was_in_water != _is_in_water:
		var move_dir: Vector3 = Vector3.ZERO
		if _input_cache.has("move"):
			var move_record: Dictionary = _input_cache.get("move", {})
			if move_record.has("camera"):
				var cam_val: Variant = move_record["camera"]  # puede ser Variant
				if cam_val is Vector3:
					move_dir = cam_val
		_evaluate_context_state(move_dir)


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
