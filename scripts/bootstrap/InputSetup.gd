extends Node

# Acciones y sus bindings por defecto (teclado/ratón)
const _ACTION_BINDINGS := {
	# Movimiento básico
	&"move_forward": [Key.KEY_W],
	&"move_back": [Key.KEY_S],
	&"move_left": [Key.KEY_A],
	&"move_right": [Key.KEY_D],

	# Movimiento avanzado
	&"sprint": [Key.KEY_SHIFT],
	&"jump": [Key.KEY_SPACE],
	&"crouch": [Key.KEY_C],  # agacharse / sigilo

	# Interacción / contexto
	&"interact": [Key.KEY_E],  # hablar/abrir/recoger/usar NPCs y objetos
	&"use": [Key.KEY_F],  # acción contextual secundaria (futuro)
	&"build": [Key.KEY_B],  # entrar/salir del modo construir

	# Combate
	&"attack_primary": [MOUSE_BUTTON_LEFT],  # click izq: ataque principal
	&"attack_secondary": [MOUSE_BUTTON_RIGHT],  # click der: defensa/apuntar

	# Sistema
	&"pause": [Key.KEY_ESCAPE]
}

const _MOUSE_BUTTON_CODES := [
	MOUSE_BUTTON_LEFT,
	MOUSE_BUTTON_RIGHT,
]

@onready var _actions: Dictionary = _ACTION_BINDINGS

func _enter_tree() -> void:
	# Limpia acción obsoleta si existe (se usará 'interact' para hablar)
	if InputMap.has_action("talk"):
		InputMap.erase_action("talk")

	# Crea acciones y agrega eventos si faltan (sin duplicar)
	for action in _actions.keys():
		var action_name := StringName(action)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var desired_events := _actions[action_name] as Array
		for key in desired_events:
			var ev := _make_event_from_key(key)
			if ev == null:
				continue
			if not _action_has_event(action_name, ev):
				InputMap.action_add_event(action_name, ev)

	# Este nodo sólo corre una vez al inicio
	queue_free()

# Crea InputEventKey o InputEventMouseButton según el código recibido
func _make_event_from_key(keycode: int) -> InputEvent:
	# Rango simple para distinguir mouse vs teclado
	if _MOUSE_BUTTON_CODES.has(keycode):
		var mb := InputEventMouseButton.new()
		# Usa asignación dinámica para conservar los códigos enteros sin castear.
		mb.set("button_index", keycode)
		return mb
	var k := InputEventKey.new()
	# Igual que con el ratón, se mantiene el entero original para evitar casts.
	k.set("physical_keycode", keycode)
	return k

# Evita duplicar bindings comparando tipo y código
func _action_has_event(action: StringName, ev: InputEvent) -> bool:
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
