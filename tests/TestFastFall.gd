extends Node

class MockPlayer:
	extends CharacterBody3D
	var fall_gravity_multiplier: float = 1.5
	var fast_fall_speed_multiplier: float = 1.5
	var run_speed: float = 6.0
	var sprint_speed: float = 9.5
	var accel_ground: float = 26.0
	var accel_air: float = 9.5
	var decel: float = 10.0
	var gravity: float = 10.0

func _ready() -> void:
	var player := MockPlayer.new()
	var state := StateModule.new()
	state.setup(player)
	var initial_y := -2.0
	player.velocity = Vector3(0.0, initial_y, 0.0)
	var dt := 0.1
	state.pre_move_update(dt)
	var expected_y := initial_y - player.gravity * state.fall_gravity_scale * dt
	assert(is_equal_approx(player.velocity.y, expected_y), "Fast fall gravity multiplier was not applied.")

	player.velocity = Vector3(0.0, 0.5, 0.0)
	state.pre_move_update(dt)
	var expected_cross := 0.5 - player.gravity * dt
	if expected_cross < 0.0:
		var fall_scale := max(state.fall_gravity_scale, 1.0)
		expected_cross -= player.gravity * (fall_scale - 1.0) * dt
	assert(is_equal_approx(player.velocity.y, expected_cross), "Fast fall multiplier should trigger even when transitioning from a held jump.")

	var movement := MovementModule.new()
	movement.setup(player)
	movement.max_speed_air = player.run_speed
	var input_dir := Vector3(1.0, 0.0, 0.0)
	var sim_dt := 0.1
	player.velocity = Vector3.ZERO
	player.velocity.y = -1.0
	var iterations := 120
	for _i in range(iterations):
		movement.set_frame_input(input_dir, false)
		movement.physics_tick(sim_dt)
	var falling_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var expected_fall_speed := movement.max_speed_air * movement.fast_fall_speed_multiplier
	assert(absf(falling_speed - expected_fall_speed) <= 0.1, "Falling horizontal speed mismatch: expected %f got %f" % [expected_fall_speed, falling_speed])

	player.velocity = Vector3.ZERO
	var ground_iterations := 120
	for _j in range(ground_iterations):
		player.velocity.y = 0.0
		movement.set_frame_input(input_dir, false)
		movement.physics_tick(sim_dt)
	var ground_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var expected_ground := movement.max_speed_ground
	assert(absf(ground_speed - expected_ground) <= 0.1, "Ground horizontal speed mismatch: expected %f got %f" % [expected_ground, ground_speed])
	assert(falling_speed > ground_speed * 1.45, "Fast fall should be at least 45% faster than ground run speed.")
	print("FAST_FALL_OK", falling_speed, ground_speed)
	get_tree().quit()
