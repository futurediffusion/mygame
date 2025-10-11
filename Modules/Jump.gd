extends ModuleBase
class_name JumpModule

@export var jump_speed: float = 6.8
@export var coyote_time: float = 0.12
@export var max_hold_time: float = 0.15
@export_range(0.0, 1.0, 0.01) var hold_gravity_scale: float = 0.45
@export_range(0.0, 1.0, 0.01) var release_velocity_scale: float = 0.35

var player: CharacterBody3D
var anim_tree: AnimationTree
var camera_rig: Node

var _owner_body: CharacterBody3D
var _state: StateModule
var _input: InputBuffer
var _combo: PerfectJumpCombo

const PARAM_JUMP: StringName = &"parameters/Jump/request"

var _jumping: bool = false
var _hold_timer_s: float = 0.0
var _last_on_floor_time_s: float = -1.0
var _last_jump_time_s: float = -1.0
var _air_time: float = 0.0
var _last_jump_velocity: float = 0.0

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
	_last_on_floor_time_s = Time.get_ticks_msec() * 0.001 if _owner_body.is_on_floor() else -1.0
	if _state == null and owner_body.has_node("Modules/State"):
		_state = owner_body.get_node("Modules/State") as StateModule
	elif _state == null and owner_body.has_node("State"):
		_state = owner_body.get_node("State") as StateModule
	_combo = _get_combo()

func physics_tick(dt: float) -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	if _owner_body.has_method("should_skip_module_updates") and _owner_body.should_skip_module_updates():
		_jumping = false
		_hold_timer_s = 0.0
		return
	var now_s := Time.get_ticks_msec() * 0.001
	var on_floor := _owner_body.is_on_floor()
	if on_floor:
		_last_on_floor_time_s = now_s
		_air_time = 0.0
	else:
		_air_time += dt
	var last_floor_time := _get_last_on_floor_time()
	var still_holding := false
	if _input != null:
		still_holding = _input.jump_is_held
	else:
		still_holding = Input.is_action_pressed("jump")
	var buffered_jump := _input != null and _input.is_jump_buffered(now_s)
	var wants_jump := buffered_jump
	if _input == null and Input.is_action_just_pressed("jump"):
		wants_jump = true
	if wants_jump and _can_jump(on_floor, now_s, last_floor_time):
		_do_jump(now_s)
		if buffered_jump:
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

func _can_jump(on_floor: bool, now_s: float, last_floor_time: float) -> bool:
	if on_floor:
		return true
	return last_floor_time >= 0.0 and (now_s - last_floor_time) <= coyote_time

func _get_last_on_floor_time() -> float:
	if _state != null and is_instance_valid(_state):
		return _state.last_on_floor_time_s
	return _last_on_floor_time_s

func _do_jump(now_s: float) -> void:
	var final_speed := jump_speed
	var combo := _get_combo()
	if combo != null:
		final_speed *= combo.jump_multiplier()
	_owner_body.floor_snap_length = 0.0
	_owner_body.velocity.y = max(_owner_body.velocity.y, final_speed)
	_jumping = true
	_hold_timer_s = 0.0
	_last_jump_velocity = final_speed
	_last_jump_time_s = now_s
	_last_on_floor_time_s = -1.0
	_air_time = 0.0
	if _state != null and is_instance_valid(_state):
		_state.jumped.emit()
	_trigger_jump_animation()
	_play_jump_audio()
	if camera_rig != null and is_instance_valid(camera_rig) and camera_rig.has_method("_play_jump_kick"):
		camera_rig.call_deferred("_play_jump_kick")
	if combo != null and combo.is_in_perfect_window():
		combo.register_perfect()

func _get_combo() -> PerfectJumpCombo:
	if _combo != null and is_instance_valid(_combo):
		return _combo
	if player != null and is_instance_valid(player):
		_combo = player.get_node_or_null("PerfectJumpCombo") as PerfectJumpCombo
	return _combo

func _trigger_jump_animation() -> void:
	if anim_tree != null:
		anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _play_jump_audio() -> void:
	if player == null or not is_instance_valid(player):
		return
	if "m_audio" in player and is_instance_valid(player.m_audio):
		player.m_audio.play_jump()
	elif "jump_sfx" in player and is_instance_valid(player.jump_sfx):
		player.jump_sfx.play()
