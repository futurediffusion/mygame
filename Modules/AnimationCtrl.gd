extends ModuleBase
class_name AnimationCtrlModule

var player: CharacterBody3D
var anim_tree: AnimationTree
var anim_player: AnimationPlayer

@export var animation_tree_path: NodePath  # <-- AÑADE ESTA LÍNEA
@export var state_module_path: NodePath   

# Paths dentro del AnimationTree
const PARAM_LOC: StringName = &"parameters/Locomotion/blend_position"
const PARAM_AIRBLEND: StringName = &"parameters/AirBlend/blend_amount"
const PARAM_FALLANIM: StringName = &"parameters/FallAnim/animation"
const PARAM_SPRINTSCL: StringName = &"parameters/SprintScale/scale"
const PARAM_SM_PLAYBACK: StringName = &"parameters/StateMachine/playback"

# Parámetros expuestos
@export var fall_speed_threshold: float = -1.5
@export var min_air_time_to_fall: float = 0.10

# Copiados del Player para mantener fidelidad
var walk_speed := 2.5
var run_speed := 6.0
var sprint_speed := 9.5
var sprint_anim_speed_scale := 1.15
var sprint_blend_bias := 0.85
var fall_clip_name: StringName = &"fall air loop"

# Estado interno
var _is_sprinting := false
var _airborne := false
var _has_jumped := false
var _fall_triggered := false
var _time_in_air := 0.0

var _state_machine: AnimationNodeStateMachinePlayback

func setup(p: CharacterBody3D) -> void:
	player = p
	anim_tree = p.anim_tree
	anim_player = p.anim_player

	if "walk_speed" in p:
		walk_speed = p.walk_speed
	if "run_speed" in p:
		run_speed = p.run_speed
	if "sprint_speed" in p:
		sprint_speed = p.sprint_speed
	if "sprint_anim_speed_scale" in p:
		sprint_anim_speed_scale = p.sprint_anim_speed_scale
	if "sprint_blend_bias" in p:
		sprint_blend_bias = p.sprint_blend_bias

	if "fall_clip_name" in p:
		fall_clip_name = p.fall_clip_name

	if anim_tree:
		if animation_tree_path == NodePath():
			animation_tree_path = anim_tree.get_path()
		anim_tree.anim_player = anim_player.get_path()
		anim_tree.active = true
		if _tree_has_param(PARAM_FALLANIM):
			anim_tree.set(PARAM_FALLANIM, fall_clip_name)
		if _tree_has_param(PARAM_LOC):
			anim_tree.set(PARAM_LOC, 0.0)
		_set_air_blend(0.0)
		_set_sprint_scale(1.0)
		_cache_state_machine()

	_connect_state_signals()

func set_frame_anim_inputs(is_sprinting: bool, _air_time: float) -> void:
	_is_sprinting = is_sprinting

func physics_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("should_skip_module_updates") and player.should_skip_module_updates():
		return
	if player.has_method("should_block_animation_update") and player.should_block_animation_update():
		return

	var is_on_floor := player.is_on_floor()
	if not is_on_floor:
		_handle_airborne(delta)
	else:
		_handle_grounded()

func _handle_airborne(delta: float) -> void:
	if not _airborne:
		_airborne = true
		_time_in_air = 0.0
		_fall_triggered = false
		if not _has_jumped:
			_travel_to_state("Jump")
		_set_locomotion_blend(0.0)
		_set_sprint_scale(1.0)

	_time_in_air += delta

	var vel_y := player.velocity.y
	var should_trigger_fall := _time_in_air >= min_air_time_to_fall or vel_y <= fall_speed_threshold
	if should_trigger_fall and not _fall_triggered:
		_travel_to_state("Fall")
		_fall_triggered = true

	_set_air_blend(1.0 if _fall_triggered else 0.0)


func _handle_grounded() -> void:
	if _airborne:
		_airborne = false
		_time_in_air = 0.0
		_fall_triggered = false
		_has_jumped = false
		if _state_machine and _state_machine.get_current_node() in ["Fall", "Jump"]:
			if _has_state("Land"):
				_travel_to_state("Land")
			else:
				_travel_to_state("Locomotion")

	var blend := _calculate_locomotion_blend()
	_set_locomotion_blend(blend)
	_apply_sprint_scale(blend)
	_set_air_blend(0.0)

