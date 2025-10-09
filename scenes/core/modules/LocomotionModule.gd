extends IPlayerModule
class_name LocomotionModule

@export var cfg: LocomotionConfig
@export var face_lerp: float = 0.18
@export var model_path: NodePath = NodePath("")
@export var debug_print: bool = false

var model: Node3D

func _ensure_cfg_defaults() -> void:
	if cfg != null: return
	cfg = LocomotionConfig.new()
	cfg.walk_speed = 2.5
	cfg.run_speed = 6.0
	cfg.sprint_speed = 9.5
	cfg.jump_velocity = 7.0
	cfg.accel_ground = 22.0
	cfg.accel_air = 8.0
	cfg.decel = 18.0
	cfg.max_slope_deg = 46.0
	cfg.snap_len = 0.3
	cfg.coyote_time = 0.12
	cfg.jump_buffer = 0.15
	push_warning("LocomotionModule: cfg no asignado. Usando valores por defecto.")

# ================== OVERRIDES DE LA BASE ==================
func _on_setup() -> void:
	_ensure_cfg_defaults()
	player.floor_max_angle = deg_to_rad(cfg.max_slope_deg)
	player.floor_snap_length = cfg.snap_len
	model = getp(model_path) as Node3D

func _physics_tick(dt: float) -> void:
	if debug_print and Engine.get_frames_drawn() % 20 == 0:
		dbg_print("wish_dir=%s  velocity.xz=%s" % [player.wish_dir, Vector2(player.velocity.x, player.velocity.z)])

	var on_floor := player.is_on_floor()
	var has_input: bool = player.wish_dir.length_squared() > 0.0001


	# Velocidad objetivo según input/sprint
	var target_speed: float = cfg.walk_speed
	if player.is_sprinting and has_input:
		target_speed = cfg.sprint_speed
	elif has_input:
		target_speed = cfg.run_speed

	# Dinámica horizontal
	var desired: Vector2 = Vector2(player.wish_dir.x, player.wish_dir.z) * target_speed
	var current: Vector2 = get_hvel()
	var accel: float = cfg.accel_ground if on_floor else cfg.accel_air

	var next := current
	if has_input:
		var diff := desired - current
		var dist: float = diff.length()
		if dist <= 0.001:
			next = desired
		else:
			var change: float = min(accel * dt, dist)
			next = current + diff.normalized() * change
	else:
		var speed: float = current.length()
		if speed <= 0.001:
			next = Vector2.ZERO
		else:
			var drop: float = min(speed, cfg.decel * dt)
			next = current.normalized() * (speed - drop)

	set_hvel(next)

	# Rotación del modelo hacia la dirección de movimiento
	if model and next.length_squared() > 0.0025:
		# 'next' es un Vector2 (x,z). En nuestro sistema "forward" es -Z,
		# por lo que necesitamos invertir ambos ejes para obtener el yaw correcto.
		var target_yaw: float = atan2(-next.x, -next.y)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)
