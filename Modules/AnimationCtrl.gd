extends ModuleBase
class_name AnimationCtrlModule

var player: CharacterBody3D
var anim_tree: AnimationTree
var anim_player: AnimationPlayer

@export var animation_tree_path: NodePath
@export var state_module_path: NodePath

# Paths dentro del AnimationTree
const PARAM_LOC: StringName = &"parameters/LocomotionSpeed/Locomotion/blend_position"
const PARAM_LOC_LEGACY: StringName = &"parameters/Locomotion/blend_position"
const PARAM_AIRBLEND: StringName = &"parameters/AirBlend/blend_amount"
const PARAM_FALLANIM: StringName = &"parameters/FallAnim/animation"
const PARAM_SPRINTSCL: StringName = &"parameters/LocomotionSpeed/SprintSpeed/scale"
const PARAM_SPRINTSCL_LEGACY: StringName = &"parameters/SprintScale/scale"
const PARAM_SM_PLAYBACK: StringName = &"parameters/StateMachine/playback"
const PARAM_ROOT_PLAYBACK: StringName = &"parameters/playback"

const STATE_LOCOMOTION: StringName = &"LocomotionSpeed"
const STATE_LOCOMOTION_LEGACY: StringName = &"Locomotion"
const STATE_JUMP: StringName = &"Jump"
const STATE_FALL: StringName = &"FallAnim"
const STATE_LAND: StringName = &"Land"

# Parámetros expuestos
@export var fall_speed_threshold: float = -1.5
@export var min_air_time_to_fall: float = 0.10
@export_range(0.0, 0.5, 0.01) var locomotion_to_jump_blend_time_min: float = 0.08
@export_range(0.0, 0.5, 0.01) var locomotion_to_jump_blend_time_max: float = 0.18
@export_range(0.0, 0.5, 0.01) var jump_to_fall_blend_time_min: float = 0.12
@export_range(0.0, 0.5, 0.01) var jump_to_fall_blend_time_max: float = 0.32
@export_range(0.0, 0.5, 0.01) var fall_to_locomotion_blend_time: float = 0.14
@export_range(0.0, 0.5, 0.01) var fall_to_land_blend_time: float = 0.18
@export_range(0.0, 1.0, 0.01) var fall_blend_ramp_delay: float = 0.10
@export_range(0.0, 1.0, 0.01) var fall_blend_ramp_time: float = 0.20
@export_range(0.0, 30.0, 0.5) var fall_blend_lerp_speed: float = 12.0

# Copiados del Player para mantener fidelidad
var walk_speed := 2.5
var run_speed := 6.0
var sprint_speed := 9.5
var sprint_anim_speed_scale := 1.15
var sprint_blend_bias := 0.85
var fall_clip_name: StringName = &"fall air loop"

# Estado interno
var _is_sprinting := false
var _airborne := false
var _has_jumped := false
var _fall_triggered := false
var _time_in_air := 0.0
var _current_air_blend := 0.0

var _state_machine: AnimationNodeStateMachinePlayback
var _state_machine_graph: AnimationNodeStateMachine
var _state_locomotion: StringName = STATE_LOCOMOTION
var _locomotion_params: Array[StringName] = []
var _sprint_scale_params: Array[StringName] = []
var _transition_indices: Dictionary = {}

func setup(p: CharacterBody3D) -> void:
	player = p
	if p != null and is_instance_valid(p):
		anim_tree = p.anim_tree
		anim_player = p.anim_player

	if "walk_speed" in p:
		walk_speed = p.walk_speed
	if "run_speed" in p:
		run_speed = p.run_speed
	if "sprint_speed" in p:
		sprint_speed = p.sprint_speed
	if "sprint_anim_speed_scale" in p:
		sprint_anim_speed_scale = p.sprint_anim_speed_scale
	if "sprint_blend_bias" in p:
		sprint_blend_bias = p.sprint_blend_bias

	if "fall_clip_name" in p:
		fall_clip_name = p.fall_clip_name

	if anim_tree == null and animation_tree_path != NodePath():
		anim_tree = get_node_or_null(animation_tree_path) as AnimationTree
	if anim_player == null and player != null and is_instance_valid(player):
		anim_player = player.anim_player
	if anim_tree:
		if animation_tree_path == NodePath():
			animation_tree_path = anim_tree.get_path()
		if anim_player != null and is_instance_valid(anim_player):
			anim_tree.anim_player = anim_player.get_path()
		anim_tree.active = true
		_refresh_parameter_cache()
		if _tree_has_param(PARAM_FALLANIM):
			anim_tree.set(PARAM_FALLANIM, fall_clip_name)
		_set_locomotion_blend(0.0)
		_set_air_blend(0.0)
		_set_sprint_scale(1.0)
		_cache_state_machine()

	_connect_state_signals()

