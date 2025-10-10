extends Node
class_name SimClock

# Intervalos configurables (segundos simulados por tick de cada grupo)
@export_range(0.01, 5.0, 0.01) var local_interval: float = 0.0167 # ~60 FPS sim local
@export_range(0.05, 2.0, 0.01) var regional_interval: float = 0.25
@export_range(0.5, 300.0, 0.5) var global_interval: float = 5.0

var _acc := { "local": 0.0, "regional": 0.0, "global": 0.0 }
var _paused: bool = false

# Registro por grupo: cada entrada debe tener método physics_tick(dt)
var _registry := {
	"local": [],
	"regional": [],
	"global": []
}

var _group_paused := {
	"local": false,
	"regional": false,
	"global": false
}

var _module_paused: Dictionary = {}

signal ticked(group_name: String, dt: float)

func set_paused(p: bool) -> void:
	_paused = p

func register(node: Object, group_name: String) -> void:
	if not _registry.has(group_name):
		push_error("Tick group inválido: %s" % group_name)
		return
	if node in _registry[group_name]:
		return
	_registry[group_name].append(node)

func unregister(node: Object, group_name: String) -> void:
	if not _registry.has(group_name):
		return
	_registry[group_name].erase(node)
	_module_paused.erase(node)

func set_group_interval(group_name: StringName, seconds: float) -> void:
	var value := max(seconds, 0.0)
	match String(group_name):
		"local":
			local_interval = value
		"regional":
			regional_interval = value
		"global":
			global_interval = value

func get_group_interval(group_name: StringName) -> float:
	match String(group_name):
		"local":
			return local_interval
		"regional":
			return regional_interval
		"global":
			return global_interval
	return 0.0

func set_group_paused(group_name: StringName, paused: bool) -> void:
	if _group_paused.has(group_name):
		_group_paused[group_name] = paused

func set_module_paused(node: Object, paused: bool) -> void:
	if node == null or not is_instance_valid(node):
		_module_paused.erase(node)
		return
	_module_paused[node] = paused

func reset_module(node: Object) -> void:
	_module_paused.erase(node)

func reset_group(group_name: StringName) -> void:
	if _group_paused.has(group_name):
		_group_paused[group_name] = false

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
	_acc["local"] += delta
	_acc["regional"] += delta
	_acc["global"] += delta
	# Local
	while _acc["local"] >= local_interval and local_interval > 0.0:
		_tick_group("local", local_interval)
		_acc["local"] -= local_interval
	# Regional
	while _acc["regional"] >= regional_interval and regional_interval > 0.0:
		_tick_group("regional", regional_interval)
		_acc["regional"] -= regional_interval
	# Global
	while _acc["global"] >= global_interval and global_interval > 0.0:
		_tick_group("global", global_interval)
		_acc["global"] -= global_interval

func _tick_group(group_name: String, dt: float) -> void:
	if _group_paused.get(group_name, false):
		return
	var list := _registry[group_name]
	# Copia para evitar invalidación si alguien se desregistra en tick
	for n in list.duplicate():
		if not is_instance_valid(n):
			_registry[group_name].erase(n)
			_module_paused.erase(n)
			continue
		if _module_paused.get(n, false):
			continue
		if n.has_method("physics_tick"):
			n.physics_tick(dt)
	emit_signal("ticked", group_name, dt)

func _resolve_group(module: Object) -> String:
	var group: Variant = null
	if module != null and is_instance_valid(module) and module.has_method("get"):
		group = module.get("tick_group")
	if typeof(group) == TYPE_STRING:
		return group
	if typeof(group) == TYPE_STRING_NAME:
		return String(group)
	return "local"
