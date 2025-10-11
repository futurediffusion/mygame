extends Node
class_name SimClockScheduler

# R3→R4 MIGRATION: Canonical tick groups shared across modules.
const GROUP_LOCAL: StringName = &"local"
const GROUP_REGIONAL: StringName = &"regional"
const GROUP_GLOBAL: StringName = &"global"

# Intervalos configurables (segundos simulados por tick de cada grupo)
@export_range(0.01, 5.0, 0.01) var local_interval: float = 0.0167 # ~60 FPS sim local
@export_range(0.05, 2.0, 0.01) var regional_interval: float = 0.25
@export_range(0.5, 300.0, 0.5) var global_interval: float = 5.0
@export var order_strategy: String = "path" # R3→R4 MIGRATION

var _acc: Dictionary = {
	GROUP_LOCAL: 0.0,
	GROUP_REGIONAL: 0.0,
	GROUP_GLOBAL: 0.0
}
var _paused: bool = false

# Registro por grupo: cada entrada debe tener método physics_tick(dt)
var _registry: Dictionary = {
	GROUP_LOCAL: [],
	GROUP_REGIONAL: [],
	GROUP_GLOBAL: []
}

var _group_paused: Dictionary = {
	GROUP_LOCAL: false,
	GROUP_REGIONAL: false,
	GROUP_GLOBAL: false
}

var _module_paused: Dictionary = {}
# R3→R4 MIGRATION: Lookup para asociaciones nodo-grupo.
var _node_groups: Dictionary = {}
var _module_priority: Dictionary = {} # R3→R4 MIGRATION
# R3→R4 MIGRATION: Telemetría de ticks por grupo.
var _tick_counters: Dictionary = {
	GROUP_LOCAL: 0,
	GROUP_REGIONAL: 0,
	GROUP_GLOBAL: 0
}
var _tick_sim_time: Dictionary = {
	GROUP_LOCAL: 0.0,
	GROUP_REGIONAL: 0.0,
	GROUP_GLOBAL: 0.0
}

signal ticked(group_name: StringName, dt: float)

func set_paused(p: bool) -> void:
	_paused = p

func register(node: Node, group_name: StringName) -> void:
	var module := node
	if module == null or not is_instance_valid(module):
		return
	var canonical_group := _normalize_group(group_name)
	if canonical_group == StringName():
		push_error("Tick group inválido: %s" % group_name)
		return
	var previous_group: StringName = _node_groups.get(module, StringName())
	if previous_group != StringName() and previous_group != canonical_group:
		if _registry.has(previous_group):
			_registry[previous_group].erase(module) # R3→R4 MIGRATION
	if module in _registry[canonical_group]:
		return
	_registry[canonical_group].append(module)
	_node_groups[module] = canonical_group
	if not _module_priority.has(module): # R3→R4 MIGRATION
		_module_priority[module] = 0
	if Engine.is_editor_hint():
		print_verbose("SimClock register %s -> %s" % [module, canonical_group]) # R3→R4 MIGRATION

func unregister(node: Node) -> void:
	var module := node
	if module == null:
		return
	var group_name: StringName = _node_groups.get(module, StringName())
	if group_name == StringName():
		return
	if _registry.has(group_name):
		_registry[group_name].erase(module) # R3→R4 MIGRATION
	_node_groups.erase(module)
	_module_paused.erase(module)
	_module_priority.erase(module) # R3→R4 MIGRATION
	if Engine.is_editor_hint():
		print_verbose("SimClock unregister %s" % module) # R3→R4 MIGRATION

func set_group_interval(group_name: StringName, seconds: float) -> void:
	var value: float = maxf(seconds, 0.0)
	match group_name:
		GROUP_LOCAL:
			local_interval = value
		GROUP_REGIONAL:
			regional_interval = value
		GROUP_GLOBAL:
			global_interval = value

func get_group_interval(group_name: StringName) -> float:
	match group_name:
		GROUP_LOCAL:
			return local_interval
		GROUP_REGIONAL:
			return regional_interval
		GROUP_GLOBAL:
			return global_interval
	return 0.0

# R3→R4 MIGRATION: Nuevo control de pausa por grupo.
func pause_group(group_name: StringName, paused: bool) -> void:
	var canonical_group := _normalize_group(group_name)
	if canonical_group == StringName():
		return
	_group_paused[canonical_group] = paused
	if Engine.is_editor_hint():
		print_verbose("SimClock pause_group %s -> %s" % [canonical_group, paused])

func set_group_paused(group_name: StringName, paused: bool) -> void:
	pause_group(group_name, paused)

func set_priority(node: Node, prio: int) -> void: # R3→R4 MIGRATION
	if node == null or not is_instance_valid(node):
		return
	_module_priority[node] = prio
	if Engine.is_editor_hint():
		print_verbose("SimClock set_priority %s -> %s" % [node, prio])

func set_module_paused(node: Object, paused: bool) -> void:
	if node == null or not is_instance_valid(node):
		_module_paused.erase(node)
		return
	_module_paused[node] = paused

func reset_module(node: Object) -> void:
	_module_paused.erase(node)

func reset_group(group_name: StringName) -> void:
	var canonical_group := _normalize_group(group_name)
	if canonical_group == StringName():
		return
	_group_paused[canonical_group] = false