func set_frame_anim_inputs(is_sprinting: bool, _air_time: float) -> void:
	_is_sprinting = is_sprinting

func physics_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("should_skip_module_updates") and player.should_skip_module_updates():
		return
	if player.has_method("should_block_animation_update") and player.should_block_animation_update():
		return

	var is_on_floor := player.is_on_floor()
	if not is_on_floor:
		_handle_airborne(delta)
	else:
		_handle_grounded()

func _handle_airborne(delta: float) -> void:
	if not _airborne:
		_airborne = true
		_time_in_air = 0.0
		_fall_triggered = false
		if not _has_jumped:
			_travel_to_state(STATE_JUMP)
		_set_locomotion_blend(0.0)
		_set_sprint_scale(1.0)

	_time_in_air += delta

	var vel_y := player.velocity.y
	var should_trigger_fall := false
	if vel_y <= fall_speed_threshold:
		should_trigger_fall = true
	elif _time_in_air >= min_air_time_to_fall:
		if vel_y <= 0.0:
			should_trigger_fall = true
	if should_trigger_fall and not _fall_triggered:
		_travel_to_state(STATE_FALL)
		_fall_triggered = true

	var target_air_blend := _calculate_fall_blend_target()
	_current_air_blend = lerpf(_current_air_blend, target_air_blend, clampf(delta * fall_blend_lerp_speed, 0.0, 1.0))
	_update_jump_fall_transition_blend()
	_set_air_blend(_current_air_blend)


func _handle_grounded() -> void:
	if _airborne:
		_airborne = false
		_time_in_air = 0.0
		_fall_triggered = false
		_has_jumped = false
		_current_air_blend = 0.0
		_update_jump_fall_transition_blend()
		if _state_machine and _state_machine.get_current_node() in [STATE_FALL, STATE_JUMP]:
			if _has_state(STATE_LAND):
				_travel_to_state(STATE_LAND)
			else:
				_travel_to_state(_state_locomotion)

	var blend := _calculate_locomotion_blend()
	_update_locomotion_jump_transition(blend)
	_set_locomotion_blend(blend)
	_apply_sprint_scale(blend)
	_set_air_blend(0.0)

func _calculate_locomotion_blend() -> float:
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var target_max := sprint_speed if _is_sprinting else run_speed
	if target_max <= 0.0:
		return 0.0

	var blend := 0.0
	if hspeed <= walk_speed:
		blend = remap(hspeed, 0.0, walk_speed, 0.0, 0.4)
	else:
		blend = remap(hspeed, walk_speed, target_max, 0.4, 1.0)

	if _is_sprinting:
		blend = pow(clampf(blend, 0.0, 1.0), sprint_blend_bias)

	return clampf(blend, 0.0, 1.0)

func _apply_sprint_scale(blend: float) -> void:
	var scale := 1.0
	if _is_sprinting:
		scale = lerp(1.0, sprint_anim_speed_scale, blend)
	_set_sprint_scale(scale)

func _set_locomotion_blend(value: float) -> void:
	if anim_tree == null:
		return
	var clamped := clampf(value, 0.0, 1.0)
	var applied := false
	for param in _locomotion_params:
		anim_tree.set(param, clamped)
		applied = true
	if not applied and _tree_has_param(PARAM_LOC_LEGACY):
		anim_tree.set(PARAM_LOC_LEGACY, clamped)

func _set_air_blend(value: float) -> void:
	if _tree_has_param(PARAM_AIRBLEND):
		anim_tree.set(PARAM_AIRBLEND, clampf(value, 0.0, 1.0))

func _set_sprint_scale(value: float) -> void:
	if anim_tree == null:
		return
	var applied := false
	for param in _sprint_scale_params:
		anim_tree.set(param, value)
		applied = true
	if not applied and _tree_has_param(PARAM_SPRINTSCL_LEGACY):
		anim_tree.set(PARAM_SPRINTSCL_LEGACY, value)

