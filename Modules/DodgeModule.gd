extends ModuleBase
class_name DodgeModule

@export var stamina_cost: float = 20.0
@export var roll_time: float = 0.5
@export var roll_speed: float = 24.0
@export var iframe_start: float = 0.08
@export var iframe_end: float = 0.28
@export var allow_in_air: bool = false
@export var preserve_floor_snap: bool = true

var player: CharacterBody3D
var anim_module: AnimationCtrlModule
var stamina: Stamina

var _rolling: bool = false
var _t: float = 0.0
var _dir: Vector3 = Vector3.ZERO
var _saved_floor_snap_len: float = 0.0
var _has_saved_floor_snap: bool = false

func setup(owner_body: CharacterBody3D, animation_ctrl: AnimationCtrlModule = null, _audio_ctrl: AudioCtrlModule = null) -> void:
	player = owner_body
	if player == null or not is_instance_valid(player):
		return
	if animation_ctrl != null and is_instance_valid(animation_ctrl):
		anim_module = animation_ctrl
	else:
		anim_module = player.get_node_or_null("Modules/AnimationCtrl") as AnimationCtrlModule
		if anim_module == null:
			anim_module = player.get_node_or_null("AnimationCtrl") as AnimationCtrlModule
	if "stamina" in player:
		stamina = player.stamina

func physics_tick(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _should_skip_updates():
		if _rolling:
			_end_roll()
		return
	if _rolling:
		_update_roll(dt)
	else:
		_check_input()

func is_rolling() -> bool:
	return _rolling

func _check_input() -> void:
	if not Input.is_action_just_pressed("roll"):
		return
	if not allow_in_air and not player.is_on_floor():
		return
	if not _has_required_stamina():
		return
	_start_roll()

func _start_roll() -> void:
	_rolling = true
	_t = 0.0
	_dir = _resolve_direction()
	if _dir.length_squared() > 0.0001:
		_dir = _dir.normalized()
	else:
		_dir = Vector3.ZERO
	_consume_stamina()
	_cache_floor_snap()
	if preserve_floor_snap:
		player.floor_snap_length = 0.0
	if anim_module != null and is_instance_valid(anim_module):
		anim_module.play_dodge()

func _update_roll(dt: float) -> void:
	_t += dt
	var invul := _t >= iframe_start and _t <= iframe_end
	_set_invulnerability(invul)
	var duration := maxf(roll_time, 0.001)
	var normalized := clampf(_t / duration, 0.0, 1.0)
	var decay := clampf(1.0 - normalized, 0.0, 1.0)
	var speed := roll_speed * (0.6 + 0.4 * decay)
	player.velocity.x = _dir.x * speed
	player.velocity.z = _dir.z * speed
	if _t >= duration:
		_end_roll()

func _end_roll() -> void:
	_rolling = false
	_t = 0.0
	_set_invulnerability(false)
	_restore_floor_snap()

func _resolve_direction() -> Vector3:
	var move_dir := Vector3.ZERO
	if player != null and is_instance_valid(player):
		var cache_variant: Variant = player.call("get_input_cache") if player.has_method("get_input_cache") else null
		if cache_variant is Dictionary:
			var cache_dict := cache_variant as Dictionary
			var move_record_variant: Variant = cache_dict.get("move")
			if move_record_variant is Dictionary:
				var move_record := move_record_variant as Dictionary
				var camera_dir_variant: Variant = move_record.get("camera")
				if camera_dir_variant is Vector3:
					var camera_dir := camera_dir_variant as Vector3
					move_dir = camera_dir
		if move_dir.length_squared() < 0.0001:
			var basis := player.global_transform.basis
			move_dir = -basis.z
		move_dir.y = 0.0
	if not move_dir.is_finite():
		move_dir = Vector3.ZERO
	return move_dir

func _has_required_stamina() -> bool:
	if stamina == null or not is_instance_valid(stamina):
		return true
	var cost := maxf(stamina_cost, 0.0)
	return stamina.value >= cost

func _consume_stamina() -> void:
	if stamina == null or not is_instance_valid(stamina):
		return
	var cost := maxf(stamina_cost, 0.0)
	if cost <= 0.0:
		return
	stamina.value = maxf(0.0, stamina.value - cost)

func _set_invulnerability(enabled: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if "invulnerable" in player:
		player.invulnerable = enabled
		return
	if player.has_method("set_invulnerable"):
		player.call("set_invulnerable", enabled)
		return
	player.set("invulnerable", enabled)

func _cache_floor_snap() -> void:
	if not preserve_floor_snap:
		return
	if player == null or not is_instance_valid(player):
		_has_saved_floor_snap = false
		return
	_saved_floor_snap_len = player.floor_snap_length
	_has_saved_floor_snap = true

func _restore_floor_snap() -> void:
	if not preserve_floor_snap:
		return
	if not _has_saved_floor_snap:
		return
	if player == null or not is_instance_valid(player):
		_has_saved_floor_snap = false
		return
	player.floor_snap_length = _saved_floor_snap_len
	_has_saved_floor_snap = false

func _should_skip_updates() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player.has_method("should_skip_module_updates"):
		return false
	var skip_variant: Variant = player.call("should_skip_module_updates")
	if skip_variant is bool:
		return skip_variant
	return bool(skip_variant)
