extends Node
class_name JumpModule

var player: CharacterBody3D

# Parámetros de salto (mantengo tus valores)
var coyote_time := 0.12
var jump_buffer := 0.15
var jump_velocity := 8.5
var gravity_scale := 1.0
var fall_gravity_multiplier := 1.5

# Estado interno
var _air_time: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_button_held := false

# Opcionales
var anim_tree: AnimationTree
var camera_rig: Node
const PARAM_JUMP: StringName = &"parameters/Jump/request"

# --- Flags de integración ---
# Si TRUE: la gravedad la aplica State; Jump NO debe aplicarla.
@export var uses_state_gravity := true
# Factor de “salto corto” (mantengo 0.5 como en tu versión)
@export var jump_cutoff_factor := 0.5

func setup(p: CharacterBody3D) -> void:
	player = p
	# Fidelidad con Player (si existen)
	coyote_time = p.coyote_time if "coyote_time" in p else coyote_time
	jump_buffer = p.jump_buffer if "jump_buffer" in p else jump_buffer
	jump_velocity = p.jump_velocity if "jump_velocity" in p else jump_velocity
	gravity_scale = p.gravity_scale if "gravity_scale" in p else gravity_scale
	fall_gravity_multiplier = p.fall_gravity_multiplier if "fall_gravity_multiplier" in p else fall_gravity_multiplier
	anim_tree = p.anim_tree if "anim_tree" in p else null
	camera_rig = p.camera_rig if "camera_rig" in p else null

func physics_tick(delta: float) -> void:
	# Fase 3: mover timers + ejecución al tick
	update_jump_mechanics(delta)
	handle_jump_input()
	# OJO: la gravedad la hace State (Fase 1). El salto variable lo seguimos aplicando aquí:
	apply_variable_jump_height()

# --- Mecánicas de salto ---
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
	var can_jump: bool = _jump_buffer_timer > 0.0 and (player.is_on_floor() or _coyote_timer > 0.0)
	if can_jump:
		execute_jump()

func execute_jump() -> void:
	player.velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	trigger_jump_animation()

	# Audio: usa módulo si está, si no el sfx directo
	if "m_audio" in player and is_instance_valid(player.m_audio):
		player.m_audio.play_jump()
	elif "jump_sfx" in player and is_instance_valid(player.jump_sfx):
		player.jump_sfx.play()

	if camera_rig and camera_rig.has_method("_play_jump_kick"):
		camera_rig.call_deferred("_play_jump_kick")

func trigger_jump_animation() -> void:
	if anim_tree:
		anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# --- Gravedad (NO usada si uses_state_gravity = true) ---
# Mantenemos por compatibilidad, pero será NO-OP cuando Fase 1 está activa.
func apply_gravity(delta: float, base_gravity: float) -> void:
	if uses_state_gravity:
		return
	if not player.is_on_floor():
		var g := base_gravity * gravity_scale
		# Fast falling SOLO al caer (velocity.y < 0)
		if player.velocity.y < 0.0:
			g *= fall_gravity_multiplier
		player.velocity.y -= g * delta

# Salto variable: SOLO cuando va subiendo (velocity.y > 0)
func apply_variable_jump_height() -> void:
	if (not _jump_button_held) and player.velocity.y > 0.0:
		player.velocity.y *= jump_cutoff_factor

func get_air_time() -> float:
	return _air_time

func is_falling() -> bool:
	return not player.is_on_floor() and player.velocity.y < 0.0

func is_rising() -> bool:
	return not player.is_on_floor() and player.velocity.y > 0.0
