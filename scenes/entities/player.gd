extends CharacterBody3D
class_name Player

# === MOVIMIENTO Y CONTROL ===
@export var move_speed: float = 6.0              # (compatibilidad, no se usa directo)
@export var jump_velocity: float = 7.0
@export var mouse_sens: float = 0.003
@export var walk_speed: float = 2.5              # velocidad a la que el blend está en "walk"
@export var run_speed: float = 6.0               # velocidad máxima sin sprint
@export var sprint_speed: float = 9.5            # velocidad máxima en sprint

@export var face_lerp: float = 0.18
@export var model_forward_correction_deg: float = 0.0

# === SPRINT: animación ===
@export var sprint_anim_speed_scale: float = 1.15 # acelera la animación de Locomotion al esprintar
@export var sprint_blend_bias: float = 0.85       # empuja el blend hacia "run" un poco antes (0.8–1.0)

# === ANIMACIONES ===
@export var fall_clip_name := "fall air loop"     # clip exacto de caída

# Cuándo empieza a considerarse “caída” y cómo sube el blend
@export var fall_threshold: float = -0.05         # empieza fall cuando vel.y < esto
@export var fall_ramp_delay: float = 0.10         # s tras el despegue antes de empezar a mezclar fall
@export var fall_ramp_time: float = 0.20          # cuánto tarda en subir de 0→1 el peso objetivo de fall
@export var fall_blend_lerp: float = 12.0         # rapidez de seguimiento al objetivo (suavizado)

# === NODOS ===
@onready var yaw: Node3D = $CameraRig/Yaw
@onready var pitch: Node3D = $CameraRig/Yaw/Pitch
@onready var model: Node3D = $Pivot/Model
@onready var anim_tree: AnimationTree = $Pivot/Model/AnimationTree
@onready var anim_player: AnimationPlayer = $Pivot/Model/AnimationPlayer

# === RUTAS EN EL ANIMATION TREE ===
const PARAM_LOC       := "parameters/Locomotion/blend_position"
const PARAM_JUMP      := "parameters/Jump/request"
const PARAM_AIRBLEND  := "parameters/AirBlend/blend_amount" # <- como cuando funcionaba
const PARAM_FALLANIM  := "parameters/FallAnim/animation"
const PARAM_SPRINTSCL := "parameters/SprintScale/scale"     # TimeScale (SprintScale)

# === VARIABLES INTERNAS ===
var yaw_angle := 0.0
var pitch_angle := 0.0
var was_on_floor := true
var air_time := 0.0   # tiempo continuo en el aire

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true
	# Vincula el clip de caída al nodo Animation "FallAnim"
	anim_tree.set(PARAM_FALLANIM, fall_clip_name)
	# Inicializa: locomoción normal y estamos "en suelo" (sin aire)
	anim_tree.set(PARAM_SPRINTSCL, 1.0)
	anim_tree.set(PARAM_AIRBLEND, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw_angle -= event.relative.x * mouse_sens
		pitch_angle = clamp(pitch_angle - event.relative.y * mouse_sens, deg_to_rad(-60), deg_to_rad(60))
		yaw.rotation.y = yaw_angle
		pitch.rotation.x = pitch_angle

func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	if not is_on_floor():
		velocity.y -= gravity * delta

	# === DIRECCIÓN EN PLANO RELATIVA A LA CÁMARA ===
	var iz := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var ix := Input.get_action_strength("move_right")  - Input.get_action_strength("move_left")
	var forward: Vector3 = -yaw.global_transform.basis.z
	var right:   Vector3 =  yaw.global_transform.basis.x
	var dir: Vector3 = (forward * iz + right * ix)
	if dir.length() > 1.0:
		dir = dir.normalized()

	# === SPRINT ON/OFF ===
	var sprinting := Input.is_action_pressed("sprint")
	var max_ground_speed := sprint_speed if sprinting else run_speed

	# === VELOCIDAD (horizontal) ===
	# Simplicidad: velocidad inmediata (si quieres, luego metemos accel/deaccel)
	velocity.x = dir.x * max_ground_speed
	velocity.z = dir.z * max_ground_speed

	# === SALTO ===
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		_play_jump()

	move_and_slide()

	# === AIR TIME (para el ramp de fall) ===
	if is_on_floor():
		air_time = 0.0
	else:
		air_time += delta

	# === ORIENTACIÓN DEL MESH SEGÚN DIRECCIÓN ===
	if dir.length() > 0.05:
		var target_yaw := atan2(dir.x, dir.z) + deg_to_rad(model_forward_correction_deg)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, face_lerp)

	# === BLEND Idle/Walk/Run ===
	var speed_h: float = Vector2(velocity.x, velocity.z).length()
	var t: float = 0.0
	if speed_h <= walk_speed:
		t = remap(speed_h, 0.0, max(0.01, walk_speed), 0.0, 0.4)
	else:
		# usamos el techo actual (run o sprint) para que el mapeo sea consistente
		t = remap(speed_h, walk_speed, max(walk_speed, max_ground_speed), 0.4, 1.0)
	# Sesgo: si sprinting, empuja un poquito hacia "run"
	if sprinting:
		t = pow(clampf(t, 0.0, 1.0), sprint_blend_bias)
	anim_tree.set(PARAM_LOC, clampf(t, 0.0, 1.0))

	# === TimeScale SOLO para locomoción (SprintScale) ===
	var anim_scale := 1.0
	if sprinting:
		# Acelera más cuanto más cerca estés del extremo de "run"
		anim_scale = lerp(1.0, sprint_anim_speed_scale, t)
	anim_tree.set(PARAM_SPRINTSCL, anim_scale)

	# === FALL / AIRBLEND con ramp suave (como antes) ===
	var target_air: float = 0.0
	if not is_on_floor() and velocity.y < fall_threshold:
		# Arranca a mezclar FALL tras fall_ramp_delay y sube a 1 en fall_ramp_time con suavizado
		var ramp := inverse_lerp(fall_ramp_delay, fall_ramp_delay + fall_ramp_time, air_time)
		ramp = clampf(ramp, 0.0, 1.0)
		# suavizado tipo smoothstep (curva S)
		ramp = ramp * ramp * (3.0 - 2.0 * ramp)
		target_air = ramp

	# Suavizado hacia el objetivo (lectura directa; la ruta ahora es correcta)
	var current_air: float = anim_tree.get(PARAM_AIRBLEND)
	var step := clampf(delta * fall_blend_lerp, 0.0, 1.0)
	var new_air := lerpf(current_air, target_air, step)
	anim_tree.set(PARAM_AIRBLEND, new_air)

	# === ATERRIZAJE ===
	if is_on_floor() and not was_on_floor:
		anim_tree.set(PARAM_AIRBLEND, 0.0)
		# Si quieres cortar OneShot al aterrizar:
		# anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	was_on_floor = is_on_floor()

func _play_jump() -> void:
	anim_tree.set(PARAM_JUMP, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
