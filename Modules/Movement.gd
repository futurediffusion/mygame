extends ModuleBase
class_name MovementModule

@export var max_speed_ground: float = 7.5
@export var max_speed_air: float = 6.5
@export var accel_ground: float = 26.0
@export var accel_air: float = 9.5
@export var ground_friction: float = 10.0
@export_range(1.0, 3.0, 0.05) var fast_fall_speed_multiplier: float = 1.5

var sprint_speed: float = 9.5
var speed_multiplier: float = 1.0

var player: CharacterBody3D
var _move_dir: Vector3 = Vector3.ZERO
var _is_sprinting: bool = false
var _combo: PerfectJumpCombo

func setup(p: CharacterBody3D) -> void:
	player = p
	if "run_speed" in player:
		max_speed_ground = player.run_speed
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

func set_frame_input(input_dir: Vector3, is_sprinting: bool) -> void:
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
	if not on_floor and player.velocity.y < 0.0:
		target_speed *= max(fast_fall_speed_multiplier, 1.0)
	if _is_sprinting and on_floor:
		target_speed = sprint_speed
	var combo_speed_mul: float = 1.0
	var combo := _get_combo()
	if combo:
		combo_speed_mul = combo.speed_multiplier()
	target_speed = max(target_speed, 0.0) * speed_multiplier * combo_speed_mul
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
	_combo = player.get_node_or_null("PerfectJumpCombo") as PerfectJumpCombo
	return _combo
