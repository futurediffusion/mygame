extends Node
class_name AttackCallBridge

# Este nodo actúa como puente entre AnimationTree/AnimationPlayer y AttackModule

# Mapeo de nombres de animación a IDs de ataque
const ANIMATION_TO_ATTACK_ID := {
	"punchrighta": "P1",
	"Punch1": "P1",
	"punch1": "P1",
	"punchleftb": "P2",
	"Punch2": "P2",
	"punch2": "P2",
	"punchrightc": "P3",
	"Punch3": "P3",
	"punch3": "P3",
}

# Tiempos de ventana de ataque por animación
const ATTACK_WINDOWS := {
	"punchrighta": { "start": 0.12, "end": 0.213 },
	"Punch1": { "start": 0.12, "end": 0.213 },
	"punchleftb": { "start": 0.113, "end": 0.207 },
	"Punch2": { "start": 0.113, "end": 0.207 },
	"punchrightc": { "start": 0.147, "end": 0.267 },
	"Punch3": { "start": 0.147, "end": 0.267 },
}

# Mapeo de parámetros del AnimationTree a animaciones
const TREE_PARAMS_TO_ANIM := {
	"parameters/LocomotionSpeed/Punch1/active": "punchrighta",
	"parameters/Punch1/active": "punchrighta",
	"parameters/LocomotionSpeed/Punch2/active": "punchleftb",
	"parameters/Punch2/active": "punchleftb",
	"parameters/LocomotionSpeed/Punch3/active": "punchrightc",
	"parameters/Punch3/active": "punchrightc",
}

var _owner_body: CharacterBody3D
var _attack_module: AttackModule
var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer
var _current_attack_anim: String = ""
var _window_opened: bool = false
var _window_closed: bool = false
var _last_checked_params: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	_resolve_dependencies()

func _resolve_dependencies() -> void:
	_owner_body = _find_character_body()
	if _owner_body == null:
		push_error("[AttackBridge] No se encontró CharacterBody3D padre")
		return

	_attack_module = _find_attack_module(_owner_body)
	if _attack_module == null:
		push_error("[AttackBridge] No se encontró AttackModule en: ", _owner_body.name)
		return

	_anim_tree = _find_animation_tree()
	_anim_player = _find_animation_player()

	if _anim_tree:
		print("[AttackBridge] ✓ AnimationTree encontrado")
		for param in TREE_PARAMS_TO_ANIM.keys():
			_last_checked_params[param] = false

	if _anim_player:
		if not _anim_player.animation_started.is_connected(_on_animation_started):
			_anim_player.animation_started.connect(_on_animation_started)
		if not _anim_player.animation_finished.is_connected(_on_animation_finished):
			_anim_player.animation_finished.connect(_on_animation_finished)
		print("[AttackBridge] ✓ AnimationPlayer conectado")

	print("[AttackBridge] ✓ Configurado correctamente")
	print("[AttackBridge]   - Owner: ", _owner_body.name)
	print("[AttackBridge]   - AttackModule: ", _attack_module.name)

func _process(delta: float) -> void:
	if _anim_tree and _anim_tree.active:
		_check_animation_tree_state()

	if _current_attack_anim != "":
		_process_attack_window(delta)

func _check_animation_tree_state() -> void:
	for param in TREE_PARAMS_TO_ANIM.keys():
		if not _anim_tree.has_parameter(param):
			continue

		var is_active: bool = _anim_tree.get(param)
		var was_active: bool = _last_checked_params.get(param, false)

		if is_active and not was_active:
			var anim_name: String = TREE_PARAMS_TO_ANIM[param]
			print("[AttackBridge] 🎬 Animación detectada vía Tree: ", anim_name, " (param: ", param, ")")
			_start_attack_animation(anim_name)

		if not is_active and was_active:
			var anim_name: String = TREE_PARAMS_TO_ANIM[param]
			if _current_attack_anim == anim_name:
				print("[AttackBridge] 🏁 Animación finalizada vía Tree: ", anim_name)
				_end_attack_animation(anim_name)

		_last_checked_params[param] = is_active

