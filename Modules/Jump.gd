extends ModuleBase
class_name JumpModule

signal jump_performed(impulse: float)

@export var jump_speed: float = GameConstants.DEFAULT_JUMP_SPEED
@export var coyote_time: float = GameConstants.DEFAULT_COYOTE_TIME_S
@export var max_hold_time: float = GameConstants.DEFAULT_JUMP_HOLD_MAX_S
@export_range(0.0, 1.0, 0.01) var hold_gravity_scale: float = GameConstants.DEFAULT_HOLD_GRAVITY_SCALE
@export_range(0.0, 1.0, 0.01) var release_velocity_scale: float = GameConstants.DEFAULT_RELEASE_VELOCITY_SCALE

var player: CharacterBody3D
var anim_tree: AnimationTree
var camera_rig: Node
var capabilities: Capabilities

var _owner_body: CharacterBody3D
var _state: StateModule
var _input: InputBuffer
const PARAM_JUMP: StringName = &"parameters/Jump/request"

var _jumping: bool = false
var _hold_timer_s: float = 0.0
var _last_on_floor_time_s: float = -1.0
var _last_jump_time_s: float = -1.0
var _air_time: float = 0.0
var _last_jump_velocity: float = 0.0
var _floor_snap_to_restore: float = 0.0
var _restore_snap_pending: bool = false
var _manual_jump_triggered: bool = false
var _manual_jump_request_time_s: float = -1.0
var _manual_jump_buffer_time: float = 0.2

func _ready() -> void:
	pass

func setup(owner_body: CharacterBody3D, state: StateModule = null, input: InputBuffer = null) -> void:
	player = owner_body
	_owner_body = owner_body
	_state = state
	_input = input
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	if "jump_velocity" in owner_body:
		jump_speed = owner_body.jump_velocity
	if "coyote_time" in owner_body:
		coyote_time = owner_body.coyote_time
	if "anim_tree" in owner_body:
		anim_tree = owner_body.anim_tree
	if "camera_rig" in owner_body:
		camera_rig = owner_body.camera_rig
	if "capabilities" in owner_body:
		var caps_variant: Variant = owner_body.get("capabilities")
		if caps_variant is Capabilities:
			capabilities = caps_variant
	if "jump_buffer" in owner_body:
		var buffer_variant: Variant = owner_body.get("jump_buffer")
		if buffer_variant is float or buffer_variant is int:
			_manual_jump_buffer_time = maxf(float(buffer_variant), 0.0)
	_last_on_floor_time_s = Time.get_ticks_msec() * 0.001 if _owner_body.is_on_floor() else -1.0
	if _state == null and owner_body.has_node("Modules/State"):
		_state = owner_body.get_node("Modules/State") as StateModule
	elif _state == null and owner_body.has_node("State"):
		_state = owner_body.get_node("State") as StateModule
	_cache_floor_snap_target()

func physics_tick(dt: float) -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	if _owner_body.has_method("should_skip_module_updates") and _owner_body.should_skip_module_updates():
		_restore_floor_snap_if_needed()
		_jumping = false
		_hold_timer_s = 0.0
		return
	var now_s := Time.get_ticks_msec() * 0.001
	var on_floor := _owner_body.is_on_floor()
	if on_floor:
		_last_on_floor_time_s = now_s
		_air_time = 0.0
		_restore_floor_snap_if_needed()
	else:
		_air_time += dt
	var last_floor_time := _get_last_on_floor_time()
	var still_holding := false
	if _input != null:
		still_holding = _input.jump_is_held
	else:
		still_holding = Input.is_action_pressed("jump")
	var buffered_jump := false
	if _input != null:
		buffered_jump = _input.is_jump_buffered(now_s)
	var manual_request_active := false
	if _manual_jump_triggered:
		if _manual_jump_request_time_s < 0.0 or (now_s - _manual_jump_request_time_s) <= _manual_jump_buffer_time:
			manual_request_active = true
		else:
			_manual_jump_triggered = false
	var wants_jump := manual_request_active
	if not wants_jump:
		if _input != null:
			wants_jump = buffered_jump
		else:
			wants_jump = Input.is_action_just_pressed("jump")
	if wants_jump and _can_jump(on_floor, now_s, last_floor_time):
		_do_jump(now_s)
		if manual_request_active:
			_manual_jump_triggered = false
		elif buffered_jump and _input != null:
			_input.consume_jump_buffer()
	if _jumping:
		if still_holding and _hold_timer_s < max_hold_time and _owner_body.velocity.y > 0.0:
			var hold_scale := clampf(hold_gravity_scale, 0.0, 1.0)
			var base_gravity := _state.gravity if _state != null and is_instance_valid(_state) else float(ProjectSettings.get_setting("physics/3d/default_gravity"))
			var reduction := base_gravity * (1.0 - hold_scale)
			_owner_body.velocity.y -= reduction * dt
			_hold_timer_s += dt
		else:
			if not still_holding and _hold_timer_s < max_hold_time and _owner_body.velocity.y > 0.0:
				var release_scale := clampf(release_velocity_scale, 0.0, 1.0)
				if release_scale < 1.0:
					var base_jump_speed := _last_jump_velocity if _last_jump_velocity > 0.0 else jump_speed
					var capped_velocity := base_jump_speed * release_scale
					if release_scale <= 0.0:
						capped_velocity = 0.0
					if _owner_body.velocity.y > capped_velocity:
						_owner_body.velocity.y = capped_velocity
			_jumping = false

