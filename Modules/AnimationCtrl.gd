extends ModuleBase
class_name AnimationCtrlModule

var player: CharacterBody3D
var anim_tree: AnimationTree
var anim_player: AnimationPlayer

@export var animation_tree_path: NodePath
@export var state_module_path: NodePath

const LOGGER_CONTEXT := "AnimationCtrl"

# Paths dentro del AnimationTree
const PARAM_LOC: StringName = &"parameters/LocomotionSpeed/Locomotion/blend_position"
const PARAM_LOC_LEGACY: StringName = &"parameters/Locomotion/blend_position"
const PARAM_AIRBLEND: StringName = &"parameters/AirBlend/blend_amount"
const PARAM_AIRBLEND_STATE: StringName = &"parameters/LocomotionSpeed/AirBlend/blend_amount"
const PARAM_FALLANIM: StringName = &"parameters/FallAnim/animation"
const PARAM_SPRINTSCL: StringName = &"parameters/LocomotionSpeed/SprintSpeed/scale"
const PARAM_SPRINTSCL_LEGACY: StringName = &"parameters/SprintScale/scale"
const PARAM_SM_PLAYBACK: StringName = &"parameters/StateMachine/playback"
const PARAM_ROOT_PLAYBACK: StringName = &"parameters/playback"
const PARAM_JUMP_REQUEST: StringName = &"parameters/LocomotionSpeed/Jump/request"
const PARAM_JUMP_REQUEST_LEGACY: StringName = &"parameters/Jump/request"
const PARAM_SNEAK_MOVE: StringName = &"parameters/LocomotionSpeed/SneakIdleWalk/blend_position"
const PARAM_SNEAK_BLEND: StringName = &"parameters/LocomotionSpeed/SneakBlend/blend_amount"
const PARAM_SNEAK_BLEND_ALT: StringName = &"parameters/LocomotionSpeed/SneakBlend/blend"
const PARAM_SNEAK_ENTER_REQUEST: StringName = &"parameters/LocomotionSpeed/SneakEnter/request"
const PARAM_SNEAK_EXIT_REQUEST: StringName = &"parameters/LocomotionSpeed/SneakExit/request"
const PARAM_SNEAK_ENTER_FADE_IN: StringName = &"parameters/LocomotionSpeed/SneakEnter/fadein_time"
const PARAM_SNEAK_ENTER_FADE_OUT: StringName = &"parameters/LocomotionSpeed/SneakEnter/fadeout_time"
const PARAM_SNEAK_ENTER_MIX: StringName = &"parameters/LocomotionSpeed/SneakEnter/mix"
const PARAM_SNEAK_ENTER_MIX_MODE: StringName = &"parameters/LocomotionSpeed/SneakEnter/mix_mode"

const STATE_LOCOMOTION: StringName = &"LocomotionSpeed"
const STATE_LOCOMOTION_LEGACY: StringName = &"Locomotion"
const STATE_JUMP: StringName = &"Jump"
const STATE_FALL: StringName = &"FallAnim"
const STATE_LAND: StringName = &"Land"
const CLIP_SNEAK_ENTER: StringName = &"sneak_enter"
const CLIP_SNEAK_EXIT: StringName = &"sneak_exit"

const CONTEXT_DEFAULT := 0
const CONTEXT_SNEAK := 1
const CONTEXT_SWIM := 2
const CONTEXT_TALK := 3
const CONTEXT_SIT := 4

