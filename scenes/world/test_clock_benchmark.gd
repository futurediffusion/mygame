extends Node3D

@export var allies_to_spawn: int = 30
@export var spawn_spacing: float = 2.5
@export var ally_scene: PackedScene = preload("res://scenes/entities/Ally.tscn")

@onready var _ally_container: Node3D = %Allies
@onready var _toggle_simclock_button: Button = %ToggleSimClockButton
@onready var _toggle_pause_button: Button = %TogglePauseButton
@onready var _ticks_label: Label = %TicksLabel

var _is_group_paused: bool = false

func _ready() -> void:
	_spawn_allies()
	_connect_controls()
	_update_controls()

func _process(_delta: float) -> void:
	_update_ticks_label()

func _connect_controls() -> void:
        if _toggle_simclock_button != null:
                _toggle_simclock_button.disabled = true
                _toggle_simclock_button.text = "Modo Ally: SimClock"
	if _toggle_pause_button != null:
		_toggle_pause_button.pressed.connect(_on_toggle_pause_pressed)

func _spawn_allies() -> void:
	if ally_scene == null or _ally_container == null:
		return
	for child in _ally_container.get_children():
		child.queue_free()
	var per_row := int(ceil(sqrt(float(allies_to_spawn))))
	for index in range(allies_to_spawn):
		var ally := ally_scene.instantiate()
		if ally == null:
			continue
		ally.name = "BenchmarkAlly_%03d" % index
		_ally_container.add_child(ally)
		var row: int = index / max(per_row, 1)
		var col: int = index % max(per_row, 1)
		var offset := Vector3(float(col) * spawn_spacing, 0.0, float(row) * spawn_spacing)
		ally.global_position = offset

func _on_toggle_pause_pressed() -> void:
        var clock := _get_simclock()
        if clock == null:
                return
        _is_group_paused = not _is_group_paused
        clock.pause_group(Flags.ALLY_TICK_GROUP, _is_group_paused)
        _update_controls()

func _update_controls() -> void:
	_update_pause_button()
        if _toggle_simclock_button != null:
                _toggle_simclock_button.text = "Modo Ally: SimClock"

func _update_pause_button() -> void:
	if _toggle_pause_button == null:
		return
	var label := "Reanudar grupo local" if _is_group_paused else "Pausar grupo local"
	_toggle_pause_button.text = label

func _update_ticks_label() -> void:
        if _ticks_label == null:
                return
        var clock := _get_simclock()
        if clock == null:
                _ticks_label.text = "SimClock no disponible"
                return
        var stats := clock.get_group_stats()
	var group := Flags.ALLY_TICK_GROUP
	var data: Dictionary = stats.get(group, {})
	var tick_count: int = int(data.get("tick_count", 0))
	var sim_time: float = float(data.get("sim_time", 0.0))
	var ticks_per_second := 0.0
	if sim_time > 0.0:
		ticks_per_second = float(tick_count) / sim_time
	_ticks_label.text = "Grupo %s → ticks: %d | sim_time: %.2f | ticks/s: %.2f | modo: SimClock" % [String(group), tick_count, sim_time, ticks_per_second]

func _get_simclock() -> SimClockAutoload:
	if typeof(SimClock) != TYPE_NIL:
		return SimClock as SimClockAutoload
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_root().get_node_or_null(^"/root/SimClock") as SimClockAutoload
