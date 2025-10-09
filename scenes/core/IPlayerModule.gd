extends Node
class_name IPlayerModule
## Base para módulos del Player (Godot 4.x)
## - Gestiona enable/disable
## - Guarda referencia a Player (CharacterBody3D)
## - Da helpers para manejar velocity/vel (compat refactor)
## - Define hooks virtuales: _on_setup, _physics_tick, _process_tick, _on_enabled, _on_shutdown
## - Convenciones:
##   * InputModule: escribe player.wish_dir / player.is_sprinting y emite señales
##   * JumpModule: sólo Y (gravedad + salto) → usar set_vel_y()
##   * LocomotionModule: sólo XZ → usar set_hvel()
##   * Animation/Audio: no modificar velocity

# --------------------------
# Estado & flags
# --------------------------
var player: CharacterBody3D            # asignado en setup()
var enabled: bool = true : set = set_enabled

@export var debug: bool = false
@export var debug_every_n_frames: int = 20  # 0 = nunca

# --------------------------
# API pública (no override)
# --------------------------
func setup(p: CharacterBody3D) -> void:
	if p == null or not (p is CharacterBody3D):
		push_error("%s.setup(): Player inválido." % [get_script().resource_path])
		return
	player = p
	_on_setup()

func physics_tick(delta: float) -> void:
	if not enabled: return
	_physics_tick(delta)

func process_tick(delta: float) -> void:
	if not enabled: return
	_process_tick(delta)

func shutdown() -> void:
	_on_shutdown()

func set_enabled(v: bool) -> void:
	if enabled == v: return
	enabled = v
	_on_enabled(v)

# --------------------------
# Hooks virtuales (overridea en subclases)
# --------------------------
func _on_setup() -> void:
	# Para implementar en el módulo derivado
	pass

func _physics_tick(_delta: float) -> void:
	# Para implementar en el módulo derivado
	pass

func _process_tick(_delta: float) -> void:
	# Para implementar en el módulo derivado
	pass

func _on_enabled(_v: bool) -> void:
	# Para implementar si necesitas reaccionar a enabled/disabled
	pass

func _on_shutdown() -> void:
	# Limpieza/conexiones, si aplica
	pass

# --------------------------
# Helpers de acceso a nodos del Player
# --------------------------
func getp(path: NodePath) -> Node:
	# Acceso seguro a nodos del Player
	if player == null or String(path) == "": return null
	return player.get_node_or_null(path)

# --------------------------
# Helpers de velocity (compat 'vel' del refactor)
# SIEMPRE escribimos en player.velocity (el que usa move_and_slide)
# y reflejamos en 'vel' si existe para otros módulos.
# --------------------------
func has_vel_field() -> bool:
	return player != null and ("vel" in player)

func get_vel() -> Vector3:
	return player.velocity

func set_vel(v: Vector3) -> void:
	player.velocity = v
	if has_vel_field():
		player.vel = v

func set_vel_y(y: float) -> void:
	player.velocity.y = y
	if has_vel_field():
		player.vel.y = y

func get_hvel() -> Vector2:
	return Vector2(player.velocity.x, player.velocity.z)

func set_hvel(v: Vector2) -> void:
	player.velocity.x = v.x
	player.velocity.z = v.y
	if has_vel_field():
		player.vel.x = v.x
		player.vel.z = v.y

# --------------------------
# Helpers de debug
# --------------------------
func dbg_print(msg: String) -> void:
	if not debug: return
	if debug_every_n_frames <= 0: 
		print(msg)
	elif Engine.get_frames_drawn() % debug_every_n_frames == 0:
		print(msg)
