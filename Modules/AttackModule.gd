extends ModuleBase
class_name AttackModule

signal attack_started(step: int)
signal attack_window_opened(step: int)
signal attack_window_closed(step: int)
signal attack_hit(step: int, target_id, hit_data: Dictionary)
signal attack_finished(step: int)

const ACTION_ATTACK_PRIMARY := &"attack_primary"
const ACTION_ATTACK_FALLBACK := &"attack"
const BUFFER_WINDOW := 0.20
const COMBO_COOLDOWN := 0.25
const STEP_PUNCH1 := 1
const STEP_PUNCH2 := 2
const STEP_PUNCH3 := 3

const STEP_ORDER := [STEP_PUNCH1, STEP_PUNCH2, STEP_PUNCH3]

const ATTACK_ID_TO_STEP := {
	"P1": STEP_PUNCH1,
	"P2": STEP_PUNCH2,
	"P3": STEP_PUNCH3,
}

const STEP_TO_ATTACK_ID := {
	STEP_PUNCH1: StringName("P1"),
	STEP_PUNCH2: StringName("P2"),
	STEP_PUNCH3: StringName("P3"),
}

const HAND_RIGHT := StringName("right")
const HAND_LEFT := StringName("left")

const ATTACK_TO_HITBOX := {
	StringName("P1"): {
		"hand_bone": StringName("mixamorig_RightHand"),
		"forearm_bone": StringName("mixamorig_RightForeArm"),
		"hitbox": HAND_RIGHT,
	},
	StringName("P2"): {
		"hand_bone": StringName("mixamorig_LeftHand"),
		"forearm_bone": StringName("mixamorig_LeftForeArm"),
		"hitbox": HAND_LEFT,
	},
	StringName("P3"): {
		"hand_bone": StringName("mixamorig_RightHand"),
		"forearm_bone": StringName("mixamorig_RightForeArm"),
		"hitbox": HAND_RIGHT,
	},
}

const STEP_DATA := {
	STEP_PUNCH1: {
		"duration": 0.42,
		"window_open": 0.18,
		"window_close": 0.32,
		"combo_window": 0.35,
		"lock_move": 0.10,
		"damage": 10,
		"impulse": Vector3(2.5, 1.2, 0.0),
		"tag": &"punch1",
	},
	STEP_PUNCH2: {
		"duration": 0.46,
		"window_open": 0.17,
		"window_close": 0.31,
		"combo_window": 0.36,
		"lock_move": 0.12,
		"damage": 13,
		"impulse": Vector3(2.8, 1.3, 0.0),
		"tag": &"punch2",
	},
	STEP_PUNCH3: {
		"duration": 0.52,
		"window_open": 0.22,
		"window_close": 0.40,
		"combo_window": 0.40,
		"lock_move": 0.14,
		"damage": 18,
		"impulse": Vector3(3.2, 1.6, 0.0),
		"tag": &"punch3",
	},
}

const STEP_REQUEST_PATHS := {
	STEP_PUNCH1: [
		&"parameters/LocomotionSpeed/Punch1/request",
		&"parameters/Punch1/request",
	],
	STEP_PUNCH2: [
		&"parameters/LocomotionSpeed/Punch2/request",
		&"parameters/Punch2/request",
	],
	STEP_PUNCH3: [
		&"parameters/LocomotionSpeed/Punch3/request",
		&"parameters/Punch3/request",
	],
}

const STEP_ACTIVE_PATHS := {
	STEP_PUNCH1: [
		&"parameters/LocomotionSpeed/Punch1/active",
		&"parameters/Punch1/active",
	],
	STEP_PUNCH2: [
		&"parameters/LocomotionSpeed/Punch2/active",
		&"parameters/Punch2/active",
	],
	STEP_PUNCH3: [
		&"parameters/LocomotionSpeed/Punch3/active",
		&"parameters/Punch3/active",
	],
}

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

var is_attacking: bool = false
var combo_step: int = 0
var time_in_step: float = 0.0
var buffered_attack: bool = false
var hit_active: bool = false
var current_attack_id: StringName = StringName()
var already_hit: Dictionary = {}
var cooldown_until: float = 0.0

var _queued_next_step: int = 0
var _buffer_time_remaining: float = 0.0
var _move_lock_remaining: float = 0.0
var _window_open_emitted: bool = false
var _window_close_emitted: bool = false
var _current_step_data: Dictionary = {}
var _manual_window_control: bool = false

