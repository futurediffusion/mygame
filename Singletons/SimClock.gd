extends Node
class_name SimClockScheduler

# Intervalos configurables (segundos simulados por tick de cada grupo)
@export_range(0.01, 5.0, 0.01) var local_interval: float = 0.0167 # ~60 FPS sim local
@export_range(0.05, 2.0, 0.01) var regional_interval: float = 0.25
@export_range(0.5, 300.0, 0.5) var global_interval: float = 5.0

const _GROUP_NAMES := ["local", "regional", "global"]

var _acc: Dictionary[String, float] = {
	"local": 0.0,
	"regional": 0.0,
	"global": 0.0
}
var _paused: bool = false

# Registro por grupo: cada entrada debe tener método physics_tick(dt)
var _registry: Dictionary[String, Array] = {
	"local": [],
	"regional": [],
	"global": []
}

var _group_paused: Dictionary[String, bool] = {
	"local": false,
	"regional": false,
	"global": false
}

var _module_paused: Dictionary[Object, bool] = {}

signal ticked(group_name: String, dt: float)

func set_paused(p: bool) -> void:
	_paused = p

func register(node: Object, group_name: Variant) -> void:
        var normalized := _normalize_group_name(group_name)
        if normalized == "" or not _registry.has(normalized):
                push_error("Tick group inválido: %s" % group_name)
                return
        if node in _registry[normalized]:
                return
        _registry[normalized].append(node)

func unregister(node: Object, group_name: Variant) -> void:
        var normalized := _normalize_group_name(group_name)
        if normalized == "" or not _registry.has(normalized):
                return
        _registry[normalized].erase(node)
        _module_paused.erase(node)

func set_group_interval(group_name: Variant, seconds: float) -> void:
        var value: float = maxf(seconds, 0.0)
        match _normalize_group_name(group_name):
                "local":
                        local_interval = value
                "regional":
			regional_interval = value
		"global":
			global_interval = value

func get_group_interval(group_name: Variant) -> float:
        match _normalize_group_name(group_name):
                "local":
                        return local_interval
                "regional":
                        return regional_interval
                "global":
                        return global_interval
        return 0.0

func set_group_paused(group_name: Variant, paused: bool) -> void:
        var normalized := _normalize_group_name(group_name)
        if normalized != "" and _group_paused.has(normalized):
                _group_paused[normalized] = paused

func set_module_paused(node: Object, paused: bool) -> void:
	if node == null or not is_instance_valid(node):
		_module_paused.erase(node)
		return
	_module_paused[node] = paused

func reset_module(node: Object) -> void:
	_module_paused.erase(node)

func reset_group(group_name: Variant) -> void:
        var normalized := _normalize_group_name(group_name)
        if normalized != "" and _group_paused.has(normalized):
                _group_paused[normalized] = false

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
        var list: Array = _registry[group_name]
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
        if module == null or not is_instance_valid(module):
                return "local"
        if module.has_method("get_tick_group_name"):
                var named := _normalize_group_name(module.call("get_tick_group_name"))
                if named != "":
                        return named
        if module.has_method("get"):
                var group: Variant = module.get("tick_group")
                var normalized := _normalize_group_name(group)
                if normalized != "":
                        return normalized
        return "local"

func _normalize_group_name(group: Variant) -> String:
        match typeof(group):
                TYPE_STRING, TYPE_STRING_NAME:
                        return String(group)
                TYPE_INT:
                        if typeof(ModuleBase) != TYPE_NIL:
                                return ModuleBase.tick_group_name_for(group)
                        var idx := int(group)
                        if idx >= 0 and idx < _GROUP_NAMES.size():
                                return _GROUP_NAMES[idx]
        return ""
