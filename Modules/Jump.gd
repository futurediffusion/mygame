extends Node
class_name JumpModule

var player: CharacterBody3D
# leemos/exportables igual que el Player original
var coyote_time := 0.12
var jump_buffer := 0.15
var jump_velocity := 7.0

# estado interno (igual que el Player)
var _air_time := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0

# Referencias opcionales del Player
var anim_tree: AnimationTree
var camera_rig: Node

# Constantes de anim
const PARAM_JUMP: StringName = &"parameters/Jump/request"

func setup(p: CharacterBody3D) -> void:
	player = p
	# leer valores del Player para mantener fidelidad
	coyote_time = p.coyote_time
	jump_buffer = p.jump_buffer
	jump_velocity = p.jump_velocity
	anim_tree = p.anim_tree
	camera_rig = p.camera_rig

func physics_tick(_delta: float) -> void:
	pass

# --- Partes 1:1 con el Player ---
func update_jump_mechanics(delta: float) -> void:
	if player.is_on_floor():
		_coyote_timer = coyote_time
		_air_time = 0.0
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)
		_air_time += delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)

func handle_jump_input() -> void:
	var can_jump: bool = _jump_buffer_timer > 0.0 and (player.is_on_floor() or _coyote_timer > 0.0)
	if can_jump:
		execute_jump()

func execute_jump() -> void:
	player.velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0

	trigger_jump_animation()
	if is_instance_valid(player.jump_sfx):
		player.jump_sfx.play()

	if camera_rig:
		camera_rig.call_deferred("_play_jump_kick")

func trigger_jump_animation() -> void:
	if anim_tree:
		anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# expone por si Anim necesita consultar aire
func get_air_time() -> float:
	return _air_time