func _cache_state_machine() -> void:
	# Garantiza que tengamos referencia válida al AnimationTree.
	_state_machine = null
	_state_machine_graph = null
	if anim_tree == null:
		push_warning("AnimationTree no asignado; revisa que el módulo se configure en setup().")
		return
	if animation_tree_path == NodePath():
		animation_tree_path = anim_tree.get_path()
		_refresh_parameter_cache()

	var playback := _resolve_state_machine_playback()
	if playback == null:
		push_warning("No se encontró un AnimationNodeStateMachinePlayback válido en el AnimationTree. Revisa que el root sea un StateMachine y que su 'playback' esté expuesto.")
		return

	_state_machine = playback
	var tree_root := anim_tree.tree_root
	if tree_root is AnimationNodeStateMachine:
		_state_machine_graph = tree_root
	else:
		_state_machine_graph = null
		push_warning("El AnimationTree configurado no expone un AnimationNodeStateMachine como raíz; no se puede validar la existencia de estados.")
	_state_locomotion = _resolve_state_name(STATE_LOCOMOTION, STATE_LOCOMOTION_LEGACY)
	_travel_to_state(_state_locomotion)
	_cache_transition_indices()
	_configure_transition_blends()

func _resolve_state_machine_playback() -> AnimationNodeStateMachinePlayback:
	if anim_tree == null:
		return null

	var playback := anim_tree.get(PARAM_SM_PLAYBACK) as AnimationNodeStateMachinePlayback
	if playback != null:
		return playback

	playback = anim_tree.get(PARAM_ROOT_PLAYBACK) as AnimationNodeStateMachinePlayback
	if playback != null:
		return playback

	if not anim_tree.has_method("get_property_list"):
		return null

	var properties := anim_tree.get_property_list()
	for prop in properties:
		if prop is Dictionary and prop.has("name"):
			var name_str := String(prop["name"])
			if name_str.ends_with("/playback"):
				var candidate := anim_tree.get(StringName(name_str)) as AnimationNodeStateMachinePlayback
				if candidate != null:
					return candidate

	return null

func _connect_state_signals() -> void:
	if player == null:
		return

	var state_mod: Node = null

	# 1) si hay ruta exportada, úsala
	if state_module_path != NodePath():
		state_mod = get_node_or_null(state_module_path)

	# 2) fallback: buscar por convención en la jerarquía del player
	if state_mod == null and player.has_node("Modules/State"):
		state_mod = player.get_node("Modules/State")
	elif state_mod == null and player.has_node("State"):
		state_mod = player.get_node("State")

	if state_mod == null:
		return

	# Conexiones seguras (evita duplicados)
	if state_mod.has_signal("landed"):
		if not state_mod.landed.is_connected(_on_landed):
			state_mod.landed.connect(_on_landed)
	if state_mod.has_signal("jumped"):
		if not state_mod.jumped.is_connected(_on_jumped):
			state_mod.jumped.connect(_on_jumped)
	if state_mod.has_signal("left_ground"):
		if not state_mod.left_ground.is_connected(_on_left_ground):
			state_mod.left_ground.connect(_on_left_ground)


func _on_jumped() -> void:
	_has_jumped = true
	_airborne = true
	_time_in_air = 0.0
	_fall_triggered = false
	_current_air_blend = 0.0
	_update_jump_fall_transition_blend()
	_set_locomotion_blend(0.0)
	_set_air_blend(0.0)
	_set_sprint_scale(1.0)
	_travel_to_state(STATE_JUMP)

func _on_left_ground() -> void:
	if _has_jumped:
		return
	_airborne = true
	_time_in_air = 0.0
	_fall_triggered = false
	_current_air_blend = 0.0
	_update_jump_fall_transition_blend()
	_set_locomotion_blend(0.0)
	_set_air_blend(0.0)
	_set_sprint_scale(1.0)
	_travel_to_state(STATE_JUMP)

func _on_landed(_is_hard: bool) -> void:
	_airborne = false
	_has_jumped = false
	_time_in_air = 0.0
	_fall_triggered = false
	_current_air_blend = 0.0
	_update_jump_fall_transition_blend()
	_set_air_blend(0.0)
	if _has_state(STATE_LAND):
		_travel_to_state(STATE_LAND)
	else:
		_travel_to_state(_state_locomotion)

func _travel_to_state(state_name: StringName) -> void:
	if _state_machine == null:
		return
	if String(state_name).is_empty():
		return
	if _state_machine_graph != null and not _state_machine_graph.has_node(state_name):
		return
	_state_machine.travel(state_name)

