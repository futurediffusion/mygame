extends Player
class_name Enemy

@export_node_path("Node") var brain_path: NodePath

var brain: EnemyBrain

func _ready() -> void:
	super._ready()
	var resolved := _resolve_brain()
	if resolved != null:
		resolved.set_enemy(self)

func _gather_control_intents(delta: float, allow_input: bool) -> Dictionary:
	if not allow_input:
		return {
			"move_dir": Vector3.ZERO,
			"look_dir": Vector3.ZERO,
			"is_sprinting": false,
			"want_roll": false,
			"want_attack": false,
			"want_jump": false
		}
	var resolved := _resolve_brain()
	if resolved == null:
		return super._gather_control_intents(delta, false)
	resolved.update_brain(delta)
	var intents := resolved.get_intents()
	var move_dir: Vector3 = intents.get("move_dir", Vector3.ZERO)
	if not move_dir.is_finite():
		move_dir = Vector3.ZERO
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()
	var look_dir: Vector3 = intents.get("look_dir", move_dir)
	if not look_dir.is_finite():
		look_dir = Vector3.ZERO
	if look_dir.length_squared() > 1.0:
		look_dir = look_dir.normalized()
	var want_attack := bool(intents.get("want_attack", false))
	return {
		"move_dir": move_dir,
		"look_dir": look_dir,
		"is_sprinting": false,
		"want_roll": false,
		"want_attack": want_attack,
		"want_jump": false
	}

func _resolve_brain() -> EnemyBrain:
	if brain != null and is_instance_valid(brain):
		return brain
	var node: Node = null
	if brain_path != NodePath():
		node = get_node_or_null(brain_path)
	if node == null:
		node = get_node_or_null("Brain")
	if node is EnemyBrain:
		brain = node
		if brain != null and brain.get_enemy() != self:
			brain.set_enemy(self)
		return brain
	brain = null
	return null
