extends Node3D
class_name CameraRig

# ============================================================================
# CAMERA POSITIONING
# ============================================================================
@export_group("Position")
@export_range(0.0, 5.0, 0.1) var height_offset: float = 1.5

@export_group("Look Sensitivity")
@export_range(0.01, 1.0, 0.01) var sensitivity_deg: float = 0.12
@export var invert_y: bool = false

@export_group("Smoothing")
@export_range(0.01, 0.5, 0.01) var smooth_time: float = 0.08

@export_group("Pitch Limits")
@export_range(-89.0, 0.0, 1.0) var min_pitch_deg: float = -60.0
@export_range(0.0, 89.0, 1.0) var max_pitch_deg: float = 60.0

@export_group("Zoom")
@export_range(0.5, 5.0, 0.1) var min_radius: float = 2.0
@export_range(5.0, 30.0, 0.5) var max_radius: float = 15.0
@export_range(0.5, 30.0, 0.5) var radius: float = 5.0
@export_range(0.1, 2.0, 0.1) var zoom_step: float = 0.5

@export_group("Field of View")
@export_range(50.0, 120.0, 1.0) var fov_default: float = 70.0
@export_range(0.0, 10.0, 0.5) var fov_kick_jump: float = 3.0
@export_range(0.0, 15.0, 0.5) var fov_kick_land_hard: float = 6.0

@export_group("Input")
@export var capture_on_start: bool = true

# ============================================================================
# CACHED NODES
# ============================================================================
@onready var yaw: Node3D = $Yaw
@onready var pitch: Node3D = $Yaw/Pitch
@onready var spring: SpringArm3D = $Yaw/Pitch/SpringArm3D
@onready var cam: Camera3D = $Yaw/Pitch/SpringArm3D/Camera3D

# ============================================================================
# INTERNAL STATE
# ============================================================================
var _current_yaw_deg: float = 0.0
var _current_pitch_deg: float = 15.0
var _target_yaw_deg: float = 0.0
var _target_pitch_deg: float = 15.0
var _target_radius: float = 5.0

# Cached values
var _y_invert_multiplier: float = 1.0
var _smooth_time_safe: float

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	_initialize_position()
	_initialize_rotation()
	_initialize_zoom()
	_initialize_camera()
	_configure_spring_arm()
	_setup_input_capture()
	_cache_constants()

func _initialize_position() -> void:
	position.y = height_offset

func _initialize_rotation() -> void:
	_current_yaw_deg = yaw.rotation_degrees.y
	_current_pitch_deg = clampf(pitch.rotation_degrees.x, min_pitch_deg, max_pitch_deg)
	_target_yaw_deg = _current_yaw_deg
	_target_pitch_deg = _current_pitch_deg

func _initialize_zoom() -> void:
	_target_radius = radius
	spring.spring_length = clampf(radius, min_radius, max_radius)

func _initialize_camera() -> void:
	if cam:
		cam.fov = fov_default

func _configure_spring_arm() -> void:
	# CRÍTICO: El SpringArm3D necesita collision_mask configurado
	# para detectar geometría del mundo y evitar atravesar paredes
	spring.collision_mask = 1  # Layer 1 para geometría del mundo
	spring.spring_length = radius
	spring.margin = 0.2  # Pequeño margen para evitar clipping
	
	# IMPORTANTE: Configurar shape para el raycast
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	spring.shape = shape

func _setup_input_capture() -> void:
	if capture_on_start:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _cache_constants() -> void:
	_y_invert_multiplier = -1.0 if invert_y else 1.0
	_smooth_time_safe = max(0.0001, smooth_time)

# ============================================================================
# INPUT HANDLING
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _handle_escape_key(event):
		return
	
	if _is_mouse_captured():
		_handle_mouse_motion(event)
		_handle_mouse_wheel(event)

func _handle_escape_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		return false
	
	_toggle_mouse_capture()
	return true

func _toggle_mouse_capture() -> void:
	var current_mode: Input.MouseMode = Input.get_mouse_mode()
	var new_mode: Input.MouseMode = (
		Input.MOUSE_MODE_VISIBLE if current_mode == Input.MOUSE_MODE_CAPTURED 
		else Input.MOUSE_MODE_CAPTURED
	)
	Input.set_mouse_mode(new_mode)

