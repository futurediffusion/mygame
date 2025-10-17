extends Node
## Crea acciones de input si no existen y se auto-destruye.

const DEFAULT_ACTIONS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE
}

func _enter_tree() -> void:
	for action_name in DEFAULT_ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var ev := InputEventKey.new()
			ev.keycode = DEFAULT_ACTIONS[action_name]
			InputMap.action_add_event(action_name, ev)
	queue_free()