var _punch_request_params: Dictionary = {}
var _punch_active_params: Dictionary = {}
var _dodge_active_params: Array[StringName] = []

@export var skeleton_path: NodePath = NodePath("../../Pivot/Model/Armature/Skeleton3D")
@export var right_hand_hitbox_path: NodePath = NodePath("../../Hitboxes/RightHandHitbox")
@export var left_hand_hitbox_path: NodePath = NodePath("../../Hitboxes/LeftHandHitbox")
@export_range(0.0, 1.0, 0.01) var hitbox_forward_offset: float = 0.1

var _skeleton: Skeleton3D
var _right_hand_hitbox: Node3D
var _left_hand_hitbox: Node3D
var _active_hitbox: Node3D
var _active_hand_bone: StringName = StringName()
var _active_forearm_bone: StringName = StringName()
var _active_hitbox_id: StringName = StringName()
var _active_hitbox_key: StringName = StringName()
var _should_track_hitbox: bool = false
var _bone_index_cache: Dictionary = {}

func _ready() -> void:
	super._ready()
	set_process_input(true)
	set_clock_subscription(false)
	_refresh_parameter_cache()
	_resolve_hitbox_dependencies()

func _input(event: InputEvent) -> void:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	if not _is_attack_event(event):
		return
	if not is_attacking:
		if puede_atacar():
			_start_combo_step(STEP_PUNCH1)
	else:
		_queue_or_buffer_next()

func physics_tick(dt: float) -> void:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		if is_attacking:
			_abort_current_attack()
		_update_active_hitbox()
		return
	if is_attacking and _is_any_param_true(tree, _dodge_active_params):
		_abort_current_attack()
		_update_active_hitbox()
		return
	if not is_attacking:
		_update_active_hitbox()
		return
	var data := _current_step_data
	if data.is_empty():
		_abort_current_attack()
		_update_active_hitbox()
		return
	time_in_step += dt
	if _move_lock_remaining > 0.0:
		_move_lock_remaining = maxf(_move_lock_remaining - dt, 0.0)
	if buffered_attack:
		_buffer_time_remaining = maxf(_buffer_time_remaining - dt, 0.0)
		if _buffer_time_remaining <= 0.0:
			buffered_attack = false
	var window_open := float(data.get("window_open", 0.0))
	var window_close := float(data.get("window_close", 0.0))
	var combo_window := float(data.get("combo_window", 0.0))
	if not _manual_window_control and not _window_open_emitted and time_in_step >= window_open:
		_window_open_emitted = true
		current_attack_id = STEP_TO_ATTACK_ID.get(combo_step, StringName())
		hit_active = true
		already_hit.clear()
		_on_hit_window_opened(current_attack_id)
		attack_window_opened.emit(combo_step)
		if buffered_attack and combo_step < STEP_PUNCH3:
			_queue_next_step(combo_step + 1)
			buffered_attack = false
			_buffer_time_remaining = 0.0
	var combo_window_close := window_open + combo_window
	var window_should_close := time_in_step >= window_close
	if not _manual_window_control and window_should_close and hit_active:
		hit_active = false
		_on_hit_window_closed()
		if not _window_close_emitted:
			_window_close_emitted = true
			attack_window_closed.emit(combo_step)
	if not window_should_close and time_in_step > combo_window_close and buffered_attack:
		buffered_attack = false
		_buffer_time_remaining = 0.0
	var duration := float(data.get("duration", 0.0))
	if time_in_step >= duration:
		_end_or_continue_combo()
	_update_active_hitbox()

func puede_atacar() -> bool:
	if is_attacking:
		return false
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return false
	if _is_any_param_true(tree, _dodge_active_params):
		return false
	if _get_time_seconds() < cooldown_until:
		return false
	return true

func on_attack_overlap(target_id, hit_point: Vector3, hit_normal: Vector3) -> void:
	if not hit_active:
		return
	if already_hit.has(target_id):
		return
	var data := _get_active_attack_data()
	if data.is_empty():
		return
	already_hit[target_id] = true
	var step_id := _get_step_from_attack_id(current_attack_id)
	if step_id == 0:
		step_id = combo_step
	var payload := {
		"step": step_id,
		"damage": data.get("damage", 0),
		"impulse": data.get("impulse", Vector3.ZERO),
		"tag": data.get("tag", &""),
		"hit_point": hit_point,
		"hit_normal": hit_normal,
	}
	attack_hit.emit(step_id, target_id, payload)

