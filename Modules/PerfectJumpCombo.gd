extends Node
class_name PerfectJumpCombo

@export var perfect_window: float = 0.06
@export var combo_curve_gamma: float = 0.5
@export var combo_speed_bonus_max: float = 3.0
@export_range(1.0, 2.0, 0.01) var combo_jump_bonus_max: float = 2.0

const MAX_JUMP_LEVEL: int = 100

var _body: CharacterBody3D
var _was_on_floor: bool = false
var _landed_timer: float = 0.0
var _combo_count: int = 0

signal combo_changed(value: int)
signal perfect_jump()
signal combo_reset()

func _ready() -> void:
	_body = _resolve_body()
	if _body != null and _body.is_on_floor():
		_was_on_floor = true

func physics_tick(delta: float) -> void:
	var body := _get_body()
	if body == null:
		_reset_timers()
		return
	var on_floor := body.is_on_floor()
	if on_floor and not _was_on_floor:
		_open_perfect_window()
	_was_on_floor = on_floor
	if on_floor:
		if _landed_timer > 0.0:
			_landed_timer = max(_landed_timer - delta, 0.0)
	else:
		_landed_timer = 0.0

func on_landed() -> void:
	_open_perfect_window()
	_was_on_floor = true

func register_jump(was_perfect: bool) -> void:
	if was_perfect:
		var previous := _combo_count
		_combo_count = min(_combo_count + 1, MAX_JUMP_LEVEL)
		if _combo_count != previous:
			combo_changed.emit(_combo_count)
		perfect_jump.emit()
	else:
		if _combo_count != 0:
			_combo_count = 0
			combo_changed.emit(_combo_count)
			combo_reset.emit()
	_landed_timer = 0.0

func register_perfect() -> void:
	register_jump(true)

func register_failed_jump() -> void:
	register_jump(false)

func reset_combo() -> void:
	if _combo_count == 0:
		return
	_combo_count = 0
	combo_changed.emit(_combo_count)
	combo_reset.emit()

func get_combo() -> int:
	return _combo_count

func get_jump_level() -> int:
	return _combo_count

func get_max_jump_level() -> int:
	return MAX_JUMP_LEVEL

func is_in_perfect_window() -> bool:
	return _landed_timer > 0.0 and _was_on_floor

func get_multipliers() -> Dictionary:
	var ratio := _progress_ratio()
	var eased := _eased_speed_ratio(ratio)
	return {
		"speed_mult": lerp(1.0, combo_speed_bonus_max, eased),
		"jump_mult": lerp(1.0, combo_jump_bonus_max, ratio)
	}

func speed_multiplier() -> float:
	return get_multipliers().get("speed_mult", 1.0)

func jump_multiplier() -> float:
	return get_multipliers().get("jump_mult", 1.0)

func _progress_ratio() -> float:
	if MAX_JUMP_LEVEL <= 0:
		return 0.0
	return clampf(float(_combo_count) / float(MAX_JUMP_LEVEL), 0.0, 1.0)

func _eased_speed_ratio(ratio: float) -> float:
	if ratio <= 0.0:
		return 0.0
	if ratio >= 1.0:
		return 1.0
	var gamma := maxf(combo_curve_gamma, 0.0001)
	return clampf(pow(ratio, gamma), 0.0, 1.0)

func _open_perfect_window() -> void:
	_landed_timer = max(perfect_window, 0.0)

func _reset_timers() -> void:
	_landed_timer = 0.0
	_was_on_floor = false

func _get_body() -> CharacterBody3D:
	if _body != null and is_instance_valid(_body):
		return _body
	_body = _resolve_body()
	return _body

func _resolve_body() -> CharacterBody3D:
	var candidate: Object = owner
	if candidate is CharacterBody3D and is_instance_valid(candidate):
		return candidate
	candidate = get_parent()
	if candidate is CharacterBody3D and is_instance_valid(candidate):
		return candidate
	return null
