extends Control

@export var player_path: NodePath

@onready var bar = %HealthBar
@onready var label = %HealthLabel

var player: Node = null
var health: Health = null

var _node_added_connected := false
var _warned_missing_player := false
var _warned_missing_health := false

func _ready() -> void:
	_hide_label()
	_try_bind_to_player()
	_update_node_added_watcher()

func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.disconnect(_on_tree_node_added)
	_node_added_connected = false
	_unbind_player()

func _try_bind_to_player() -> void:
	var resolved := _find_player()
	if resolved == null:
		if not _warned_missing_player:
			push_warning("HUD: no encontré el Player o su nodo Health")
			_warned_missing_player = true
		_update_node_added_watcher()
		return
	_warned_missing_player = false
	if resolved == player and health != null and is_instance_valid(health):
		_update_node_added_watcher()
		return
	_bind_player(resolved)
	_update_node_added_watcher()

func _find_player() -> Node:
	if player_path != NodePath():
		var node := get_node_or_null(player_path)
		if node != null:
			return node
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _bind_player(player_node: Node) -> void:
	_unbind_player()
	player = player_node
	if player != null and is_instance_valid(player):
		if not player.tree_exited.is_connected(_on_player_tree_exited):
			player.tree_exited.connect(_on_player_tree_exited)
		_bind_health_from_player(player)

func _bind_health_from_player(player_node: Node) -> void:
	var health_node := player_node.get_node_or_null("Health")
	if health_node is Health:
		health = health_node
		if not health.health_changed.is_connected(_on_health_changed):
			health.health_changed.connect(_on_health_changed)
		if not health.died.is_connected(_on_player_died):
			health.died.connect(_on_player_died)
		_warned_missing_health = false
		_on_health_changed(health.current, health.max_health)
	else:
		health = null
		if not _warned_missing_health:
			push_warning("HUD: nodo Health no usa el script Health.gd")
			_warned_missing_health = true

func _unbind_player() -> void:
	_disconnect_health_signals()
	if player != null and is_instance_valid(player):
		if player.tree_exited.is_connected(_on_player_tree_exited):
			player.tree_exited.disconnect(_on_player_tree_exited)
	player = null
	_hide_label()

func _disconnect_health_signals() -> void:
	if health != null and is_instance_valid(health):
		if health.health_changed.is_connected(_on_health_changed):
			health.health_changed.disconnect(_on_health_changed)
		if health.died.is_connected(_on_player_died):
			health.died.disconnect(_on_player_died)
	health = null

func _on_tree_node_added(_node: Node) -> void:
	call_deferred("_try_bind_to_player")

func _on_player_tree_exited() -> void:
	_unbind_player()
	_update_node_added_watcher()

func _update_node_added_watcher() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var should_watch := player == null or not is_instance_valid(player)
	if should_watch:
		if not _node_added_connected:
			tree.node_added.connect(_on_tree_node_added)
			_node_added_connected = true
	else:
		if tree.node_added.is_connected(_on_tree_node_added):
			tree.node_added.disconnect(_on_tree_node_added)
		_node_added_connected = false

func _on_health_changed(current: float, max_hp: float) -> void:
	bar.max_value = max_hp
	bar.value = current
	if not _ensure_label():
		return
	label.visible = true
	label.text = str(round(current)) + " / " + str(round(max_hp))

func _on_player_died() -> void:
	if not _ensure_label():
		return
	label.visible = true
	label.text = "DEAD"

func _hide_label() -> void:
	if not _ensure_label():
		return
	label.visible = false
	label.text = ""

func _ensure_label() -> bool:
	if label != null and is_instance_valid(label):
		return true
	var candidate := find_child("HealthLabel", true, false)
	if candidate is Label:
		label = candidate
		return true
	return false
