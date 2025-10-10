extends Node
class_name SimClockService

const DEFAULT_GROUP: StringName = "local"
const MAX_TICKS_PER_FRAME := 8

var group_intervals: Dictionary = {
	"global": 1.0,
	"regional": 0.1,
	"local": 1.0 / 60.0,
}

var _group_paused: Dictionary = {}
var _module_accumulators: Dictionary = {}
var _module_paused: Dictionary = {}

func process_module_tick(module: Object, delta: float) -> void:
	if module == null:
		return
	if not is_instance_valid(module):
		_module_accumulators.erase(module)
		_module_paused.erase(module)
		return
	if not module.has_method("physics_tick"):
		return
	if _module_paused.get(module, false):
		return
	var group: StringName = _resolve_group(module)
	if _group_paused.get(group, false):
		return
	var interval := _resolve_interval(group)
	if interval <= 0.0:
		module.physics_tick(delta)
		return
	var accumulator: float = _module_accumulators.get(module, 0.0) + delta
	var ticks := 0
	while accumulator >= interval and ticks < MAX_TICKS_PER_FRAME:
		module.physics_tick(interval)
		accumulator -= interval
		ticks += 1
	if ticks == MAX_TICKS_PER_FRAME and accumulator >= interval:
		accumulator = fmod(accumulator, interval)
	_module_accumulators[module] = accumulator

func set_group_interval(group: StringName, seconds: float) -> void:
	group_intervals[group] = max(0.0, seconds)

func get_group_interval(group: StringName) -> float:
	return _resolve_interval(group)

func set_group_paused(group: StringName, paused: bool, reset_accumulators := false) -> void:
	_group_paused[group] = paused
	if paused and reset_accumulators:
		for module in _module_accumulators.keys():
			if _resolve_group(module) == group:
				_module_accumulators[module] = 0.0

func set_module_paused(module: Object, paused: bool, reset_accumulator := true) -> void:
	if module == null or not is_instance_valid(module):
		return
	_module_paused[module] = paused
	if paused and reset_accumulator:
		_module_accumulators[module] = 0.0

func reset_module(module: Object) -> void:
	_module_accumulators.erase(module)
	_module_paused.erase(module)

func reset_group(group: StringName) -> void:
	for module in _module_accumulators.keys():
		if _resolve_group(module) == group:
			_module_accumulators[module] = 0.0

func _resolve_group(module: Object) -> StringName:
	var group: Variant = module.get("tick_group")
	if typeof(group) == TYPE_STRING_NAME or typeof(group) == TYPE_STRING:
		return StringName(group)
	return DEFAULT_GROUP

func _resolve_interval(group: StringName) -> float:
	if group_intervals.has(group):
		return float(group_intervals[group])
	return float(group_intervals.get(DEFAULT_GROUP, 0.0))
