extends Node
class_name PerfectJumpCombo

signal combo_changed(value: int)
signal perfect_jump()
signal combo_reset()

@export var window_ms: int = 120:
	set(value):
		_window_ms = max(value, 0)
	get:
		return _window_ms
@export var bonus_speed: float = 1.15
@export var bonus_jump: float = 1.08
@export var max_combo: int = 100

var capabilities: Capabilities

var _window_ms: int = 120
var _combo_count: int = 0
var _last_jump_time_ms: int = -999999
var _armed: bool = false
var _player: Node
var _jump_node: Object

func _ready() -> void:
	if owner != null and is_instance_valid(owner):
		setup(owner)

func _exit_tree() -> void:
	_disconnect_signals()

func setup(player: Node) -> void:
	_disconnect_signals()
	_player = null
	if player == null or not is_instance_valid(player):
		return
	_player = player
	_connect_jump_signal(player)
	_connect_landed_signal(player)
	_resolve_capabilities()

func physics_tick(_delta: float) -> void:
	pass

func on_landed() -> void:
	_on_landed(0.0)

func register_jump(was_perfect: bool) -> void:
	if capabilities != null and not capabilities.can_jump:
		return
	if was_perfect:
		var previous := _combo_count
		_combo_count = min(_combo_count + 1, _max_jump_level())
		if _combo_count != previous:
			combo_changed.emit(_combo_count)
		perfect_jump.emit()
	else:
		if _combo_count != 0:
			_combo_count = 0
			combo_changed.emit(_combo_count)
			combo_reset.emit()

func register_perfect() -> void:
	register_jump(true)

func register_failed_jump() -> void:
	register_jump(false)

func reset_combo() -> void:
	if _combo_count == 0:
		return
	_combo_count = 0
	combo_changed.emit(_combo_count)
	combo_reset.emit()

func get_combo() -> int:
	return _combo_count

func get_jump_level() -> int:
	return _combo_count

func get_max_jump_level() -> int:
	return _max_jump_level()

func is_in_perfect_window() -> bool:
	return _armed and (Time.get_ticks_msec() - _last_jump_time_ms) <= _window_ms

func get_multipliers() -> Dictionary:
	if _combo_count <= 0:
		return {
			"speed_mult": 1.0,
			"jump_mult": 1.0
		}
	return {
		"speed_mult": max(bonus_speed, 1.0),
		"jump_mult": max(bonus_jump, 1.0)
	}

func speed_multiplier() -> float:
	return get_multipliers().get("speed_mult", 1.0)

func jump_multiplier() -> float:
	return get_multipliers().get("jump_mult", 1.0)

func _connect_jump_signal(player: Node) -> void:
	var jump_node := _resolve_jump_node(player)
	if jump_node == null:
		_jump_node = null
		return
	_jump_node = jump_node
	if jump_node.has_signal("jump_performed") and not jump_node.jump_performed.is_connected(_on_jump_performed):
		jump_node.jump_performed.connect(_on_jump_performed)

func _connect_landed_signal(player: Node) -> void:
	if player.has_signal("landed") and not player.landed.is_connected(_on_landed):
		player.landed.connect(_on_landed)

func _disconnect_signals() -> void:
	if _jump_node != null and is_instance_valid(_jump_node) and _jump_node.has_signal("jump_performed"):
		if _jump_node.jump_performed.is_connected(_on_jump_performed):
			_jump_node.jump_performed.disconnect(_on_jump_performed)
	_jump_node = null
	if _player != null and is_instance_valid(_player) and _player.has_signal("landed"):
		if _player.landed.is_connected(_on_landed):
			_player.landed.disconnect(_on_landed)

func _on_jump_performed(_impulse: float) -> void:
	if capabilities != null and not capabilities.can_jump:
		return
	_last_jump_time_ms = Time.get_ticks_msec()
	_armed = true

func _on_landed(_impact: float) -> void:
	if not _armed:
		return
	if capabilities != null and not capabilities.can_jump:
		_armed = false
		return
	var elapsed := Time.get_ticks_msec() - _last_jump_time_ms
	var window := max(_window_ms, 0)
	if elapsed <= window:
		register_jump(true)
		_apply_bonus()
	else:
		register_jump(false)
	_armed = false

func _apply_bonus() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var speed_mult := max(bonus_speed, 1.0)
	var jump_mult := max(bonus_jump, 1.0)
	if _player.has_method("apply_perfect_jump_bonus"):
		_player.apply_perfect_jump_bonus(speed_mult, jump_mult)

func _resolve_jump_node(player: Node) -> Object:
	if player.has_node("Modules/Jump"):
		var module_jump := player.get_node_or_null("Modules/Jump")
		if module_jump != null and is_instance_valid(module_jump):
			return module_jump
	if player.has_node("Jump"):
		var direct_jump := player.get_node_or_null("Jump")
		if direct_jump != null and is_instance_valid(direct_jump):
			return direct_jump
	if "m_jump" in player:
		var member_jump := player.get("m_jump")
		if member_jump is Node and is_instance_valid(member_jump):
			return member_jump
	return null

func _resolve_capabilities() -> void:
	var carrier: Object = _player
	if carrier == null or not is_instance_valid(carrier):
		carrier = owner
	if carrier == null:
		return
	if "capabilities" in carrier:
		var caps_variant: Variant = carrier.get("capabilities")
		if caps_variant is Capabilities:
			capabilities = caps_variant

func _max_jump_level() -> int:
	return max(max_combo, 1)
