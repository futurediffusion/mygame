extends ModuleBase
class_name AllyFSMModule

@export var owner_ally: NodePath

var _ally_cached: Node
var _runtime_enabled := false

func _ready() -> void:
	# R3→R4 MIGRATION: Forzar tick group del Ally desde Flags.
	tick_group = Flags.ALLY_TICK_GROUP
	if not Flags.USE_SIMCLOCK_ALLY:
		_runtime_enabled = false
		set_process(false)
		set_physics_process(false)
		if Engine.is_editor_hint():
			print_verbose("R3→R4 MIGRATION: AllyFSMModule en fallback (_physics_process)")
		return
	_runtime_enabled = true
	super._ready()
	if Engine.is_editor_hint():
		print_verbose("R3→R4 MIGRATION: AllyFSMModule registrado en %s" % tick_group)

func physics_tick(dt: float) -> void:
	# R3→R4 MIGRATION: Delegar tick al Ally dueño.
	var ally := _resolve_ally()
	if ally == null:
		return
	ally._ally_physics_update(dt)

func set_runtime_enabled(is_enabled: bool) -> void:
	# R3→R4 MIGRATION: Controlar registro dinámico según disponibilidad del clock.
	var sim_clock := _sim_clock_ref if _sim_clock_ref != null else _fetch_sim_clock()
	if not Flags.USE_SIMCLOCK_ALLY:
		if _is_registered and sim_clock != null:
			sim_clock.unregister(self)
		if Engine.is_editor_hint():
			print_verbose("R3→R4 MIGRATION: AllyFSMModule deshabilitado (flag global)")
		_is_registered = false
		_sim_clock_ref = null
		_runtime_enabled = false
		set_process(false)
		set_physics_process(false)
		return
	if is_enabled:
		_runtime_enabled = true
		_register_self()
		if Engine.is_editor_hint():
			print_verbose("R3→R4 MIGRATION: AllyFSMModule habilitado (%s)" % tick_group)
	else:
		_runtime_enabled = false
		if _is_registered and sim_clock != null:
			sim_clock.unregister(self)
		if Engine.is_editor_hint():
			print_verbose("R3→R4 MIGRATION: AllyFSMModule deshabilitado (fallback)")
		_is_registered = false
		_sim_clock_ref = null

func _resolve_ally() -> Node:
	# R3→R4 MIGRATION: Determinar el Ally asociado al módulo.
	if _ally_cached != null and is_instance_valid(_ally_cached):
		return _ally_cached
	var node: Node = null
	if owner_ally != NodePath():
		node = get_node_or_null(owner_ally)
	if node == null:
		node = get_parent()
	if node != null and node.has_method("_ally_physics_update"):
		_ally_cached = node
	else:
		_ally_cached = null
	return _ally_cached
