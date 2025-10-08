# res://scripts/player/CameraOrbit.gd
extends Node3D

# --- Config ---
@export var height_offset: float = 1.5          # altura del pivote (cabeza/torso)
@export var sensitivity_deg: float = 0.12       # grados por píxel
@export var smooth_time: float = 0.08
@export var invert_y: bool = false
@export var capture_on_start: bool = true

@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float =  60.0

@export var min_radius: float = 2.0
@export var max_radius: float = 15.0
@export var radius: float = 5.0
@export var zoom_step: float = 0.5

# --- Nodos del rig ---
@onready var yaw: Node3D = $Yaw
@onready var pitch: Node3D = $Yaw/Pitch
@onready var spring: SpringArm3D = $Yaw/Pitch/SpringArm3D

# --- Estado (en grados para coherencia con rotation_degrees) ---
var _yaw_deg: float = 0.0
var _pitch_deg: float = 15.0
var _yaw_des_deg: float = 0.0
var _pitch_des_deg: float = 15.0
var _radius_des: float = 5.0

func _ready() -> void:
	# Coloca el rig a la altura deseada y toma estado inicial
	position.y = height_offset
	_radius_des = radius
	_yaw_deg = yaw.rotation_degrees.y
	_pitch_deg = clamp(pitch.rotation_degrees.x, min_pitch_deg, max_pitch_deg)
	_yaw_des_deg = _yaw_deg
	_pitch_des_deg = _pitch_deg
	spring.spring_length = clamp(radius, min_radius, max_radius)
	if capture_on_start:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Toggle captura con ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var mm := Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if mm == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

	# Rotación con mouse (si está capturado)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var s: float = sensitivity_deg
		_yaw_des_deg -= event.relative.x * s
		var sign_y: float = -1.0 if invert_y else 1.0
		_pitch_des_deg -= event.relative.y * s * sign_y
		_pitch_des_deg = clamp(_pitch_des_deg, min_pitch_deg, max_pitch_deg)

	# Zoom con rueda
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_radius_des = max(min_radius, _radius_des - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_radius_des = min(max_radius, _radius_des + zoom_step)

func _process(delta: float) -> void:
	# Mantén la altura del rig consistente
	if abs(position.y - height_offset) > 0.001:
		position.y = height_offset

	# Suavizado exponencial (como tu versión)
	var k: float = 1.0 - exp(-delta / max(0.0001, smooth_time))
	_yaw_deg = _lerp_angle_deg(_yaw_deg, _yaw_des_deg, k)
	_pitch_deg = lerp(_pitch_deg, _pitch_des_deg, k)
	radius = lerp(radius, _radius_des, k)

	# Aplicar al rig
	yaw.rotation_degrees.y = _yaw_deg
	pitch.rotation_degrees.x = _pitch_deg
	spring.spring_length = clamp(radius, min_radius, max_radius)

# Lerp angular en grados (evita saltos cruzando 180°)
func _lerp_angle_deg(a: float, b: float, t: float) -> float:
	var delta := fposmod((b - a) + 180.0, 360.0) - 180.0
	return a + delta * t
