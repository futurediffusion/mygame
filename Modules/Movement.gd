extends Node
class_name MovementModule

var player: CharacterBody3D

# cache de parámetros que lee del Player (para ser fieles al original)
var accel_ground := 22.0
var accel_air := 8.0
var decel := 18.0
var run_speed := 6.0
var sprint_speed := 9.5

# input cacheado por frame (inyectado desde Player)
var _input_dir := Vector3.ZERO
var _is_sprinting := false

func setup(p: CharacterBody3D) -> void:
	player = p
	# leemos del Player para replicar valores exportados (por si cambian en el editor)
	accel_ground = p.accel_ground
	accel_air = p.accel_air
	decel = p.decel
	run_speed = p.run_speed
	sprint_speed = p.sprint_speed

func set_frame_input(input_dir: Vector3, is_sprinting: bool) -> void:
	_input_dir = input_dir
	_is_sprinting = is_sprinting

func h_vec() -> Vector2:
	return Vector2(player.velocity.x, player.velocity.z)

func set_h_vec(v: Vector2) -> void:
	player.velocity.x = v.x
	player.velocity.z = v.y

func h_speed() -> float:
	return h_vec().length()

func physics_tick(delta: float) -> void:
	update_horizontal_velocity(delta, _input_dir, _is_sprinting)

# ---- Funciones 1:1 con el Player original ----
func update_horizontal_velocity(delta: float, input_dir: Vector3, is_sprinting: bool) -> void:
	var target_speed: float = sprint_speed if is_sprinting else run_speed
	var current_horiz: Vector2 = h_vec()

	if input_dir != Vector3.ZERO:
		var target_horiz: Vector2 = Vector2(input_dir.x, input_dir.z) * target_speed
		current_horiz = accelerate_towards(current_horiz, target_horiz, delta)
	else:
		if h_speed() < 0.001:
			current_horiz = Vector2.ZERO
		else:
			current_horiz = apply_deceleration(current_horiz, delta)

	set_h_vec(current_horiz)

func accelerate_towards(current: Vector2, target: Vector2, delta: float) -> Vector2:
	var accel_rate: float = accel_ground if player.is_on_floor() else accel_air
	var difference: Vector2 = target - current
	var distance: float = difference.length()

	if distance < 0.001:
		return target

	var change_amount: float = min(accel_rate * delta, distance)
	return current + difference.normalized() * change_amount

func apply_deceleration(current: Vector2, delta: float) -> Vector2:
	var speed: float = current.length()
	if speed < 0.001:
		return Vector2.ZERO

	var drop: float = min(speed, decel * delta)
	return current.normalized() * (speed - drop)
