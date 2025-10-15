extends ModuleBase
class_name OrientationModule

var player: CharacterBody3D
var model: Node3D
var face_lerp := 0.18
var model_forward_correction_deg := 0.0
var _model_correction_rad := 0.0
var _input_dir := Vector3.ZERO
var _max_tilt_rad: float = deg_to_rad(50.0)
var _last_surface_normal: Vector3 = Vector3.UP
var _last_yaw_angle: float = 0.0

func setup(p: CharacterBody3D) -> void:
	player = p
	model = p.model
	face_lerp = p.face_lerp
	model_forward_correction_deg = p.model_forward_correction_deg
	_model_correction_rad = deg_to_rad(model_forward_correction_deg)
	if "max_slope_deg" in p:
		_max_tilt_rad = deg_to_rad(clampf(p.max_slope_deg, 0.0, 50.0))
	else:
		_max_tilt_rad = deg_to_rad(50.0)
	_last_surface_normal = Vector3.UP
	_last_yaw_angle = 0.0

## Registra el input direccional que usará la orientación en el siguiente tick.
## - `input_dir`: Vector3 normalizado en XZ que representa la dirección objetivo del modelo.
## Efectos: almacena el vector para que `physics_tick` gire al modelo cuando el input supere el umbral mínimo.
func set_frame_input(input_dir: Vector3) -> void:
	assert(input_dir.is_finite(), "OrientationModule.set_frame_input recibió un input_dir no finito.")
	assert(absf(input_dir.length()) <= 1.1, "OrientationModule.set_frame_input espera un vector normalizado (<= 1.1).")
	_input_dir = input_dir

func physics_tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("should_skip_module_updates") and player.should_skip_module_updates():
		return
	update_model_rotation(delta, _input_dir)

func update_model_rotation(_delta: float, input_dir: Vector3) -> void:
	if model == null or not is_instance_valid(model):
		return
	var desired_up := _determine_target_up()
	var yaw_angle := _last_yaw_angle
	if input_dir.length_squared() >= 0.0025:
		yaw_angle = atan2(input_dir.x, input_dir.z)
		_last_yaw_angle = yaw_angle
	var corrected_yaw := yaw_angle + _model_correction_rad
	var forward_flat := Vector3(sin(corrected_yaw), 0.0, cos(corrected_yaw))
	if forward_flat.length_squared() < 0.0001:
		forward_flat = Vector3.FORWARD
	var forward := forward_flat
	if not desired_up.is_equal_approx(Vector3.UP):
		forward = forward.slide(desired_up)
		if forward.length_squared() < 0.0001:
			var fallback := desired_up.cross(Vector3.RIGHT)
			if fallback.length_squared() < 0.0001:
				fallback = desired_up.cross(Vector3.FORWARD)
			forward = fallback.normalized()
	forward = forward.normalized()
	var right := forward.cross(desired_up).normalized()
	if right.length_squared() < 0.0001:
		right = desired_up.cross(Vector3.FORWARD).normalized()
	var corrected_forward := desired_up.cross(right).normalized()
	var basis := Basis()
	basis.x = right
	basis.y = desired_up
	basis.z = corrected_forward
	basis = basis.orthonormalized()
	var target_quat := basis.get_rotation_quaternion()
	var current_quat: Quaternion = model.rotation_quaternion
	var weight: float = clampf(face_lerp, 0.0, 1.0)
	model.rotation_quaternion = current_quat.slerp(target_quat, weight)

func _determine_target_up() -> Vector3:
	var desired_up := _last_surface_normal
	if desired_up.length_squared() <= 0.0001:
		desired_up = Vector3.UP
	if player != null and is_instance_valid(player):
		if player.is_on_floor():
			var floor_normal := player.get_floor_normal()
			if floor_normal.length_squared() > 0.0001:
				desired_up = _clamp_surface_normal(floor_normal.normalized())
				_last_surface_normal = desired_up
	return desired_up

func _clamp_surface_normal(normal: Vector3) -> Vector3:
	var n := normal.normalized()
	if n.length_squared() <= 0.0001:
		return Vector3.UP
	var angle := acos(clampf(n.dot(Vector3.UP), -1.0, 1.0))
	if angle <= _max_tilt_rad:
		return n
	var axis := Vector3.UP.cross(n)
	if axis.length_squared() <= 0.0001:
		return Vector3.UP
	axis = axis.normalized()
	return Vector3.UP.rotated(axis, _max_tilt_rad)
