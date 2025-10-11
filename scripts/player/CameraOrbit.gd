extends Node3D
class_name CameraOrbit

@export var camera: Camera3D
@export var player_body: CharacterBody3D

# Distancias
@export var desired_distance: float = 3.5
@export var min_distance: float = 0.6
@export var max_distance: float = 6.0

# Colisión (ajusta el mask en el Inspector según tus capas de mundo)
@export var collision_mask: int = 0xFFFFFFFF
@export var safe_margin: float = 0.08   # cuánto "nos alejamos" de la pared
@export var collision_radius_hint: float = 0.25 # para compensar grosor de cámara

# Look & feel
@export var sens_x: float = 0.12
@export var sens_y: float = 0.10
@export var pitch_min_deg: float = -70.0
@export var pitch_max_deg: float = 75.0
@export var distance_smooth: float = 12.0
@export var aim_smooth: float = 18.0
@export var zoom_step: float = 0.7

var _yaw: float = 0.0
var _pitch: float = 0.15 # rad, ~8.6°
var _current_distance: float

func _ready() -> void:
    # Autodetecta la Camera3D si no se asignó
    if camera == null:
        camera = get_node_or_null("Camera3D")
    if camera == null:
        push_error("[CameraOrbit] Asigna una Camera3D en el inspector o como hijo directo.")
        set_process(false)
        set_physics_process(false)
        return
    _current_distance = clamp(desired_distance, min_distance, max_distance)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        _yaw -= event.relative.x * sens_x * 0.01
        _pitch -= event.relative.y * sens_y * 0.01
        _pitch = clamp(
            _pitch,
            deg_to_rad(pitch_min_deg),
            deg_to_rad(pitch_max_deg)
        )
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            desired_distance = clamp(desired_distance - zoom_step, min_distance, max_distance)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            desired_distance = clamp(desired_distance + zoom_step, min_distance, max_distance)

func _physics_process(delta: float) -> void:
    # 1) Orienta el pivot según yaw/pitch
    var target_basis := Basis()
    target_basis = target_basis.rotated(Vector3.UP, _yaw)
    target_basis = target_basis.rotated(target_basis.x, _pitch)

    # Interpolar suavemente la orientación del pivot (evita jitter con animaciones del player)
    var new_basis := global_transform.basis.slerp(target_basis, clamp(aim_smooth * delta, 0.0, 1.0))
    global_transform.basis = new_basis

    # 2) Calcula la posición ideal de la cámara (detrás del pivot)
    var origin: Vector3 = global_transform.origin
    var back_dir: Vector3 = -global_transform.basis.z # en Godot, -Z es forward; para ir "atrás" usamos +Z del pivot
    var ideal_target: Vector3 = origin + back_dir * desired_distance

    # 3) Raycast para evitar clipping (excluye al player)
    var space_state := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(origin, ideal_target)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    query.collision_mask = collision_mask
    if player_body != null:
        query.exclude = [player_body.get_rid()]

    var hit := space_state.intersect_ray(query)

    var target_pos: Vector3 = ideal_target
    if hit.size() > 0:
        # Ajusta distancia para quedar justo antes del obstáculo
        var hit_pos: Vector3 = hit["position"]
        var dist: float = origin.distance_to(hit_pos) - (safe_margin + collision_radius_hint)
        dist = clamp(dist, min_distance, desired_distance)
        target_pos = origin + back_dir * dist

    # 4) Suaviza la distancia para evitar "pops" al entrar/salir de colisión
    var target_dist := origin.distance_to(target_pos)
    _current_distance = lerp(_current_distance, target_dist, clamp(distance_smooth * delta, 0.0, 1.0))

    # 5) Coloca cámara y mira al pivot
    camera.global_transform.origin = origin + back_dir * _current_distance
    camera.look_at(origin, Vector3.UP)

    # 6) Opcional: alinear "near" para reducir clipping con el suelo en picado
    # camera.near = 0.05
