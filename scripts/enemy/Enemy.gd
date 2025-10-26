extends Player
class_name Enemy

const PHYSICS_LAYERS := preload("res://scripts/core/PhysicsLayers.gd")

@export_node_path("Node") var brain_path: NodePath

var brain: EnemyBrain

func apply_damage(amount: float, from: Node = null) -> void:
	super.apply_damage(amount, from)

func _ready() -> void:
	super._ready()
	if input_buffer != null and is_instance_valid(input_buffer):
		if input_buffer.get_parent() == self:
			remove_child(input_buffer)
		input_buffer.queue_free()
		input_buffer = null
	if m_jump != null and is_instance_valid(m_jump):
		if m_jump.has_property("allow_direct_input"):
			m_jump.allow_direct_input = false
		m_jump.setup(self, m_state, null, m_movement)
	collision_layer = PHYSICS_LAYERS.LAYER_ENEMY
	collision_mask = PHYSICS_LAYERS.MASK_ENEMY
	if attack_module != null and is_instance_valid(attack_module):
		attack_module.accepts_input = false
		print("[Enemy] AttackModule configurado - accepts_input: false")
	var resolved := _resolve_brain()
	if resolved != null:
		resolved.set_enemy(self)
		print("[Enemy] Brain configurado: ", resolved.name)
	print("[Enemy] ✓ Inicializado: ", name)
	print("[Enemy] ✓ Collision Layer: ", collision_layer, " (LAYER_ENEMY)")
	print("[Enemy] ✓ Collision Mask: ", collision_mask)

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
		return {
			"move_dir": Vector3.ZERO,
			"look_dir": Vector3.ZERO,
			"is_sprinting": false,
			"want_roll": false,
			"want_attack": false,
			"want_jump": false
		}
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
	if want_attack and attack_module != null and is_instance_valid(attack_module):
		if attack_module.has_method("trigger_attack_request"):
			attack_module.trigger_attack_request()
			print("[Enemy] ⚔️ Solicitando ataque")
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
