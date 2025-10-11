# AGENTS.md — Notas operativas para Codex (MyGame R3)

## 1. Auditoría rápida del repositorio
- Los módulos del jugador derivan de `ModuleBase`, que se suscribe solo al `SimClock` y enruta `_on_clock_tick` hacia `physics_tick(dt)`; no hay `_physics_process` en estos scripts. 【F:Modules/ModuleBase.gd†L1-L35】【F:README.md†L38-L41】
- El `SimClock` autoload gobierna la cadencia por grupos (`local`, `regional`, `global`), ordena por prioridad y expone contadores para debug. 【F:Singletons/SimClock.gd†L1-L99】【F:README.md†L174-L181】
- El HUD está desacoplado por `EventBus.hud_message`; los mensajes pasan por `EventBus.post_hud` y `HUD.gd` gestiona visibilidad con timers. 【F:Singletons/EventBus.gd†L3-L16】【F:scenes/ui/HUD.gd†L1-L28】
- El bootstrap de input vive en `scripts/bootstrap/InputSetup.gd`, limpia acciones obsoletas y evita duplicados al registrar bindings. 【F:scripts/bootstrap/InputSetup.gd†L3-L75】
- Las estadísticas y progresión de aliados se controlan desde `Resources/AllyStats.gd`, con saneado de árboles de skills y diminishing returns; `Data.gd` + `ally_archetypes.json` siguen siendo la fuente de verdad. 【F:Resources/AllyStats.gd†L1-L199】【F:README.md†L16-L173】

## 2. Reglas imprescindibles
1. **Motor objetivo: Godot 4.4 (Forward+).** Revisa APIs antes de usar funciones nuevas o sintaxis de 4.5+. 【F:README.md†L4-L9】
2. **Indentación con tabs en GDScript.** Evita mezclar espacios; el proyecto ya se normalizó así. 【F:README.md†L42-L44】
3. **Mantén `class_name` en scripts reutilizables** (módulos, recursos, autoloads) para conservar el autocompletado. 【F:Modules/ModuleBase.gd†L1-L35】【F:Singletons/SimClock.gd†L1-L57】
4. **Nada de `_physics_process` en módulos/aliados.** Usa `physics_tick(dt)` registrado en `SimClock`. 【F:Modules/ModuleBase.gd†L11-L35】【F:README.md†L38-L41】
5. **Evita el operador ternario compacto (`?:`).** Prefiere `a if cond else b` para mantener compatibilidad 4.4. 【F:README.md†L30-L33】
6. **Propaga HUD/UI vía `EventBus.post_hud` o señales existentes.** No acoples escenas directas. 【F:Singletons/EventBus.gd†L3-L16】【F:scenes/ui/HUD.gd†L6-L28】
7. **Datos primero.** Cambios de stats o arquetipos pasan por JSON + `Data.gd`, no hardcodees en lógica. 【F:README.md†L16-L173】
8. **Orden del tick del Player:** `State.pre_move_update(dt)` → `Jump.physics_tick(dt)` → resto de módulos → `move_and_slide()` → `State.post_move_update()`. Mantén este flujo para que coyote/hold usen el mismo reloj. 【F:scenes/entities/player.gd†L190-L233】

## 3. Patrones y plantillas útiles
- **Nuevo módulo de jugador/NPC**
  1. Extiende `ModuleBase`, define `class_name`, exports (`sim_group`, `priority`) y dependencias (ej. `@export var player: Player`).
  2. Registra lógica en `physics_tick(dt)` y comenta el coste si corre cada tick.
  3. Para pruebas de orden usa `tests/TestClock.tscn` (Godot headless). `godot --headless --run res://tests/TestClock.tscn`. 【F:README.md†L38-L41】
- **Integrar con SimClock manualmente**
  - Si un nodo no puede heredar `ModuleBase`, llama `SimClock.register_module(self, group, priority)` en `_ready()` y respeta `group`/`priority` definidos en `Singletons/SimClock.gd`. 【F:Singletons/SimClock.gd†L25-L99】
- **Aliados y FSM**
  - Usa la API pública (`set_move_dir`, `engage_melee`, etc.) y añade nuevos estados como `_do_state(dt)` que actualicen animación + stats mediante `AllyStats`. 【F:README.md†L143-L170】
- **Balance y progresión**
  - Para stamina/skills reutiliza `AllyStats.note_stamina_cycle` y `gain_skill` con `action_hash` para aprovechar los factores de repetición. 【F:Resources/AllyStats.gd†L152-L199】
- **Input adicional**
  - Nuevas acciones deben agregarse en `InputSetup.gd`, cuidando `queue_free()` al final y evitando reinstanciar el nodo legacy. 【F:scripts/bootstrap/InputSetup.gd†L29-L75】

## 4. Checklist mental antes de comitear
- Tabs consistentes y tipado explícito (`float`, `Vector3`, etc.) en nuevas variables.
- `class_name` + export paths revisados en inspector.
- Registro correcto en `SimClock` (grupo/priority esperados, sin `await`).
- HUD/eventos pasan por `EventBus`.
- Cambios en datos reflejados en JSON + `Data.gd`.
- Ejecuta al menos el test de reloj o la escena relevante en modo headless cuando alteres prioridades/ticks.

## 5. Snippet recordatorio (copiar/pegar)
```gdscript
extends ModuleBase
class_name ExampleModule

@export var owner_ref: Node

func _ready() -> void:
	super._ready()

func physics_tick(dt: float) -> void:
	# CPU: O(1) por tick, sin asignaciones complejas
	if owner_ref == null:
		return
	owner_ref.some_method(dt)
```

> Mantén este archivo sincronizado si detectas nuevas invariantes (ej. métricas de SimClock, AnimationTree compartido) para que el agente siempre tenga el mapa actualizado.

## 6. Notas recientes
- Cuando ajustes PerfectJumpCombo, resetea el combo al fallar la ventana perfecta y evita decaimientos ocultos; Godot 4.4 detecta mejor los regresos si el contador pasa por 0 explícito.
- Al implementar salto variable, corta la velocidad ascendente al soltar (usa `release_velocity_scale`) en lugar de añadir `velocity +=` múltiples veces; evita micro saltos inconsistentes en Godot 4.4.
- Godot 4.4 falla con "Unexpected indent" si se cuelan espacios en `scenes/entities/player.gd`; mantén tabs estrictos al ajustar `_update_module_stats()` o cualquier bloque que sincronice exports con módulos.
- Evita retirar `class_name` de los autoloads (`SimClockAutoload`, `GameStateAutoload`): Godot 4.4 deja de exponerlos y los casts tipados en escenas (`player.gd`, módulos) empiezan a marcar errores de parseo.
- Cuando un script tipado necesita castear `SimClockAutoload`, precarga `res://Singletons/SimClock.gd` (`const SIMCLOCK_SCRIPT := preload(...)`) y valida `autoload is SIMCLOCK_SCRIPT` antes de usar `as`; así Godot 4.4 registra la clase global incluso en escenas que cargan antes del autoload.
- No reutilices un `class_name` idéntico al nombre del autoload (ej. `GameState` → `/root/GameState`); Godot 4.4 reporta "Class <name> hides an autoload singleton". Usa un sufijo como `Autoload` y actualiza los type hints en nodos consumidores.
- Fast fall depende de dos módulos: `MovementModule` multiplica `max_speed_air` por `fast_fall_speed_multiplier` sólo durante la caída y `StateModule` aplica `fall_gravity_scale` ≥ 1.0; mantén ambos exports sincronizados desde `player.gd` para conservar el 50 % extra de velocidad en descenso.
