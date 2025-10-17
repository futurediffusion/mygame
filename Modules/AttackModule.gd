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
var already_hit: Dictionary = {}
var cooldown_until: float = 0.0

var _queued_next_step: int = 0
var _buffer_time_remaining: float = 0.0
var _move_lock_remaining: float = 0.0
var _window_open_emitted: bool = false
var _window_close_emitted: bool = false
var _current_step_data: Dictionary = {}

var _punch_request_params: Dictionary = {}
var _punch_active_params: Dictionary = {}
var _dodge_active_params: Array[StringName] = []

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
		return
	if is_attacking and _is_any_param_true(tree, _dodge_active_params):
		_abort_current_attack()
		return
	if not is_attacking:
		return
	var data := _current_step_data
	if data.is_empty():
		_abort_current_attack()
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
	if not _window_open_emitted and time_in_step >= window_open:
		_window_open_emitted = true
		hit_active = true
		already_hit.clear()
		attack_window_opened.emit(combo_step)
		if buffered_attack and combo_step < STEP_PUNCH3:
			_queue_next_step(combo_step + 1)
			buffered_attack = false
			_buffer_time_remaining = 0.0
	var combo_window_close := window_open + combo_window
	var window_should_close := time_in_step >= window_close
	if window_should_close and hit_active:
		hit_active = false
		if not _window_close_emitted:
			_window_close_emitted = true
			attack_window_closed.emit(combo_step)
	if not window_should_close and time_in_step > combo_window_close and buffered_attack:
		buffered_attack = false
		_buffer_time_remaining = 0.0
	var duration := float(data.get("duration", 0.0))
	if time_in_step >= duration:
		_end_or_continue_combo()

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

func on_attack_overlap(target_id, hit_info) -> void:
	if not hit_active:
		return
	if already_hit.has(target_id):
		return
	var data := _current_step_data
	if data.is_empty():
		return
	already_hit[target_id] = true
	var payload := {
		"step": combo_step,
		"damage": data.get("damage", 0),
		"impulse": data.get("impulse", Vector3.ZERO),
		"tag": data.get("tag", &""),
		"hit_info": hit_info,
	}
	attack_hit.emit(combo_step, target_id, payload)

func get_move_lock_remaining() -> float:
	return maxf(_move_lock_remaining, 0.0)

func is_move_locked() -> bool:
	return _move_lock_remaining > 0.0

func reset_state() -> void:
	_abort_current_attack()
	cooldown_until = 0.0

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
	already_hit.clear()
	buffered_attack = false
	_buffer_time_remaining = 0.0
	_move_lock_remaining = float(data.get("lock_move", 0.0))
	_window_open_emitted = false
	_window_close_emitted = false
	_current_step_data = data
	_queued_next_step = 0
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
		if not _window_close_emitted:
			_window_close_emitted = true
			attack_window_closed.emit(last_step)
	if _queued_next_step != 0:
		_start_combo_step(_queued_next_step)
		return
	if last_step == STEP_PUNCH3:
		cooldown_until = _get_time_seconds() + COMBO_COOLDOWN
	_abort_current_attack()

func _abort_current_attack() -> void:
	var last_step := combo_step
	if last_step != 0:
		_cancel_animation_step(last_step)
	is_attacking = false
	combo_step = 0
	time_in_step = 0.0
	buffered_attack = false
	hit_active = false
	already_hit.clear()
	_queued_next_step = 0
	_buffer_time_remaining = 0.0
	_move_lock_remaining = 0.0
	_window_open_emitted = false
	_window_close_emitted = false
	_current_step_data = {}
	if last_step != 0:
		attack_finished.emit(last_step)

func _cancel_animation_step(step: int) -> void:
	var tree := _animation_tree
	if tree == null or not is_instance_valid(tree):
		return
	var faded := false
	var request_params: Array = _punch_request_params.get(step, [])
	for param in request_params:
		tree.set(param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		faded = true
	if faded:
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
