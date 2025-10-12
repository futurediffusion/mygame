extends Node

class MockBody:
	extends CharacterBody3D

	var jump_velocity: float = 8.5
	var coyote_time: float = 0.12
	var gravity: float = 24.8
	var sim_on_floor: bool = true
	var combo_node: PerfectJumpCombo

	func is_on_floor() -> bool:
		return sim_on_floor

	func should_skip_module_updates() -> bool:
		return false

	func get_node_or_null(path: NodePath) -> Node:
		if String(path) == "PerfectJumpCombo" and combo_node != null:
			return combo_node
		return null

	func set_on_floor(value: bool) -> void:
		sim_on_floor = value

func _ready() -> void:
	var body := MockBody.new()
	var combo := PerfectJumpCombo.new()
	combo._body = body
	combo.reset_combo()
	combo._was_on_floor = true
	combo._landed_timer = combo.perfect_window
	body.combo_node = combo

	var state := StateModule.new()
	state.setup(body)

	var input := InputBuffer.new()
	var jump := JumpModule.new()
	jump.setup(body, state, input)
	jump._combo = combo

	var now_s := Time.get_ticks_msec() * 0.001
	input.last_jump_pressed_s = now_s
	input.jump_is_held = true
	state.last_on_floor_time_s = now_s

	var dt := 0.016
	jump.physics_tick(dt)

	assert(combo.get_combo() == 1, "Perfect jump should increment combo counter.")
	assert(combo.jump_multiplier() > 1.0, "Combo multiplier should increase after a perfect jump.")

	combo.register_failed_jump()
	assert(combo.get_combo() == 0, "Failed jumps should reset combo counter.")

	print("JUMP_COMBO_OK", combo.get_combo())
	get_tree().quit()
