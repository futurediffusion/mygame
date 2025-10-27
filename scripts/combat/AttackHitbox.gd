extends Area3D
class_name AttackHitbox

const PHYSICS_LAYERS := preload("res://scripts/core/PhysicsLayers.gd")

@export var modules_root_path: NodePath = NodePath("../../Modules")
@export_flags_3d_physics var detection_mask: int = PHYSICS_LAYERS.LAYER_PLAYER | PHYSICS_LAYERS.LAYER_ALLY | PHYSICS_LAYERS.LAYER_ENEMY

var _owner_body: CharacterBody3D
var _owner_label: String = "?"
var _modules_root: Node
var _attack_module: AttackModule
var _overlapping_body_ids: Dictionary = {}
var _overlapping_area_ids: Dictionary = {}

func _ready() -> void:
	monitorable = true
	monitoring = true
	collision_layer = 0
	collision_mask = detection_mask
	print("[AttackHitbox] Inicializado con detection_mask: ", detection_mask)
	print("[AttackHitbox] LAYER_PLAYER: ", PHYSICS_LAYERS.LAYER_PLAYER)
	print("[AttackHitbox] LAYER_ENEMY: ", PHYSICS_LAYERS.LAYER_ENEMY)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)
	_owner_body = _find_character_body()
	if _owner_body:
		_owner_label = str(_owner_body.name)
		print("[AttackHitbox] Owner body encontrado: ", _owner_label, " en capa: ", _owner_body.collision_layer)
	else:
		_owner_label = "<sin_owner>"
	set_physics_process(true)

func _on_body_entered(body: Node) -> void:
	var body_name := "null"
	if body:
		body_name = str(body.name)
	var body_layer := "N/A"
	if body is CollisionObject3D:
		body_layer = str(body.collision_layer)
	print("[AttackHitbox] body_entered detectado: ", body_name, " - Capa: ", body_layer)
	_track_body(body)
	_handle_target(body)

func _on_body_exited(body: Node) -> void:
	var body_name := "null"
	if body:
		body_name = str(body.name)
	print("[AttackHitbox] body_exited detectado: ", body_name)
	_untrack_body(body)

func _on_area_entered(area: Area3D) -> void:
	var area_name := "null"
	if area:
		area_name = str(area.name)
	print("[AttackHitbox] area_entered detectado: ", area_name)
	_track_area(area)
	_handle_target(area)

func _on_area_exited(area: Area3D) -> void:
	var area_name := "null"
	if area:
		area_name = str(area.name)
	print("[AttackHitbox] area_exited detectado: ", area_name)
	_untrack_area(area)

func process_existing_overlaps() -> void:
	if not monitoring:
		return
	_cleanup_invalid_targets()
	_print_debug_overlaps("process_existing_overlaps")
	for body in _overlapping_body_ids.values():
		_handle_target(body)
	for area in _overlapping_area_ids.values():
		_handle_target(area)

func _physics_process(_delta: float) -> void:
	var attack_module := _resolve_attack_module()
	if attack_module == null or not is_instance_valid(attack_module):
		return
	if not attack_module.hit_active:
		return
	_cleanup_invalid_targets()
	_print_debug_overlaps("_physics_process")
	for body in _overlapping_body_ids.values():
		_handle_target(body)
	for area in _overlapping_area_ids.values():
		_handle_target(area)

func _track_body(body: Node) -> void:
	if body == null:
		return
	if body == _owner_body:
		print("[AttackHitbox] (", _owner_label, ") Ignorando track de owner")
		return
	var key := body.get_instance_id()
	_overlapping_body_ids[key] = body
	print("[AttackHitbox] (", _owner_label, ") Body trackeado: ", str(body.name), " → total cuerpos: ", _overlapping_body_ids.size())

func _untrack_body(body: Node) -> void:
	if body == null:
		return
	var key := body.get_instance_id()
	_overlapping_body_ids.erase(key)

func _track_area(area: Area3D) -> void:
	if area == null:
		return
	var key := area.get_instance_id()
	_overlapping_area_ids[key] = area
	print("[AttackHitbox] (", _owner_label, ") Área trackeada: ", str(area.name), " → total áreas: ", _overlapping_area_ids.size())

func _untrack_area(area: Area3D) -> void:
	if area == null:
		return
	var key := area.get_instance_id()
	_overlapping_area_ids.erase(key)

func _cleanup_invalid_targets() -> void:
	var remove_body_ids: Array = []
	for key in _overlapping_body_ids.keys():
		var node: Node = _overlapping_body_ids[key]
		if node == null or not is_instance_valid(node):
			remove_body_ids.append(key)
	for key in remove_body_ids:
		_overlapping_body_ids.erase(key)
	var remove_area_ids: Array = []
	for key in _overlapping_area_ids.keys():
		var node: Node = _overlapping_area_ids[key]
		if node == null or not is_instance_valid(node):
			remove_area_ids.append(key)
	for key in remove_area_ids:
		_overlapping_area_ids.erase(key)
	if remove_body_ids.size() > 0 or remove_area_ids.size() > 0:
		print("[AttackHitbox] (", _owner_label, ") Limpieza de overlaps → cuerpos removidos: ", remove_body_ids.size(), ", áreas removidas: ", remove_area_ids.size())

