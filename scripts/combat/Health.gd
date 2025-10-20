extends Node
class_name Health

signal health_changed(current: float, max: float)
signal damaged(amount: float, from: Node)
signal died()

@export var max_health: float = 100.0
@export var start_health: float = 100.0
@export var invul_time: float = 0.0

var current: float = 0.0
var _invul_until: float = 0.0

func _ready() -> void:
	max_health = maxf(max_health, 1.0)
	current = clampf(start_health, 0.0, max_health)
	health_changed.emit(current, max_health)

func is_dead() -> bool:
	return current <= 0.0

func take_damage(amount: float, from: Node = null) -> void:
	if amount <= 0.0 or is_dead():
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < _invul_until:
		return
	current = maxf(0.0, current - amount)
	damaged.emit(amount, from)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()
	if invul_time > 0.0:
		_invul_until = now + invul_time

func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	current = minf(max_health, current + amount)
	health_changed.emit(current, max_health)

func set_max_health(new_max: float, keep_ratio: bool = true) -> void:
	var ratio := 1.0
	if max_health > 0.0:
		ratio = current / max_health
	max_health = maxf(1.0, new_max)
	if keep_ratio:
		current = clampf(ratio * max_health, 0.0, max_health)
	else:
		current = clampf(current, 0.0, max_health)
	health_changed.emit(current, max_health)
