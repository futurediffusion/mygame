extends Node
class_name JumpModule

var player: CharacterBody3D

# Parámetros de salto mejorados (Triple A feel)
var coyote_time := 0.12
var jump_buffer := 0.15
var jump_velocity := 8.5  # Aumentado para un salto más enérgico
var gravity_scale := 1.0
var fall_gravity_multiplier := 1.5  # 50% más gravedad al caer

# Estado interno
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
        # Leer valores del Player para mantener fidelidad
        coyote_time = p.coyote_time if "coyote_time" in p else coyote_time
        jump_buffer = p.jump_buffer if "jump_buffer" in p else jump_buffer
        jump_velocity = p.jump_velocity if "jump_velocity" in p else jump_velocity
        anim_tree = p.anim_tree if "anim_tree" in p else null
        camera_rig = p.camera_rig if "camera_rig" in p else null

func physics_tick(_delta: float) -> void:
        pass

# --- Mecánicas de salto mejoradas ---
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
        if "jump_sfx" in player and is_instance_valid(player.jump_sfx):
                player.jump_sfx.play()

        if camera_rig and camera_rig.has_method("_play_jump_kick"):
                camera_rig.call_deferred("_play_jump_kick")

func trigger_jump_animation() -> void:
        if anim_tree:
                anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# NUEVA FUNCIÓN: Aplicar gravedad con fast falling
func apply_gravity(delta: float, base_gravity: float) -> void:
        if not player.is_on_floor():
                var gravity_to_apply := base_gravity * gravity_scale

                # Fast falling: solo cuando está cayendo (velocidad.y > 0)
                if player.velocity.y > 0.0:
                        gravity_to_apply *= fall_gravity_multiplier

                player.velocity.y -= gravity_to_apply * delta

# Salto variable: soltar el botón para caer más rápido
func apply_variable_jump_height() -> void:
        if Input.is_action_just_released("jump") and player.velocity.y < 0.0:
                # Reducir velocidad vertical si está subiendo
                player.velocity.y *= 0.5

# Expone el tiempo en el aire por si otros sistemas lo necesitan
func get_air_time() -> float:
        return _air_time

# Verifica si está cayendo
func is_falling() -> bool:
        return not player.is_on_floor() and player.velocity.y > 0.0

# Verifica si está subiendo
func is_rising() -> bool:
        return not player.is_on_floor() and player.velocity.y < 0.0
