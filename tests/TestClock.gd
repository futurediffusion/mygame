extends Node

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
