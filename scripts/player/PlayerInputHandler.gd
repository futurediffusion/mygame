extends Node
class_name PlayerInputHandler

signal input_updated(input_cache: Dictionary, state: Dictionary)
signal talk_requested()
signal sit_toggled(is_sitting: bool)
signal interact_requested()
signal combat_mode_switched(mode: String)
signal build_mode_toggled(is_building: bool)

enum SneakInputMode {
	TOGGLE,
	HOLD,
}

@export_enum("Toggle", "Hold") var sneak_input_mode: int = SneakInputMode.TOGGLE

var input_actions: Dictionary = {}
var _input_cache: Dictionary = {}
var _is_sneaking := false
var _is_sitting := false
var _is_build_mode := false
var _using_ranged := false
var _talk_active := false
var _pending_hold_exit := false
var _exit_sneak_callback: Callable = Callable()

func set_input_actions(actions: Dictionary) -> void:
	input_actions = actions.duplicate(true)

func initialize_cache() -> void:
	_initialize_input_cache()

func update_input(allow_input: bool, move_dir: Vector3) -> void:
	if _input_cache.is_empty():
		_initialize_input_cache()
	var raw_axes := Vector2.ZERO
	if allow_input:
		raw_axes.x = Input.get_axis("move_left", "move_right")
		raw_axes.y = Input.get_axis("move_back", "move_forward")
	var move_record: Dictionary = _input_cache.get("move", {})
	move_record["raw"] = raw_axes
	move_record["camera"] = move_dir
	_input_cache["move"] = move_record
	var sprint_record := _update_action_cache("sprint", input_actions.get("sprint", []), allow_input)
	var crouch_record := _update_action_cache("crouch", input_actions.get("crouch", []), allow_input)
	var jump_record := _update_action_cache("jump", input_actions.get("jump", []), allow_input)
	var talk_record := _update_action_cache("talk", input_actions.get("talk", []), allow_input)
	var sit_record := _update_action_cache("sit", input_actions.get("sit", []), allow_input)
	var interact_record := _update_action_cache("interact", input_actions.get("interact", []), allow_input)
	var combat_record := _update_action_cache("combat_switch", input_actions.get("combat_switch", []), allow_input)
	var build_record := _update_action_cache("build", input_actions.get("build", []), allow_input)
	if allow_input:
		if talk_record.get("just_pressed", false):
			talk_requested.emit()
		_talk_active = talk_record.get("pressed", false)
	else:
		_talk_active = false
	talk_record["active"] = _talk_active
	_input_cache["talk"] = talk_record
	var crouch_pressed: bool = crouch_record.get("pressed", false)
	var crouch_just_pressed: bool = crouch_record.get("just_pressed", false)
	var crouch_just_released: bool = crouch_record.get("just_released", false)
	if allow_input:
		match sneak_input_mode:
			SneakInputMode.TOGGLE:
				if crouch_just_pressed:
					if _is_sneaking:
						if _request_exit_sneak():
							_is_sneaking = false
					else:
						_is_sneaking = true
						_pending_hold_exit = false
			SneakInputMode.HOLD:
				if crouch_pressed:
					_is_sneaking = true
					_pending_hold_exit = false
				elif _is_sneaking and (crouch_just_released or _pending_hold_exit):
					if _request_exit_sneak():
						_is_sneaking = false
						_pending_hold_exit = false
					else:
						_is_sneaking = true
						_pending_hold_exit = true
	elif sneak_input_mode == SneakInputMode.HOLD and _pending_hold_exit and _is_sneaking and not crouch_pressed:
		if _request_exit_sneak():
			_is_sneaking = false
			_pending_hold_exit = false
		else:
			_is_sneaking = true
			_pending_hold_exit = true
	crouch_record["active"] = _is_sneaking
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
	_input_cache["jump"] = jump_record
	_input_cache["interact"] = interact_record
	var state := {
		"is_sneaking": _is_sneaking,
		"is_sitting": _is_sitting,
		"is_build_mode": _is_build_mode,
		"is_using_ranged": _using_ranged,
		"talk_active": _talk_active,
	}
	input_updated.emit(get_input_cache(), state)

func set_context_state(state: int) -> void:
	if _input_cache.is_empty():
		_initialize_input_cache()
	_input_cache["context_state"] = state

func get_input_cache() -> Dictionary:
	return _input_cache.duplicate(true)

func is_sneaking() -> bool:
	return _is_sneaking

func is_sitting() -> bool:
	return _is_sitting

func is_build_mode() -> bool:
	return _is_build_mode

func is_using_ranged() -> bool:
	return _using_ranged

func is_talk_active() -> bool:
	return _talk_active

func set_exit_sneak_callback(callback: Callable) -> void:
	_exit_sneak_callback = callback

func _request_exit_sneak() -> bool:
	if not _exit_sneak_callback.is_valid():
		return true
	var result_variant: Variant = _exit_sneak_callback.call()
	if result_variant is bool:
		return result_variant
	return bool(result_variant)

func _initialize_input_cache() -> void:
	_input_cache.clear()
	var move_record := {
		"raw": Vector2.ZERO,
		"camera": Vector3.ZERO,
	}
	_input_cache["move"] = move_record
	for key in input_actions.keys():
		_input_cache[key] = {
			"pressed": false,
			"just_pressed": false,
			"just_released": false,
		}
	_input_cache["context_state"] = Player.ContextState.DEFAULT

func _update_action_cache(key: String, action_names: Array, allow_input: bool) -> Dictionary:
	var record: Dictionary = _input_cache.get(key, {
		"pressed": false,
		"just_pressed": false,
		"just_released": false,
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