# Parámetros expuestos
@export var fall_speed_threshold: float = -1.5
@export var min_air_time_to_fall: float = GameConstants.MIN_AIR_TIME_FOR_FALL_S
@export_range(0.0, 0.5, 0.01) var locomotion_to_jump_blend_time_min: float = 0.08
@export_range(0.0, 0.5, 0.01) var locomotion_to_jump_blend_time_max: float = 0.18
@export_range(0.0, 0.5, 0.01) var jump_to_fall_blend_time_min: float = 0.12
@export_range(0.0, 0.5, 0.01) var jump_to_fall_blend_time_max: float = 0.32
@export_range(0.0, 0.5, 0.01) var fall_to_locomotion_blend_time: float = 0.14
@export_range(0.0, 0.5, 0.01) var fall_to_land_blend_time: float = 0.18
@export_range(0.0, 1.0, 0.01) var fall_blend_ramp_delay: float = GameConstants.DEFAULT_FALL_RAMP_DELAY_S
@export_range(0.0, 1.0, 0.01) var fall_blend_ramp_time: float = GameConstants.DEFAULT_FALL_RAMP_TIME_S
@export_range(0.0, 30.0, 0.5) var fall_blend_lerp_speed: float = GameConstants.DEFAULT_FALL_BLEND_LERP_SPEED
@export_range(0.05, 1.5, 0.01) var sneak_enter_blend_time: float = 0.35
@export_range(0.0, 1.0, 0.01) var sneak_enter_idle_mix: float = 0.8
@export_range(0.05, 1.5, 0.01) var sneak_exit_blend_in_time: float = 0.35
@export_range(0.05, 1.5, 0.01) var sneak_exit_blend_out_time: float = 0.35

# Copiados del Player para mantener fidelidad
var walk_speed := GameConstants.DEFAULT_WALK_SPEED
var run_speed := GameConstants.DEFAULT_RUN_SPEED
var sprint_speed := GameConstants.DEFAULT_SPRINT_SPEED
var sprint_anim_speed_scale := GameConstants.DEFAULT_SPRINT_ANIM_SPEED_SCALE
var sprint_blend_bias := GameConstants.DEFAULT_SPRINT_BLEND_BIAS
var fall_clip_name: StringName = GameConstants.DEFAULT_FALL_CLIP_NAME

# Estado interno
var _is_sprinting := false
var _airborne := false
var _has_jumped := false
var _fall_triggered := false
var _time_in_air := 0.0
var _current_air_blend := 0.0

var _state_machine: AnimationNodeStateMachinePlayback
var _state_machine_graph: AnimationNodeStateMachine
var _state_machine_started := false
var _state_locomotion: StringName = STATE_LOCOMOTION
var _locomotion_params: Array[StringName] = []
var _sprint_scale_params: Array[StringName] = []
var _air_blend_params: Array[StringName] = []
var _jump_request_params: Array[StringName] = []
var _sneak_enter_request_params: Array[StringName] = []
var _sneak_exit_request_params: Array[StringName] = []
var _sneak_move_params: Array[StringName] = []
var _sneak_blend_params: Array[StringName] = []
var _sneak_enter_fadein_params: Array[StringName] = []
var _sneak_enter_fadeout_params: Array[StringName] = []
var _sneak_enter_mix_params: Array[StringName] = []
var _sneak_enter_mix_mode_params: Array[StringName] = []
var _transition_indices: Dictionary = {}
var _jump_fired := false
var _sneak_active := false
var _current_context_state: int = CONTEXT_DEFAULT
var _sneak_blend_value := 0.0
var _sneak_blend_target := 0.0
var _sneak_enter_clip_length := 0.35
var _sneak_exit_clip_length := 0.4
var _sneak_exit_duration := 0.0
var _sneak_exit_timer := 0.0
var _sneak_enter_playing := false
var _sneak_exit_playing := false
var _sneak_enter_timer := 0.0

const SNEAK_PRE_BLEND := 0.2

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

	_cache_sneak_animation_lengths()
	_set_sneak_move_blend(0.0)
	_set_sneak_blend_target(0.0, 0.0)
	_sneak_enter_playing = false
	_sneak_exit_playing = false
	_sneak_exit_duration = 0.0
	_sneak_exit_timer = 0.0
	_sneak_enter_timer = 0.0

	_connect_state_signals()
	_initialize_context_state()

