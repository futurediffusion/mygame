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
var capabilities: Capabilities
var _state_machine: StateMachineModule

var _rolling: bool = false
var _t: float = 0.0
var _dir: Vector3 = Vector3.ZERO
var _saved_floor_snap_len: float = 0.0
var _has_saved_floor_snap: bool = false
var _queued_roll_dir: Vector3 = Vector3.ZERO
var _has_queued_roll: bool = false
var _just_started: bool = false
var _just_finished: bool = false

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
	if "capabilities" in player:
		var caps_variant: Variant = player.get("capabilities")
		if caps_variant is Capabilities:
			capabilities = caps_variant
	_state_machine = _resolve_state_machine()

func physics_tick(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_just_started = false
	_just_finished = false
	if _should_skip_updates():
		if _rolling:
			_end_roll()
		return
	if _rolling:
		_update_roll(dt)
		return
	if _has_queued_roll:
		var queued_dir := _queued_roll_dir
		_has_queued_roll = false
		_start_roll(queued_dir)
		return

func is_rolling() -> bool:
	return _rolling

func can_start() -> bool:
	if _rolling:
		return false
	if player == null or not is_instance_valid(player):
		return false
	if capabilities != null and not capabilities.can_dodge:
		return false
	if not allow_in_air and not player.is_on_floor():
		return false
	return _has_required_stamina()


func start_dodge(dir: Vector3) -> bool:
	if not can_start():
		return false
	var desired_dir := _sanitize_direction(dir)
	if desired_dir.length_squared() < 0.0001:
		desired_dir = _fallback_direction()
	_has_queued_roll = true
	_queued_roll_dir = desired_dir
	return true

func finished() -> bool:
	return _just_finished

func just_fired() -> bool:
	return _just_started

func _start_roll(dir: Vector3) -> void:
	if _rolling:
		return
	if capabilities != null and not capabilities.can_dodge:
		return
	_rolling = true
	_t = 0.0
	_dir = dir
	if _dir.length_squared() > 0.0001:
		_dir = _dir.normalized()
	else:
		_dir = Vector3.ZERO
	_consume_stamina()
	_cache_floor_snap()
	if preserve_floor_snap:
		player.floor_snap_length = 0.0
	_notify_player_roll_state(true)
	_just_started = true
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
	_notify_player_roll_state(false)
	_just_finished = true

func _sanitize_direction(dir: Vector3) -> Vector3:
	if not dir.is_finite():
		return Vector3.ZERO
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return Vector3(dir.x, 0.0, dir.z)

func _fallback_direction() -> Vector3:
	var state_machine := _resolve_state_machine()
	if state_machine != null and is_instance_valid(state_machine):
		var intent := state_machine.get_move_intent()
		if intent.length_squared() > 0.0001:
			var flattened := Vector3(intent.x, 0.0, intent.z)
			if flattened.length_squared() > 0.0001:
				return flattened.normalized()
	return _get_player_forward_dir()

func _get_player_forward_dir() -> Vector3:
	if player == null or not is_instance_valid(player):
		return Vector3.ZERO
	var basis := player.global_transform.basis
	if "model" in player:
		var model_variant: Variant = player.get("model")
		if model_variant is Node3D:
			var model_node := model_variant as Node3D
			if model_node != null and is_instance_valid(model_node):
				basis = model_node.global_transform.basis
	var forward := basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.BACK
	if not forward.is_finite():
		return Vector3.ZERO
	return forward.normalized()

func _resolve_state_machine() -> StateMachineModule:
	if _state_machine != null and is_instance_valid(_state_machine):
		return _state_machine
	if player == null or not is_instance_valid(player):
		_state_machine = null
		return null
	var modules_node := player.get_node_or_null("Modules")
	if modules_node != null and is_instance_valid(modules_node):
		var candidate := modules_node.get_node_or_null("StateMachine") as StateMachineModule
		if candidate != null:
			_state_machine = candidate
			return _state_machine
	var direct := player.get_node_or_null("StateMachine") as StateMachineModule
	if direct != null:
		_state_machine = direct
	return _state_machine

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

func _notify_player_roll_state(active: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("set_roll_collider_override"):
		return
	player.call("set_roll_collider_override", active)

func _should_skip_updates() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player.has_method("should_skip_module_updates"):
		return false
	var skip_variant: Variant = player.call("should_skip_module_updates")
	if skip_variant is bool:
		return skip_variant
	return bool(skip_variant)