func attack_start_hit(attack_id: Variant) -> void:
	if not is_attacking:
		return
	var normalized_id := _normalize_attack_id(attack_id)
	if normalized_id == StringName():
		return
	var step := _get_step_from_attack_id(normalized_id)
	if step == 0 or step != combo_step:
		return
	current_attack_id = normalized_id
	_manual_window_control = true
	hit_active = true
	already_hit.clear()
	_on_hit_window_opened(current_attack_id)
	if not _window_open_emitted:
		_window_open_emitted = true
		attack_window_opened.emit(combo_step)


func attack_end_hit(attack_id: Variant) -> void:
	if not is_attacking:
		return
	var normalized_id := _normalize_attack_id(attack_id)
	if normalized_id == StringName():
		return
	if current_attack_id != normalized_id:
		return
	hit_active = false
	_on_hit_window_closed()
	already_hit.clear()
	current_attack_id = StringName()
	if not _window_close_emitted:
		_window_close_emitted = true
		attack_window_closed.emit(combo_step)


func get_move_lock_remaining() -> float:
	return maxf(_move_lock_remaining, 0.0)

func is_move_locked() -> bool:
	return _move_lock_remaining > 0.0

func reset_state() -> void:
	_abort_current_attack()
	cooldown_until = 0.0

func _resolve_hitbox_dependencies() -> void:
	_skeleton = null
	_right_hand_hitbox = null
	_left_hand_hitbox = null
	_active_hitbox = null
	_active_hand_bone = StringName()
	_active_forearm_bone = StringName()
	_active_hitbox_id = StringName()
	_active_hitbox_key = StringName()
	_should_track_hitbox = false
	_bone_index_cache.clear()
	_ensure_skeleton()
	_ensure_hitbox_nodes()

func _queue_or_buffer_next() -> void:
	if combo_step >= STEP_PUNCH3:
		return
	var data := _current_step_data
	if data.is_empty():
		return
	var window_open := float(data.get("window_open", 0.0))
	var combo_window := float(data.get("combo_window", 0.0))
	var combo_window_close := window_open + combo_window
	if time_in_step >= window_open and time_in_step <= combo_window_close:
		_queue_next_step(combo_step + 1)
	elif time_in_step < window_open:
		buffered_attack = true
		_buffer_time_remaining = BUFFER_WINDOW

func _queue_next_step(step: int) -> void:
	if _queued_next_step != 0:
		return
	if step > STEP_PUNCH3:
		return
	_queued_next_step = step
	buffered_attack = false
	_buffer_time_remaining = 0.0

func _start_combo_step(step: int) -> void:
	var data: Dictionary = STEP_DATA.get(step, {})
	if data.is_empty():
		return
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	is_attacking = true
	combo_step = step
	time_in_step = 0.0
	hit_active = false
	_deactivate_active_hitbox()
	current_attack_id = STEP_TO_ATTACK_ID.get(step, StringName())
	already_hit.clear()
	buffered_attack = false
	_buffer_time_remaining = 0.0
	_move_lock_remaining = float(data.get("lock_move", 0.0))
	_window_open_emitted = false
	_window_close_emitted = false
	_current_step_data = data
	_queued_next_step = 0
	_manual_window_control = false
	_fire_step(step)
	attack_started.emit(step)

func _fire_step(step: int) -> void:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	var fired := false
	var request_params: Array = _punch_request_params.get(step, [])
	for param in request_params:
		tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		fired = true
	if not fired:
		var active_params: Array = _punch_active_params.get(step, [])
		for param in active_params:
			tree.set(param, true)

func _end_or_continue_combo() -> void:
	var last_step := combo_step
	if hit_active:
		hit_active = false
		_on_hit_window_closed()
		if not _window_close_emitted:
			_window_close_emitted = true
			attack_window_closed.emit(last_step)
	if _queued_next_step != 0:
		_start_combo_step(_queued_next_step)
		return
	if last_step == STEP_PUNCH3:
		cooldown_until = _get_time_seconds() + COMBO_COOLDOWN
	_finish_current_attack(false)

