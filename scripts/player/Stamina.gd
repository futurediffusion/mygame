extends Node
class_name Stamina

@export var max_stamina: float = 100.0
@export var sprint_drain_per_s: float = 18.0
@export var regen_per_s: float = 11.0
@export var regen_delay: float = 0.6

var value: float
var _regen_block: float = 0.0

func _ready() -> void:
	value = max_stamina

func can_sprint() -> bool:
	return value > max_stamina * 0.08

func consume_for_sprint(delta: float) -> void:
	value = max(0.0, value - sprint_drain_per_s * delta)
	_regen_block = regen_delay

func tick(delta: float) -> void:
	if _regen_block > 0.0:
		_regen_block -= delta
	elif value < max_stamina:
		value = min(max_stamina, value + regen_per_s * delta)
