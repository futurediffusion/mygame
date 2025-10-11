extends Node
class_name PerfectJumpCombo

@export var perfect_window: float = 0.10	# 100 ms tras aterrizar
@export var speed_bonus_per_stack: float = 0.06
@export var jump_bonus_per_stack: float = 0.05
@export var max_stacks: int = 5
@export var decay_per_sec: float = 1.0

var _stacks: float = 0.0
var _time_since_land: float = 9999.0

signal combo_changed(stacks: float)

func physics_tick(dt: float) -> void:
	_time_since_land += dt
	if _stacks > 0.0:
		var before: float = _stacks
		_stacks = max(0.0, _stacks - decay_per_sec * dt)
		if not is_equal_approx(_stacks, before):
			emit_signal("combo_changed", _stacks)

func on_landed() -> void:
	_time_since_land = 0.0

func register_perfect() -> void:
	var before: float = _stacks
	_stacks = clamp(_stacks + 1.0, 0.0, float(max_stacks))
	if not is_equal_approx(_stacks, before):
		emit_signal("combo_changed", _stacks)

func speed_multiplier() -> float:
	return 1.0 + (speed_bonus_per_stack * _stacks)

func jump_multiplier() -> float:
	return 1.0 + (jump_bonus_per_stack * _stacks)

func is_in_perfect_window() -> bool:
	return _time_since_land <= perfect_window
