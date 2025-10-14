extends Node
class_name SneakAnimController

@export var animation_tree: AnimationTree
@export var sneak_walk_max_speed: float = 1.8
@export var enter_blend_time: float = 0.25

var _sneaking := false
var _enter_tween: Tween

const PARAM_SNEAK_BLEND_PATHS: Array[StringName] = [
	StringName("parameters/SneakBlend/blend"),
	StringName("parameters/SneakBlend/blend_amount"),
	StringName("parameters/LocomotionSpeed/SneakBlend/blend"),
	StringName("parameters/LocomotionSpeed/SneakBlend/blend_amount"),
]
const PARAM_ENTER_HANDOFF_PATHS: Array[StringName] = [
	StringName("parameters/EnterHandoff/blend"),
	StringName("parameters/EnterHandoff/blend_amount"),
	StringName("parameters/LocomotionSpeed/EnterHandoff/blend"),
	StringName("parameters/LocomotionSpeed/EnterHandoff/blend_amount"),
]
const PARAM_SNEAK_ENTER_REQUEST_PATHS: Array[StringName] = [
	StringName("parameters/SneakEnter/request"),
	StringName("parameters/LocomotionSpeed/SneakEnter/request"),
]
const PARAM_SNEAK_EXIT_REQUEST_PATHS: Array[StringName] = [
	StringName("parameters/SneakExit/request"),
	StringName("parameters/LocomotionSpeed/SneakExit/request"),
]
const PARAM_SNEAK_IDLE_PATHS: Array[StringName] = [
	StringName("parameters/SneakIdleWalk/blend_position"),
	StringName("parameters/LocomotionSpeed/SneakIdleWalk/blend_position"),
]
const PARAM_SNEAK_IDLE_2_PATHS: Array[StringName] = [
	StringName("parameters/SneakIdleWalk2/blend_position"),
	StringName("parameters/LocomotionSpeed/SneakIdleWalk2/blend_position"),
]

func _ready() -> void:
	if animation_tree == null or not is_instance_valid(animation_tree):
		push_warning("AnimationTree no asignado en SneakAnimController.")
		return
	animation_tree.active = true
	_reset_parameters()

func toggle_sneak() -> void:
	set_sneak_enabled(not _sneaking)

func set_sneak_enabled(enable: bool) -> void:
	if _sneaking == enable:
		return
	if animation_tree == null or not is_instance_valid(animation_tree):
		_sneaking = enable
		return
	_sneaking = enable
	if enable:
		_set_param_list(PARAM_SNEAK_BLEND_PATHS, 1.0)
		_request_one_shot(PARAM_SNEAK_ENTER_REQUEST_PATHS)
		_set_param_list(PARAM_ENTER_HANDOFF_PATHS, 0.0)
		_start_enter_tween()
	else:
		_stop_enter_tween()
		_request_one_shot(PARAM_SNEAK_EXIT_REQUEST_PATHS)
		_set_param_list(PARAM_SNEAK_BLEND_PATHS, 0.0)
		_set_param_list(PARAM_ENTER_HANDOFF_PATHS, 0.0)

func update_sneak_speed(current_speed: float) -> void:
	if animation_tree == null or not is_instance_valid(animation_tree):
		return
	var ratio := 0.0
	if sneak_walk_max_speed > 0.0:
		ratio = clampf(current_speed / sneak_walk_max_speed, 0.0, 1.0)
	_set_param_list(PARAM_SNEAK_IDLE_PATHS, ratio)
	_set_param_list(PARAM_SNEAK_IDLE_2_PATHS, ratio)

func _reset_parameters() -> void:
	_set_param_list(PARAM_SNEAK_BLEND_PATHS, 0.0)
	_set_param_list(PARAM_ENTER_HANDOFF_PATHS, 0.0)
	_set_param_list(PARAM_SNEAK_IDLE_PATHS, 0.0)
	_set_param_list(PARAM_SNEAK_IDLE_2_PATHS, 0.0)

func _start_enter_tween() -> void:
	_stop_enter_tween()
	if enter_blend_time <= 0.0:
		_set_param_list(PARAM_ENTER_HANDOFF_PATHS, 1.0)
		return
	var has_target := false
	for path in PARAM_ENTER_HANDOFF_PATHS:
		if animation_tree.has_parameter(path):
			has_target = true
			break
	if not has_target:
		return
	_enter_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _enter_tween == null:
		return
	for path in PARAM_ENTER_HANDOFF_PATHS:
		if animation_tree.has_parameter(path):
			var property_path: NodePath = NodePath(String(path))
			_enter_tween.tween_property(animation_tree, property_path, 1.0, enter_blend_time)
	_enter_tween.finished.connect(_on_enter_tween_finished)

func _stop_enter_tween() -> void:
	if _enter_tween != null:
		if is_instance_valid(_enter_tween):
			_enter_tween.kill()
		_enter_tween = null

func _on_enter_tween_finished() -> void:
	_enter_tween = null

func _request_one_shot(paths: Array[StringName]) -> void:
	for path in paths:
		if animation_tree.has_parameter(path):
			animation_tree.set(path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _set_param_list(paths: Array[StringName], value: Variant) -> void:
	for path in paths:
		if animation_tree.has_parameter(path):
			animation_tree.set(path, value)
