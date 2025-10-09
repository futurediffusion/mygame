# AudioModule.gd (versión que ya trae timer opcional + eventos)
extends IPlayerModule
class_name AudioModule

var was_on_floor: bool = true
var foot_timer: float = 0.0

var jump_sfx: AudioStreamPlayer3D
var land_sfx: AudioStreamPlayer3D
var foot_sfx: AudioStreamPlayer3D

@export var step_interval_run: float = 0.42
@export var step_interval_sprint: float = 0.30
@export var footsteps_via_timer: bool = false

func setup(p: CharacterBody3D) -> void:
	player = p
	# 🔧 ahora busca los SFX como hijos del Player (tu jerarquía)
	jump_sfx = player.get_node_or_null(^"JumpSFX")
	land_sfx = player.get_node_or_null(^"LandSFX")
	foot_sfx = player.get_node_or_null(^"FootstepSFX")

func physics_tick(dt: float) -> void:
	if player.just_jumped and jump_sfx:
		jump_sfx.play()

	var on_floor: bool = player.is_on_floor()

	if on_floor and not was_on_floor and land_sfx:
		land_sfx.play()

	if footsteps_via_timer:
		var speed_h: float = Vector3(player.vel.x, 0.0, player.vel.z).length()
		if on_floor and speed_h > 0.5:
			foot_timer -= dt
			var interval: float = step_interval_sprint if player.is_sprinting else step_interval_run
			if foot_timer <= 0.0:
				foot_timer = interval
				_play_footstep_sound()
		else:
			foot_timer = 0.0

	was_on_floor = on_floor

func play_footstep() -> void:
	if player.is_on_floor():
		_play_footstep_sound()

func _play_footstep_sound() -> void:
	if not foot_sfx:
		return
	foot_sfx.pitch_scale = randf_range(0.95, 1.05)
	foot_sfx.play()
