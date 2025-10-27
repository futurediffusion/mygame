extends Node
class_name AttackCallBridge

# Este nodo actúa como puente entre AnimationPlayer y AttackModule
# Funciona para cualquier humanoide (Player, Enemy, Ally)

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

var _owner_body: CharacterBody3D
var _attack_module: AttackModule
var _anim_player: AnimationPlayer
var _current_attack_anim: String = ""
var _window_opened: bool = false
var _window_closed: bool = false

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
	
	_anim_player = _find_animation_player()
	if _anim_player:
		if not _anim_player.animation_started.is_connected(_on_animation_started):
			_anim_player.animation_started.connect(_on_animation_started)
		if not _anim_player.animation_finished.is_connected(_on_animation_finished):
			_anim_player.animation_finished.connect(_on_animation_finished)
		print("[AttackBridge] ✓ AnimationPlayer conectado")
	
	print("[AttackBridge] ✓ Configurado correctamente")
	print("[AttackBridge]   - Owner: ", _owner_body.name)
	print("[AttackBridge]   - AttackModule: ", _attack_module.name)

func _process(_delta: float) -> void:
	if _current_attack_anim == "" or _anim_player == null:
		return
	
	if not ATTACK_WINDOWS.has(_current_attack_anim):
		return
	
	var config: Dictionary = ATTACK_WINDOWS[_current_attack_anim]
	var position := _anim_player.current_animation_position
	var start_time: float = config.get("start", 0.0)
	var end_time: float = config.get("end", 0.0)
	var attack_id: String = ANIMATION_TO_ATTACK_ID.get(_current_attack_anim, "P1")
	
	# Abrir ventana
	if not _window_opened and position >= start_time:
		_window_opened = true
		print("[AttackBridge] 🗡️ Abriendo ventana: ", attack_id, " (", _current_attack_anim, ") en ", position, "s")
		attack_start_hit(attack_id)
	
	# Cerrar ventana
	if _window_opened and not _window_closed and position >= end_time:
		_window_closed = true
		print("[AttackBridge] 🛡️ Cerrando ventana: ", attack_id, " en ", position, "s")
		attack_end_hit(attack_id)

func _on_animation_started(anim_name: String) -> void:
	print("[AttackBridge] 🎬 Animación iniciada: ", anim_name)
	
	if ANIMATION_TO_ATTACK_ID.has(anim_name):
		_current_attack_anim = anim_name
		_window_opened = false
		_window_closed = false
		print("[AttackBridge]   ✓ Es animación de ataque, monitoreando...")
	else:
		_current_attack_anim = ""

func _on_animation_finished(anim_name: String) -> void:
	if _current_attack_anim == anim_name:
		# Forzar cierre si no se cerró
		if _window_opened and not _window_closed:
			var attack_id: String = ANIMATION_TO_ATTACK_ID.get(_current_attack_anim, "P1")
			print("[AttackBridge] 🔒 Forzando cierre: ", attack_id)
			attack_end_hit(attack_id)
		_current_attack_anim = ""
		_window_opened = false
		_window_closed = false

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

func _find_animation_player() -> AnimationPlayer:
	var model = get_parent()
	if model:
		for child in model.get_children():
			if child is AnimationPlayer:
				return child
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