## Registra los flags de locomoción usados para calcular blends de animación en el tick siguiente.
## - `is_sprinting`: indica si el jugador intenta esprintar y se usará para escalar el blend de locomoción.
## - `_air_time`: tiempo acumulado en el aire, utilizado por transiciones como el estado de caída.
## Efectos: valida los parámetros y actualiza `_is_sprinting`; el tiempo de aire se evalúa dentro de `physics_tick`.
func set_frame_anim_inputs(is_sprinting: bool, _air_time: float) -> void:
	assert(is_finite(_air_time), "AnimationCtrlModule.set_frame_anim_inputs espera un air_time finito.")
	assert(_air_time >= 0.0, "AnimationCtrlModule.set_frame_anim_inputs espera un air_time no negativo.")
	_is_sprinting = is_sprinting

func _cache_sneak_animation_lengths() -> void:
	if anim_player == null or not is_instance_valid(anim_player):
		return
	var enter_anim: Animation = anim_player.get_animation(CLIP_SNEAK_ENTER)
	if enter_anim != null:
		_sneak_enter_clip_length = maxf(enter_anim.length, 0.0)
	var exit_anim: Animation = anim_player.get_animation(CLIP_SNEAK_EXIT)
	if exit_anim != null:
		_sneak_exit_clip_length = maxf(exit_anim.length, 0.0)
	var enter_duration := _calculate_sneak_enter_duration()
	_apply_sneak_enter_settings(enter_duration)

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

	_update_sneak_blend(delta)
	_update_sneak_exit_state(delta)
	if _sneak_active:
		_update_sneak_move_blend()
		_set_air_blend(0.0)
		_set_sprint_scale(1.0)
	else:
		_set_sneak_move_blend(0.0)

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
	if _sneak_active:
		_set_sprint_scale(1.0)
		_set_air_blend(0.0)
		if _airborne:
			if _has_jumped and player != null and is_instance_valid(player):
				if player.velocity.y > 0.0:
					return
			_airborne = false
			_time_in_air = 0.0
			_fall_triggered = false
			_has_jumped = false
			_current_air_blend = 0.0
			_stop_jump_one_shot()
		return

	if _airborne:
		if _has_jumped and player != null and is_instance_valid(player):
			if player.velocity.y > 0.0:
				return
		_airborne = false
		_time_in_air = 0.0
		_fall_triggered = false
		_has_jumped = false
		_current_air_blend = 0.0
		_stop_jump_one_shot()
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

func _set_tree_params(params: Array[StringName], fallback: StringName, value: float, clamp_01 := false) -> void:
	if anim_tree == null:
		return
	var final_value := value
	if clamp_01:
		final_value = clampf(value, 0.0, 1.0)
	var applied := false
	for param in params:
		anim_tree.set(param, final_value)
		applied = true
	if not applied and not String(fallback).is_empty() and _tree_has_param(fallback):
		anim_tree.set(fallback, final_value)

func _set_locomotion_blend(value: float) -> void:
	_set_tree_params(_locomotion_params, PARAM_LOC_LEGACY, value, true)

func _set_air_blend(value: float) -> void:
	_set_tree_params(_air_blend_params, PARAM_AIRBLEND, value, true)

func _set_sprint_scale(value: float) -> void:
	_set_tree_params(_sprint_scale_params, PARAM_SPRINTSCL_LEGACY, value)

func _fire_jump_one_shot() -> bool:
	if anim_tree == null:
		return false
	var requested := false
	for param in _jump_request_params:
		anim_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		requested = true
	if requested:
		_jump_fired = true
	return requested

func _stop_jump_one_shot() -> void:
	if anim_tree == null:
		return
	if not _jump_fired:
		return
	for param in _jump_request_params:
		anim_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_jump_fired = false