func _print_debug_overlaps(context: String) -> void:
	var tracked_bodies: Array[String] = []
	for body in _overlapping_body_ids.values():
		if body != null and is_instance_valid(body):
			tracked_bodies.append(str(body.name))
	var tracked_areas: Array[String] = []
	for area in _overlapping_area_ids.values():
		if area != null and is_instance_valid(area):
			tracked_areas.append(str(area.name))
	var engine_body_labels: Array[String] = []
	if has_method("get_overlapping_bodies"):
		for engine_body in get_overlapping_bodies():
			engine_body_labels.append(_format_engine_overlap(engine_body))
	var engine_area_labels: Array[String] = []
	if has_method("get_overlapping_areas"):
		for engine_area in get_overlapping_areas():
			engine_area_labels.append(_format_engine_overlap(engine_area))
	if tracked_bodies.is_empty() and tracked_areas.is_empty() and engine_body_labels.is_empty() and engine_area_labels.is_empty():
		print("[AttackHitbox] (", _owner_label, ") ", context, " → sin overlaps registrados")
		return
	print(
		"[AttackHitbox] (", _owner_label, ") ", context,
		" → cuerpos: ", ", ".join(tracked_bodies),
		" | áreas: ", ", ".join(tracked_areas),
		" || engine cuerpos: ", ", ".join(engine_body_labels),
		" | engine áreas: ", ", ".join(engine_area_labels)
	)

func _format_engine_overlap(entry: Node) -> String:
	if entry == null:
		return "<null>"
	if not is_instance_valid(entry):
		return "<freed>"
	var parts: Array[String] = []
	parts.append(str(entry.name))
	parts.append(entry.get_class())
	if entry is CollisionObject3D:
		parts.append("layer=" + str(entry.collision_layer))
	return "[" + ", ".join(parts) + "]"

func _handle_target(target: Node) -> void:
	var attack_module := _resolve_attack_module()
	if attack_module == null or not is_instance_valid(attack_module):
		print("[AttackHitbox] (", _owner_label, ") ERROR: No se pudo resolver AttackModule")
		return
	if not attack_module.hit_active:
		print("[AttackHitbox] (", _owner_label, ") Ataque no activo, ignorando overlap con ", _describe_target(target))
		return
	var character := _extract_character_body(target)
	if character == null:
		var target_name := "null"
		if target:
			target_name = str(target.name)
		print("[AttackHitbox] (", _owner_label, ") No se pudo extraer CharacterBody3D de: ", target_name)
		return
	if character == _owner_body:
		print("[AttackHitbox] (", _owner_label, ") Target es el owner (", str(character.name), "), ignorando")
		return
	var hit_normal := -global_transform.basis.z
	print("[AttackHitbox] (", _owner_label, ") Llamando on_attack_overlap para: ", str(character.name), " desde ", _describe_target(target))
	attack_module.on_attack_overlap(character, global_position, hit_normal)

func _describe_target(target: Node) -> String:
	if target == null:
		return "<null>"
	var parts: Array[String] = []
	parts.append(str(target.name))
	parts.append(target.get_class())
	if target is CollisionObject3D:
		parts.append("layer=" + str(target.collision_layer))
	return "[" + ", ".join(parts) + "]"

func _resolve_attack_module() -> AttackModule:
	if _attack_module != null and is_instance_valid(_attack_module):
		return _attack_module
	var modules_root := _resolve_modules_root()
	if modules_root == null:
		print("[AttackHitbox] ERROR: No se pudo resolver modules_root")
		return null
	for child in modules_root.get_children():
		if child is AttackModule:
			_attack_module = child
			print("[AttackHitbox] AttackModule encontrado: ", str(child.name))
			return _attack_module
	print("[AttackHitbox] ERROR: No se encontró AttackModule en modules_root")
	return null

func _resolve_modules_root() -> Node:
	if _modules_root != null and is_instance_valid(_modules_root):
		return _modules_root
	if modules_root_path == NodePath():
		print("[AttackHitbox] ERROR: modules_root_path está vacío")
		return null
	var node := get_node_or_null(modules_root_path)
	if node != null:
		_modules_root = node
		print("[AttackHitbox] Modules root resuelto: ", str(node.name))
	else:
		print("[AttackHitbox] ERROR: No se encontró nodo en path: ", modules_root_path)
	return _modules_root

func _find_character_body() -> CharacterBody3D:
	var node: Node = self
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _extract_character_body(node: Node) -> CharacterBody3D:
	var current := node
	while current != null:
		if current is CharacterBody3D:
			return current
		current = current.get_parent()
	return null
