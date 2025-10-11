extends Node
class_name ModuleBase

enum TickGroup {
        LOCAL,
        REGIONAL,
        GLOBAL,
}

const _TICK_GROUP_NAMES := ["local", "regional", "global"]

var _tick_group: int = TickGroup.LOCAL
@export var tick_group: TickGroup = TickGroup.LOCAL:
        set(value):
                _tick_group = _coerce_tick_group(value)
        get:
                return _tick_group

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
        sim_clock.register(self, get_tick_group_name())
        _sim_clock_ref = sim_clock
        _is_registered = true

func _exit_tree() -> void:
	if not _is_registered:
		return
        var sim_clock := _sim_clock_ref if _sim_clock_ref != null else _fetch_sim_clock()
        if sim_clock != null:
                sim_clock.unregister(self, get_tick_group_name())
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

func get_tick_group_name() -> String:
        return _TICK_GROUP_NAMES[ModuleBase._clamp_index(_tick_group)]

static func tick_group_name_for(value: Variant) -> String:
        match typeof(value):
                TYPE_STRING, TYPE_STRING_NAME:
                        return String(value)
                TYPE_INT:
                        var idx := _clamp_index(int(value))
                        return _TICK_GROUP_NAMES[idx]
        return _TICK_GROUP_NAMES[TickGroup.LOCAL]

static func _coerce_tick_group(value: Variant) -> int:
        match typeof(value):
                TYPE_INT:
                        return _clamp_index(int(value))
                TYPE_STRING, TYPE_STRING_NAME:
                        var idx := _TICK_GROUP_NAMES.find(String(value))
                        if idx >= 0:
                                return idx
        return TickGroup.LOCAL

static func _clamp_index(idx: int) -> int:
        if idx < 0:
                return 0
        var max_index := _TICK_GROUP_NAMES.size() - 1
        if idx > max_index:
                return max_index
        return idx
