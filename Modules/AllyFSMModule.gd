extends ModuleBase
class_name AllyFSMModule

@export var owner_ally: NodePath
@export var sim_group: StringName = Flags.ALLY_TICK_GROUP
@export var priority: int = 20

var _ally_cached: Node

func _ready() -> void:
	super._ready()

func physics_tick(dt: float) -> void:
	var ally := _resolve_ally()
	if ally == null:
		return
	if ally.has_method("physics_tick"):
		ally.physics_tick(dt)

func _resolve_ally() -> Node:
	if _ally_cached != null and is_instance_valid(_ally_cached):
		return _ally_cached
	var node: Node = null
	if owner_ally != NodePath():
		node = get_node_or_null(owner_ally)
	if node == null:
		node = get_parent()
	if node != null and node.has_method("physics_tick"):
		_ally_cached = node
	else:
		_ally_cached = null
	return _ally_cached
