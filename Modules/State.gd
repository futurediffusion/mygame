extends ModuleBase
class_name StateModule

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var fall_gravity_scale: float = 1.6
@export var floor_max_angle: float = 0.785398
@export var floor_snap_length: float = 0.3

signal jumped
signal left_ground
signal landed(is_hard: bool)

var _owner_body: CharacterBody3D
var _was_on_floor: bool = false
var last_on_floor_time_s: float = -1.0
var _pre_move_velocity_y: float = 0.0

func setup(owner_body: CharacterBody3D) -> void:
	_owner_body = owner_body
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	_was_on_floor = _owner_body.is_on_floor()
	var now_s := Time.get_ticks_msec() * 0.001
	last_on_floor_time_s = now_s if _was_on_floor else -1.0
	if "gravity" in owner_body:
		gravity = owner_body.gravity
	if "fall_gravity_multiplier" in owner_body:
		fall_gravity_scale = max(owner_body.fall_gravity_multiplier, 1.0)
	if "max_slope_deg" in owner_body:
		floor_max_angle = deg_to_rad(owner_body.max_slope_deg)
	if "snap_len" in owner_body:
		floor_snap_length = owner_body.snap_len
	_owner_body.floor_max_angle = floor_max_angle
	_owner_body.floor_snap_length = floor_snap_length

func physics_tick(_dt: float) -> void:
	pass

func pre_move_update(dt: float) -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	if _owner_body.has_method("should_skip_module_updates") and _owner_body.should_skip_module_updates():
		return
	_pre_move_velocity_y = _owner_body.velocity.y
	if _owner_body.is_on_floor():
		if _owner_body.velocity.y < 0.0:
			_owner_body.velocity.y = 0.0
		return
	var fall_scale: float = maxf(fall_gravity_scale, 1.0)
	var base_gravity: float = gravity * dt
	if _owner_body.velocity.y <= 0.0:
		_owner_body.velocity.y -= base_gravity * fall_scale
	else:
		_owner_body.velocity.y -= base_gravity
		if _owner_body.velocity.y < 0.0 and fall_scale > 1.0:
			var extra_gravity: float = base_gravity * (fall_scale - 1.0)
			_owner_body.velocity.y -= extra_gravity

func post_move_update() -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	var now_s := Time.get_ticks_msec() * 0.001
	var on_floor := _owner_body.is_on_floor()
	if on_floor:
		last_on_floor_time_s = now_s
	if _was_on_floor and not on_floor:
		left_ground.emit()
	elif (not _was_on_floor) and on_floor:
		var impact_velocity := absf(_pre_move_velocity_y)
		var is_hard := impact_velocity > 10.0
		landed.emit(is_hard)
	_was_on_floor = on_floor

func emit_jumped() -> void:
	jumped.emit()
