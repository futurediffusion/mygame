extends Node
class_name JumpModule

var player: CharacterBody3D

var coyote_time := 0.12
var jump_buffer := 0.15
var jump_velocity := 8.5

var _air_time := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_button_held := false

func setup(p: CharacterBody3D) -> void:
	player = p
	coyote_time = p.coyote_time
	jump_buffer = p.jump_buffer
	jump_velocity = p.jump_velocity

func physics_tick(delta: float) -> void:
	update_jump_mechanics(delta)
	handle_jump_input()
	apply_variable_jump_height()

func update_jump_mechanics(delta: float) -> void:
	if player.is_on_floor():
		_coyote_timer = coyote_time
		_air_time = 0.0
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)
		_air_time += delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer
		_jump_button_held = true
	else:
		_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)
		if Input.is_action_just_released("jump"):
			_jump_button_held = false

func handle_jump_input() -> void:
	var can_jump := _jump_buffer_timer > 0.0 and (player.is_on_floor() or _coyote_timer > 0.0)
	if can_jump:
		execute_jump()

func execute_jump() -> void:
	player.velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	player._trigger_jump_animation()
	if is_instance_valid(player.jump_sfx):
		player.jump_sfx.play()

func apply_variable_jump_height() -> void:
	# corta el salto si suelta el botón durante el ascenso
	if not _jump_button_held and player.velocity.y > 0.0:
		player.velocity.y *= 0.55

func get_air_time() -> float:
	return _air_time

# Compatibilidad (si Player aún llama)
func apply_gravity(_delta: float, _base_g: float) -> void:
	pass
