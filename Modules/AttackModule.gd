extends ModuleBase
class_name AttackModule

const ACTION_ATTACK_PRIMARY := &"attack_primary"
const ACTION_ATTACK_FALLBACK := &"attack"
const PARAM_PUNCH_REQUESTS := [
	&"parameters/LocomotionSpeed/Punch1/request",
	&"parameters/Punch1/request",
]
const PARAM_PUNCH_ACTIVE_FLAGS := [
	&"parameters/LocomotionSpeed/Punch1/active",
	&"parameters/Punch1/active",
]
const PARAM_DODGE_ACTIVE_FLAGS := [
	&"parameters/LocomotionSpeed/Dodge/active",
	&"parameters/Dodge/active",
]

var _animation_tree: AnimationTree
var animation_tree: AnimationTree:
	set(value):
		if _animation_tree == value:
			return
		_animation_tree = value
		_refresh_parameter_cache()
	get:
		return _animation_tree

var _punch_request_params: Array[StringName] = []
var _punch_active_params: Array[StringName] = []
var _dodge_active_params: Array[StringName] = []

# TODO: Combo system
# - Detectar segundo click durante Punch1
# - Lanzar Punch2 si está dentro de la ventana de tiempo

func _ready() -> void:
	super._ready()
	set_process_input(true)
	set_clock_subscription(false)
	_refresh_parameter_cache()

func _input(event: InputEvent) -> void:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	if not _is_attack_event(event):
		return
	if puede_atacar():
		reproducir_golpe()

func puede_atacar() -> bool:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return false
	if _is_any_param_true(tree, _dodge_active_params):
		return false
	if _is_any_param_true(tree, _punch_active_params):
		return false
	return true

func reproducir_golpe() -> void:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	var fired := false
	for param in _punch_request_params:
		tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		fired = true
	if fired:
		return
	for param in _punch_active_params:
		tree.set(param, true)

func _is_attack_event(event: InputEvent) -> bool:
	if event.is_action_pressed(ACTION_ATTACK_PRIMARY) and not event.is_echo():
		return true
	if InputMap.has_action(ACTION_ATTACK_FALLBACK) and event.is_action_pressed(ACTION_ATTACK_FALLBACK) and not event.is_echo():
		return true
	return false

func _refresh_parameter_cache() -> void:
	_punch_request_params.clear()
	_punch_active_params.clear()
	_dodge_active_params.clear()
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	for path in PARAM_PUNCH_REQUESTS:
		if tree.has_parameter(path):
			_punch_request_params.append(path)
	for path in PARAM_PUNCH_ACTIVE_FLAGS:
		if tree.has_parameter(path):
			_punch_active_params.append(path)
	for path in PARAM_DODGE_ACTIVE_FLAGS:
		if tree.has_parameter(path):
			_dodge_active_params.append(path)

func _is_any_param_true(tree: AnimationTree, params: Array[StringName]) -> bool:
	for param in params:
		var value: Variant = tree.get(param)
		if value is bool and value:
			return true
		if value == true:
			return true
	return false
