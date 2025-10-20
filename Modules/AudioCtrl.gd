extends ModuleBase
class_name AudioCtrlModule

var player: CharacterBody3D
var jump_sfx: AudioStreamPlayer3D = null
var land_sfx: AudioStreamPlayer3D = null
var footstep_sfx: AudioStreamPlayer3D = null

const FOOTSTEP_PITCH_WALK := 1.0
const FOOTSTEP_PITCH_SNEAK := pow(2.0, -4.0 / 12.0)
# Keep regular footsteps at neutral pitch; sneaking remains slightly lower at -4 semitones.
const DEFAULT_FOOTSTEP_VOLUME_WALK_DB := -5.0
const DEFAULT_FOOTSTEP_VOLUME_SNEAK_DB := -8.0
const DEFAULT_SNEAK_PERIOD_MULTIPLIER := 1.9

@export var use_timer_footsteps := false
@export_range(0.0, 5.0, 0.05) var footstep_min_speed: float = 0.5
@export_range(0.0, 5.0, 0.05) var footstep_min_speed_sneak: float = 0.2
@export_range(0.1, 2.0, 0.01) var footstep_period_slow: float = 0.5
@export_range(0.1, 2.0, 0.01) var footstep_period_fast: float = 0.28
@export_range(0.5, 2.0, 0.01) var footstep_period_bias: float = 1.05
@export_range(1.0, 3.0, 0.01) var footstep_sneak_period_multiplier: float = DEFAULT_SNEAK_PERIOD_MULTIPLIER
@export_range(-80.0, 24.0, 0.1) var footstep_volume_walk_db: float = DEFAULT_FOOTSTEP_VOLUME_WALK_DB
@export_range(-80.0, 24.0, 0.1) var footstep_volume_sneak_db: float = DEFAULT_FOOTSTEP_VOLUME_SNEAK_DB
@export var auto_detect_sneak_on_play := true
@export var footstep_pitch_range_walk := Vector2(FOOTSTEP_PITCH_WALK - 0.01, FOOTSTEP_PITCH_WALK + 0.01)
@export var footstep_pitch_range_sneak := Vector2(FOOTSTEP_PITCH_SNEAK - 0.01, FOOTSTEP_PITCH_SNEAK + 0.01)
var _footstep_timer := 0.0

func setup(p: CharacterBody3D) -> void:
	player = p
	jump_sfx = _extract_stream_player(&"jump_sfx", ^"JumpSFX")
	land_sfx = _extract_stream_player(&"land_sfx", ^"LandSFX")
	footstep_sfx = _extract_stream_player(&"footstep_sfx", ^"FootstepSFX")

func _extract_stream_player(property_name: StringName, fallback_path: NodePath) -> AudioStreamPlayer3D:
	if player == null or not is_instance_valid(player):
		return null
	var candidate: Variant = null
	for property_data in player.get_property_list():
		if not (property_data is Dictionary):
			continue
		var name_value := property_data.get("name")
		if StringName(name_value) == property_name:
			candidate = player.get(property_name)
			break
	if candidate is AudioStreamPlayer3D:
		return candidate
	if fallback_path != NodePath():
		var fallback := player.get_node_or_null(fallback_path)
		if fallback is AudioStreamPlayer3D:
			return fallback
	return null

func physics_tick(delta: float) -> void:
	if not use_timer_footsteps:
		return
	if player == null or not is_instance_valid(player):
		return
	if not player.is_on_floor():
		_footstep_timer = 0.0
		return
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var is_sneaking := _is_player_sneaking()
	var min_speed := footstep_min_speed_sneak if is_sneaking else footstep_min_speed
	if hspeed < min_speed:
		_footstep_timer = 0.0
		return
	var step_period := _calculate_step_period(hspeed, is_sneaking)
	_footstep_timer += delta
	if _footstep_timer >= step_period:
		_footstep_timer -= step_period
		play_footstep()

func play_jump() -> void:
	if is_instance_valid(jump_sfx):
		jump_sfx.play()

func play_landing(is_hard: bool) -> void:
	if not is_instance_valid(land_sfx) or land_sfx.stream == null:
		return
	land_sfx.volume_db = -6.0 if is_hard else -12.0
	land_sfx.pitch_scale = 0.95 if is_hard else 1.05
	land_sfx.play()

func play_footstep(is_sneaking: Variant = null) -> void:
	if not is_instance_valid(footstep_sfx):
		return
	if player == null or not is_instance_valid(player):
		return
	if not player.is_on_floor():
		return
	var resolved_sneak := _resolve_sneak_state(is_sneaking)
	var volume := footstep_volume_sneak_db if resolved_sneak else footstep_volume_walk_db
	footstep_sfx.volume_db = volume
	var pitch_range := footstep_pitch_range_sneak if resolved_sneak else footstep_pitch_range_walk
	var pitch_min := minf(pitch_range.x, pitch_range.y)
	var pitch_max := maxf(pitch_range.x, pitch_range.y)
	footstep_sfx.pitch_scale = randf_range(pitch_min, pitch_max)
	footstep_sfx.play()

func _calculate_step_period(speed: float, is_sneaking: bool) -> float:
	var target_speed := speed
	if "sprint_speed" in player:
		target_speed = maxf(player.sprint_speed, 0.01)
	if is_sneaking and "walk_speed" in player:
		target_speed = maxf(player.walk_speed, 0.01)
	var speed_ratio := 0.0
	if target_speed > 0.0:
		speed_ratio = clampf(speed / target_speed, 0.0, 1.0)
	var slow_period := maxf(footstep_period_slow, 0.01)
	var fast_period := maxf(footstep_period_fast, 0.01)
	var base_period := lerpf(slow_period, fast_period, speed_ratio)
	base_period *= maxf(footstep_period_bias, 0.01)
	if is_sneaking:
		base_period *= maxf(footstep_sneak_period_multiplier, 1.0)
	return maxf(base_period, 0.01)

func _is_player_sneaking() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if player.has_method("get_context_state"):
		var ctx_value: Variant = player.get_context_state()
		if typeof(ctx_value) == TYPE_INT:
			var ctx_enum: Variant = player.get("ContextState")
			if ctx_enum is Dictionary and ctx_enum.has("SNEAK"):
				if int(ctx_value) == int(ctx_enum["SNEAK"]):
					return true
			if int(ctx_value) == 1:
				return true
	if player.has_method("is_sneaking"):
		return bool(player.is_sneaking())
	return false

func _resolve_sneak_state(candidate: Variant) -> bool:
	if typeof(candidate) == TYPE_BOOL:
		return bool(candidate)
	if not auto_detect_sneak_on_play:
		return false
	return _is_player_sneaking()
