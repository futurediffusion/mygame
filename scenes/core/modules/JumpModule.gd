extends IPlayerModule
class_name JumpModule

@export var cfg: LocomotionConfig
@export var input_module_path: NodePath = ^"Modules/InputModule"

var coyote_timer := 0.0
var buffer_timer := 0.0
var gravity := 9.8
var _input_connected := false

# === Helpers: nativo 'velocity' + reflejo a 'vel' si existe ===
func _get_vel() -> Vector3:
	return player.velocity

func _set_vel(v: Vector3) -> void:
	player.velocity = v
	if "vel" in player:
		player.vel = v

func _set_vel_y(y: float) -> void:
	player.velocity.y = y
	if "vel" in player:
		player.vel.y = y

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
	push_warning("JumpModule: cfg no asignado. Usando valores por defecto.")

func setup(p: CharacterBody3D) -> void:
	player = p
	_ensure_cfg_defaults()
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

	var input_mod := (player.get_node_or_null(input_module_path) as Node)
	if input_mod and input_mod.has_signal("jump_tapped"):
		input_mod.connect("jump_tapped", Callable(self, "_on_jump_tapped"))
		_input_connected = true
	else:
		_input_connected = false
		push_warning("JumpModule: no encontré InputModule o su señal 'jump_tapped'. Fallback a Input.is_action_just_pressed('jump').")

func physics_tick(dt: float) -> void:
	var on_floor := player.is_on_floor()

	if on_floor:
		coyote_timer = cfg.coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - dt)

	buffer_timer = max(0.0, buffer_timer - dt)

	if not _input_connected and Input.is_action_just_pressed("jump"):
		_on_jump_tapped()

	# Gravedad solo en aire (Y)
	if not on_floor:
		var v := _get_vel()
		v.y -= gravity * dt
		_set_vel(v)

	var can_jump := buffer_timer > 0.0 and (on_floor or coyote_timer > 0.0)
	if can_jump:
		_perform_jump()
	else:
		player.just_jumped = false

func _on_jump_tapped() -> void:
	buffer_timer = cfg.jump_buffer

func _perform_jump() -> void:
	_set_vel_y(cfg.jump_velocity)
	buffer_timer = 0.0
	coyote_timer = 0.0
	player.just_jumped = true
