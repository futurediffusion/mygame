extends Node
class_name SimClock

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
@export var fixed_dt_global: float = 1.0

var _accum_local: float = 0.0
var _accum_regional: float = 0.0
var _accum_global: float = 0.0

func _ready() -> void:
	_ensure_group_defaults()

func _process(delta: float) -> void:
	_accum_local += delta
	_accum_regional += delta
	_accum_global += delta

	while _accum_local >= fixed_dt_local:
		_tick_group(GROUP_LOCAL, fixed_dt_local)
		_accum_local -= fixed_dt_local
	while _accum_regional >= fixed_dt_regional:
		_tick_group(GROUP_REGIONAL, fixed_dt_regional)
		_accum_regional -= fixed_dt_regional
	while _accum_global >= fixed_dt_global:
		_tick_group(GROUP_GLOBAL, fixed_dt_global)
		_accum_global -= fixed_dt_global

func register_module(mod: Node, group: StringName, priority: int) -> void:
	for key in _groups.keys():
		var existing: Array = _groups[key]
		_groups[key] = existing.filter(func(entry): return entry.mod != mod)
	_ensure_group_entry(group)
	var list: Array = _groups[group]
	list.append({ "mod": mod, "prio": priority })
	list.sort_custom(Callable(self, "_cmp_prio"))
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
			"interval": _get_group_interval(group)
		}
	return result

func _cmp_prio(a: Dictionary, b: Dictionary) -> bool:
	var prio_a: int = int(a.prio)
	var prio_b: int = int(b.prio)
	if prio_a == prio_b:
		var node_a: Node = a.mod if a.has("mod") else null
		var node_b: Node = b.mod if b.has("mod") else null
		var path_a := ""
		var path_b := ""
		if node_a != null and is_instance_valid(node_a):
			path_a = String(node_a.get_path())
		if node_b != null and is_instance_valid(node_b):
			path_b = String(node_b.get_path())
		return path_a < path_b
	return prio_a < prio_b

func _on_mod_exited(group: StringName, mod: Node) -> void:
	if not _groups.has(group):
		return
	var list: Array = _groups[group]
	list = list.filter(func(it): return it.mod != mod)
	_groups[group] = list

func _tick_group(group: StringName, dt: float) -> void:
	if _group_paused.get(group, false):
		return
	if not _groups.has(group):
		return
	var list: Array = _groups[group]
	for entry in list.duplicate():
		var m: Node = entry.mod
		if is_instance_valid(m) and m.is_inside_tree():
			if m.has_method("_on_clock_tick"):
				m._on_clock_tick(group, dt)
	_tick_counters[group] = int(_tick_counters.get(group, 0)) + 1
	_tick_sim_time[group] = float(_tick_sim_time.get(group, 0.0)) + dt
	emit_signal("ticked", group, dt)

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