func process_module_tick(module: Object, dt: float) -> void:
	if module == null or not is_instance_valid(module):
		return
	if _paused:
		return
	var group := _resolve_group(module)
	if _group_paused.get(group, false):
		return
	if _module_paused.get(module, false):
		return
	if module.has_method("physics_tick"):
		module.physics_tick(dt)

func _physics_process(delta: float) -> void:
	if _paused:
		return
	_acc[GROUP_LOCAL] += delta
	_acc[GROUP_REGIONAL] += delta
	_acc[GROUP_GLOBAL] += delta
	# Local
	while _acc[GROUP_LOCAL] >= local_interval and local_interval > 0.0:
		_tick_group(GROUP_LOCAL, local_interval)
		_acc[GROUP_LOCAL] -= local_interval
	# Regional
	while _acc[GROUP_REGIONAL] >= regional_interval and regional_interval > 0.0:
		_tick_group(GROUP_REGIONAL, regional_interval)
		_acc[GROUP_REGIONAL] -= regional_interval
	# Global
	while _acc[GROUP_GLOBAL] >= global_interval and global_interval > 0.0:
		_tick_group(GROUP_GLOBAL, global_interval)
		_acc[GROUP_GLOBAL] -= global_interval


func _tick_group(group_name: StringName, dt: float) -> void:
	if _group_paused.get(group_name, false):
		return
	if not _registry.has(group_name):
		return
	var ordered: Array = _get_ordered_modules(group_name) # R3→R4 MIGRATION
	for n in ordered:
		if _module_paused.get(n, false):
			continue
		if n.has_method("physics_tick"):
			n.physics_tick(dt)
	if _tick_counters.has(group_name):
		_tick_counters[group_name] = int(_tick_counters[group_name]) + 1 # R3→R4 MIGRATION
	if _tick_sim_time.has(group_name):
		_tick_sim_time[group_name] = float(_tick_sim_time[group_name]) + dt # R3→R4 MIGRATION
	emit_signal("ticked", group_name, dt)

func _resolve_group(module: Object) -> StringName:
	if _node_groups.has(module):
		return _node_groups[module]
	var group_variant: Variant = _safe_get(module, &"tick_group")
	var normalized := _normalize_variant_group(group_variant)
	if normalized != StringName():
		return normalized
	return GROUP_LOCAL

# R3→R4 MIGRATION: Helpers para normalizar acceso a propiedades dinámicas.
func _safe_get(module: Object, property_name: StringName) -> Variant:
	if module != null and is_instance_valid(module) and module.has_method("get"):
		return module.get(property_name)
	return null

func _normalize_variant_group(group_variant: Variant) -> StringName:
	if group_variant is StringName:
		return _normalize_group(group_variant)
	if group_variant is String:
		return _normalize_group(StringName(group_variant))
	return StringName()

func _normalize_group(group_name: StringName) -> StringName:
	for candidate in [GROUP_LOCAL, GROUP_REGIONAL, GROUP_GLOBAL]:
		if candidate == group_name or String(candidate) == String(group_name):
			return candidate
	return StringName()

# R3→R4 MIGRATION: Deterministic ordering helpers.
func _get_ordered_modules(group_name: StringName) -> Array:
	var cleaned: Array = []
	if not _registry.has(group_name):
		return cleaned
	for n in _registry[group_name].duplicate():
		if not is_instance_valid(n):
			_registry[group_name].erase(n)
			_module_paused.erase(n)
			_module_priority.erase(n)
			continue
		cleaned.append(n)
	match order_strategy:
		"priority":
			cleaned.sort_custom(Callable(self, "_compare_by_priority"))
		"path":
			cleaned.sort_custom(Callable(self, "_compare_by_path"))
		_:
			pass
	return cleaned

func _compare_by_path(a: Object, b: Object) -> bool:
	var path_a := String(_safe_node_path(a))
	var path_b := String(_safe_node_path(b))
	return path_a < path_b

func _compare_by_priority(a: Object, b: Object) -> bool:
	var priority_a: int = int(_module_priority.get(a, 0))
	var priority_b: int = int(_module_priority.get(b, 0))
	if priority_a == priority_b:
		return _compare_by_path(a, b)
	return priority_a < priority_b

func _safe_node_path(node: Object) -> NodePath:
	if node != null and is_instance_valid(node) and node is Node:
		return (node as Node).get_path()
	return NodePath()

# R3→R4 MIGRATION: Estadísticas públicas para herramientas.
func get_group_stats() -> Dictionary:
	var stats := {}
	for group in [GROUP_LOCAL, GROUP_REGIONAL, GROUP_GLOBAL]:
		stats[group] = {
			"tick_count": int(_tick_counters.get(group, 0)),
			"sim_time": float(_tick_sim_time.get(group, 0.0)),
			"interval": get_group_interval(group)
		}
	return stats

# R3→R4 MIGRATION: Salida rápida para consola de depuración.
func print_clock_stats() -> void:
	var stats := get_group_stats()
	for group in stats.keys():
		var data: Dictionary = stats[group]
		var tick_count: int = int(data.get("tick_count", 0))
		var sim_time: float = float(data.get("sim_time", 0.0))
		var ticks_per_second := 0.0
		if sim_time > 0.0:
			ticks_per_second = float(tick_count) / sim_time
		print("[SimClock] %s -> ticks: %d, sim_time: %.4f, ticks/s: %.2f" % [String(group), tick_count, sim_time, ticks_per_second])