func _is_mouse_captured() -> bool:
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

func _handle_mouse_motion(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	_update_rotation_targets(motion.relative)

func _update_rotation_targets(mouse_delta: Vector2) -> void:
	_target_yaw_deg -= mouse_delta.x * sensitivity_deg
	_target_pitch_deg -= mouse_delta.y * sensitivity_deg * _y_invert_multiplier
	_target_pitch_deg = clampf(_target_pitch_deg, min_pitch_deg, max_pitch_deg)

func _handle_mouse_wheel(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	
	match button_event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_target_radius = maxf(min_radius, _target_radius - zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			_target_radius = minf(max_radius, _target_radius + zoom_step)

# ============================================================================
# UPDATE LOOP
# ============================================================================
func _process(delta: float) -> void:
	_maintain_height()
	_update_smooth_rotation(delta)
	_update_smooth_zoom(delta)
	_apply_transforms()

func _maintain_height() -> void:
	"""Mantiene la altura relativa al padre (Player)"""
	if abs(position.y - height_offset) > 0.001:
		position.y = height_offset

func _update_smooth_rotation(delta: float) -> void:
	var interpolation_factor: float = _calculate_smooth_factor(delta)
	
	_current_yaw_deg = _lerp_angle_deg(_current_yaw_deg, _target_yaw_deg, interpolation_factor)
	_current_pitch_deg = lerpf(_current_pitch_deg, _target_pitch_deg, interpolation_factor)

func _update_smooth_zoom(delta: float) -> void:
	var interpolation_factor: float = _calculate_smooth_factor(delta)
	radius = lerpf(radius, _target_radius, interpolation_factor)

func _calculate_smooth_factor(delta: float) -> float:
	return 1.0 - exp(-delta / _smooth_time_safe)

func _apply_transforms() -> void:
	yaw.rotation_degrees.y = _current_yaw_deg
	pitch.rotation_degrees.x = _current_pitch_deg
	spring.spring_length = clampf(radius, min_radius, max_radius)

func _lerp_angle_deg(from: float, to: float, weight: float) -> float:
	var difference: float = fposmod((to - from) + 180.0, 360.0) - 180.0
	return from + difference * weight

# ============================================================================
# FOV EFFECTS (Called from Player)
# ============================================================================
func _on_player_landed(is_hard: bool) -> void:
	if not cam:
		return
	
	var kick_intensity: float = fov_kick_land_hard if is_hard else (fov_kick_jump * 0.5)
	_apply_fov_kick(kick_intensity)

func _play_jump_kick() -> void:
	if not cam:
		return
	
	cam.fov = minf(fov_default + fov_kick_jump, cam.fov + fov_kick_jump)

func _apply_fov_kick(kick_amount: float) -> void:
	var target_fov: float = fov_default + kick_amount
	cam.fov = lerpf(cam.fov, target_fov, 0.7)
	
	await get_tree().create_timer(0.08).timeout
	
	if cam:  # Verify camera still exists after await
		cam.fov = lerpf(cam.fov, fov_default, 0.2)

# ============================================================================
# PUBLIC API
# ============================================================================
func get_look_direction() -> Vector3:
	"""Returns the forward direction the camera is facing"""
	return -yaw.global_transform.basis.z

func get_right_direction() -> Vector3:
	"""Returns the right direction relative to camera"""
	return yaw.global_transform.basis.x

func set_yaw_rotation(degrees: float) -> void:
	"""Instantly set yaw rotation (useful for teleports/respawns)"""
	_current_yaw_deg = degrees
	_target_yaw_deg = degrees
	yaw.rotation_degrees.y = degrees

func set_pitch_rotation(degrees: float) -> void:
	"""Instantly set pitch rotation (useful for teleports/respawns)"""
	var clamped: float = clampf(degrees, min_pitch_deg, max_pitch_deg)
	_current_pitch_deg = clamped
	_target_pitch_deg = clamped
	pitch.rotation_degrees.x = clamped

func reset_fov() -> void:
	"""Reset FOV to default value"""
	if cam:
		cam.fov = fov_default

func get_camera() -> Camera3D:
	"""Get the Camera3D node"""
	return cam

func get_spring_arm() -> SpringArm3D:
	"""Get the SpringArm3D node for advanced configuration"""
	return spring
