extends Node
class_name AnimationCtrlModule

var player: CharacterBody3D
var anim_tree: AnimationTree
var anim_player: AnimationPlayer

# Paths (deben existir en tu AnimationTree)
const PARAM_LOC: StringName = &"parameters/Locomotion/blend_position"
const PARAM_AIRBLEND: StringName = &"parameters/AirBlend/blend_amount"
const PARAM_FALLANIM: StringName = &"parameters/FallAnim/animation"
const PARAM_SPRINTSCL: StringName = &"parameters/SprintScale/scale"

# Se copian de Player en setup para mantener fidelidad
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

# Estado interno de blend
var _current_air_blend := 0.0

# Inputs cacheados por frame
var _is_sprinting := false
var _air_time := 0.0

func setup(p: CharacterBody3D) -> void:
	player = p
	anim_tree = p.anim_tree
	anim_player = p.anim_player

	# Copiar exportados del Player
	if "walk_speed" in p: walk_speed = p.walk_speed
	if "run_speed" in p: run_speed = p.run_speed
	if "sprint_speed" in p: sprint_speed = p.sprint_speed
	if "sprint_anim_speed_scale" in p: sprint_anim_speed_scale = p.sprint_anim_speed_scale
	if "sprint_blend_bias" in p: sprint_blend_bias = p.sprint_blend_bias

	if "fall_clip_name" in p: fall_clip_name = p.fall_clip_name
	if "fall_threshold" in p: fall_threshold = p.fall_threshold
	if "fall_ramp_delay" in p: fall_ramp_delay = p.fall_ramp_delay
	if "fall_ramp_time" in p: fall_ramp_time = p.fall_ramp_time
	if "fall_blend_lerp" in p: fall_blend_lerp = p.fall_blend_lerp

	# Init AnimationTree
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	anim_tree.set(PARAM_FALLANIM, fall_clip_name)
	anim_tree.set(PARAM_SPRINTSCL, 1.0)
	anim_tree.set(PARAM_AIRBLEND, 0.0)

func set_frame_anim_inputs(is_sprinting: bool, air_time: float) -> void:
	_is_sprinting = is_sprinting
	_air_time = air_time

func physics_tick(delta: float) -> void:
	_update_locomotion_blend(_is_sprinting)
	_update_sprint_timescale(_is_sprinting)
	_update_air_blend(delta, _air_time)

# Compatibilidad (si alguien externo aún llama)
func update_animation_state(delta: float, _input_dir: Vector3, is_sprinting: bool, air_time: float) -> void:
	set_frame_anim_inputs(is_sprinting, air_time)
	physics_tick(delta)

func _update_locomotion_blend(is_sprinting: bool) -> void:
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var target_max := sprint_speed if is_sprinting else run_speed
	var blend: float
	if hspeed <= walk_speed:
		blend = remap(hspeed, 0.0, walk_speed, 0.0, 0.4)
	else:
		blend = remap(hspeed, walk_speed, target_max, 0.4, 1.0)
	if is_sprinting:
		blend = pow(clampf(blend, 0.0, 1.0), sprint_blend_bias)
	anim_tree.set(PARAM_LOC, clampf(blend, 0.0, 1.0))

func _update_sprint_timescale(is_sprinting: bool) -> void:
	if not is_sprinting:
		anim_tree.set(PARAM_SPRINTSCL, 1.0)
		return
	var blend_pos: float = float(anim_tree.get(PARAM_LOC))
	var scale_factor := lerp(1.0, sprint_anim_speed_scale, blend_pos)
	anim_tree.set(PARAM_SPRINTSCL, scale_factor)

func _update_air_blend(delta: float, air_time: float) -> void:
	var target := _calculate_fall_blend(air_time)
	var lerp_speed := clampf(delta * fall_blend_lerp, 0.0, 1.0)
	_current_air_blend = lerpf(_current_air_blend, target, lerp_speed)
	anim_tree.set(PARAM_AIRBLEND, _current_air_blend)

func _calculate_fall_blend(air_time: float) -> float:
	if player.is_on_floor() or player.velocity.y >= fall_threshold:
		return 0.0
	var elapsed := air_time - fall_ramp_delay
	if elapsed <= 0.0:
		return 0.0
	var t := clampf(elapsed / fall_ramp_time, 0.0, 1.0)
	return smoothstep(0.0, 1.0, t)
