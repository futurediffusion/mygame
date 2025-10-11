extends CanvasLayer

@onready var label: Label = $Label
var _hide_timer: SceneTreeTimer = null

func _ready() -> void:
    if Engine.has_singleton("EventBus"):
        EventBus.hud_message.connect(_on_hud)
    _hide_label()

func _on_hud(text: String, seconds: float) -> void:
    label.text = text
    label.visible = true

    if _hide_timer != null and is_instance_valid(_hide_timer):
        if _hide_timer.timeout.is_connected(_on_hide_timeout):
            _hide_timer.timeout.disconnect(_on_hide_timeout)
        _hide_timer = null

    _hide_timer = get_tree().create_timer(max(seconds, 0.05))
    _hide_timer.timeout.connect(_on_hide_timeout)

func _on_hide_timeout() -> void:
    _hide_label()
    _hide_timer = null

func _hide_label() -> void:
    label.visible = false