func _process_attack_window(_delta: float) -> void:
	if not ATTACK_WINDOWS.has(_current_attack_anim):
		return

	if _anim_player == null:
		return

	var config: Dictionary = ATTACK_WINDOWS[_current_attack_anim]
	var position := _anim_player.current_animation_position
	var start_time: float = config.get("start", 0.0)
	var end_time: float = config.get("end", 0.0)
	var attack_id := ANIMATION_TO_ATTACK_ID.get(_current_attack_anim, "P1")

	if not _window_opened and position >= start_time:
		_window_opened = true
		print("[AttackBridge] 🗡️ Abriendo ventana: ", attack_id, " (", _current_attack_anim, ") en ", position, "s")
		attack_start_hit(attack_id)

	if _window_opened and not _window_closed and position >= end_time:
		_window_closed = true
		print("[AttackBridge] 🛡️ Cerrando ventana: ", attack_id, " en ", position, "s")
		attack_end_hit(attack_id)

func _start_attack_animation(anim_name: String) -> void:
	if ANIMATION_TO_ATTACK_ID.has(anim_name):
		_current_attack_anim = anim_name
		_window_opened = false
		_window_closed = false
		print("[AttackBridge]   ✓ Monitoreando ataque...")

func _end_attack_animation(anim_name: String) -> void:
	if _current_attack_anim == anim_name:
		if _window_opened and not _window_closed:
			var attack_id := ANIMATION_TO_ATTACK_ID.get(_current_attack_anim, "P1")
			print("[AttackBridge] 🔒 Forzando cierre: ", attack_id)
			attack_end_hit(attack_id)

		_current_attack_anim = ""
		_window_opened = false
		_window_closed = false

func _on_animation_started(anim_name: String) -> void:
	print("[AttackBridge] 🎬 Animación iniciada (Player signal): ", anim_name)
	_start_attack_animation(anim_name)

func _on_animation_finished(anim_name: String) -> void:
	_end_attack_animation(anim_name)

# Estos métodos también pueden ser llamados directamente por animation tracks
func attack_start_hit(attack_id) -> void:
	if _attack_module == null or not is_instance_valid(_attack_module):
		return

	print("[AttackBridge] 🎯 attack_start_hit → ", attack_id, " (Owner: ", _owner_body.name if _owner_body else "null", ")")
	_attack_module.attack_start_hit(attack_id)

func attack_end_hit(attack_id) -> void:
	if _attack_module == null or not is_instance_valid(_attack_module):
		return

	print("[AttackBridge] 🛡️ attack_end_hit → ", attack_id)
	_attack_module.attack_end_hit(attack_id)

func _find_character_body() -> CharacterBody3D:
	var node: Node = self
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _find_animation_tree() -> AnimationTree:
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is AnimationTree:
				return child

	if _owner_body:
		return _search_animation_tree_recursive(_owner_body)

	return null

func _find_animation_player() -> AnimationPlayer:
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is AnimationPlayer:
				return child
	return null

func _search_animation_tree_recursive(node: Node) -> AnimationTree:
	if node is AnimationTree:
		return node
	for child in node.get_children():
		var result = _search_animation_tree_recursive(child)
		if result != null:
			return result
	return null

func _find_attack_module(body: Node) -> AttackModule:
	var modules_node = body.get_node_or_null("Modules")
	if modules_node:
		for child in modules_node.get_children():
			if child is AttackModule:
				return child
	return _search_attack_module_recursive(body)

func _search_attack_module_recursive(node: Node) -> AttackModule:
	if node is AttackModule:
		return node
	for child in node.get_children():
		var result = _search_attack_module_recursive(child)
		if result != null:
			return result
	return null
