extends Node
class_name AttackCallBridge

var _owner_body: CharacterBody3D
var _attack_module: AttackModule
var _animation_player: AnimationPlayer
var _relative_path: NodePath

func _ready() -> void:
	await get_tree().process_frame
	_resolve_dependencies()
	_retarget_method_tracks()

func attack_start_hit(attack_id) -> void:
	if not _ensure_attack_module():
		return
	print("[AttackCallBridge] 🎯 attack_start_hit → ", attack_id, " (Owner: ", _owner_body.name if _owner_body else "null", ")")
	_attack_module.attack_start_hit(attack_id)

func attack_end_hit(attack_id) -> void:
	if not _ensure_attack_module():
		return
	print("[AttackCallBridge] 🛡️ attack_end_hit → ", attack_id)
	_attack_module.attack_end_hit(attack_id)

func _ensure_attack_module() -> bool:
	if _attack_module != null and is_instance_valid(_attack_module):
		return true
	if _owner_body == null:
		push_warning("[AttackCallBridge] Owner no resuelto, no se puede obtener AttackModule")
		return false
	_attack_module = _find_attack_module(_owner_body)
	if _attack_module == null:
		push_warning("[AttackCallBridge] No se encontró AttackModule para: %s" % _owner_body.name)
		return false
	return true

func _resolve_dependencies() -> void:
	_owner_body = _find_character_body()
	if _owner_body:
		print("[AttackCallBridge] ✓ Owner: ", _owner_body.name)
	else:
		push_warning("[AttackCallBridge] No se encontró CharacterBody3D en ancestros")
	_attack_module = _find_attack_module(_owner_body) if _owner_body else null
	if _attack_module:
		print("[AttackCallBridge] ✓ AttackModule: ", _attack_module.name)
	else:
		push_warning("[AttackCallBridge] AttackModule no disponible")
	_animation_player = _find_animation_player()
	if _animation_player:
		_relative_path = _animation_player.get_path_to(self)
		print("[AttackCallBridge] ✓ AnimationPlayer: ", _animation_player.get_path())
		print("[AttackCallBridge] ✓ Path relativo: ", _relative_path)
	else:
		push_warning("[AttackCallBridge] No se encontró AnimationPlayer")

func _retarget_method_tracks() -> void:
	if _animation_player == null:
		return
	var relative_path := _relative_path if _relative_path != NodePath() else _animation_player.get_path_to(self)
	if relative_path == NodePath():
		push_warning("[AttackCallBridge] No se pudo calcular path relativo")
		return
	for anim_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(anim_name)
		if animation == null:
			continue
		var changed := false
		for track_idx in range(animation.get_track_count()):
			if animation.track_get_type(track_idx) != Animation.TYPE_METHOD:
				continue
			var has_attack_method := false
			for key_idx in range(animation.track_get_key_count(track_idx)):
				var key_value := animation.track_get_key_value(track_idx, key_idx)
				if key_value is Dictionary:
					var method_name: String = key_value.get("method", "")
					if method_name == "attack_start_hit" or method_name == "attack_end_hit":
						has_attack_method = true
						break
			if not has_attack_method:
				continue
			var current_path := animation.track_get_path(track_idx)
			if current_path == relative_path:
				continue
			if not current_path.is_empty():
				var current_path_str := String(current_path)
				if current_path_str == String(relative_path):
					continue
				print("[AttackCallBridge] ↺ Retargeting track en ", anim_name, ": ", current_path, " → ", relative_path)
			else:
				print("[AttackCallBridge] ↺ Configurando path para track en ", anim_name, " → ", relative_path)
			animation.track_set_path(track_idx, relative_path)
			changed = true
		if changed:
			animation.resource_changed()

func _find_animation_player() -> AnimationPlayer:
	var node := get_parent()
	if node:
		var anim_player := node.get_node_or_null("AnimationPlayer")
		if anim_player and anim_player is AnimationPlayer:
			return anim_player
	return find_child("AnimationPlayer", true, false) as AnimationPlayer

func _find_character_body() -> CharacterBody3D:
	var node: Node = self
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _find_attack_module(body: Node) -> AttackModule:
	if body == null:
		return null
	var modules := body.get_node_or_null("Modules")
	if modules:
		for child in modules.get_children():
			if child is AttackModule:
				return child
	return _search_attack_module_recursive(body)

func _search_attack_module_recursive(node: Node) -> AttackModule:
	if node == null:
		return null
	if node is AttackModule:
		return node
	for child in node.get_children():
		var found := _search_attack_module_recursive(child)
		if found:
			return found
	return null
