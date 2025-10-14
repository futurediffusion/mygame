extends ModuleBase
class_name OrientationModule

var player: CharacterBody3D
var model: Node3D
var face_lerp := 0.18
var model_forward_correction_deg := 0.0
var _model_correction_rad := 0.0
var _input_dir := Vector3.ZERO

func setup(p: CharacterBody3D) -> void:
	player = p
	model = p.model
	face_lerp = p.face_lerp
	model_forward_correction_deg = p.model_forward_correction_deg
	_model_correction_rad = deg_to_rad(model_forward_correction_deg)

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
	if input_dir.length_squared() < 0.0025:
		return
	var target_yaw: float = atan2(input_dir.x, input_dir.z) + _model_correction_rad
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)

