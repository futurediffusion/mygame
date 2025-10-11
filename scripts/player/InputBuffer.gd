extends Node
class_name InputBuffer

@export var jump_buffer_time: float = 0.120
var _jump_pressed_at: float = -1.0

func note_jump_pressed(now: float) -> void:
	_jump_pressed_at = now

func consume_jump(now: float) -> bool:
	if _jump_pressed_at < 0.0:
		return false
	if (now - _jump_pressed_at) <= jump_buffer_time:
		_jump_pressed_at = -1.0
		return true
	_jump_pressed_at = -1.0
	return false