func _cache_state_machine() -> void:
	# Garantiza que tengamos referencia válida al AnimationTree.
	_state_machine = null
	_state_machine_graph = null
	_state_machine_started = false
	if anim_tree == null:
		LoggerService.warn(LOGGER_CONTEXT, "AnimationTree no asignado; revisa que el módulo se configure en setup().")
		return
	if animation_tree_path == NodePath():
		animation_tree_path = anim_tree.get_path()
		_refresh_parameter_cache()

	var playback := _resolve_state_machine_playback()
	if playback == null:
		LoggerService.warn(LOGGER_CONTEXT, "No se encontró un AnimationNodeStateMachinePlayback válido en el AnimationTree. Revisa que el root sea un StateMachine y que su 'playback' esté expuesto.")
		return

	_state_machine = playback
	var tree_root := anim_tree.tree_root
	if tree_root is AnimationNodeStateMachine:
		_state_machine_graph = tree_root
	else:
		_state_machine_graph = null
		LoggerService.warn(LOGGER_CONTEXT, "El AnimationTree configurado no expone un AnimationNodeStateMachine como raíz; no se puede validar la existencia de estados.")
	_state_locomotion = _resolve_state_name(STATE_LOCOMOTION, STATE_LOCOMOTION_LEGACY)
	_start_state_machine(_state_locomotion)
	_cache_transition_indices()
	_configure_transition_blends()

func _resolve_state_machine_playback() -> AnimationNodeStateMachinePlayback:
	if anim_tree == null:
		return null

	if anim_tree.has_method("get_state_machine_playback"):
		var playback_variant: Variant = anim_tree.call("get_state_machine_playback")
		var playback_direct := playback_variant as AnimationNodeStateMachinePlayback
		if playback_direct != null:
			return playback_direct

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

func _initialize_context_state() -> void:
	_current_context_state = CONTEXT_DEFAULT
	_sneak_active = false
	if player != null and is_instance_valid(player):
		if player.has_method("get_context_state"):
			var ctx_value: Variant = player.get_context_state()
			if typeof(ctx_value) == TYPE_INT:
				_current_context_state = int(ctx_value)
				_sneak_active = _current_context_state == CONTEXT_SNEAK
		if player.has_signal("context_state_changed"):
			if not player.context_state_changed.is_connected(_on_player_context_state_changed):
				player.context_state_changed.connect(_on_player_context_state_changed)
	_apply_context_state(_current_context_state, true)

func _on_player_context_state_changed(new_state: int, _previous: int) -> void:
	_apply_context_state(new_state)

func _apply_context_state(state: int, force: bool = false) -> void:
	_current_context_state = state
	var wants_sneak := state == CONTEXT_SNEAK
	if wants_sneak:
		if force or not _sneak_active:
			_activate_sneak()
	else:
		if _sneak_active:
			_deactivate_sneak()
		elif force:
			_stop_sneak_enter_one_shot()
			_stop_sneak_exit_one_shot()
			_set_sneak_move_blend(0.0)
			_set_sneak_blend_target(0.0, 0.0)
			_sneak_exit_playing = false
			_sneak_exit_timer = 0.0

func _update_sneak_move_blend() -> void:
	if not _sneak_active:
		_set_sneak_move_blend(0.0)
		return
	if _sneak_enter_timer > 0.0 or _sneak_enter_playing:
		return
	if player == null or not is_instance_valid(player):
		return
	var target := _current_sneak_speed_ratio()
	_set_sneak_move_blend(target)

func _set_sneak_move_blend(value: float) -> void:
	if anim_tree == null:
		return
	var clamped := clampf(value, 0.0, 1.0)
	var applied := false
	for param in _sneak_move_params:
		anim_tree.set(param, clamped)
		applied = true
	if not applied:
		if _tree_has_param(PARAM_SNEAK_MOVE):
			anim_tree.set(PARAM_SNEAK_MOVE, clamped)

func _tween_param(path: String, to_value: float, dur: float, trans := Tween.TRANS_SINE, ease_mode := Tween.EASE_OUT) -> void:
	if anim_tree == null:
		return
	if path.is_empty():
		return
	var duration: float = maxf(dur, 0.0)
	if duration <= 0.0:
		anim_tree.set(path, to_value)
		return
	var tw := create_tween().set_trans(trans).set_ease(ease_mode)
	tw.tween_property(anim_tree, path, to_value, duration)

