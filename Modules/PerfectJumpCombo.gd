extends Node
class_name PerfectJumpCombo
# Módulo autónomo: controla coyote, buffer, ventana de aterrizaje "perfect" y combo.

# --- Parámetros base ---
@export var base_jump_velocity: float = 12.5

# --- Calidad de salto ---
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12

# --- Perfect Jump Combo ---
@export var combo_max: int = 100
@export var perfect_window: float = 0.06
@export var combo_speed_bonus_max: float = 3.0
@export var combo_jump_bonus_max: float = 2.0
@export var combo_curve_gamma: float = 0.5  # 0.5 = sqrt → sube fuerte al inicio

# --- Estado interno ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _landed_timer: float = 0.0
var _was_on_floor: bool = false
var _combo_count: int = 0

# Señales opcionales (por si quieres UI/FX)
signal combo_changed(new_count: int, ratio: float)
signal perfect_window_opened(duration: float)

# ===== API PÚBLICA =====

func on_physics_step(delta: float, on_floor_now: bool) -> void:
	# Gestiona ventana perfect en aterrizaje
	if on_floor_now and not _was_on_floor:
		_landed_timer = perfect_window
		emit_signal("perfect_window_opened", perfect_window)
	_was_on_floor = on_floor_now

	if on_floor_now:
		if _landed_timer > 0.0:
			_landed_timer = max(_landed_timer - delta, 0.0)
	else:
		_landed_timer = 0.0

	# Coyote
	if on_floor_now:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	# Buffer
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

func on_jump_input_pressed() -> void:
	# Llamar cuando detectes el just_pressed de "jump"
	_jump_buffer_timer = jump_buffer

func consume_jump_if_available(on_floor_now: bool) -> float:
	# Devuelve el impulso Y (>0) si hay salto válido; 0.0 si no hay salto.
	if _jump_buffer_timer <= 0.0:
		return 0.0
	if _coyote_timer <= 0.0 and not on_floor_now:
		return 0.0

	var perfect := on_floor_now and (_landed_timer > 0.0)

	# Combo: si fue perfect, avanza; si no, reinicia.
	if perfect:
		var prev := _combo_count
		_combo_count = min(_combo_count + 1, combo_max)
		if _combo_count != prev:
			emit_signal("combo_changed", _combo_count, get_combo_ratio())
	else:
		if _combo_count != 0:
			_combo_count = 0
			emit_signal("combo_changed", _combo_count, 0.0)

	# Pulso de salto
	var impulse := base_jump_velocity * get_jump_multiplier()

	# Consumir timers/ventana
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_landed_timer = 0.0

	return impulse

func get_speed_multiplier() -> float:
	var r := get_combo_ratio()
	var eased := pow(r, combo_curve_gamma)
	return lerp(1.0, combo_speed_bonus_max, eased)

func get_jump_multiplier() -> float:
	var r := get_combo_ratio()
	var eased := pow(r, combo_curve_gamma)
	return lerp(1.0, combo_jump_bonus_max, eased)

func get_combo_ratio() -> float:
	return clamp(float(_combo_count) / float(max(1, combo_max)), 0.0, 1.0)

func reset_combo() -> void:
	if _combo_count != 0:
		_combo_count = 0
		emit_signal("combo_changed", _combo_count, 0.0)

func get_combo_count() -> int:
	return _combo_count
