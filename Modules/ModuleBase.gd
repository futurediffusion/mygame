extends Node
class_name ModuleBase

@export_enum("local", "regional", "global") var tick_group: String = "local"
var _is_registered := false
var _sim_clock_ref: SimClockScheduler

func _ready() -> void:
	call_deferred("_register_self")

func _register_self() -> void:
	if _is_registered or not is_inside_tree():
		return
	var sim_clock := _fetch_sim_clock()
	if sim_clock == null:
		return
	sim_clock.register(self, tick_group)
	_sim_clock_ref = sim_clock
	_is_registered = true

func _exit_tree() -> void:
	if not _is_registered:
		return
	var sim_clock := _sim_clock_ref if _sim_clock_ref != null else _fetch_sim_clock()
	if sim_clock != null:
		sim_clock.unregister(self, tick_group)
	_is_registered = false
	_sim_clock_ref = null

func physics_tick(_dt: float) -> void:
	pass

func _fetch_sim_clock() -> SimClockScheduler:
	if typeof(SimClock) != TYPE_NIL:
		return SimClock as SimClockScheduler
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_root().get_node_or_null(^"/root/SimClock") as SimClockScheduler
