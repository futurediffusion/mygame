extends Node
class_name StateModule

var player: CharacterBody3D
var gravity: float
var _was_on_floor := true

func setup(p: CharacterBody3D) -> void:
	player = p
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_was_on_floor = player.is_on_floor()

func physics_tick(_delta: float) -> void:
	# Solo aterrizaje por ahora (gravedad queda en JumpModule según tu Player actual)
	_handle_landing_internal()

# --- Copia fiel de tu lógica original, pero aquí ---
func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

func _handle_landing_internal() -> void:
	if not player.is_on_floor() or _was_on_floor:
		_was_on_floor = player.is_on_floor()
		return

	var impact_velocity: float = abs(player.velocity.y)
	var is_hard_landing: bool = impact_velocity > 10.0

	# Reusar callbacks del Player para no romper nada externo
	player._play_landing_audio(is_hard_landing)
	player._trigger_camera_landing(is_hard_landing)

	_was_on_floor = player.is_on_floor()

# API pública por compatibilidad (puente)
func handle_landing() -> void:
	_handle_landing_internal()
