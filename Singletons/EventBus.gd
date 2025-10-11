extends Node

signal hud_message(text: String, seconds: float)
signal ally_died(ally_id: int)
signal save_requested()
signal load_requested(slot: String)
signal stamina_changed(current: float, max_value: float)

func post_hud(text: String, seconds: float = 2.0) -> void:
        emit_signal("hud_message", text, seconds)

func notify_ally_died(ally_id: int) -> void:
        emit_signal("ally_died", ally_id)
