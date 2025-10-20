# res://ui/HUD.gd
extends Control

@export var player_path: NodePath

@onready var bar = %HealthBar
@onready var label = %HealthLabel

var player: Node = null
var health: Health = null

func _ready() -> void:
	# Si no se asignó por Inspector, intenta encontrar al Player por grupo
	if player_path != NodePath():
		player = get_node_or_null(player_path)
	else:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

	if player:
		var health_node := player.get_node_or_null("Health")
		if health_node is Health:
			health = health_node
			# Conectar a los eventos de Vida
			health.health_changed.connect(_on_health_changed)
			health.died.connect(_on_player_died)
			# Inicializar
			_on_health_changed(health.current, health.max_health)
		else:
			push_warning("HUD: nodo Health no usa el script Health.gd")
	else:
		push_warning("HUD: no encontré el Player o su nodo Health")

func _on_health_changed(current: float, max_hp: float) -> void:
	bar.max_value = max_hp
	bar.value = current
	label.text = str(round(current)) + " / " + str(round(max_hp))

func _on_player_died() -> void:
	# Aquí puedes mostrar un mensajito o cambiar color
	label.text = "DEAD"