func _tween_cached_params(params: Array[StringName], to_value: float, duration: float, fallback: StringName = StringName()) -> void:
	if anim_tree == null:
		return
	var applied := false
	for param in params:
		var path := String(param)
		if path.is_empty():
			continue
		_tween_param(path, to_value, duration)
		applied = true
	if not applied and fallback != StringName() and _tree_has_param(fallback):
		_tween_param(String(fallback), to_value, duration)

func _get_primary_param(params: Array[StringName], fallback: StringName = StringName()) -> StringName:
	if not params.is_empty():
		return params[0]
	if fallback != StringName() and _tree_has_param(fallback):
		return fallback
	return StringName()

func _get_sneak_blend_fallback() -> StringName:
	if _tree_has_param(PARAM_SNEAK_BLEND):
		return PARAM_SNEAK_BLEND
	if _tree_has_param(PARAM_SNEAK_BLEND_ALT):
		return PARAM_SNEAK_BLEND_ALT
	return StringName()

func _current_sneak_speed_ratio() -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	if walk_speed <= 0.0:
		return 0.0
	return clampf(hspeed / maxf(walk_speed, 0.001), 0.0, 1.0)

func _calculate_sneak_enter_duration() -> float:
	var duration := maxf(sneak_enter_blend_time, _sneak_enter_clip_length)
	if duration <= 0.0:
		duration = sneak_enter_blend_time
	return maxf(duration, 0.0)

func _set_sneak_blend_target(target: float, duration: float) -> void:
	_sneak_blend_target = clampf(target, 0.0, 1.0)
	if anim_tree == null:
		_sneak_blend_value = _sneak_blend_target
		return
	var clamped_duration := maxf(duration, 0.0)
	if clamped_duration <= 0.0:
		_apply_sneak_blend(_sneak_blend_target)
		return
	_tween_cached_params(_sneak_blend_params, _sneak_blend_target, clamped_duration, _get_sneak_blend_fallback())

