extends Node
class_name PerfectJumpCombo

@export var perfect_window: float = 0.15
@export var combo_curve_gamma: float = 0.5
@export var combo_speed_bonus_max: float = 3.0
@export_range(1.0, 2.0, 0.01) var combo_jump_bonus_max: float = 2.0

const MAX_JUMP_LEVEL: int = 100

var _body: CharacterBody3D
var _was_on_floor: bool = false
var _landed_timer: float = 0.0
var _combo_count: int = 0
var _pending_landed: bool = false

var capabilities: Capabilities

signal combo_changed(value: int)
signal perfect_jump()
signal combo_reset()

const STATE_MODULE_SCRIPT := preload("res://Modules/State.gd")

func _ready() -> void:
	_body = _resolve_body()
	if _body != null and _body.is_on_floor():
		_was_on_floor = true
	_resolve_capabilities()
	_autowire_state_module(_body)

func physics_tick(delta: float) -> void:
	var body := _get_body()
	if body == null:
		_reset_timers()
		return
	var on_floor := body.is_on_floor()
	var just_landed := false
	if _pending_landed:
		_open_perfect_window()
		just_landed = true
		_pending_landed = false
	elif on_floor and not _was_on_floor:
		_open_perfect_window()
		just_landed = true
	on_floor = on_floor or just_landed
	_was_on_floor = on_floor
	if on_floor:
		if _landed_timer > 0.0:
			_landed_timer = max(_landed_timer - delta, 0.0)
	else:
		_landed_timer = 0.0

func on_landed() -> void:
	_open_perfect_window()
	_was_on_floor = true
	_pending_landed = true

func register_jump(was_perfect: bool) -> void:
	if capabilities != null and not capabilities.can_jump:
		return
	if was_perfect:
		var previous := _combo_count
		_combo_count = min(_combo_count + 1, MAX_JUMP_LEVEL)
		if _combo_count != previous:
			combo_changed.emit(_combo_count)
		perfect_jump.emit()
	else:
		if _combo_count != 0:
			_combo_count = 0
			combo_changed.emit(_combo_count)
			combo_reset.emit()
	_landed_timer = 0.0

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
	return MAX_JUMP_LEVEL

func is_in_perfect_window() -> bool:
	return _landed_timer > 0.0 and _was_on_floor

func get_multipliers() -> Dictionary:
	var ratio := _progress_ratio()
	var eased := _eased_speed_ratio(ratio)
	return {
		"speed_mult": lerp(1.0, combo_speed_bonus_max, eased),
		"jump_mult": lerp(1.0, combo_jump_bonus_max, ratio)
	}

func speed_multiplier() -> float:
	return get_multipliers().get("speed_mult", 1.0)

func jump_multiplier() -> float:
	return get_multipliers().get("jump_mult", 1.0)

func _progress_ratio() -> float:
	if MAX_JUMP_LEVEL <= 0:
		return 0.0
	return clampf(float(_combo_count) / float(MAX_JUMP_LEVEL), 0.0, 1.0)

func _eased_speed_ratio(ratio: float) -> float:
	if ratio <= 0.0:
		return 0.0
	if ratio >= 1.0:
		return 1.0
	var gamma := maxf(combo_curve_gamma, 0.0001)
	return clampf(pow(ratio, gamma), 0.0, 1.0)

func _open_perfect_window() -> void:
	_landed_timer = max(perfect_window, 0.0)

func _reset_timers() -> void:
	_landed_timer = 0.0
	_was_on_floor = false
	_pending_landed = false

func _get_body() -> CharacterBody3D:
	if _body != null and is_instance_valid(_body):
		return _body
	_body = _resolve_body()
	_resolve_capabilities()
	_autowire_state_module(_body)
	return _body

func _resolve_body() -> CharacterBody3D:
	var candidate: Object = owner
	if candidate is CharacterBody3D and is_instance_valid(candidate):
		return candidate
	candidate = get_parent()
	if candidate is CharacterBody3D and is_instance_valid(candidate):
		return candidate
	return null

func _autowire_state_module(body: CharacterBody3D = null) -> void:
	var carrier := body
	if carrier == null:
		carrier = _get_body()
	if carrier == null or not is_instance_valid(carrier):
		return
	var state_node: Node = null
	if carrier.has_node("Modules/State"):
		state_node = carrier.get_node_or_null("Modules/State")
	elif carrier.has_node("State"):
		state_node = carrier.get_node_or_null("State")
	if state_node == null or not is_instance_valid(state_node):
		return
	if state_node is STATE_MODULE_SCRIPT:
		var state_module := state_node as StateModule
		if state_module != null and not state_module.landed.is_connected(_on_state_module_landed):
			state_module.landed.connect(_on_state_module_landed)

func _on_state_module_landed(_is_hard: bool) -> void:
	on_landed()

func _resolve_capabilities() -> void:
	var carrier: Object = _body
	if carrier == null or not is_instance_valid(carrier):
		carrier = owner
	if carrier == null:
		return
	if "capabilities" in carrier:
		var caps_variant: Variant = carrier.get("capabilities")
		if caps_variant is Capabilities:
			capabilities = caps_variant

