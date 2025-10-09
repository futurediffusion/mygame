extends IPlayerModule
class_name AnimationModule

@export var cfg: LocomotionConfig
@export var anim_tree_path: NodePath        # ej: Pivot/Model/AnimationTree
@export var anim_player_path: NodePath      # ej: Pivot/Model/AnimationPlayer
@export var fall_clip_name: StringName = &"fall air loop"
@export var use_fall_anim_param: bool = false   # <— solo true si tu árbol tiene parameters/FallAnim/animation

@export var sprint_anim_speed_scale: float = 1.15
@export var sprint_blend_bias: float = 0.85
@export var fall_threshold: float = -0.05
@export var fall_ramp_delay: float = 0.10
@export var fall_ramp_time: float = 0.20
@export var fall_blend_lerp: float = 12.0

const P_LOC  := &"parameters/Locomotion/blend_position"
const P_JUMP := &"parameters/Jump/request"
const P_AIR  := &"parameters/AirBlend/blend_amount"
const P_FALL := &"parameters/FallAnim/animation"
const P_SCL  := &"parameters/SprintScale/scale"

var anim_tree: AnimationTree
var anim_player: AnimationPlayer

var _loc_is_vec2: bool = false
var _air_time: float = 0.0
var _current_air_blend: float = 0.0

func _get_hvel2() -> Vector2:
	if "vel" in player:
		return Vector2(player.vel.x, player.vel.z)
	return Vector2(player.velocity.x, player.velocity.z)

func _get_vel_y() -> float:
	if "vel" in player:
		return player.vel.y
	return player.velocity.y

func setup(p: CharacterBody3D) -> void:
	player = p
	if cfg == null:
		cfg = LocomotionConfig.new()

	anim_tree = player.get_node_or_null(anim_tree_path)
	anim_player = player.get_node_or_null(anim_player_path)
	if anim_tree == null:
		push_error("AnimationModule: asigna anim_tree_path (ej: Pivot/Model/AnimationTree).")
		return

	if anim_player:
		anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true

	# Detectar si locomotion es 2D o 1D leyendo el valor actual
	var v = anim_tree.get(P_LOC)
	_loc_is_vec2 = v is Vector2

	# Iniciales (sets directos; FallAnim opcional)
	if use_fall_anim_param:
		anim_tree.set(P_FALL, fall_clip_name)
	anim_tree.set(P_SCL, 1.0)
	anim_tree.set(P_AIR, 0.0)

func physics_tick(dt: float) -> void:
	if anim_tree == null:
		return

	# --- Locomotion blend ---
	var hvel := _get_hvel2()
	var horiz_speed: float = hvel.length()
	var target_max: float = (cfg.sprint_speed if player.is_sprinting else cfg.run_speed)

	var blend_value: float
	if horiz_speed <= cfg.walk_speed:
		blend_value = remap(horiz_speed, 0.0, cfg.walk_speed, 0.0, 0.4)
	else:
		blend_value = remap(horiz_speed, cfg.walk_speed, target_max, 0.4, 1.0)
	if player.is_sprinting:
		blend_value = pow(clampf(blend_value, 0.0, 1.0), sprint_blend_bias)

	if _loc_is_vec2:
		var d: Vector3 = player.wish_dir
		anim_tree.set(P_LOC, Vector2(d.x, -d.z))  # (strafe, forward) con forward=-Z
	else:
		anim_tree.set(P_LOC, clampf(blend_value, 0.0, 1.0))

	# --- Jump OneShot ---
	if "just_jumped" in player and player.just_jumped:
		anim_tree.set(P_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# --- Sprint scale ---
	var speed_ratio := clampf(horiz_speed / max(0.01, target_max), 0.0, 1.0)
	var scale_factor: float = (lerp(1.0, sprint_anim_speed_scale, speed_ratio) if player.is_sprinting else 1.0)
	anim_tree.set(P_SCL, scale_factor)

	# --- Air blend con rampa ---
	_air_time = 0.0 if player.is_on_floor() else _air_time + dt
	var target_blend: float = _calc_fall_blend()
	var lerp_speed: float = clampf(dt * fall_blend_lerp, 0.0, 1.0)
	_current_air_blend = lerpf(_current_air_blend, target_blend, lerp_speed)
	anim_tree.set(P_AIR, _current_air_blend)

func _calc_fall_blend() -> float:
	if player.is_on_floor() or _get_vel_y() >= fall_threshold:
		return 0.0
	var elapsed := _air_time - fall_ramp_delay
	if elapsed <= 0.0:
		return 0.0
	var ramp_progress := clampf(elapsed / fall_ramp_time, 0.0, 1.0)
	return smoothstep(0.0, 1.0, ramp_progress)