func _apply_sneak_blend(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	_sneak_blend_value = clamped
	_set_sneak_blend_param(clamped)

func _set_sneak_blend_param(value: float) -> void:
	if anim_tree == null:
		return
	var applied := false
	for param in _sneak_blend_params:
		anim_tree.set(param, value)
		applied = true
	if not applied:
		if _tree_has_param(PARAM_SNEAK_BLEND):
			anim_tree.set(PARAM_SNEAK_BLEND, value)
		elif _tree_has_param(PARAM_SNEAK_BLEND_ALT):
			anim_tree.set(PARAM_SNEAK_BLEND_ALT, value)

func _apply_cached_param(params: Array[StringName], fallback: StringName, value: Variant) -> void:
	if anim_tree == null:
		return
	var applied := false
	for param in params:
		anim_tree.set(param, value)
		applied = true
	if not applied and _tree_has_param(fallback):
		anim_tree.set(fallback, value)

func _set_sneak_enter_fade_in(value: float) -> void:
	_apply_cached_param(_sneak_enter_fadein_params, PARAM_SNEAK_ENTER_FADE_IN, value)

func _set_sneak_enter_fade_out(value: float) -> void:
	_apply_cached_param(_sneak_enter_fadeout_params, PARAM_SNEAK_ENTER_FADE_OUT, value)

func _set_sneak_enter_mix(value: float) -> void:
	_apply_cached_param(_sneak_enter_mix_params, PARAM_SNEAK_ENTER_MIX, value)

func _set_sneak_enter_mix_mode(value: int) -> void:
	_apply_cached_param(_sneak_enter_mix_mode_params, PARAM_SNEAK_ENTER_MIX_MODE, value)

func _apply_sneak_enter_fade_settings(duration: float) -> void:
	var clamped_duration := maxf(duration, 0.0)
	if clamped_duration <= 0.0:
		_set_sneak_enter_fade_in(0.0)
		_set_sneak_enter_fade_out(0.0)
		return
	var fade_time := clampf(sneak_enter_blend_time, 0.0, clamped_duration)
	if fade_time <= 0.0:
		fade_time = clamped_duration
	var min_window := minf(clamped_duration, 0.05)
	if fade_time < min_window:
		fade_time = min_window
	_set_sneak_enter_fade_in(fade_time)
	_set_sneak_enter_fade_out(fade_time)

func _apply_sneak_enter_settings(duration: float) -> void:
	_apply_sneak_enter_fade_settings(duration)
	_set_sneak_enter_mix_mode(AnimationNodeOneShot.MIX_MODE_BLEND)
	_set_sneak_enter_mix(clampf(sneak_enter_idle_mix, 0.0, 1.0))

func _prime_sneak_idle_blend() -> void:
	if _sneak_blend_value >= SNEAK_PRE_BLEND:
		return
	_apply_sneak_blend(SNEAK_PRE_BLEND)

func _do_enter_sneak(enter_duration: float, target_ratio: float) -> void:
	var clamped_duration := maxf(enter_duration, 0.0)
	var clamped_ratio := clampf(target_ratio, 0.0, 1.0)
	_apply_sneak_enter_settings(clamped_duration)
	_prime_sneak_idle_blend()
	_set_sneak_move_blend(0.0)
	_tween_cached_params(_sneak_move_params, clamped_ratio, clamped_duration, PARAM_SNEAK_MOVE)
	_request_sneak_enter_one_shot()
	_sneak_blend_target = 1.0
	if clamped_duration <= 0.0:
		_apply_sneak_blend(1.0)
	else:
		_tween_cached_params(_sneak_blend_params, 1.0, clamped_duration, _get_sneak_blend_fallback())
	_sneak_enter_timer = clamped_duration
	if _sneak_enter_timer <= 0.0:
		_sneak_enter_playing = false

func _do_exit_sneak() -> void:
	_sneak_enter_timer = 0.0
	_sneak_enter_playing = false
	_request_sneak_exit_one_shot()
	_set_sneak_move_blend(0.0)
	_sneak_blend_target = 0.0
	var exit_duration := maxf(sneak_exit_blend_out_time, 0.0)
	if exit_duration <= 0.0:
		_apply_sneak_blend(0.0)
	else:
		_tween_cached_params(_sneak_blend_params, 0.0, exit_duration, _get_sneak_blend_fallback())

func _update_sneak_blend(delta: float) -> void:
	if _sneak_enter_timer > 0.0:
		_sneak_enter_timer = maxf(_sneak_enter_timer - delta, 0.0)
		if _sneak_enter_timer <= 0.0:
			_sneak_enter_playing = false
	if anim_tree == null:
		return
	var param := _get_primary_param(_sneak_blend_params, _get_sneak_blend_fallback())
	if param == StringName():
		return
	var current: Variant = anim_tree.get(param)
	if current is float:
		_sneak_blend_value = clampf(float(current), 0.0, 1.0)

func _activate_sneak() -> void:
	if _sneak_active:
		_set_sneak_blend_target(1.0, 0.0)
		return
	_sneak_active = true
	_sneak_exit_playing = false
	_sneak_exit_timer = 0.0
	_stop_sneak_exit_one_shot()
	var enter_duration := _calculate_sneak_enter_duration()
	var speed_ratio := _current_sneak_speed_ratio()
	_do_enter_sneak(enter_duration, speed_ratio)

func _deactivate_sneak() -> void:
	_stop_sneak_enter_one_shot()
	if not _sneak_active:
		if not _sneak_exit_playing:
			_set_sneak_blend_target(0.0, 0.0)
		_set_sneak_move_blend(0.0)
		return
	_sneak_active = false
	_do_exit_sneak()

func _request_sneak_enter_one_shot() -> bool:
	if anim_tree == null:
		_sneak_enter_playing = false
		return false
	var fired := false
	for param in _sneak_enter_request_params:
		anim_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		fired = true
	if not fired and _tree_has_param(PARAM_SNEAK_ENTER_REQUEST):
		anim_tree.set(PARAM_SNEAK_ENTER_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		fired = true
	_sneak_enter_playing = fired
	return fired

func _stop_sneak_enter_one_shot() -> void:
	if anim_tree == null:
		_sneak_enter_playing = false
		_sneak_enter_timer = 0.0
		return
	var had_param := false
	for param in _sneak_enter_request_params:
		anim_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		had_param = true
	if not had_param and _tree_has_param(PARAM_SNEAK_ENTER_REQUEST):
		anim_tree.set(PARAM_SNEAK_ENTER_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		had_param = true
	_sneak_enter_timer = 0.0
	_sneak_enter_playing = false

func _request_sneak_exit_one_shot() -> void:
	if anim_tree == null:
		_sneak_exit_playing = false
		return
	var fired := false
	for param in _sneak_exit_request_params:
		anim_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		fired = true
	if fired:
		_sneak_exit_playing = true
		_sneak_exit_duration = _calculate_sneak_exit_duration()
		_sneak_exit_timer = _sneak_exit_duration
	else:
		_sneak_exit_playing = false
		_sneak_exit_duration = 0.0
		_sneak_exit_timer = 0.0

func _stop_sneak_exit_one_shot() -> void:
	if anim_tree == null:
		_sneak_exit_playing = false
		_sneak_exit_duration = 0.0
		_sneak_exit_timer = 0.0
		return
	if not _sneak_exit_playing:
		return
	for param in _sneak_exit_request_params:
		anim_tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_sneak_exit_playing = false
	_sneak_exit_duration = 0.0
	_sneak_exit_timer = 0.0

func _calculate_sneak_exit_duration() -> float:
	var duration := maxf(_sneak_exit_clip_length, sneak_exit_blend_in_time)
	return maxf(duration, 0.0)

func _update_sneak_exit_state(delta: float) -> void:
	if not _sneak_exit_playing:
		return
	if _sneak_exit_timer > 0.0:
		_sneak_exit_timer = maxf(_sneak_exit_timer - delta, 0.0)
	if _sneak_exit_timer <= 0.0:
		_sneak_exit_playing = false
		_sneak_exit_duration = 0.0

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
	_stop_jump_one_shot()
	_update_jump_fall_transition_blend()
	_set_air_blend(0.0)
	if _has_state(STATE_LAND):
		_travel_to_state(STATE_LAND)
	else:
		_travel_to_state(_state_locomotion)

func _start_state_machine(state_name: StringName) -> void:
	if _state_machine == null:
		return
	if String(state_name).is_empty():
		return
	if _state_machine_graph != null and not _state_machine_graph.has_node(state_name):
		return
	_state_machine.start(state_name)
	_state_machine_started = true

func _travel_to_state(state_name: StringName) -> void:
	if _state_machine == null:
		_cache_state_machine()
	if state_name == STATE_JUMP:
		_fire_jump_one_shot()
	elif state_name == _state_locomotion or state_name == STATE_LAND:
		_stop_jump_one_shot()

	if _state_machine == null:
		return
	if String(state_name).is_empty():
		return
	if _state_machine_graph != null and not _state_machine_graph.has_node(state_name):
		return
	if not _state_machine_started:
		_start_state_machine(state_name)
		if not _state_machine_started:
			return
	_state_machine.travel(state_name)

func _refresh_parameter_cache() -> void:
	_locomotion_params.clear()
	_sprint_scale_params.clear()
	_air_blend_params.clear()
	_jump_request_params.clear()
	_sneak_enter_request_params.clear()
	_sneak_exit_request_params.clear()
	_sneak_move_params.clear()
	_sneak_blend_params.clear()
	_sneak_enter_fadein_params.clear()
	_sneak_enter_fadeout_params.clear()
	_sneak_enter_mix_params.clear()
	_sneak_enter_mix_mode_params.clear()
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
	var air_candidates: Array[StringName] = [PARAM_AIRBLEND_STATE, PARAM_AIRBLEND]
	for param in air_candidates:
		if _tree_has_param(param) and not _air_blend_params.has(param):
			_air_blend_params.append(param)
	var jump_candidates: Array[StringName] = [PARAM_JUMP_REQUEST, PARAM_JUMP_REQUEST_LEGACY]
	for param in jump_candidates:
		if _tree_has_param(param) and not _jump_request_params.has(param):
			_jump_request_params.append(param)
	var sneak_enter_candidates: Array[StringName] = [PARAM_SNEAK_ENTER_REQUEST]
	for param in sneak_enter_candidates:
		if _tree_has_param(param) and not _sneak_enter_request_params.has(param):
			_sneak_enter_request_params.append(param)
	var sneak_exit_candidates: Array[StringName] = [PARAM_SNEAK_EXIT_REQUEST]
	for param in sneak_exit_candidates:
		if _tree_has_param(param) and not _sneak_exit_request_params.has(param):
			_sneak_exit_request_params.append(param)
	var sneak_move_candidates: Array[StringName] = [PARAM_SNEAK_MOVE]
	for param in sneak_move_candidates:
		if _tree_has_param(param) and not _sneak_move_params.has(param):
			_sneak_move_params.append(param)
	var sneak_blend_candidates: Array[StringName] = [PARAM_SNEAK_BLEND, PARAM_SNEAK_BLEND_ALT]
	for param in sneak_blend_candidates:
		if _tree_has_param(param) and not _sneak_blend_params.has(param):
			_sneak_blend_params.append(param)
	var sneak_enter_fadein_candidates: Array[StringName] = [PARAM_SNEAK_ENTER_FADE_IN]
	for param in sneak_enter_fadein_candidates:
		if _tree_has_param(param) and not _sneak_enter_fadein_params.has(param):
			_sneak_enter_fadein_params.append(param)
	var sneak_enter_fadeout_candidates: Array[StringName] = [PARAM_SNEAK_ENTER_FADE_OUT]
	for param in sneak_enter_fadeout_candidates:
		if _tree_has_param(param) and not _sneak_enter_fadeout_params.has(param):
			_sneak_enter_fadeout_params.append(param)
	var sneak_enter_mix_candidates: Array[StringName] = [PARAM_SNEAK_ENTER_MIX]
	for param in sneak_enter_mix_candidates:
		if _tree_has_param(param) and not _sneak_enter_mix_params.has(param):
			_sneak_enter_mix_params.append(param)

	var sneak_enter_mix_mode_candidates: Array[StringName] = [PARAM_SNEAK_ENTER_MIX_MODE]
	for param in sneak_enter_mix_mode_candidates:
		if _tree_has_param(param) and not _sneak_enter_mix_mode_params.has(param):
			_sneak_enter_mix_mode_params.append(param)

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

	# Godot 4 expone has_parameter() para rutas de AnimationTree.
	if anim_tree.has_method("has_parameter"):
		var has_param_variant: Variant = anim_tree.call("has_parameter", param)
		if has_param_variant is bool:
			if has_param_variant:
				return true
		elif has_param_variant == true:
			return true

	# Verificar si el parámetro existe intentando leerlo del property list
	if anim_tree.has_method("get_property_list"):
		var param_list: Array = anim_tree.get_property_list()
		var target_name := String(param)
		for prop in param_list:
			if prop is Dictionary and prop.has("name"):
				if String(prop["name"]) == target_name:
					return true

	return false

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
	var index := _get_transition_index(from_state, to_state)
	if index == -1:
		return
	var clamped := maxf(blend_time, 0.0)
	var setter := ""
	var getter := ""
	if _state_machine_graph.has_method("set_transition_blend_time"):
		setter = "set_transition_blend_time"
		if _state_machine_graph.has_method("get_transition_blend_time"):
			getter = "get_transition_blend_time"
	elif _state_machine_graph.has_method("set_transition_duration"):
		setter = "set_transition_duration"
		if _state_machine_graph.has_method("get_transition_duration"):
			getter = "get_transition_duration"
	if setter.is_empty():
		return
	if not getter.is_empty():
		var current: float = _state_machine_graph.call(getter, index)
		if is_equal_approx(current, clamped):
			return
	_state_machine_graph.call(setter, index, clamped)

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

