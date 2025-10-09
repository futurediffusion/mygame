extends IPlayerModule
class_name StaminaModule

@export var stamina_scene_path: String = ""   # opcional: si prefieres instanciar una escena que tenga Stamina.gd
@export var stamina_node_path: NodePath       # si ya tienes un nodo con Stamina.gd en la escena
@export var jump_cost: float = 15.0           # costo por salto (ajústalo a gusto)

var stamina: Stamina                          # tu clase Stamina.gd

func setup(p: CharacterBody3D) -> void:
	player = p

	# 1) Si nos diste un path a un nodo existente con Stamina.gd, lo usamos
	if String(stamina_node_path) != "":
		stamina = player.get_node_or_null(stamina_node_path)
		if stamina == null:
			push_error("StaminaModule: no encontré el nodo en stamina_node_path")
	# 2) Si nos pasas una escena por ruta (por ejemplo una .tscn que tenga Stamina.gd en el root), la instanciamos
	elif stamina_scene_path != "":
		var packed: PackedScene = load(stamina_scene_path)
		if packed:
			var inst = packed.instantiate()
			player.add_child(inst)
			stamina = inst
	# 3) Si no nos diste nada, creamos el nodo Stamina en caliente
	if stamina == null:
		stamina = Stamina.new()
		stamina.name = "Stamina"
		player.add_child(stamina)

	# Opcional: conecta señales para HUD/FX
	# stamina.stamina_changed.connect(_on_stamina_changed)
	# stamina.stamina_depleted.connect(_on_stamina_depleted)
	# stamina.sprint_available.connect(_on_sprint_available)

func physics_tick(dt: float) -> void:
	if stamina == null:
		return

	# Consumir por salto
	if player.just_jumped:
		stamina.consume_instant(jump_cost)

	# Consumir por sprint sostenido
	var moving: bool = player.wish_dir != Vector3.ZERO
	var on_floor: bool = player.is_on_floor()
	if player.is_sprinting and moving and on_floor:
		stamina.consume_for_sprint(dt)
		# Si ya no alcanza, cortar sprint
		if not stamina.can_sprint():
			player.is_sprinting = false

func process_tick(dt: float) -> void:
	if stamina == null:
		return
	stamina.tick(dt)  # maneja cooldown + regen

# ---------- Helpers opcionales para HUD ----------
func get_stamina_percent() -> float:
	return stamina.get_percent() if stamina else 0.0

func get_stamina_values() -> Dictionary:
	return stamina.get_debug_info() if stamina else {}
