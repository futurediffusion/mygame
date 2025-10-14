extends Node

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

class DummyMod:
        extends ModuleBase

        var name: String = ""
        var hits: int = 0

        func physics_tick(_dt: float) -> void:
                hits += 1
                var owner := get_parent()
                if owner != null:
                        owner._order.append(name)

var _order: Array = []

func _ready() -> void:
        await _validate_player_registration()
        var mod_a := DummyMod.new()
        mod_a.name = "A"
        mod_a.priority = 10
        var mod_b := DummyMod.new()
        mod_b.name = "B"
        mod_b.priority = 20
        add_child(mod_a)
        add_child(mod_b)
        await get_tree().create_timer(0.2).timeout
        print(_order) # Esperado: ["A", "B", "A", "B", ...]

func _validate_player_registration() -> void:
        var player: Player = PLAYER_SCENE.instantiate()
        add_child(player)
        await get_tree().process_frame
        var clock := get_node_or_null(^"/root/SimClock") as SimClockAutoload
        assert(clock != null, "SimClock autoload no disponible")
        var group_entries: Array = clock._groups.get(player.sim_group, [])
        var found := false
        for entry in group_entries:
                if entry.get("mod") == player:
                        found = true
                        break
        assert(found, "Player debe registrarse en SimClock")
        player.queue_free()
        await get_tree().process_frame