func _abort_current_attack() -> void:
	_finish_current_attack(true)

func _finish_current_attack(cancel_animation: bool) -> void:
	var last_step := combo_step
	if hit_active:
		hit_active = false
		_on_hit_window_closed()
		if last_step != 0 and not _window_close_emitted:
			_window_close_emitted = true
			attack_window_closed.emit(last_step)
	if last_step != 0:
		_cancel_animation_step(last_step, cancel_animation)
	is_attacking = false
	combo_step = 0
	time_in_step = 0.0
	buffered_attack = false
	hit_active = false
	current_attack_id = StringName()
	already_hit.clear()
	_queued_next_step = 0
	_buffer_time_remaining = 0.0
	_move_lock_remaining = 0.0
	_window_open_emitted = false
	_window_close_emitted = false
	_current_step_data = {}
	_manual_window_control = false
	if last_step != 0:
		attack_finished.emit(last_step)

func _get_step_from_attack_id(attack_id: StringName) -> int:
	if attack_id == StringName():
		return 0
	return ATTACK_ID_TO_STEP.get(String(attack_id), 0)

func _normalize_attack_id(attack_id: Variant) -> StringName:
	if attack_id is StringName:
		return attack_id
	if attack_id is String:
		return StringName(attack_id)
	return StringName()

func _get_active_attack_data() -> Dictionary:
	var step := _get_step_from_attack_id(current_attack_id)
	if step == 0:
		step = combo_step
	if step == 0:
		return {}
	return STEP_DATA.get(step, {})

func _cancel_animation_step(step: int, request_fade_out: bool = true) -> void:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	var faded := false
	var request_params: Array = _punch_request_params.get(step, [])
	if request_fade_out:
		for param in request_params:
			tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
			faded = true
	if request_fade_out and faded:
		return
	var active_params: Array = _punch_active_params.get(step, [])
	for param in active_params:
		tree.set(param, false)

func _refresh_parameter_cache() -> void:
	_punch_request_params.clear()
	_punch_active_params.clear()
	_dodge_active_params.clear()
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	for step in STEP_ORDER:
		var request_params: Array[StringName] = []
		for path in STEP_REQUEST_PATHS.get(step, []):
			if _tree_has_param(tree, path):
				request_params.append(path)
		_punch_request_params[step] = request_params
		var active_params: Array[StringName] = []
		for path in STEP_ACTIVE_PATHS.get(step, []):
			if _tree_has_param(tree, path):
				active_params.append(path)
		_punch_active_params[step] = active_params
	for path in PARAM_DODGE_ACTIVE_FLAGS:
		if _tree_has_param(tree, path):
			_dodge_active_params.append(path)

func _tree_has_param(tree: AnimationTree, param: StringName) -> bool:
	if tree == null:
		return false
	if tree.has_method("has_parameter"):
		var has_param_variant: Variant = tree.call("has_parameter", param)
		if has_param_variant is bool:
			if has_param_variant:
				return true
		elif has_param_variant == true:
			return true
	if tree.has_method("get_property_list"):
		var property_list: Array = tree.get_property_list()
		var target_name := String(param)
		for prop in property_list:
			if prop is Dictionary and prop.has("name"):
				if String(prop["name"]) == target_name:
					return true
	return false

func _is_any_param_true(tree: AnimationTree, params: Array[StringName]) -> bool:
	for param in params:
		var value: Variant = tree.get(param)
		if value is bool and value:
			return true
		if value == true:
			return true
	return false

func _is_attack_event(event: InputEvent) -> bool:
	if event.is_action_pressed(ACTION_ATTACK_PRIMARY) and not event.is_echo():
		return true
	if InputMap.has_action(ACTION_ATTACK_FALLBACK) and event.is_action_pressed(ACTION_ATTACK_FALLBACK) and not event.is_echo():
		return true
	return false

func _get_time_seconds() -> float:
	return Time.get_ticks_msec() * 0.001

func _ensure_skeleton() -> Skeleton3D:
	if _skeleton != null and is_instance_valid(_skeleton):
		return _skeleton
	var previous := _skeleton
	_skeleton = null
	if skeleton_path == NodePath():
		return _skeleton
	var node := get_node_or_null(skeleton_path)
	if node is Skeleton3D:
		_skeleton = node
		if previous != _skeleton:
			_bone_index_cache.clear()
	return _skeleton

