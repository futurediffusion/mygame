# res://scripts/combat/Health.gd
extends Node

signal health_changed(current: float, max: float)
signal damaged(amount: float, from: Node)
signal died()

@export var max_health: float = 100.0
@export var start_health: float = 100.0
@export var invul_time: float = 0.0 # segundos de “no recibir daño” tras ser golpeado (0 = desactivado)

var current: float
var _invul_until: float = 0.0

func _ready() -> void:
	current = clamp(start_health, 0.0, max_health)
	emit_signal("health_changed", current, max_health)

func is_dead() -> bool:
	return current <= 0.0

func take_damage(amount: float, from: Node = null) -> void:
	if amount <= 0.0 or is_dead():
		return
	if Time.get_ticks_msec()/1000.0 < _invul_until:
		return

	current = max(0.0, current - amount)
	emit_signal("damaged", amount, from)
	emit_signal("health_changed", current, max_health)

	if current <= 0.0:
		emit_signal("died")

	if invul_time > 0.0:
		_invul_until = Time.get_ticks_msec()/1000.0 + invul_time

func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	current = min(max_health, current + amount)
	emit_signal("health_changed", current, max_health)

func set_max_health(new_max: float, keep_ratio: bool = true) -> void:
	var ratio := (current / max_health) if max_health > 0.0 else 1.0
	max_health = max(1.0, new_max)
	current = clamp((ratio * max_health) if keep_ratio else current, 0.0, max_health)
	emit_signal("health_changed", current, max_health)
