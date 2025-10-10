extends Node
class_name AudioCtrlModule

var player: CharacterBody3D
var jump_sfx: AudioStreamPlayer3D
var land_sfx: AudioStreamPlayer3D
var footstep_sfx: AudioStreamPlayer3D

func setup(p: CharacterBody3D) -> void:
	player = p
	jump_sfx = p.jump_sfx
	land_sfx = p.land_sfx
	footstep_sfx = p.footstep_sfx

func physics_tick(_delta: float) -> void:
	pass

func play_jump() -> void:
	if is_instance_valid(jump_sfx):
		jump_sfx.play()

func play_landing(is_hard: bool) -> void:
	if not is_instance_valid(land_sfx) or land_sfx.stream == null:
		return
	land_sfx.volume_db = -6.0 if is_hard else -12.0
	land_sfx.pitch_scale = 0.95 if is_hard else 1.05
	land_sfx.play()

func play_footstep() -> void:
	if not is_instance_valid(footstep_sfx) or not player.is_on_floor():
		return
	footstep_sfx.pitch_scale = randf_range(0.95, 1.05)
	footstep_sfx.play()
