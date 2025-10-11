extends Node
class_name ModuleBase

const DEFAULT_SIM_GROUP: StringName = &"local"
const DEFAULT_PRIORITY: int = 0

@export var sim_group: StringName = DEFAULT_SIM_GROUP
@export var priority: int = DEFAULT_PRIORITY
var _subscribed: bool = false

func _ready() -> void:
	_subscribe_clock()

func _exit_tree() -> void:
	_unsubscribe_clock()

func _subscribe_clock() -> void:
	if _subscribed:
		return
	var clock := _get_simclock()
	if clock == null:
		push_warning("SimClock autoload no disponible; omitiendo registro para %s." % name)
		return
	clock.register_module(self, sim_group, priority)
	_subscribed = true

func _unsubscribe_clock() -> void:
	_subscribed = false

func _on_clock_tick(group: StringName, dt: float) -> void:
	if group == sim_group:
		physics_tick(dt)

func physics_tick(_dt: float) -> void:
	pass

func _get_simclock() -> SimClockAutoload:
	var tree := get_tree()
	if tree == null:
		return null
	var autoload := tree.get_root().get_node_or_null("/root/SimClock")
	if autoload == null:
		return null
	return autoload as SimClockAutoload
