extends Node
## Crea acciones de input si no existen y se auto-destruye.

func _enter_tree() -> void:
	var actions := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE
	}
	for action_name in actions.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var ev := InputEventKey.new()
			ev.keycode = actions[action_name]
			InputMap.action_add_event(action_name, ev)
	queue_free()
