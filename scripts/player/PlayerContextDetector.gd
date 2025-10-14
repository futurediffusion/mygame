extends Node
class_name PlayerContextDetector

signal context_changed(new_state: int, previous_state: int)

var _context_state: int = Player.ContextState.DEFAULT
var _water_areas: Array[Area3D] = []
var _is_in_water := false
var _frame_is_sitting := false
var _frame_talk_active := false
var _frame_is_sneaking := false
var _frame_is_on_floor := false

func reset() -> void:
	_context_state = Player.ContextState.DEFAULT
	_water_areas.clear()
	_is_in_water = false
	_frame_is_sitting = false
	_frame_talk_active = false
	_frame_is_sneaking = false
	_frame_is_on_floor = false

func update_frame(is_sitting: bool, talk_active: bool, is_sneaking: bool, is_on_floor: bool) -> void:
	_frame_is_sitting = is_sitting
	_frame_talk_active = talk_active
	_frame_is_sneaking = is_sneaking
	_frame_is_on_floor = is_on_floor
	_reevaluate_context()

func mark_water_area(area: Area3D, entered: bool) -> void:
	if area == null or not is_instance_valid(area):
		return
	var is_water := false
	if area.is_in_group("water"):
		is_water = true
	elif area.has_meta("is_water"):
		var meta_value: Variant = area.get_meta("is_water")
		if meta_value is bool:
			is_water = meta_value
		else:
			is_water = bool(meta_value)
	if not is_water:
		return
	if entered:
		if not _water_areas.has(area):
			_water_areas.append(area)
	else:
		_water_areas.erase(area)
	var was_in_water := _is_in_water
	_is_in_water = _water_areas.size() > 0
	if was_in_water != _is_in_water:
		_reevaluate_context()

func get_context_state() -> int:
	return _context_state

func is_in_water() -> bool:
	return _is_in_water

func _reevaluate_context() -> void:
	var desired := Player.ContextState.DEFAULT
	if _frame_is_sitting:
		desired = Player.ContextState.SIT
	elif _frame_talk_active:
		desired = Player.ContextState.TALK
	elif _is_in_water:
		desired = Player.ContextState.SWIM
	elif _frame_is_sneaking and _frame_is_on_floor:
		desired = Player.ContextState.SNEAK
	_set_context_state(desired)

func _set_context_state(state: int) -> void:
	if _context_state == state:
		return
	var previous := _context_state
	_context_state = state
	context_changed.emit(state, previous)
