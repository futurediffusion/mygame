extends Node
class_name ModuleBase

const DEFAULT_SIM_GROUP: StringName = &"local"
const DEFAULT_PRIORITY: int = 0
const SIMCLOCK_SCRIPT := preload("res://Singletons/SimClock.gd")

@export var sim_group: StringName = DEFAULT_SIM_GROUP
@export var priority: int = DEFAULT_PRIORITY
var _subscribed: bool = false

func _ready() -> void:
	_subscribe_clock()

func _exit_tree() -> void:
	var clock := _get_simclock()
	if _subscribed and clock != null:
		clock.unregister_module(self, sim_group)
	_subscribed = false

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
	if not _subscribed:
		return
	var clock := _get_simclock()
	if clock != null:
		clock.unregister_module(self, sim_group)
	_subscribed = false

func _on_clock_tick(group: StringName, dt: float) -> void:
	if group == sim_group:
		physics_tick(dt)

func physics_tick(_dt: float) -> void:
	pass

func _get_simclock() -> SimClockAutoload:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Viewport = tree.get_root()
	if root == null:
		return null
	var autoload: Node = root.get_node_or_null(^"/root/SimClock")
	if autoload == null:
		return null
	if autoload is SIMCLOCK_SCRIPT:
		return autoload as SimClockAutoload
	return null

func is_clock_subscribed() -> bool:
	return _subscribed

func set_clock_subscription(enabled: bool) -> void:
	if enabled:
		_subscribe_clock()
	else:
		_unsubscribe_clock()
