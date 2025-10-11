extends ModuleBase
class_name StateModule

@export var gravity: float = 24.0
@export var fall_multiplier: float = 1.0
@export var floor_snap_on_ground: float = 0.3
@export var floor_snap_in_air: float = 0.0
@export var configure_physics: bool = true

var player: CharacterBody3D
var _was_on_floor: bool = true
var _jump_module: JumpModule

signal landed(is_hard: bool)
@warning_ignore("unused_signal")
signal jumped
signal left_ground

func setup(p: CharacterBody3D) -> void:
	player = p
	_was_on_floor = player.is_on_floor()
	_jump_module = _find_jump_module(player)

	if "gravity" in p:
		gravity = p.gravity
	elif ProjectSettings.has_setting("physics/3d/default_gravity"):
		gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if "fall_gravity_multiplier" in p:
		fall_multiplier = p.fall_gravity_multiplier

	if configure_physics:
		if "max_slope_deg" in player:
			player.floor_max_angle = deg_to_rad(player.max_slope_deg)
		if "snap_len" in player:
			floor_snap_on_ground = player.snap_len
	player.floor_snap_length = floor_snap_on_ground

func physics_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("should_skip_module_updates") and player.should_skip_module_updates():
		return
	if _jump_module == null or not is_instance_valid(_jump_module):
		_jump_module = _find_jump_module(player)

	var now_on_floor: bool = player.is_on_floor()
	var v: Vector3 = player.velocity
	var jm: JumpModule = _jump_module

	if not now_on_floor:
		var g: float = gravity
		if fall_multiplier != 1.0 and v.y < 0.0:
			g *= fall_multiplier
		if jm and jm.is_hold_active():
			g *= jm.extra_hold_gravity_scale
		v.y -= g * delta
		if _was_on_floor:
			_set_floor_snap(floor_snap_in_air)
			if jm:
				jm.on_left_ground()
			emit_signal("left_ground")
	else:
		if v.y < 0.0:
			v.y = 0.0
		_set_floor_snap(floor_snap_on_ground)
		if not _was_on_floor:
			if jm:
				jm.on_landed()
			var impact_velocity: float = absf(player.velocity.y)
			var is_hard: bool = impact_velocity > 10.0
			if player.has_method("_play_landing_audio"):
				player._play_landing_audio(is_hard)
			if player.has_method("_trigger_camera_landing"):
				player._trigger_camera_landing(is_hard)
			emit_signal("landed", is_hard)

	player.velocity = v
	_was_on_floor = now_on_floor

func _set_floor_snap(length: float) -> void:
	if player != null and is_instance_valid(player):
		player.floor_snap_length = length

func apply_gravity(_delta: float) -> void:
	pass

func _find_jump_module(owner: Node) -> JumpModule:
	if owner == null or not is_instance_valid(owner):
		return null
	var candidate: Node = null
	if owner.has_node("Modules/Jump"):
		candidate = owner.get_node("Modules/Jump")
	elif owner.has_node("Jump"):
		candidate = owner.get_node("Jump")
	if candidate and candidate is JumpModule:
		return candidate
	return null
