extends Node
class_name StateModule

var player: CharacterBody3D
var gravity: float
var _was_on_floor := true

@export var configure_physics := true

signal landed(is_hard: bool)

func setup(p: CharacterBody3D) -> void:
	player = p
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_was_on_floor = player.is_on_floor()

	# (Opcional) mover config de físicas desde Player
	if configure_physics:
		if "max_slope_deg" in player:
			player.floor_max_angle = deg_to_rad(player.max_slope_deg)
		if "snap_len" in player:
			player.floor_snap_length = player.snap_len

func physics_tick(delta: float) -> void:
	# Gravedad base (única fuente de verdad)
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
		# print("state tick gravity", player.velocity.y)

	# Aterrizaje (edge aire→suelo)
	var now_on_floor := player.is_on_floor()
	if now_on_floor and not _was_on_floor:
		var impact_velocity: float = abs(player.velocity.y)
		var is_hard := impact_velocity > 10.0
		player._play_landing_audio(is_hard)
		player._trigger_camera_landing(is_hard)
		emit_signal("landed", is_hard)
	_was_on_floor = now_on_floor

# Compatibilidad si alguien llama esto (NO hacer nada)
func apply_gravity(_delta: float) -> void:
	pass
