extends IPlayerModule
class_name InputModule

signal jump_tapped

@export var cam_yaw_path: NodePath = ^"CameraRig/Yaw"
@export var cam_orbit_fallback: NodePath = ^"CameraOrbit"

var cam_yaw: Node3D

func _on_setup() -> void:
	# Cachea la referencia a la cámara/Yaw (o fallback). Si no hay, usa el propio Player.
	cam_yaw = getp(cam_yaw_path) as Node3D
	if cam_yaw == null:
		cam_yaw = getp(cam_orbit_fallback) as Node3D

func _physics_tick(_dt: float) -> void:
	# Vector2 de input: x=izq/der, y=atrás/adelante
	var v2: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var x: float = v2.x
	var z: float = v2.y  # y positivo es "adelante"

	# Basis relativo a la cámara si existe, si no al Player
	var basis: Basis = cam_yaw.global_transform.basis if cam_yaw != null else player.global_transform.basis
	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x

	# Ignora cualquier componente vertical del basis (la cámara puede estar inclinada)
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var dir: Vector3 = right * x + forward * z
	player.wish_dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.ZERO

	player.is_sprinting = Input.is_action_pressed("sprint")
	if Input.is_action_just_pressed("jump"):
		jump_tapped.emit()
