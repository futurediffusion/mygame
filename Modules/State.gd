extends ModuleBase
class_name StateModule

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var fall_gravity_scale: float = 1.6
@export var floor_max_angle: float = 0.785398
@export var floor_snap_length: float = 0.3
@export_range(0.0, 2.0, 0.05) var floor_snap_length_sneak: float = 0.18

signal jumped
signal left_ground
signal landed(is_hard: bool)

var _owner_body: CharacterBody3D
var _was_on_floor: bool = false
var last_on_floor_time_s: float = -1.0
var _pre_move_velocity_y: float = 0.0
var _default_floor_snap_length: float = 0.3
var _current_floor_snap_length: float = 0.3

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
	_default_floor_snap_length = floor_snap_length
	_current_floor_snap_length = floor_snap_length
	if floor_snap_length_sneak <= 0.0:
		floor_snap_length_sneak = maxf(_default_floor_snap_length * 0.6, 0.0)
	_owner_body.floor_max_angle = floor_max_angle
	_apply_floor_snap_length(_default_floor_snap_length)
	if owner_body.has_signal("context_state_changed"):
		if not owner_body.context_state_changed.is_connected(_on_owner_context_state_changed):
			owner_body.context_state_changed.connect(_on_owner_context_state_changed)

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
		var is_hard := impact_velocity > GameConstants.HARD_LANDING_V
		landed.emit(is_hard)
	_was_on_floor = on_floor

func emit_jumped() -> void:
	jumped.emit()

func configure_floor_snap_lengths(standing_len: float, sneak_len: float) -> void:
	_default_floor_snap_length = maxf(standing_len, 0.0)
	floor_snap_length = _default_floor_snap_length
	floor_snap_length_sneak = maxf(sneak_len, 0.0)
	_apply_floor_snap_length(_default_floor_snap_length)

func _apply_floor_snap_length(length: float) -> void:
	_current_floor_snap_length = maxf(length, 0.0)
	if _owner_body != null and is_instance_valid(_owner_body):
		_owner_body.floor_snap_length = _current_floor_snap_length

func set_active_floor_snap_length(length: float) -> void:
	_apply_floor_snap_length(length)

func _on_owner_context_state_changed(new_state: int, _previous_state: int) -> void:
	var target := _default_floor_snap_length
	var context_enum: Dictionary = {}
	if _owner_body != null and is_instance_valid(_owner_body):
		var ctx_enum: Variant = _owner_body.get("ContextState")
		if ctx_enum is Dictionary:
			context_enum = ctx_enum
	var sneak_state: int = int(context_enum.get("SNEAK", 1))
	if int(new_state) == int(sneak_state):
		target = floor_snap_length_sneak
	_apply_floor_snap_length(target)