func _ensure_hitbox_nodes() -> void:
	if (_right_hand_hitbox == null or not is_instance_valid(_right_hand_hitbox)) and right_hand_hitbox_path != NodePath():
		var right_node := get_node_or_null(right_hand_hitbox_path)
		if right_node is Node3D:
			_right_hand_hitbox = right_node
	if (_left_hand_hitbox == null or not is_instance_valid(_left_hand_hitbox)) and left_hand_hitbox_path != NodePath():
		var left_node := get_node_or_null(left_hand_hitbox_path)
		if left_node is Node3D:
			_left_hand_hitbox = left_node

func _resolve_hitbox(hand: StringName) -> Node3D:
	_ensure_hitbox_nodes()
	if hand == HAND_RIGHT:
		if _right_hand_hitbox != null and is_instance_valid(_right_hand_hitbox):
			return _right_hand_hitbox
	elif hand == HAND_LEFT:
		if _left_hand_hitbox != null and is_instance_valid(_left_hand_hitbox):
			return _left_hand_hitbox
	return null

func _activate_hitbox_for_attack(attack_id: StringName) -> void:
	_active_hitbox_id = attack_id
	var config := ATTACK_TO_HITBOX.get(attack_id, null)
	if config == null:
		_clear_hitbox_tracking()
		return
	_active_hand_bone = config.get("hand_bone", StringName())
	_active_forearm_bone = config.get("forearm_bone", StringName())
	_active_hitbox_key = config.get("hitbox", StringName())
	_active_hitbox = _resolve_hitbox(_active_hitbox_key)
	_should_track_hitbox = _active_hitbox != null and is_instance_valid(_active_hitbox)

func _on_hit_window_opened(attack_id: StringName) -> void:
	_activate_hitbox_for_attack(attack_id)

func _on_hit_window_closed() -> void:
	_deactivate_active_hitbox()

func _deactivate_active_hitbox() -> void:
	if not _should_track_hitbox and (_active_hitbox == null or not is_instance_valid(_active_hitbox)):
		return
	_clear_hitbox_tracking()

func _clear_hitbox_tracking() -> void:
	_active_hitbox = null
	_active_hitbox_id = StringName()
	_active_hitbox_key = StringName()
	_active_hand_bone = StringName()
	_active_forearm_bone = StringName()
	_should_track_hitbox = false

func _get_bone_index(bone_name: StringName) -> int:
	if bone_name == StringName():
		return -1
	if _bone_index_cache.has(bone_name):
		return int(_bone_index_cache[bone_name])
	var skeleton := _ensure_skeleton()
	if skeleton == null:
		return -1
	var index := skeleton.find_bone(String(bone_name))
	_bone_index_cache[bone_name] = index
	return index

func _update_active_hitbox() -> void:
	if not hit_active:
		if _should_track_hitbox:
			_deactivate_active_hitbox()
		return
	if not _should_track_hitbox:
		_activate_hitbox_for_attack(current_attack_id)
		if not _should_track_hitbox:
			return
	var skeleton := _ensure_skeleton()
	if skeleton == null:
		return
	if _active_hitbox == null or not is_instance_valid(_active_hitbox):
		_active_hitbox = _resolve_hitbox(_active_hitbox_key)
		if _active_hitbox == null or not is_instance_valid(_active_hitbox):
			_should_track_hitbox = false
			return
	var hand_index := _get_bone_index(_active_hand_bone)
	if hand_index < 0:
		return
	var hand_pose := skeleton.get_bone_global_pose(hand_index)
	var direction := hand_pose.basis * Vector3.FORWARD
	var forearm_index := _get_bone_index(_active_forearm_bone)
	if forearm_index >= 0:
		var forearm_pose := skeleton.get_bone_global_pose(forearm_index)
		direction = hand_pose.origin - forearm_pose.origin
	if direction.length_squared() <= 0.000001:
		direction = hand_pose.basis * Vector3.FORWARD
	if direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var offset_position := hand_pose.origin + direction * hitbox_forward_offset
	_active_hitbox.global_position = offset_position
	var up_vector := hand_pose.basis.y
	if up_vector.length_squared() <= 0.000001:
		up_vector = Vector3.UP
	_active_hitbox.look_at(offset_position + direction, up_vector)
