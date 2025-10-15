extends ModuleBase
class_name MovementModule

@export var max_speed_ground: float = 7.5
@export var max_speed_air: float = 6.5
@export var accel_ground: float = GameConstants.DEFAULT_ACCEL_GROUND
@export var accel_air: float = GameConstants.DEFAULT_ACCEL_AIR
@export var ground_friction: float = GameConstants.DEFAULT_DECEL
@export_range(1.0, 3.0, 0.05) var fast_fall_speed_multiplier: float = GameConstants.DEFAULT_FAST_FALL_MULT

var sprint_speed: float = GameConstants.DEFAULT_SPRINT_SPEED
var speed_multiplier: float = 1.0

var player: CharacterBody3D
var _move_dir: Vector3 = Vector3.ZERO
var _is_sprinting: bool = false
var _combo: PerfectJumpCombo
var _max_slope_deg: float = 50.0
var _current_slope_speed: float = 1.0
var _slope_lerp_speed: float = 6.0

func setup(p: CharacterBody3D) -> void:
	player = p
	if "run_speed" in player:
		max_speed_ground = max(player.run_speed, 0.0)
	if "max_speed_air" in player:
		max_speed_air = max(player.max_speed_air, 0.0)
	elif "run_speed" in player:
		max_speed_air = max(player.run_speed, 0.0)
	if "sprint_speed" in player:
		sprint_speed = player.sprint_speed
	if "accel_ground" in player:
		accel_ground = player.accel_ground
	if "accel_air" in player:
		accel_air = player.accel_air
	if "decel" in player:
		ground_friction = max(player.decel, ground_friction)
	if "speed_multiplier" in player:
		speed_multiplier = max(player.speed_multiplier, 0.0)
	if "fast_fall_speed_multiplier" in player:
		fast_fall_speed_multiplier = max(player.fast_fall_speed_multiplier, 1.0)
	if "max_slope_deg" in player:
		_max_slope_deg = clampf(player.max_slope_deg, 0.0, 50.0)

## Registra el input de movimiento del frame actual.
## - `input_dir`: Vector3 (normalizado o cercano a 1) que indica la dirección deseada en el plano XZ.
## - `is_sprinting`: `true` si el jugador intenta esprintar en este frame.
## Efectos: almacena los parámetros para que `physics_tick` acelere el cuerpo acorde en el próximo tick.
func set_frame_input(input_dir: Vector3, is_sprinting: bool) -> void:
	assert(input_dir.is_finite(), "MovementModule.set_frame_input recibió un input_dir no finito.")
	assert(absf(input_dir.length()) <= 1.1, "MovementModule.set_frame_input espera un vector normalizado (<= 1.1).")
	_move_dir = input_dir
	_is_sprinting = is_sprinting

func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = max(multiplier, 0.0)

func physics_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("should_skip_module_updates") and player.should_skip_module_updates():
		return
	_update_horizontal_velocity(delta)

func _update_horizontal_velocity(delta: float) -> void:
	var on_floor := player.is_on_floor()
	var target_speed := max_speed_ground if on_floor else max_speed_air
	_update_slope_speed(on_floor, delta)
	if not on_floor and player.velocity.y < 0.0:
		target_speed *= max(fast_fall_speed_multiplier, 1.0)
	if _is_sprinting and on_floor:
		target_speed = sprint_speed
	var combo_speed_mul: float = 1.0
	var combo := _get_combo()
	if combo:
		combo_speed_mul = combo.speed_multiplier()
	target_speed = max(target_speed, 0.0) * speed_multiplier * combo_speed_mul * _current_slope_speed
	var want := Vector2.ZERO
	if _move_dir.length_squared() > 0.0001:
		var flattened := Vector2(_move_dir.x, _move_dir.z)
		if flattened.length_squared() > 1.0:
			flattened = flattened.normalized()
		want = flattened * target_speed
	var current := Vector2(player.velocity.x, player.velocity.z)
	if want.length_squared() > 0.0:
		var accel := accel_ground if on_floor else accel_air
		current = current.move_toward(want, accel * delta)
	elif on_floor and ground_friction > 0.0:
		current = current.move_toward(Vector2.ZERO, ground_friction * delta)
	player.velocity.x = current.x
	player.velocity.z = current.y

func _get_combo() -> PerfectJumpCombo:
	if player == null or not is_instance_valid(player):
		return null
	if _combo and is_instance_valid(_combo):
		return _combo
	if "combo" in player:
		var player_combo := player.combo as PerfectJumpCombo
		if player_combo != null and is_instance_valid(player_combo):
			_combo = player_combo
			return _combo
	_combo = player.get_node_or_null("PerfectJumpCombo") as PerfectJumpCombo
	return _combo

func _update_slope_speed(on_floor: bool, delta: float) -> void:
	var target_speed_mul := 1.0
	if on_floor and player != null and is_instance_valid(player):
		var floor_normal := player.get_floor_normal()
		if floor_normal.length_squared() > 0.0001:
			floor_normal = floor_normal.normalized()
			var slope_angle := acos(clampf(floor_normal.dot(Vector3.UP), -1.0, 1.0))
			var slope_deg := rad_to_deg(slope_angle)
			var effective_deg := min(slope_deg, _max_slope_deg)
			if effective_deg > 0.01 and _move_dir.length_squared() > 0.0:
				var downhill := Vector3.DOWN.slide(floor_normal)
				if downhill.length_squared() > 0.0001:
					downhill = downhill.normalized()
					var input_dir := Vector3(_move_dir.x, 0.0, _move_dir.z)
					if input_dir.length_squared() > 0.0:
						input_dir = input_dir.normalized()
						var alignment := downhill.dot(input_dir)
						var slope_ratio := 0.0
						if _max_slope_deg > 0.0:
							slope_ratio = clampf(effective_deg / _max_slope_deg, 0.0, 1.0)
						if alignment > 0.05:
							var downhill_weight := clampf(alignment, 0.0, 1.0)
							var progressive := downhill_weight * downhill_weight
							target_speed_mul = 1.0 + slope_ratio * progressive
						elif alignment < -0.05:
							var uphill_weight := clampf(-alignment, 0.0, 1.0)
							target_speed_mul = max(0.0, 1.0 - slope_ratio * uphill_weight)
	var lerp_weight := clampf(delta * _slope_lerp_speed, 0.0, 1.0)
	_current_slope_speed = lerp(_current_slope_speed, target_speed_mul, lerp_weight)
