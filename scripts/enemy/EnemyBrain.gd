extends Node
class_name EnemyBrain

enum BrainState {
	WANDER,
	CHASE,
	RETURN,
	ATTACK
}

const LOSE_DELAY := 2.0
const DEFAULT_BODY_RADIUS := 0.5

@export_range(10.0, 16.0, 0.1) var wander_radius: float = 12.0
@export_range(2.5, 5.5, 0.1) var wander_interval_min: float = 2.5
@export_range(2.5, 5.5, 0.1) var wander_interval_max: float = 5.5
@export_range(12.0, 16.0, 0.1) var detect_radius: float = 14.0
@export_range(6.0, 12.0, 0.1) var lose_radius_margin: float = 8.0
@export_range(0.1, 1.5, 0.05) var attack_range: float = 0.35
@export_range(0.8, 1.2, 0.05) var reattack_cooldown: float = 1.0
@export_enum("spawn") var home_point_mode: String = "spawn"

var intent_move_dir: Vector3 = Vector3.ZERO
var intent_look_dir: Vector3 = Vector3.ZERO
var intent_attack: bool = false

var _enemy: CharacterBody3D
var _home_position: Vector3 = Vector3.ZERO
var _has_home := false
var _state: BrainState = BrainState.WANDER
var _current_target: Node3D
var _attack_cooldown: float = 0.0
var _lose_timer: float = 0.0
var _wander_timer: float = 0.0
var _wander_duration: float = 0.0
var _wander_goal: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func set_enemy(enemy: CharacterBody3D) -> void:
	_enemy = enemy
	if _enemy != null and is_instance_valid(_enemy):
		if home_point_mode == "spawn":
			_set_home(_enemy.global_transform.origin)

func get_enemy() -> CharacterBody3D:
	return _enemy

func update_brain(delta: float) -> void:
	intent_move_dir = Vector3.ZERO
	intent_look_dir = Vector3.ZERO
	intent_attack = false
	var enemy := _ensure_enemy()
	if enemy == null:
		return
	if not _has_home:
		_set_home(enemy.global_transform.origin)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var target := _refresh_target(enemy, delta)
	if target != null and _is_in_attack_range(enemy, target) and _attack_cooldown <= 0.0:
		_state = BrainState.ATTACK
	elif target != null:
		_state = BrainState.CHASE
	else:
		if _state == BrainState.CHASE or _state == BrainState.ATTACK:
			_state = BrainState.RETURN
		elif _state == BrainState.RETURN and _is_at_home(enemy):
			_state = BrainState.WANDER
		elif _state != BrainState.RETURN:
			_state = BrainState.WANDER
	match _state:
		BrainState.ATTACK:
			_apply_attack(enemy, target)
			if target != null and is_instance_valid(target):
				_state = BrainState.CHASE
			elif _is_at_home(enemy):
				_state = BrainState.WANDER
			else:
				_state = BrainState.RETURN
		BrainState.CHASE:
			_apply_chase(enemy, target)
		BrainState.RETURN:
			_apply_return(enemy)
		BrainState.WANDER:
			_apply_wander(enemy, delta)
	if _state == BrainState.RETURN and _is_at_home(enemy):
		_state = BrainState.WANDER

func get_intents() -> Dictionary:
	return {
		"move_dir": intent_move_dir,
		"look_dir": intent_look_dir,
		"want_attack": intent_attack
	}

func _ensure_enemy() -> CharacterBody3D:
	if _enemy != null and is_instance_valid(_enemy):
		return _enemy
	_enemy = null
	return null

func _set_home(position: Vector3) -> void:
	_home_position = position
	_has_home = true
	_wander_goal = position
	_wander_timer = 0.0
	_wander_duration = 0.0

func _refresh_target(enemy: CharacterBody3D, delta: float) -> Node3D:
	if _current_target != null and not is_instance_valid(_current_target):
		_current_target = null
	var target := _current_target
	if target != null:
		var dist_sq := _distance_sq_flat(enemy.global_transform.origin, target.global_transform.origin)
		if dist_sq > _get_lose_radius() * _get_lose_radius():
			_lose_timer += delta
			if _lose_timer >= LOSE_DELAY:
				_current_target = null
				target = null
				_lose_timer = 0.0
		else:
			_lose_timer = 0.0
	else:
		_lose_timer = 0.0
	if _current_target == null:
		var candidate := _find_closest_player(enemy)
		if candidate != null:
			var candidate_dist_sq := _distance_sq_flat(enemy.global_transform.origin, candidate.global_transform.origin)
			if candidate_dist_sq <= detect_radius * detect_radius:
				_current_target = candidate
				_lose_timer = 0.0
	return _current_target

func _apply_attack(enemy: CharacterBody3D, target: Node3D) -> void:
	intent_move_dir = Vector3.ZERO
	var look := Vector3.ZERO
	if target != null and is_instance_valid(target):
		look = _direction_to(enemy.global_transform.origin, target.global_transform.origin)
		if look != Vector3.ZERO:
			intent_look_dir = look
	intent_attack = true
	_attack_cooldown = maxf(reattack_cooldown, 0.0)

