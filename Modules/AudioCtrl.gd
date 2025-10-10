extends Node
class_name AudioCtrlModule

var player: CharacterBody3D
var jump_sfx: AudioStreamPlayer3D
var land_sfx: AudioStreamPlayer3D
var footstep_sfx: AudioStreamPlayer3D

@export var use_timer_footsteps := false
var _footstep_timer := 0.0

func setup(p: CharacterBody3D) -> void:
	player = p
	jump_sfx = p.jump_sfx if "jump_sfx" in p else null
	land_sfx = p.land_sfx if "land_sfx" in p else null
	footstep_sfx = p.footstep_sfx if "footstep_sfx" in p else null

func physics_tick(delta: float) -> void:
	if not use_timer_footsteps:
		return
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	if not player.is_on_floor() or hspeed < 0.5:
		_footstep_timer = 0.0
		return
	const STEP_PERIOD_MULTIPLIER := 1.05
	var speed_ratio := clampf(hspeed / player.sprint_speed, 0.0, 1.0)
	var step_period := lerpf(0.5, 0.28, speed_ratio) * STEP_PERIOD_MULTIPLIER
	_footstep_timer += delta
	if _footstep_timer >= step_period:
		_footstep_timer -= step_period
		play_footstep()

func play_jump() -> void:
	if is_instance_valid(jump_sfx): jump_sfx.play()

func play_landing(is_hard: bool) -> void:
	if not is_instance_valid(land_sfx) or land_sfx.stream == null: return
	land_sfx.volume_db = -6.0 if is_hard else -12.0
	land_sfx.pitch_scale = 0.95 if is_hard else 1.05
	land_sfx.play()

func play_footstep() -> void:
	if not is_instance_valid(footstep_sfx) or not player.is_on_floor(): return
	footstep_sfx.pitch_scale = randf_range(0.95, 1.05)
	footstep_sfx.play()