func _calculate_locomotion_blend() -> float:
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var target_max := sprint_speed if _is_sprinting else run_speed
	if target_max <= 0.0:
		return 0.0

	var blend := 0.0
	if hspeed <= walk_speed:
		blend = remap(hspeed, 0.0, walk_speed, 0.0, 0.4)
	else:
		blend = remap(hspeed, walk_speed, target_max, 0.4, 1.0)

	if _is_sprinting:
		blend = pow(clampf(blend, 0.0, 1.0), sprint_blend_bias)

	return clampf(blend, 0.0, 1.0)

func _apply_sprint_scale(blend: float) -> void:
	var scale := 1.0
	if _is_sprinting:
		scale = lerp(1.0, sprint_anim_speed_scale, blend)
	_set_sprint_scale(scale)

func _set_locomotion_blend(value: float) -> void:
	if _tree_has_param(PARAM_LOC):
		anim_tree.set(PARAM_LOC, clampf(value, 0.0, 1.0))

func _set_air_blend(value: float) -> void:
	if _tree_has_param(PARAM_AIRBLEND):
		anim_tree.set(PARAM_AIRBLEND, clampf(value, 0.0, 1.0))

func _set_sprint_scale(value: float) -> void:
	if _tree_has_param(PARAM_SPRINTSCL):
		anim_tree.set(PARAM_SPRINTSCL, value)

func _cache_state_machine() -> void:
	# Garantiza que tengamos referencia válida al AnimationTree.
	if anim_tree == null:
		push_warning("AnimationTree no asignado; revisa que el módulo se configure en setup().")
		return
	if animation_tree_path == NodePath():
		animation_tree_path = anim_tree.get_path()

	# Recupera el playback con cast explícito
	var playback := anim_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		push_warning("No se encontró 'parameters/StateMachine/playback' en el AnimationTree. Revisa el nodo StateMachine y su path.")
		return

	_state_machine = playback
	_travel_to_state("Locomotion")

func _connect_state_signals() -> void:
	if player == null:
		return

	var state_mod: Node = null

	# 1) si hay ruta exportada, úsala
	if state_module_path != NodePath():
		state_mod = get_node_or_null(state_module_path)

	# 2) fallback: buscar por convención en la jerarquía del player
	if state_mod == null and player.has_node("Modules/State"):
		state_mod = player.get_node("Modules/State")
	elif state_mod == null and player.has_node("State"):
		state_mod = player.get_node("State")

	if state_mod == null:
		return

	# Conexiones seguras (evita duplicados)
	if state_mod.has_signal("landed"):
		if not state_mod.landed.is_connected(_on_landed):
			state_mod.landed.connect(_on_landed)
	if state_mod.has_signal("jumped"):
		if not state_mod.jumped.is_connected(_on_jumped):
			state_mod.jumped.connect(_on_jumped)
	if state_mod.has_signal("left_ground"):
		if not state_mod.left_ground.is_connected(_on_left_ground):
			state_mod.left_ground.connect(_on_left_ground)


func _on_jumped() -> void:
	_has_jumped = true
	_airborne = true
	_time_in_air = 0.0
	_fall_triggered = false
	_set_locomotion_blend(0.0)
	_set_air_blend(0.0)
	_set_sprint_scale(1.0)
	_travel_to_state("Jump")

func _on_left_ground() -> void:
	if _has_jumped:
		return
	_airborne = true
	_time_in_air = 0.0
	_fall_triggered = false
	_set_locomotion_blend(0.0)
	_set_air_blend(0.0)
	_set_sprint_scale(1.0)
	_travel_to_state("Jump")

func _on_landed(_is_hard: bool) -> void:
	_airborne = false
	_has_jumped = false
	_time_in_air = 0.0
	_fall_triggered = false
	_set_air_blend(0.0)
	if _has_state("Land"):
		_travel_to_state("Land")
	else:
		_travel_to_state("Locomotion")

func _travel_to_state(state_name: String) -> void:
	if _state_machine == null:
		return
	if state_name.is_empty():
		return
	_state_machine.travel(state_name)

func _tree_has_param(param: StringName) -> bool:
	if anim_tree == null:
		return false
	
	# Verificar si el parámetro existe intentando leerlo
	var param_list: Array = []
	if anim_tree.has_method("get_property_list"):
		param_list = anim_tree.get_property_list()
		for prop in param_list:
			if prop is Dictionary and prop.has("name"):
				if String(prop["name"]) == String(param):
					return true
	
	# Fallback: intentar acceder directamente
	var value = anim_tree.get(param)
	return value != null

func _has_state(state_name: String) -> bool:
	if anim_tree == null:
		return false
	var param_path := StringName("parameters/StateMachine/nodes/%s/position" % state_name)
	return _tree_has_param(param_path)
