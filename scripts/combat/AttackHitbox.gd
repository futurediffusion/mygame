extends Area3D
class_name AttackHitbox

const PHYSICS_LAYERS := preload("res://scripts/core/PhysicsLayers.gd")

@export var modules_root_path: NodePath = NodePath("../../Modules")
@export_flags_3d_physics var detection_mask: int = PHYSICS_LAYERS.LAYER_PLAYER | PHYSICS_LAYERS.LAYER_ALLY | PHYSICS_LAYERS.LAYER_ENEMY

var _owner_body: CharacterBody3D
var _modules_root: Node
var _attack_module: AttackModule

func _ready() -> void:
	monitorable = true
	monitoring = true
	collision_layer = 0
	collision_mask = detection_mask
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	_owner_body = _find_character_body()

func _on_body_entered(body: Node) -> void:
	_handle_target(body)

func _on_area_entered(area: Area3D) -> void:
	_handle_target(area)

func _handle_target(target: Node) -> void:
	var attack_module := _resolve_attack_module()
	if attack_module == null or not is_instance_valid(attack_module):
		return
	if not attack_module.hit_active:
		return
	var character := _extract_character_body(target)
	if character == null:
		return
	if character == _owner_body:
		return
	var hit_normal := -global_transform.basis.z
	attack_module.on_attack_overlap(character, global_position, hit_normal)

func _resolve_attack_module() -> AttackModule:
	if _attack_module != null and is_instance_valid(_attack_module):
		return _attack_module
	var modules_root := _resolve_modules_root()
	if modules_root == null:
		return null
	for child in modules_root.get_children():
		if child is AttackModule:
			_attack_module = child
			return _attack_module
	return null

func _resolve_modules_root() -> Node:
	if _modules_root != null and is_instance_valid(_modules_root):
		return _modules_root
	if modules_root_path == NodePath():
		return null
	var node := get_node_or_null(modules_root_path)
	if node != null:
		_modules_root = node
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
