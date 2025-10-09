extends Resource
class_name LocomotionConfig

@export_range(0.1, 15.0, 0.1) var walk_speed: float = 2.5
@export_range(0.1, 20.0, 0.1) var run_speed: float = 6.0
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 9.5
@export_range(1.0, 15.0, 0.1) var jump_velocity: float = 7.0

@export_group("Física")
@export_range(1.0, 50.0, 0.5) var accel_ground: float = 22.0
@export_range(1.0, 30.0, 0.5) var accel_air: float = 8.0
@export_range(1.0, 50.0, 0.5) var decel: float = 18.0
@export_range(0.0, 89.0, 1.0) var max_slope_deg: float = 46.0
@export_range(0.0, 2.0, 0.05) var snap_len: float = 0.3

@export_group("Salto")
@export_range(0.0, 0.5, 0.01) var coyote_time: float = 0.12
@export_range(0.0, 0.5, 0.01) var jump_buffer: float = 0.15
