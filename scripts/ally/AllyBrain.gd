extends Node
class_name AllyBrain

@export_node_path("CharacterBody3D") var ally_path: NodePath

var _ally: Ally
var _state_machine: StateMachineModule

func _ready() -> void:
	_resolve_ally()
	_resolve_state_machine()

func set_ally(ally: Ally) -> void:
	_ally = ally
	_resolve_state_machine()

func update_intents(_dt: float) -> void:
	var ally := _resolve_ally()
	if ally == null:
		return
	var fsm := _resolve_state_machine()
	if fsm == null:
		return
	var intents := ally.get_brain_intents()
	var move_dir: Vector3 = intents.get("move_dir", Vector3.ZERO)
	if not move_dir.is_finite():
		move_dir = Vector3.ZERO
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()
	var is_sprinting: bool = bool(intents.get("is_sprinting", false))
	var want_dodge: bool = bool(intents.get("want_dodge", false))
	var want_attack: bool = bool(intents.get("want_attack", false))
	var want_jump: bool = bool(intents.get("want_jump", false))
	fsm.set_intents(move_dir, is_sprinting, want_dodge, want_attack, want_jump)
	ally.clear_brain_triggers()

func _resolve_ally() -> Ally:
	if _ally != null and is_instance_valid(_ally):
		return _ally
	if ally_path != NodePath():
		var node := get_node_or_null(ally_path)
		if node is Ally:
			_ally = node
			return _ally
	var parent := get_parent()
	if parent is Ally:
		_ally = parent
		return _ally
	_ally = null
	return null

func _resolve_state_machine() -> StateMachineModule:
	if _state_machine != null and is_instance_valid(_state_machine):
		return _state_machine
	var ally := _resolve_ally()
	if ally == null:
		_state_machine = null
		return null
	var modules := ally.get_node_or_null("Modules")
	if modules != null and is_instance_valid(modules):
		var candidate := modules.get_node_or_null("StateMachine") as StateMachineModule
		if candidate != null:
			_state_machine = candidate
			return _state_machine
	var direct := ally.get_node_or_null("StateMachine") as StateMachineModule
	if direct != null:
		_state_machine = direct
	return _state_machine
