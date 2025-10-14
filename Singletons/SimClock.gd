extends Node
class_name SimClockAutoload

const GROUP_LOCAL: StringName = &"local"
const GROUP_REGIONAL: StringName = &"regional"
const GROUP_GLOBAL: StringName = &"global"

signal ticked(group: StringName, dt: float)

var _groups: Dictionary = {}
var _group_paused: Dictionary = {}
var _tick_counters: Dictionary = {}
var _tick_sim_time: Dictionary = {}

@export var fixed_dt_local: float = 1.0 / 60.0
@export var fixed_dt_regional: float = 1.0 / 10.0
@export var fixed_dt_global: float = 1.0 / 2.0

var _accum: Dictionary = {
	GROUP_LOCAL: 0.0,
	GROUP_REGIONAL: 0.0,
	GROUP_GLOBAL: 0.0,
}

func _ready() -> void:
	_ensure_group_defaults()

func _physics_process(delta: float) -> void:
	_accum[GROUP_LOCAL] += delta
	_accum[GROUP_REGIONAL] += delta
	_accum[GROUP_GLOBAL] += delta

	_process_group(GROUP_LOCAL, fixed_dt_local)
	_process_group(GROUP_REGIONAL, fixed_dt_regional)
	_process_group(GROUP_GLOBAL, fixed_dt_global)

func _process_group(group: StringName, step: float) -> void:
	while _accum.get(group, 0.0) >= step:
		_tick_group(group, step)
		_accum[group] = float(_accum.get(group, 0.0) - step)

func register_module(mod: Node, group: StringName, priority: int) -> void:
	_ensure_group_entry(group)
	var list: Array = _groups[group]
	list.append({
		"mod": mod,
		"prio": priority,
	})
	list.sort_custom(Callable(self, "_compare_entries"))
	_groups[group] = list

	if not mod.is_connected("tree_exited", Callable(self, "_on_mod_exited")):
		mod.connect("tree_exited", Callable(self, "_on_mod_exited").bind(group, mod))

func pause_group(group: StringName, paused: bool) -> void:
	_group_paused[group] = paused

func set_group_paused(group: StringName, paused: bool) -> void:
	pause_group(group, paused)

func get_group_stats() -> Dictionary:
	var result: Dictionary = {}
	for group in [GROUP_LOCAL, GROUP_REGIONAL, GROUP_GLOBAL]:
		result[group] = {
			"tick_count": int(_tick_counters.get(group, 0)),
			"sim_time": float(_tick_sim_time.get(group, 0.0)),
			"interval": _get_group_interval(group),
		}
	return result

func get_group_tick_counter(group: StringName) -> int:
	_ensure_group_entry(group)
	return int(_tick_counters.get(group, 0))

func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("prio", 0)) < int(b.get("prio", 0))

func _on_mod_exited(group: StringName, mod: Node) -> void:
	if not _groups.has(group):
		return
	var list: Array = _groups[group]
	list = list.filter(func(entry): return entry.get("mod") != mod)
	_groups[group] = list

func _tick_group(group: StringName, dt: float) -> void:
	if _group_paused.get(group, false):
		return
	if not _groups.has(group):
		return
	var list: Array = _groups[group]
	var index := 0
	while index < list.size():
		var entry: Dictionary = list[index]
		var module: Node = entry.get("mod")
		if not is_instance_valid(module):
			list.remove_at(index)
			continue
		if module.is_inside_tree() and module.has_method("_on_clock_tick"):
			module._on_clock_tick(group, dt)
		index += 1
	_groups[group] = list
	_tick_counters[group] = int(_tick_counters.get(group, 0)) + 1
	_tick_sim_time[group] = float(_tick_sim_time.get(group, 0.0)) + dt
	ticked.emit(group, dt)

func _ensure_group_defaults() -> void:
	for group in [GROUP_LOCAL, GROUP_REGIONAL, GROUP_GLOBAL]:
		_ensure_group_entry(group)

func _ensure_group_entry(group: StringName) -> void:
	if not _groups.has(group):
		_groups[group] = []
	if not _group_paused.has(group):
		_group_paused[group] = false
	if not _tick_counters.has(group):
		_tick_counters[group] = 0
	if not _tick_sim_time.has(group):
		_tick_sim_time[group] = 0.0

func _get_group_interval(group: StringName) -> float:
	match group:
		GROUP_LOCAL:
			return fixed_dt_local
		GROUP_REGIONAL:
			return fixed_dt_regional
		GROUP_GLOBAL:
			return fixed_dt_global
	return fixed_dt_local
