extends Node
class_name OrientationModule

@export_enum("global", "regional", "local") var tick_group: StringName = "local"

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

func set_frame_input(input_dir: Vector3) -> void:
	_input_dir = input_dir

func physics_tick(delta: float) -> void:
	update_model_rotation(delta, _input_dir)

func update_model_rotation(_delta: float, input_dir: Vector3) -> void:
	if input_dir.length_squared() < 0.0025:
		return
	var target_yaw: float = atan2(input_dir.x, input_dir.z) + _model_correction_rad
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)
