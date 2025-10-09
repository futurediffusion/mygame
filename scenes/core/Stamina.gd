extends Node
class_name Stamina

# ============================================================================
# STAMINA CONFIGURATION
# ============================================================================
@export_group("Capacity")
@export_range(10.0, 500.0, 1.0) var max_stamina: float = 100.0
@export_range(0.0, 1.0, 0.01) var sprint_threshold_percent: float = 0.08

@export_group("Consumption")
@export_range(1.0, 100.0, 0.5) var sprint_drain_per_s: float = 18.0

@export_group("Regeneration")
@export_range(1.0, 100.0, 0.5) var regen_per_s: float = 11.0
@export_range(0.0, 5.0, 0.1) var regen_delay: float = 0.6

# ============================================================================
# STATE
# ============================================================================
var current_value: float
var _regen_cooldown: float = 0.0

# Cached values
var _sprint_threshold: float
var _is_depleted: bool = false

# ============================================================================
# SIGNALS (for UI updates, particle effects, etc.)
# ============================================================================
signal stamina_changed(current: float, maximum: float, percent: float)
signal stamina_depleted()
signal stamina_regeneration_started()
signal sprint_available()

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	_initialize_stamina()
	_cache_thresholds()

func _initialize_stamina() -> void:
	current_value = max_stamina
	_regen_cooldown = 0.0

func _cache_thresholds() -> void:
	_sprint_threshold = max_stamina * sprint_threshold_percent

# ============================================================================
# PUBLIC API - State Queries
# ============================================================================
func can_sprint() -> bool:
	"""Returns true if player has enough stamina to sprint"""
	return current_value > _sprint_threshold

func is_full() -> bool:
	"""Returns true if stamina is at maximum capacity"""
	return current_value >= max_stamina

func is_regenerating() -> bool:
	"""Returns true if stamina is currently recovering"""
	return _regen_cooldown <= 0.0 and current_value < max_stamina

func get_percent() -> float:
	"""Returns stamina as percentage (0.0 to 1.0)"""
	return clampf(current_value / max_stamina, 0.0, 1.0)

func get_percent_clamped(min_threshold: float = 0.0, max_threshold: float = 1.0) -> float:
	"""Returns stamina remapped to a custom range"""
	var percent: float = get_percent()
	return inverse_lerp(min_threshold, max_threshold, percent)

# ============================================================================
# PUBLIC API - State Modification
# ============================================================================
func consume_for_sprint(delta: float) -> void:
	"""Consumes stamina for sprinting and blocks regeneration"""
	var drain_amount: float = sprint_drain_per_s * delta
	_consume(drain_amount)
	_block_regeneration()

func consume_instant(amount: float) -> void:
	"""Instantly consume stamina (for abilities, dodges, etc.)"""
	_consume(amount)
	_block_regeneration()

func restore_instant(amount: float) -> void:
	"""Instantly restore stamina (for pickups, abilities, etc.)"""
	_add_stamina(amount)

func refill_full() -> void:
	"""Instantly refill stamina to maximum"""
	_set_stamina(max_stamina)

func set_to_percent(percent: float) -> void:
	"""Set stamina to a specific percentage of max"""
	_set_stamina(max_stamina * clampf(percent, 0.0, 1.0))

# ============================================================================
# CORE UPDATE LOOP
# ============================================================================
func tick(delta: float) -> void:
	"""Main update function - call this every frame from parent"""
	_update_regeneration_cooldown(delta)
	_update_regeneration(delta)

# ============================================================================
# INTERNAL - Regeneration System
# ============================================================================
func _update_regeneration_cooldown(delta: float) -> void:
	if _regen_cooldown <= 0.0:
		return
	
	_regen_cooldown -= delta
	
	if _regen_cooldown <= 0.0:
		stamina_regeneration_started.emit()

func _update_regeneration(delta: float) -> void:
	if _regen_cooldown > 0.0 or current_value >= max_stamina:
		return
	
	var regen_amount: float = regen_per_s * delta
	_add_stamina(regen_amount)

func _block_regeneration() -> void:
	_regen_cooldown = regen_delay

# ============================================================================
# INTERNAL - Value Manipulation
# ============================================================================
func _consume(amount: float) -> void:
	var previous_value: float = current_value
	current_value = maxf(0.0, current_value - amount)
	
	_emit_change_signals(previous_value)
	_check_depletion()

func _add_stamina(amount: float) -> void:
	var previous_value: float = current_value
	current_value = minf(max_stamina, current_value + amount)
	
	_emit_change_signals(previous_value)
	_check_availability()

func _set_stamina(value: float) -> void:
	var previous_value: float = current_value
	current_value = clampf(value, 0.0, max_stamina)
	
	_emit_change_signals(previous_value)

# ============================================================================
# INTERNAL - Signal Management
# ============================================================================
func _emit_change_signals(previous_value: float) -> void:
	if abs(current_value - previous_value) < 0.001:
		return
	
	stamina_changed.emit(current_value, max_stamina, get_percent())

func _check_depletion() -> void:
	if _is_depleted or current_value > 0.0:
		return
	
	_is_depleted = true
	stamina_depleted.emit()

func _check_availability() -> void:
	if not _is_depleted:
		return
	
	if current_value > _sprint_threshold:
		_is_depleted = false
		sprint_available.emit()

# ============================================================================
# DEBUG UTILITIES
# ============================================================================
func _to_string() -> String:
	return "Stamina(%.1f/%.1f = %.0f%%, regen_in=%.2fs)" % [
		current_value,
		max_stamina,
		get_percent() * 100.0,
		maxf(0.0, _regen_cooldown)
	]

func get_debug_info() -> Dictionary:
	"""Returns stamina state as dictionary for debugging/UI"""
	return {
		"current": current_value,
		"max": max_stamina,
		"percent": get_percent(),
		"can_sprint": can_sprint(),
		"is_regenerating": is_regenerating(),
		"regen_cooldown": maxf(0.0, _regen_cooldown),
		"is_depleted": _is_depleted
	}
