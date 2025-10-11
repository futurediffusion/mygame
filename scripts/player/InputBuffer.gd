extends Node
class_name InputBuffer

@export var jump_buffer_time: float = 0.12

var last_jump_pressed_s: float = -1.0
var last_jump_released_s: float = -1.0
var jump_is_held: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		last_jump_pressed_s = Time.get_ticks_msec() * 0.001
		jump_is_held = true
	elif event.is_action_released("jump"):
		last_jump_released_s = Time.get_ticks_msec() * 0.001
		jump_is_held = false

func is_jump_buffered(now_s: float) -> bool:
	return last_jump_pressed_s >= 0.0 and (now_s - last_jump_pressed_s) <= jump_buffer_time

func consume_jump_buffer() -> void:
	last_jump_pressed_s = -1.0

func held_time(now_s: float) -> float:
	if not jump_is_held:
		return 0.0
	var start_s := maxf(last_jump_pressed_s, last_jump_released_s)
	return maxf(0.0, now_s - start_s)
