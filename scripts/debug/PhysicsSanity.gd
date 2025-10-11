extends ModuleBase

var t := 0.0
var start_y := 0.0
var start_t := 0.0
var fall_started := false
@export var g := 24.0
@export var movement_path: NodePath = NodePath("Modules/Movement")

func physics_tick(dt: float) -> void:
        var host := _get_host()
        if host == null:
                push_warning("PhysicsSanity no tiene CharacterBody3D host")
                queue_free()
                return

        var movement := _get_movement_module()
        if movement == null:
                push_warning("PhysicsSanity no encontró Movement module")
                queue_free()
                return

        t += dt
        if t < 1.0:
                if movement.has_method("set_frame_input"):
                        movement.set_frame_input(Vector3.FORWARD, false)
                else:
                        movement.set("_move_dir", Vector3.FORWARD)
        elif t < 2.0:
                if movement.has_method("set_frame_input"):
                        movement.set_frame_input(Vector3.ZERO, false)
                else:
                        movement.set("_move_dir", Vector3.ZERO)
        elif t < 3.0:
                if not fall_started:
                        start_t = t
                        start_y = host.global_position.y
                        fall_started = true
        else:
                var dy := (start_y - host.global_position.y)
                var fall_t := max(t - start_t, 0.0)
                var expected := 0.5 * g * fall_t * fall_t
                if abs(dy - expected) < 2.0:
                        print("OK caída (~%0.2fm): " % expected, dy)
                else:
                        print("LENTA/rápida (~%0.2fm esperados): " % expected, dy)
                queue_free()

func _get_movement_module() -> Object:
        var host := _get_host()
        if host == null:
                return null
        if movement_path.is_empty():
                return null
        return host.get_node_or_null(movement_path)

func _get_host() -> CharacterBody3D:
        var node := get_parent()
        if node is CharacterBody3D:
                return node
        if owner is CharacterBody3D:
                return owner
        return null
