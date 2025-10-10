extends Node
class_name AnimationCtrlModule

var player: CharacterBody3D
var anim_tree: AnimationTree
var anim_player: AnimationPlayer

const PARAM_LOC: StringName = &"parameters/Locomotion/blend_position"
const PARAM_AIRBLEND: StringName = &"parameters/AirBlend/blend_amount"
const PARAM_FALLANIM: StringName = &"parameters/FallAnim/animation"
const PARAM_SPRINTSCL: StringName = &"parameters/SprintScale/scale"

# valores copiados del Player (para fidelidad)
var walk_speed := 2.5
var run_speed := 6.0
var sprint_speed := 9.5
var sprint_anim_speed_scale := 1.15
var sprint_blend_bias := 0.85

var fall_clip_name: StringName = &"fall air loop"
var fall_threshold := -0.05
var fall_ramp_delay := 0.10
var fall_ramp_time := 0.20
var fall_blend_lerp := 12.0

var _current_air_blend := 0.0

func setup(p: CharacterBody3D) -> void:
	player = p
	anim_tree = p.anim_tree
	anim_player = p.anim_player

	# copiar exportados del player
	walk_speed = p.walk_speed
	run_speed = p.run_speed
	sprint_speed = p.sprint_speed
	sprint_anim_speed_scale = p.sprint_anim_speed_scale
	sprint_blend_bias = p.sprint_blend_bias

	fall_clip_name = p.fall_clip_name
	fall_threshold = p.fall_threshold
	fall_ramp_delay = p.fall_ramp_delay
	fall_ramp_time = p.fall_ramp_time
	fall_blend_lerp = p.fall_blend_lerp

	# init igual al original
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	anim_tree.set(PARAM_FALLANIM, fall_clip_name)
	anim_tree.set(PARAM_SPRINTSCL, 1.0)
	anim_tree.set(PARAM_AIRBLEND, 0.0)

func physics_tick(_delta: float) -> void:
	pass

# --- Funciones 1:1 con Player ---
func update_animation_state(delta: float, input_dir: Vector3, is_sprinting: bool, air_time: float) -> void:
	_update_locomotion_blend(is_sprinting)
	_update_sprint_timescale(is_sprinting)
	_update_air_blend(delta, air_time)

func _update_locomotion_blend(is_sprinting: bool) -> void:
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var target_max: float = sprint_speed if is_sprinting else run_speed

	var blend_value: float
	if horizontal_speed <= walk_speed:
		blend_value = remap(horizontal_speed, 0.0, walk_speed, 0.0, 0.4)
	else:
		blend_value = remap(horizontal_speed, walk_speed, target_max, 0.4, 1.0)

	if is_sprinting:
		blend_value = pow(clampf(blend_value, 0.0, 1.0), sprint_blend_bias)

	anim_tree.set(PARAM_LOC, clampf(blend_value, 0.0, 1.0))

func _update_sprint_timescale(is_sprinting: bool) -> void:
	if not is_sprinting:
		anim_tree.set(PARAM_SPRINTSCL, 1.0)
		return

	var blend_pos: float = float(anim_tree.get(PARAM_LOC))
	var scale_factor: float = lerp(1.0, sprint_anim_speed_scale, blend_pos)
	anim_tree.set(PARAM_SPRINTSCL, scale_factor)

func _update_air_blend(delta: float, air_time: float) -> void:
	var target_blend: float = _calculate_fall_blend(air_time)
	var lerp_speed: float = clampf(delta * fall_blend_lerp, 0.0, 1.0)
	_current_air_blend = lerpf(_current_air_blend, target_blend, lerp_speed)
	anim_tree.set(PARAM_AIRBLEND, _current_air_blend)

func _calculate_fall_blend(air_time: float) -> float:
	if player.is_on_floor() or player.velocity.y >= fall_threshold:
		return 0.0

	var elapsed: float = air_time - fall_ramp_delay
	if elapsed <= 0.0:
		return 0.0

	var ramp_progress: float = clampf(elapsed / fall_ramp_time, 0.0, 1.0)
	return smoothstep(0.0, 1.0, ramp_progress)
