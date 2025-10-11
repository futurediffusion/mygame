extends ModuleBase
class_name AllyFSMModule

@export var owner_ally: NodePath
@export var sim_group: StringName = Flags.ALLY_TICK_GROUP
@export var priority: int = 15

var _ally_cached: Node

func _ready() -> void:
        super._ready()
        _ally_cached = get_node_or_null(owner_ally)

func physics_tick(dt: float) -> void:
        var ally := _ally_cached
        if ally == null or not is_instance_valid(ally):
                ally = _resolve_ally()
                if ally == null:
                        return
        # Evita fallos si el Ally aún no expone la API.
        if ally.has_method("fsm_step"):
                ally.fsm_step(dt)
                if ally.has_variable("_fsm_tick_ran"):
                        ally._fsm_tick_ran = true

func _resolve_ally() -> Node:
        var node: Node = null
        if owner_ally != NodePath():
                node = get_node_or_null(owner_ally)
        if node == null:
                node = get_parent()
        if node != null and node.has_method("fsm_step"):
                _ally_cached = node
        else:
                _ally_cached = null
        return _ally_cached