func _apply_chase(enemy: CharacterBody3D, target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		_state = BrainState.RETURN
		return
	var dir := _direction_to(enemy.global_transform.origin, target.global_transform.origin)
	if dir != Vector3.ZERO:
		intent_move_dir = dir
		intent_look_dir = dir
	else:
		intent_move_dir = Vector3.ZERO
		intent_look_dir = Vector3.ZERO

func _apply_return(enemy: CharacterBody3D) -> void:
	if not _has_home:
		return
	var dist_sq := _distance_sq_flat(enemy.global_transform.origin, _home_position)
	if dist_sq <= 1.0:
		intent_move_dir = Vector3.ZERO
		intent_look_dir = _direction_to(enemy.global_transform.origin, _home_position)
		return
	var dir := _direction_to(enemy.global_transform.origin, _home_position)
	intent_move_dir = dir
	intent_look_dir = dir

func _apply_wander(enemy: CharacterBody3D, delta: float) -> void:
	if not _has_home:
		return
	_wander_timer += delta
	var dist_sq := _distance_sq_flat(enemy.global_transform.origin, _wander_goal)
	if _wander_duration <= 0.0 or _wander_timer >= _wander_duration or dist_sq <= 0.25:
		_choose_new_wander_goal()
	var dir := _direction_to(enemy.global_transform.origin, _wander_goal)
	if dir != Vector3.ZERO:
		intent_move_dir = dir
		intent_look_dir = dir
	else:
		intent_move_dir = Vector3.ZERO
		intent_look_dir = Vector3.ZERO

func _choose_new_wander_goal() -> void:
	if not _has_home:
		return
	var min_interval := minf(wander_interval_min, wander_interval_max)
	var max_interval := maxf(wander_interval_min, wander_interval_max)
	if max_interval <= 0.01:
		max_interval = 0.01
	if min_interval < 0.0:
		min_interval = 0.0
	_wander_duration = _rng.randf_range(min_interval, max_interval)
	_wander_timer = 0.0
	var radius := _rng.randf_range(0.5, maxf(wander_radius, 0.5))
	var angle := _rng.randf_range(0.0, TAU)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
	_wander_goal = _home_position + offset

func _find_closest_player(enemy: CharacterBody3D) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("player")
	var closest: Node3D = null
	var closest_dist_sq := INF
	for node in nodes:
		if node == enemy:
			continue
		if not (node is Node3D):
			continue
		var node3d := node as Node3D
		var dist_sq := _distance_sq_flat(enemy.global_transform.origin, node3d.global_transform.origin)
		if dist_sq < closest_dist_sq:
			closest = node3d
			closest_dist_sq = dist_sq
	return closest

func _distance_sq_flat(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	delta.y = 0.0
	return delta.length_squared()

func _direction_to(from: Vector3, to: Vector3) -> Vector3:
	var delta := to - from
	delta.y = 0.0
	if delta.length_squared() < 0.0001:
		return Vector3.ZERO
	return delta.normalized()

func _is_in_attack_range(enemy: CharacterBody3D, target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var dist_sq: float = _distance_sq_flat(enemy.global_transform.origin, target.global_transform.origin)
	var dist: float = sqrt(dist_sq)
	var enemy_radius := _estimate_body_radius(enemy)
	var target_radius := _estimate_body_radius(target)
	var surface_gap := maxf(0.0, dist - (enemy_radius + target_radius))
	return surface_gap <= attack_range

func _estimate_body_radius(node: Node3D) -> float:
	if node == null or not is_instance_valid(node):
		return DEFAULT_BODY_RADIUS
	var shape := _find_collision_shape(node)
	if shape == null or not is_instance_valid(shape):
		return DEFAULT_BODY_RADIUS
	var shape_res: Shape3D = shape.shape
	if shape_res == null:
		return DEFAULT_BODY_RADIUS
	var debug_mesh := shape_res.get_debug_mesh()
	if debug_mesh == null:
		return DEFAULT_BODY_RADIUS
	var aabb: AABB = debug_mesh.get_aabb()
	var scale: Vector3 = shape.global_transform.basis.get_scale()
	var scaled_x: float = aabb.size.x * absf(scale.x)
	var scaled_z: float = aabb.size.z * absf(scale.z)
	var radius := maxf(scaled_x, scaled_z) * 0.5
	if radius <= 0.0:
		return DEFAULT_BODY_RADIUS
	return radius

func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node == null or not is_instance_valid(node):
		return null
	if node is CollisionShape3D:
		return node
	var direct := node.get_node_or_null("CollisionShape3D")
	if direct is CollisionShape3D:
		return direct
	var recursive := node.find_child("CollisionShape3D", true, false)
	if recursive is CollisionShape3D:
		return recursive
	return null

func _get_lose_radius() -> float:
	return detect_radius + lose_radius_margin

func _is_at_home(enemy: CharacterBody3D) -> bool:
	if not _has_home:
		return false
	return _distance_sq_flat(enemy.global_transform.origin, _home_position) <= 1.0
