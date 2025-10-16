extends Node

class MockPlayer:
	extends CharacterBody3D
	signal landed(impact: float)

	var jump_velocity: float = 8.5
	var coyote_time: float = 0.12
	var gravity: float = 24.8
	var sim_on_floor: bool = true
	var capabilities: Capabilities = Capabilities.new()
	var perfect_bonus_log: Array[Dictionary] = []
	var perfect_speed_scale: float = 1.0
	var perfect_jump_scale: float = 1.0

	func is_on_floor() -> bool:
		return sim_on_floor

	func should_skip_module_updates() -> bool:
		return false

	func apply_perfect_jump_bonus(speed_mult: float, jump_mult: float) -> void:
		perfect_bonus_log.append({"speed": speed_mult, "jump": jump_mult})
		perfect_speed_scale = speed_mult
		perfect_jump_scale = jump_mult

	func get_perfect_speed_scale() -> float:
		return perfect_speed_scale

	func consume_perfect_jump_scale() -> float:
		var value := perfect_jump_scale
		perfect_jump_scale = 1.0
		return value

func _ready() -> void:
	var body := MockPlayer.new()
	add_child(body)
	var modules := Node.new()
	modules.name = "Modules"
	body.add_child(modules)
	var jump_module := JumpModule.new()
	jump_module.name = "Jump"
	modules.add_child(jump_module)
	var state_module := StateModule.new()
	state_module.setup(body)
	var input_buffer := InputBuffer.new()
	body.add_child(input_buffer)
	input_buffer.jump_buffer_time = body.coyote_time
	jump_module.setup(body, state_module, input_buffer)
	var combo := PerfectJumpCombo.new()
	combo.name = "PerfectJumpCombo"
	body.add_child(combo)
	combo.setup(body)
	combo.window_ms = 150

	var jump_impulses: Array[float] = []
	jump_module.jump_performed.connect(func(impulse: float) -> void:
		jump_impulses.append(impulse)
	)
	var perfect_events := 0
	combo.perfect_jump.connect(func() -> void:
		perfect_events += 1
	)

	var now_s := Time.get_ticks_msec() * 0.001
	input_buffer.last_jump_pressed_s = now_s
	input_buffer.jump_is_held = true
	state_module.last_on_floor_time_s = now_s
	body.sim_on_floor = true
	var dt := 0.016
	jump_module.physics_tick(dt)
	assert(jump_impulses.size() == 1, "JumpModule should emit jump_performed when jumping.")
	assert(is_equal_approx(jump_impulses[0], body.jump_velocity), "Initial impulse should use base jump velocity.")
	body.landed.emit(body.velocity.y)
	assert(combo.get_combo() == 1, "Perfect combo should increment after a quick landing.")
	assert(perfect_events == 1, "Perfect jump event should fire once.")
	assert(body.perfect_bonus_log.size() == 1, "Perfect bonus should be applied once.")
	assert(is_equal_approx(body.perfect_speed_scale, combo.bonus_speed), "Speed bonus should match combo configuration.")
	assert(is_equal_approx(body.perfect_jump_scale, combo.bonus_jump), "Jump bonus should match combo configuration.")

	body.sim_on_floor = true
	input_buffer.last_jump_pressed_s = Time.get_ticks_msec() * 0.001
	input_buffer.jump_is_held = true
	state_module.last_on_floor_time_s = Time.get_ticks_msec() * 0.001
	var expected_bonus := body.perfect_jump_scale
	jump_module.physics_tick(dt)
	assert(jump_impulses.size() == 2, "Second jump should also emit an impulse.")
	assert(is_equal_approx(jump_impulses[1], body.jump_velocity * expected_bonus), "Perfect jump multiplier should modify the next jump impulse.")
	assert(is_equal_approx(body.perfect_jump_scale, 1.0), "Jump multiplier should reset after being consumed.")

	combo._last_jump_time_ms -= combo.window_ms + 50
	body.landed.emit(body.velocity.y)
	assert(combo.get_combo() == 0, "Late landing should reset the combo.")
	assert(perfect_events == 1, "No additional perfect jump should trigger on late landing.")
	assert(body.perfect_bonus_log.size() == 1, "No new bonus should be applied when landing outside the window.")

	print("JUMP_COMBO_OK", combo.get_combo())
	get_tree().quit()