func get_air_time() -> float:
	return _air_time

func request_jump() -> bool:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return false
	if capabilities != null and not capabilities.can_jump:
		return false
	if _owner_body.has_method("should_skip_module_updates") and _owner_body.should_skip_module_updates():
		return false
	_manual_jump_triggered = true
	_manual_jump_request_time_s = Time.get_ticks_msec() * 0.001
	return true

func _can_jump(on_floor: bool, now_s: float, last_floor_time: float) -> bool:
	if capabilities != null and not capabilities.can_jump:
		return false
	if on_floor:
		return true
	return last_floor_time >= 0.0 and (now_s - last_floor_time) <= coyote_time

func _get_last_on_floor_time() -> float:
	if _state != null and is_instance_valid(_state):
		return _state.last_on_floor_time_s
	return _last_on_floor_time_s

func _do_jump(now_s: float) -> void:
	var final_speed := jump_speed
	_cache_floor_snap_target()
	_owner_body.floor_snap_length = 0.0
	if "snap_len" in _owner_body:
		_owner_body.snap_len = 0.0
	_restore_snap_pending = true
	_owner_body.velocity.y = max(_owner_body.velocity.y, final_speed)
	_jumping = true
	_hold_timer_s = 0.0
	_last_jump_velocity = final_speed
	_last_jump_time_s = now_s
	_last_on_floor_time_s = -1.0
	_air_time = 0.0
	if _state != null and is_instance_valid(_state):
		_state.emit_jumped()
	_trigger_jump_animation()
	_play_jump_audio()
	if camera_rig != null and is_instance_valid(camera_rig) and camera_rig.has_method("_play_jump_kick"):
		camera_rig.call_deferred("_play_jump_kick")
	jump_performed.emit(final_speed)

func _trigger_jump_animation() -> void:
	if not _tree_has_param(PARAM_JUMP):
		return
	anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _tree_has_param(param: StringName) -> bool:
	if anim_tree == null:
		return false
	if anim_tree.has_method("get_property_list"):
		for prop in anim_tree.get_property_list():
			if prop is Dictionary and prop.has("name") and String(prop["name"]) == String(param):
				return true
	return false

func _play_jump_audio() -> void:
	if player == null or not is_instance_valid(player):
		return
	if "m_audio" in player and is_instance_valid(player.m_audio):
		player.m_audio.play_jump()
	elif "jump_sfx" in player and is_instance_valid(player.jump_sfx):
		player.jump_sfx.play()

func _cache_floor_snap_target() -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		_floor_snap_to_restore = 0.0
		return
	if _state != null and is_instance_valid(_state):
		_floor_snap_to_restore = maxf(_state.floor_snap_length, 0.0)
	elif "snap_len" in _owner_body:
		_floor_snap_to_restore = maxf(float(_owner_body.snap_len), 0.0)
	else:
		_floor_snap_to_restore = maxf(_owner_body.floor_snap_length, 0.0)

func _restore_floor_snap_if_needed() -> void:
	if not _restore_snap_pending:
		return
	if _owner_body == null or not is_instance_valid(_owner_body):
		_restore_snap_pending = false
		return
	if not _owner_body.is_on_floor():
		return
	var target := maxf(_floor_snap_to_restore, 0.0)
	if _state != null and is_instance_valid(_state):
		_state.set_floor_snap_length(target)
	else:
		_owner_body.floor_snap_length = target
		if "snap_len" in _owner_body:
			_owner_body.snap_len = target
	_restore_snap_pending = false
