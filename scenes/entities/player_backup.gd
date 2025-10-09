extends CharacterBody3D
class_name Player

# ==============================
# ESTADOS COMPARTIDOS (refactor)
# ==============================
var wish_dir: Vector3 = Vector3.ZERO
var is_sprinting: bool = false
var just_jumped: bool = false

# Campo legacy para módulos viejos (generalmente XZ)
var vel: Vector3 = Vector3.ZERO

# ==============================
# FÍSICA DEL BODY
# ==============================
@export_range(0.0, 89.0, 1.0) var max_slope_deg: float = 46.0
@export_range(0.0, 2.0, 0.05) var snap_len: float = 0.3

# Debug
@export var debug_every_n_frames: int = 20

# ==============================
# MÓDULOS (esperados bajo Player/Modules)
# ==============================
@onready var modules_root: Node = get_node_or_null(^"Modules")
var _mods: Array = []

func _ready() -> void:
	if modules_root == null:
		push_error("Player: NO existe el nodo hijo 'Modules'.")
		return

	# Física básica del body (para agarre de piso consistente)
	floor_max_angle = deg_to_rad(max_slope_deg)
	floor_snap_length = snap_len

	# Orden sugerido
	var order := [
		"InputModule",
		"JumpModule",
		"LocomotionModule",
		"AnimationModule",
		"AudioModule",
		"StaminaModule"
	]
	var found := {}
	for m in modules_root.get_children():
		found[m.name] = m

	for n in order:
		if found.has(n):
			_mods.append(found[n])

	# Agrega otros módulos no listados
	for m in modules_root.get_children():
		if not _mods.has(m):
			_mods.append(m)

	# setup
	var names := []
	for m in _mods:
		names.append(m.name)
		if m.has_method("setup"):
			m.call("setup", self)
	print("Player: módulos activos -> ", ", ".join(PackedStringArray(names)))

func _physics_process(delta: float) -> void:
	# ------- ORDEN DE TICKS (NO mover aún) -------
	for m in _mods:
		if m.has_method("physics_tick"):
			m.call("physics_tick", delta)

	# ------- FUSIÓN DE VELOCIDADES (compatibilidad) -------
	# Política:
	#  - 'velocity.y' es autoridad (gravedad/salto de JumpModule).
	#  - Si algún módulo legacy escribe 'vel.xz', las usamos; si no, respetamos 'velocity.xz'.
	var merged: Vector3 = velocity
	var use_legacy_xz: bool = (not is_zero_approx(vel.x)) or (not is_zero_approx(vel.z))
	if use_legacy_xz:
		merged.x = vel.x
		merged.z = vel.z
	# Y siempre respetamos la Y calculada por los módulos modernos:
	merged.y = velocity.y

	# Aplica al body
	velocity = merged

	# ------- MOVER UNA SOLA VEZ -------
	move_and_slide()

	# Espejo inverso (por si algún módulo lee 'vel' después)
	vel = velocity

	# Debug opcional
	if debug_every_n_frames > 0 and Engine.get_frames_drawn() % debug_every_n_frames == 0:
		print("wish_dir=", wish_dir,
			"  legacy.xz=", Vector2(vel.x, vel.z),
			"  velocity=", velocity,
			"  on_floor=", is_on_floor())

func _process(delta: float) -> void:
	for m in _mods:
		if m.has_method("process_tick"):
			m.call("process_tick", delta)

# Llamado por AnimationPlayer (tracks de llamada)
func _play_footstep_audio() -> void:
	var am := modules_root.get_node_or_null("AudioModule")
	if am and am.has_method("play_footstep"):
		am.call("play_footstep")
