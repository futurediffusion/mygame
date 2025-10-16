extends ModuleBase
class_name StateMachineModule

enum State {
	IDLE,
	MOVE,
	DODGE,
	JUMP,
	SNEAK,
}

signal state_changed(new_state: State, previous_state: State)

var _owner_body: CharacterBody3D
var _movement: MovementModule
var _jump: JumpModule
var _dodge: DodgeModule
var _orientation: OrientationModule
var _capabilities: Capabilities

var _current_state: State = State.IDLE
var _intent_move_dir: Vector3 = Vector3.ZERO
var _intent_is_sprinting: bool = false
var _intent_want_dodge: bool = false
var _intent_want_attack: bool = false
var _intent_want_jump: bool = false

func setup(owner_body: CharacterBody3D) -> void:
	_owner_body = owner_body
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	_movement = _fetch_module("Movement") as MovementModule
	_jump = _fetch_module("Jump") as JumpModule
	_dodge = _fetch_module("Dodge") as DodgeModule
	_orientation = _fetch_module("Orientation") as OrientationModule
	_refresh_capabilities()

func set_intents(move_dir: Vector3, is_sprinting: bool, want_dodge: bool, want_attack: bool, want_jump: bool) -> void:
	if not move_dir.is_finite():
		move_dir = Vector3.ZERO
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()
	_intent_move_dir = move_dir
	_intent_is_sprinting = is_sprinting
	_intent_want_dodge = want_dodge
	_intent_want_attack = want_attack
	_intent_want_jump = want_jump

func change_state(new_state: State) -> void:
	if new_state == _current_state:
		return
	var previous := _current_state
	_current_state = new_state
	state_changed.emit(new_state, previous)

func physics_tick(_dt: float) -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return
	_refresh_capabilities()
	if _owner_body.has_method("should_skip_module_updates") and _owner_body.should_skip_module_updates():
		_apply_movement(Vector3.ZERO, false)
		return
	var move_dir := _sanitize_move_dir(_intent_move_dir)
	var sprinting := _intent_is_sprinting
	if _capabilities != null and not _capabilities.can_move:
		move_dir = Vector3.ZERO
		sprinting = false
	_apply_movement(move_dir, sprinting)
	var triggered_dodge := _apply_dodge_intent(move_dir)
	var triggered_jump := _apply_jump_intent()
	var new_state := _resolve_state(move_dir, triggered_jump, triggered_dodge)
	change_state(new_state)

func _apply_movement(move_dir: Vector3, is_sprinting: bool) -> void:
	if _movement != null and is_instance_valid(_movement):
		_movement.set_frame_input(move_dir, is_sprinting)
	if _orientation != null and is_instance_valid(_orientation):
		_orientation.set_frame_input(move_dir)

func _apply_dodge_intent(move_dir: Vector3) -> bool:
	if not _intent_want_dodge:
		return false
	if _dodge == null or not is_instance_valid(_dodge):
		return false
	var desired_dir := move_dir
	if desired_dir.length_squared() < 0.0001:
		desired_dir = _default_forward_dir()
	return _dodge.request_roll(desired_dir)

func _apply_jump_intent() -> bool:
	if not _intent_want_jump:
		return false
	if _jump == null or not is_instance_valid(_jump):
		return false
	return _jump.request_jump()

func _resolve_state(move_dir: Vector3, triggered_jump: bool, triggered_dodge: bool) -> State:
	if _dodge != null and is_instance_valid(_dodge) and _dodge.is_rolling():
		return State.DODGE
	if triggered_dodge:
		return State.DODGE
	if triggered_jump:
		return State.JUMP
	if _owner_body != null and is_instance_valid(_owner_body) and not _owner_body.is_on_floor():
		if triggered_jump:
			return State.JUMP
	var move_len := move_dir.length_squared()
	if move_len > 0.0001 and _capabilities_allows_move():
		if _is_owner_sneaking():
			return State.SNEAK
		return State.MOVE
	return State.IDLE

func _default_forward_dir() -> Vector3:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return Vector3.ZERO
	var basis := _owner_body.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	if not forward.is_finite():
		return Vector3.ZERO
	return forward.normalized()

func _capabilities_allows_move() -> bool:
	if _capabilities == null:
		return true
	return _capabilities.can_move

func _is_owner_sneaking() -> bool:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return false
	if _owner_body.has_method("is_sneaking"):
		var result_variant: Variant = _owner_body.call("is_sneaking")
		if result_variant is bool:
			return result_variant
		return bool(result_variant)
	return false

func _sanitize_move_dir(move_dir: Vector3) -> Vector3:
	if not move_dir.is_finite():
		return Vector3.ZERO
	if move_dir.length_squared() > 1.0:
		return move_dir.normalized()
	return move_dir

func _fetch_module(name: String) -> Node:
	if _owner_body == null or not is_instance_valid(_owner_body):
		return null
	var modules_node := _owner_body.get_node_or_null("Modules")
	if modules_node != null and is_instance_valid(modules_node):
		var from_modules := modules_node.get_node_or_null(name)
		if from_modules != null and is_instance_valid(from_modules):
			return from_modules
	return _owner_body.get_node_or_null(name)

func _refresh_capabilities() -> void:
	if _owner_body == null or not is_instance_valid(_owner_body):
		_capabilities = null
		return
	if "capabilities" in _owner_body:
		var caps_variant: Variant = _owner_body.get("capabilities")
		if caps_variant is Capabilities:
			_capabilities = caps_variant
			return
	_capabilities = null