func _refresh_parameter_cache() -> void:
	_locomotion_params.clear()
	_sprint_scale_params.clear()
	if anim_tree == null:
		return
	var loc_candidates: Array[StringName] = [PARAM_LOC, PARAM_LOC_LEGACY]
	for param in loc_candidates:
		if _tree_has_param(param) and not _locomotion_params.has(param):
			_locomotion_params.append(param)
	var sprint_candidates: Array[StringName] = [PARAM_SPRINTSCL, PARAM_SPRINTSCL_LEGACY]
	for param in sprint_candidates:
		if _tree_has_param(param) and not _sprint_scale_params.has(param):
			_sprint_scale_params.append(param)

func _resolve_state_name(preferred: StringName, fallback: StringName) -> StringName:
	if _state_machine_graph == null:
		return preferred
	if not String(preferred).is_empty() and _state_machine_graph.has_node(preferred):
		return preferred
	if not String(fallback).is_empty() and _state_machine_graph.has_node(fallback):
		return fallback
	return preferred

func _tree_has_param(param: StringName) -> bool:
	if anim_tree == null:
		return false

	# Verificar si el parámetro existe intentando leerlo
	var param_list: Array = []
	if anim_tree.has_method("get_property_list"):
		param_list = anim_tree.get_property_list()
		for prop in param_list:
			if prop is Dictionary and prop.has("name"):
				if String(prop["name"]) == String(param):
					return true

	# Fallback: intentar acceder directamente
	var value = anim_tree.get(param)
	return value != null

func _has_state(state_name: StringName) -> bool:
	if _state_machine_graph == null:
		return false
	return _state_machine_graph.has_node(state_name)

func _cache_transition_indices() -> void:
	_transition_indices.clear()
	if _state_machine_graph == null:
		return
	if not _state_machine_graph.has_method("get_transition_count"):
		return
	var count := _state_machine_graph.get_transition_count()
	for i in range(count):
		var from_state := _state_machine_graph.get_transition_from(i)
		var to_state := _state_machine_graph.get_transition_to(i)
		var key := _make_transition_key(from_state, to_state)
		_transition_indices[key] = i

func _configure_transition_blends() -> void:
	if _state_machine_graph == null:
		return
	_update_locomotion_jump_transition(0.0)
	_set_transition_blend_time(STATE_JUMP, STATE_FALL, jump_to_fall_blend_time_min)
	_set_transition_blend_time(STATE_FALL, _state_locomotion, fall_to_locomotion_blend_time)
	if _has_state(STATE_LAND):
		_set_transition_blend_time(STATE_FALL, STATE_LAND, fall_to_land_blend_time)

func _make_transition_key(from_state: StringName, to_state: StringName) -> StringName:
	return StringName(String(from_state) + "->" + String(to_state))

func _get_transition_index(from_state: StringName, to_state: StringName) -> int:
	var key := _make_transition_key(from_state, to_state)
	if not _transition_indices.has(key):
		return -1
	return int(_transition_indices[key])

func _set_transition_blend_time(from_state: StringName, to_state: StringName, blend_time: float) -> void:
	if _state_machine_graph == null:
		return
	if not _state_machine_graph.has_method("set_transition_blend_time"):
		return
	var index := _get_transition_index(from_state, to_state)
	if index == -1:
		return
	var clamped := maxf(blend_time, 0.0)
	if _state_machine_graph.has_method("get_transition_blend_time"):
		var current: float = _state_machine_graph.get_transition_blend_time(index)
		if is_equal_approx(current, clamped):
			return
	_state_machine_graph.set_transition_blend_time(index, clamped)

func _update_locomotion_jump_transition(blend_factor: float) -> void:
	var ratio := clampf(blend_factor, 0.0, 1.0)
	var duration := lerpf(locomotion_to_jump_blend_time_min, locomotion_to_jump_blend_time_max, ratio)
	_set_transition_blend_time(_state_locomotion, STATE_JUMP, duration)

func _calculate_fall_blend_target() -> float:
	if not _fall_triggered:
		return 0.0
	var elapsed := maxf(_time_in_air - fall_blend_ramp_delay, 0.0)
	if elapsed <= 0.0:
		return 0.0
	if fall_blend_ramp_time <= 0.0:
		return 1.0
	var progress := clampf(elapsed / fall_blend_ramp_time, 0.0, 1.0)
	return smoothstep(0.0, 1.0, progress)

func _update_jump_fall_transition_blend() -> void:
	var ratio := 0.0
	if _fall_triggered:
		ratio = clampf(_current_air_blend, 0.0, 1.0)
	var duration := lerpf(jump_to_fall_blend_time_min, jump_to_fall_blend_time_max, ratio)
	_set_transition_blend_time(STATE_JUMP, STATE_FALL, duration)
