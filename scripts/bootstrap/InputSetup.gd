extends Node

# Acciones y sus bindings por defecto (teclado/ratón)
@onready var _actions := {
	# Movimiento básico
	"move_forward": [KEY_W],
	"move_back":    [KEY_S],
	"move_left":    [KEY_A],
	"move_right":   [KEY_D],

	# Movimiento avanzado
	"sprint": [KEY_SHIFT],
	"jump":   [KEY_SPACE],
	"crouch": [KEY_C],  # agacharse / sigilo

	# Interacción / contexto
	"interact": [KEY_E],  # hablar/abrir/recoger/usar NPCs y objetos
	"use":      [KEY_F],  # acción contextual secundaria (futuro)
	"build":    [KEY_B],  # entrar/salir del modo construir

	# Combate
	"attack_primary":   [MOUSE_BUTTON_LEFT],   # click izq: ataque principal
	"attack_secondary": [MOUSE_BUTTON_RIGHT],  # click der: defensa/apuntar

	# Sistema
	"pause": [KEY_ESCAPE]
}

func _enter_tree() -> void:
	# Limpia acción obsoleta si existe (se usará 'interact' para hablar)
	if InputMap.has_action("talk"):
		InputMap.erase_action("talk")

	# Crea acciones y agrega eventos si faltan (sin duplicar)
	for action in _actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var desired_events := _actions[action]
		for key in desired_events:
			var ev := _make_event_from_key(key)
			if ev == null:
				continue
			if not _action_has_event(action, ev):
				InputMap.action_add_event(action, ev)

	# Este nodo sólo corre una vez al inicio
	queue_free()

# Crea InputEventKey o InputEventMouseButton según el código recibido
func _make_event_from_key(keycode: int) -> InputEvent:
	# Rango simple para distinguir mouse vs teclado
	if keycode == MOUSE_BUTTON_LEFT or keycode == MOUSE_BUTTON_RIGHT:
		var mb := InputEventMouseButton.new()
		mb.button_index = keycode
		return mb
	var k := InputEventKey.new()
	k.physical_keycode = keycode
	return k

# Evita duplicar bindings comparando tipo y código
func _action_has_event(action: String, ev: InputEvent) -> bool:
	var existing := InputMap.action_get_events(action)
	for e in existing:
		# Teclado
		if ev is InputEventKey and e is InputEventKey:
			var ek := e as InputEventKey
			var vk := ev as InputEventKey
			if ek.physical_keycode == vk.physical_keycode:
				return true
		# Ratón
		if ev is InputEventMouseButton and e is InputEventMouseButton:
			var em := e as InputEventMouseButton
			var vm := ev as InputEventMouseButton
			if em.button_index == vm.button_index:
				return true
	return false
