extends ModuleBase
class_name JumpModule

@export var jump_velocity: float = 6.5
@export var coyote_time: float = 0.120
@export var jump_hold_time: float = 0.150
@export var extra_hold_gravity_scale: float = 0.6
@export var uses_state_gravity: bool = true

var player: CharacterBody3D
var anim_tree: AnimationTree
var camera_rig: Node

const PARAM_JUMP: StringName = &"parameters/Jump/request"

var _time_since_left_floor: float = 9999.0
var _air_time: float = 0.0
var _jump_held: bool = false
var _hold_timer: float = 0.0
var _was_on_floor: bool = true
var _state_module: Node
var _combo: PerfectJumpCombo

func setup(p: CharacterBody3D) -> void:
	player = p
	_was_on_floor = player.is_on_floor()
	if _was_on_floor:
		_time_since_left_floor = 9999.0
	else:
		_time_since_left_floor = 0.0
	if "jump_velocity" in player:
		jump_velocity = player.jump_velocity
	if "coyote_time" in player:
		coyote_time = player.coyote_time
	if "anim_tree" in player:
		anim_tree = player.anim_tree
	if "camera_rig" in player:
		camera_rig = player.camera_rig
	_state_module = _locate_state_module()

func physics_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("should_skip_module_updates") and player.should_skip_module_updates():
		return

	var on_floor: bool = player.is_on_floor()
	if on_floor:
		if not _was_on_floor:
			on_landed()
		_air_time = 0.0
		_time_since_left_floor = 9999.0
	else:
		if _was_on_floor:
			on_left_ground()
		_time_since_left_floor += delta
		_air_time += delta
	_was_on_floor = on_floor

	var now: float = Time.get_unix_time_from_system()
	var want_jump: bool = false
	var ib: InputBuffer = _get_input_buffer()
	if ib:
		want_jump = ib.consume_jump(now)
	else:
		want_jump = Input.is_action_just_pressed("jump")

	var can_jump: bool = on_floor or (_time_since_left_floor <= coyote_time)
	if want_jump and can_jump:
		_perform_jump()
		_jump_held = true
		_hold_timer = 0.0

	if _jump_held:
		_hold_timer += delta
		var still_pressed: bool = Input.is_action_pressed("jump")
		if ib:
			still_pressed = ib.is_jump_down()
		if (_hold_timer >= jump_hold_time) or (not still_pressed):
			_jump_held = false

func on_left_ground() -> void:
	_time_since_left_floor = 0.0

func on_landed() -> void:
	_time_since_left_floor = 9999.0
	_hold_timer = 0.0
	_jump_held = false
	_air_time = 0.0

func is_hold_active() -> bool:
	return _jump_held

func get_air_time() -> float:
	return _air_time

func _perform_jump() -> void:
	player.floor_snap_length = 0.0
	var final_jump_velocity: float = jump_velocity
	var combo: PerfectJumpCombo = _get_combo()
	if combo:
		final_jump_velocity *= combo.jump_multiplier()
	player.velocity.y = max(player.velocity.y, final_jump_velocity)
	_air_time = 0.0
	_was_on_floor = false
	_time_since_left_floor = 0.0
	_trigger_jump_animation()
	_play_jump_audio()
	_notify_state_jump()
	if camera_rig and camera_rig.has_method("_play_jump_kick"):
		camera_rig.call_deferred("_play_jump_kick")
	if combo and combo.is_in_perfect_window():
		combo.register_perfect()

func _get_input_buffer() -> InputBuffer:
	if player and "input_buffer" in player:
		var ib: InputBuffer = player.input_buffer as InputBuffer
		if ib is InputBuffer:
			return ib
	return null

func _get_combo() -> PerfectJumpCombo:
	if player == null or not is_instance_valid(player):
		return null
	if _combo and is_instance_valid(_combo):
		return _combo
	_combo = player.get_node_or_null("PerfectJumpCombo") as PerfectJumpCombo
	return _combo

func _trigger_jump_animation() -> void:
	if anim_tree:
		anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _play_jump_audio() -> void:
	if "m_audio" in player and is_instance_valid(player.m_audio):
		player.m_audio.play_jump()
	elif "jump_sfx" in player and is_instance_valid(player.jump_sfx):
		player.jump_sfx.play()

func _notify_state_jump() -> void:
	if _state_module == null or not is_instance_valid(_state_module):
		_state_module = _locate_state_module()
	if _state_module and _state_module.has_signal("jumped"):
		_state_module.emit_signal("jumped")

func _locate_state_module() -> Node:
	if player == null or not is_instance_valid(player):
		return null
	if player.has_node("Modules/State"):
		return player.get_node("Modules/State")
	if player.has_node("State"):
		return player.get_node("State")
	return null
