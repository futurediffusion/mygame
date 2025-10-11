extends ModuleBase
class_name StateModule

@export var gravity := 24.0
@export var fall_multiplier := 1.0
@export var floor_snap_on_ground := 0.3
@export var floor_snap_in_air := 0.0
@export var configure_physics := true

var player: CharacterBody3D
var _was_on_floor := true

signal landed(is_hard: bool)
@warning_ignore("unused_signal")
signal jumped
signal left_ground

func setup(p: CharacterBody3D) -> void:
        player = p
        _was_on_floor = player.is_on_floor()

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

        var now_on_floor := player.is_on_floor()
        var velocity: Vector3 = player.velocity

        if not now_on_floor:
                var g := gravity
                if fall_multiplier != 1.0 and velocity.y < 0.0:
                        g *= fall_multiplier
                velocity.y -= g * delta
                if _was_on_floor:
                        _set_floor_snap(floor_snap_in_air)
                        emit_signal("left_ground")
        else:
                if velocity.y < 0.0:
                        velocity.y = 0.0
                _set_floor_snap(floor_snap_on_ground)

        if now_on_floor and not _was_on_floor:
                var impact_velocity: float = abs(player.velocity.y)
                var is_hard := impact_velocity > 10.0
                if player.has_method("_play_landing_audio"):
                        player._play_landing_audio(is_hard)
                if player.has_method("_trigger_camera_landing"):
                        player._trigger_camera_landing(is_hard)
                emit_signal("landed", is_hard)

        player.velocity = velocity
        _was_on_floor = now_on_floor

func _set_floor_snap(length: float) -> void:
        if player != null and is_instance_valid(player):
                player.floor_snap_length = length

# Compatibilidad si alguien llama esto (NO hacer nada)
func apply_gravity(_delta: float) -> void:
	pass
