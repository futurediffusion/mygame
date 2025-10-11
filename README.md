# MyGame – Biblia Técnica R3

## Portada del proyecto
- **Versión interna:** R3 (Revisión completa a octubre de 2024).
- **Motor:** Godot Engine 4.4 (Forward+ renderer habilitado en `project.godot`).
- **Elevator pitch:** prototipo de aventura/cooperativo con un jugador totalmente modular, aliados gestionados por FSM y progresión estadística data-driven. El objetivo de R3 es estabilizar la base jugable y documentar todos los sistemas antes de entrar en producción de R4.

### Estado actual
El build es jugable en tercera persona con cámara orbital, locomoción física y recursos básicos (stamina, sprint). Los aliados pueden patrullar, combatir, construir, hablar, nadar y sentarse usando la misma librería de animaciones que el jugador. La UI dispone de un HUD desacoplado, y los datos de progresión se generan a partir de arquetipos JSON. El reloj de simulación ya centraliza los ticks y está listo para escalar a múltiples capas.

### ¿Qué funciona en R3?
- Captura de input y bindings automáticos (`scripts/bootstrap/InputSetup.gd`).
- Controlador del jugador con módulos de movimiento, salto, orientación, animación y audio (`Modules/*.gd`, `scenes/entities/player.gd`).
- Stamina jugable y seguimiento de ciclos de uso (`scripts/player/Stamina.gd`, `scenes/entities/player.gd`).
- FSM completa de aliados con progresión de habilidades, animaciones y personalización visual (`scenes/entities/Ally.gd`).
- Progresión basada en `AllyStats` y arquetipos data-driven (`Resources/AllyStats.gd`, `data/ally_archetypes.json`, `Singletons/Data.gd`).
- Autoloads de servicios (`SimClock`, `EventBus`, `GameState`, `Save`, `Flags`) configurados en `project.godot`.
- HUD reactivo basado en eventos (`scenes/ui/HUD.gd`).

### ¿Qué queda en prototipo o backlog para R4?
- Integrar AnimationTree avanzado compartido para Player y Ally (blendspaces contextuales).
- Migrar todos los módulos y aliados al tick del `SimClock` (algunos aún dependen de `_physics_process`).
- Implementar IA enemiga, reputación y economía sistémica.
- Sistema de guardado/carga integral (actualmente sólo persiste diccionarios sueltos).
- Modularidad visual de NPCs (materiales, gear y tintado todavía dependen de rutas estáticas).
- Optimización de escenas `world/` y limpieza de `.tmp` generados por el editor.

### Registro de mantenimiento reciente
- Corregida la indentación del bucle global en `Singletons/SimClock.gd` para restaurar el parseo en Godot 4.4.
- Ajustada la indentación por tabs de los bloques `else` en `scenes/entities/Ally.gd`, resolviendo los errores de análisis en Godot 4.4.
- Orden de tick determinista en `Singletons/SimClock.gd`: nuevo export `order_strategy`, API `set_priority` y limpieza automática de módulos inválidos aseguran emisión estable antes de pausar por grupo.
- Actualizados los comparadores de orden en `Singletons/SimClock.gd` para usar `Callable` con `sort_custom` en Godot 4.4, eliminando los errores de análisis por firma de función.
- `Singletons/GameState.gd` ahora coordina las pausas del `SimClock` local durante `set_paused` y `set_cinematic`, evitando consumo de stamina o transiciones de FSM mientras dure la pausa.
- Telemetría R3→R4: `Singletons/SimClock.gd` suma contadores de ticks/tiempo y expone `print_clock_stats()`/`get_group_stats()`, mientras `scenes/entities/Ally.gd` registra transiciones de estados con `print_verbose` y `Modules/AllyFSMModule.gd` limpia registros al cambiar `USE_SIMCLOCK_ALLY` en runtime.
- Nuevo banco de pruebas `scenes/world/test_clock_benchmark.tscn` con script dedicado para instanciar aliados masivamente, alternar `Flags.USE_SIMCLOCK_ALLY`, pausar `Flags.ALLY_TICK_GROUP` y mostrar métricas de ticks/s en pantalla.
- Formalizada la migración R3→R4 inicial: `SimClock` ahora tipa grupos con `StringName`, expone pausa por grupo y se apoya en `scripts/core/Flags.gd` para banderas de compatibilidad sin alterar el loop del Player.
- Ajustado `Modules/AnimationCtrl.gd` para que verifique la existencia de parámetros del `AnimationTree` con `get_parameter_list` cuando `has_parameter` no está disponible en Godot 4.4, evitando llamadas inválidas en runtime.
- Tipado explícito y sanitización de `entry_name` en `Modules/AnimationCtrl.gd` para evitar errores de inferencia en Godot 4.4 cuando el parámetro viene como `Variant` o `null`.
- Normalizada la indentación de `Modules/Jump.gd` a tabs consistentes para Godot 4.4, eliminando los errores de análisis por mezcla de espacios y preservando la lógica de salto.
- Restaurada la indentación por tabs en `scenes/entities/player.gd` para Godot 4.4, resolviendo los errores de parsing que aparecían alrededor de `_update_module_stats()` y reactivando el script principal.
- Eliminadas las advertencias del depurador al prefijar parámetros opcionales en `scenes/entities/Ally.gd`, silenciar la señal `jumped` en `Modules/State.gd` y autoasignar `animation_tree_path` en `Modules/AnimationCtrl.gd` cuando falta en el inspector.
- Tipado explícito de `group_variant` en `Singletons/SimClock.gd` para eliminar el error de inferencia de `Variant` que bloqueaba el parseo en Godot 4.4.
- Unificado el consumo de `delta` de la FSM de `scenes/entities/Ally.gd` para que dependa del `dt` entregado por `_ally_physics_update` durante la migración a `SimClock`, manteniendo consistencia con `USE_SIMCLOCK_ALLY`.
- Añadido `Modules/AllyFSMModule.gd` para registrar la FSM de `scenes/entities/Ally.tscn` como módulo de `SimClock`, respetando `Flags.ALLY_TICK_GROUP` y preservando el fallback por `_physics_process` cuando `USE_SIMCLOCK_ALLY` está desactivado o falta el autoload.

---

## Diagrama textual de estructura del proyecto
```
res://
 ├─ README.md (este documento)
 ├─ howtopush.txt
 ├─ icon.svg / icon.svg.import (icono del proyecto)
 ├─ node_3d.tscn (escena de prueba vacía)
 ├─ project.godot (configuración, autoloads e InputMap inicial)
 ├─ Modules/
 │   ├─ AnimationCtrl.gd (controlador de AnimationTree del jugador)
 │   ├─ AudioCtrl.gd (reproducción de SFX de movimiento)
 │   ├─ Jump.gd (mecánicas de salto y buffers)
 │   ├─ ModuleBase.gd (base para módulos con registro en SimClock)
 │   ├─ Movement.gd (integración horizontal y aceleración)
 │   ├─ Orientation.gd (rotación del modelo hacia la entrada)
 │   └─ State.gd (gravedad, aterrizajes y configuración física)
 ├─ Resources/
 │   └─ AllyStats.gd (Resource con estadísticas, skills y fórmulas)
 ├─ Singletons/
 │   ├─ Data.gd (autoload de arquetipos y fábrica de stats)
 │   ├─ EventBus.gd (bus de señales globales)
 │   ├─ GameState.gd (estado global de pausa/cinemática)
 │   ├─ Save.gd (utilidad de guardado comprimido JSON)
 │   └─ SimClock.gd (scheduler de ticks local/regional/global)
 ├─ art/
 │   └─ characters/
 │       ├─ animations1.glb (+ `.import`) – rig y animaciones comunes
 │       ├─ animations1_player2.png (+ `.import`) – textura base de proxy
 │       ├─ front jump.glb (+ `.import`), land*.glb (+ `.import`) – clips adicionales
 ├─ audio/
 │   └─ sfx/
 │       ├─ footsteps/footstep.ogg (+ `.import`)
 │       └─ player/{jump,land}.ogg (+ `.import`)
 ├─ core/
 │   └─ one_shots/SetupInput.gd (bootstrap histórico de InputMap)
 ├─ data/
 │   ├─ ally_archetypes.json (arquetipos jugables)
 │   └─ animations/animations.res (AnimationLibrary compartida)
 ├─ scenes/
 │   ├─ entities/
 │   │   ├─ Ally.tscn / Ally.gd (NPC modular con FSM)
 │   │   ├─ player.tscn / player.gd (jugador principal)
 │   │   └─ player_backup.gd (versión previa de orquestador, referencia histórica)
 │   ├─ ui/
 │   │   └─ HUD.tscn / HUD.gd (capa de mensajes temporales)
 │   └─ world/
 │       ├─ test_flat.tscn, test_ramps.tscn, test_world.tscn (arenas de prueba)
 │       ├─ test_clock_benchmark.tscn (benchmark de ticks SimClock vs `_physics_process`)
 │       └─ *.tmp (copias temporales generadas por el editor)
 └─ scripts/
     ├─ bootstrap/InputSetup.gd (crea bindings de input one-shot)
     ├─ core/
     │   ├─ PhysicsLayers.gd (constantes de colisión)
     │   └─ Flags.gd (feature flags R3→R4)
     └─ player/
         ├─ CameraOrbit.gd (rig orbital y efectos de cámara)
         └─ Stamina.gd (recurso de resistencia del jugador)
```

---

## Arquitectura general
La simulación gira alrededor del `SimClock` (`Singletons/SimClock.gd`), un scheduler que agrupa nodos por cadencias (`local`, `regional`, `global`). Cada módulo (`Modules/ModuleBase.gd`) se registra automáticamente en el clock y expone `physics_tick(dt)`. El jugador (`scenes/entities/player.gd`) decide si delega el loop en el clock o si ejecuta una ruta manual cuando éste no está disponible (modo fallback editor). En cada tick se cachea el input relativo a cámara, se propagan los datos a los módulos (movimiento, orientación, salto, animación, audio) y se finaliza la integración con `move_and_slide` antes de evaluar consumo de stamina y ciclos de aprendizaje.

Los aliados (`scenes/entities/Ally.gd`) usan un FSM explícito con estados `IDLE`, `MOVE`, `COMBAT_*`, `BUILD`, `SNEAK`, `SWIM`, `TALK`, `SIT`. Cada estado aplica animaciones y actualiza estadísticas mediante `AllyStats`, el Resource que encapsula atributos base, skills y reglas de progresión (`Resources/AllyStats.gd`). Las estadísticas se generan desde la singleton `Data.gd`, que parsea `data/ally_archetypes.json`, fusiona defaults, crecimiento y configuración visual; ese mismo diccionario controla presets de materiales y gear en tiempo de ejecución.

Los autoloads (`EventBus`, `Data`, `SimClock`, `GameState`, `Save`, `Flags`) se comunican vía señales: `EventBus` difunde mensajes de HUD y eventos de gameplay; `GameState` expone flags globales de pausa/cinemática para que Player module el input; `Save` aporta utilidades de persistencia; `Data` abastece instancias `AllyStats` y presets visuales; `Flags` concentra toggles de migración (por ejemplo `USE_SIMCLOCK_ALLY`). El HUD (`scenes/ui/HUD.gd`) sólo escucha `EventBus.hud_message`, manteniendo la UI desacoplada de la lógica. El bootstrap de input (`scripts/bootstrap/InputSetup.gd`) ejecuta una sola vez al inicio y garantiza que todas las acciones (movimiento, combate, construcción) estén registradas incluso en proyectos clonados.

---

## Sistemas implementados

### Player Orchestrator (`scenes/entities/player.gd`)
Gestiona el ciclo físico del jugador, cachea el input y propaga el contexto a los módulos. Expone señales (`context_state_changed`, `talk_requested`, `sit_toggled`, `interact_requested`, `combat_mode_switched`, `build_mode_toggled`) que permiten a otros sistemas reaccionar sin acceder al input bruto. Al finalizar cada tick, decide si ejecutar `_manual_tick_modules` o esperar a `SimClock.ticked`, aplica `move_and_slide`, sincroniza stamina y reporta ciclos a `AllyStats` mediante `note_stamina_cycle`. Además actualiza `PerfectJumpCombo` para coordinar coyote, buffer y multiplicadores de salto/velocidad tanto en modo SimClock como en `_physics_process`. También detecta contacto con áreas de agua y cambia `ContextState` para el HUD o IA.

### Módulos del jugador (`Modules/`)
- **MovementModule (`Movement.gd`)**: recibe la dirección normalizada y el flag de sprint desde el Player, calcula la velocidad horizontal objetivo y aplica aceleración/decadencia separada para suelo/aire.
- **JumpModule (`Jump.gd`)**: administra coyote time, jump buffer, salto variable y disparo de animaciones/audio; emite efectos de cámara cuando procede.
- **StateModule (`State.gd`)**: centraliza la gravedad (con multiplicador de caída), configura `floor_max_angle`/`floor_snap_length` y emite las señales `jumped`, `left_ground` y `landed` al detectar transiciones aéreas.
- **OrientationModule (`Orientation.gd`)**: interpola la rotación del modelo hacia el input de locomoción respetando la corrección de forward.
- **AnimationCtrlModule (`AnimationCtrl.gd`)**: actualiza el `AnimationTree` (`PARAM_LOC`, `PARAM_AIRBLEND`, `PARAM_SPRINTSCL`) y bloquea locomoción en aire mientras gobierna un StateMachine `Jump → Fall → Land/Locomotion`.
- **AudioCtrlModule (`AudioCtrl.gd`)**: toca SFX de salto, aterrizaje y pasos con random pitch; admite modo automático por timer para footfalls.
- **PerfectJumpCombo (`Modules/PerfectJumpCombo.gd`)**: gestiona coyote time, jump buffer y la ventana de aterrizaje perfecta para escalar un combo que aumenta velocidad horizontal y potencia de salto; expone señales para UI/FX.

Todos heredan de `ModuleBase`, que resuelve el registro en `SimClock` usando `StringName` y permite pausar ticks por grupo o módulo respetando los toggles de migración.

### Ally FSM (`scenes/entities/Ally.gd`)
Un `CharacterBody3D` configurable vía inspector. Cada estado del enum ejecuta un método `_do_*` que actualiza `velocity`, reproduce animaciones (`AnimationPlayer` autocargado) y gana habilidades según la actividad (`gain_skill`, `gain_base_stat`). Ofrece API pública para control externo: `set_move_dir`, `set_crouched`, `set_sprinting`, `set_in_water`, `start_talking`, `sit_on`, `stand_up`, `engage_melee`, `register_ranged_attack`. También gestiona anclajes de asiento, temporizadores de diálogo, personalización visual (`apply_visual_from_archetype`) y seguimiento de ciclos de stamina.

### AllyStats (`Resources/AllyStats.gd`)
Resource con propiedades exportadas para HP, stamina, vitalidad, fuerza, atletismo, natación y árboles de skills (`war`, `stealth`, `science`, `craft`, `social`). Implementa reglas de progresión con `gain_skill`, `gain_base_stat`, `note_stamina_cycle`, `note_low_hp_and_bed_recovery`, `attack_power_for`, `sprint_speed`, `sprint_stamina_cost`. Controla diminishing returns mediante `_phase_multiplier_for`, `_skill_repeat_decay` y `_session_repeat_factor` para evitar grindeo repetitivo.

### Data y arquetipos (`Singletons/Data.gd` + `data/ally_archetypes.json`)
Carga el JSON al iniciarse, guarda defaults y entradas individuales, y expone consultas (`archetype_exists`, `get_archetype_entry`, `get_capabilities`, `get_archetype_visual`). `make_stats_from_archetype` instancia `AllyStats` aplicando mapeo de propiedades base, merge profundo de skill trees y crecimiento (multiplicadores y soft caps). También preserva el diccionario en `allies` para compatibilidad con código heredado.

### SimClock (`Singletons/SimClock.gd`)
Scheduler autoritativo con acumuladores por grupo (`local`, `regional`, `global`). Permite pausar grupos o módulos, ajustar intervalos y emitir la señal `ticked(group_name, dt)`. Los módulos inscritos reciben `physics_tick` según la cadencia seleccionada. Player detecta si el clock está presente y sincroniza `_finish_physics_step` tras cada tick local.

### EventBus + HUD (`Singletons/EventBus.gd`, `scenes/ui/HUD.gd`)
`EventBus` define señales globales (`hud_message`, `ally_died`, `save_requested`, `load_requested`, `stamina_changed`) y helpers `post_hud`, `notify_ally_died`. `HUD.gd` escucha `hud_message`, muestra texto en pantalla y usa un `SceneTreeTimer` para ocultarlo tras el tiempo indicado. El patrón elimina dependencias directas entre gameplay y UI.

### Input one-shot (`scripts/bootstrap/InputSetup.gd` + `core/one_shots/SetupInput.gd`)
`InputSetup.gd` se instancia al inicio, elimina la acción obsoleta `talk`, crea acciones faltantes y añade eventos (teclas o botones) sin duplicados; después se autodestruye. `core/one_shots/SetupInput.gd` queda como referencia histórica con bindings mínimos (WASD + salto) y puede retirarse cuando todos los niveles usen el bootstrap nuevo.

### Stamina y vitalidad
`Stamina.gd` mantiene `value`, consumo por sprint (`consume_for_sprint`) y regeneración con retardo (`regen_delay`). El jugador consulta `can_sprint`, llama a `consume_for_sprint` y delega los ciclos a `AllyStats.note_stamina_cycle`, que decide cuándo aumentar `stamina_max`. `AllyStats.note_low_hp_and_bed_recovery` cubre progresión de vitalidad tras recuperaciones en cama.

---

## Contrato de Stats
- **Incremento de skills:** `gain_skill(tree, skill, amount, context)` aplica multiplicadores por fase (`_phase_multiplier_for` con tramos 0–40, 40–80, 80+), factor de sesión (`_session_repeat_factor`) y decaimiento por repetición (`_skill_repeat_decay`). Acciones consecutivas con el mismo `action_hash` reducen ganancias hasta 0.25×, mientras que rotar actividades restaura el multiplicador.
- **Incremento de atributos base:** `gain_base_stat` valida rangos y sólo permite aumentar stamina cuando `_allow_stamina_gain` es verdadero (usado por ciclos). Stats como `move_speed` se clampéan a [0, 100].
- **Ciclos de stamina:** `note_stamina_cycle(consumed, recovered, window)` exige al menos 40% de consumo y 95% de recuperación en ventanas de 10–240 s. Cada ciclo exitoso otorga ~0.35 puntos de stamina escalados por `window_factor` y reduce el multiplicador para evitar farmeo continuo.
- **Recuperación de vitalidad:** `note_low_hp_and_bed_recovery` otorga vitalidad si el aliado cayó por debajo de 15% y descansó en cama; el factor de recuperación decae para prevenir exploits.
- **Fórmulas de combate:** `attack_power_for` = 0.5 × fuerza + 0.7 × skill + bonuses; `unarmed_base_damage` depende de fuerza y `war.unarmed`. `sprint_speed(base)` escala con atletismo/200, y `sprint_stamina_cost(base)` reduce el coste hasta 20% según atletismo/250.
- **Relación skills-ramas:** los árboles `war`, `stealth`, `science`, `craft`, `social` cubren subramas específicas (p. ej. `war.swords`, `stealth.lockpicking`, `science.engineering`). Ejemplos: `stats.gain_skill("war", "swords", 1.0, {"action_hash": "melee_sword"})`, `stats.note_stamina_cycle(0.55, 0.97, 60.0)`.

---

## Input y controles
Acciones creadas por `InputSetup.gd` (teclado/ratón por defecto):

| Acción | Binding | Uso |
| --- | --- | --- |
| `move_forward`, `move_back`, `move_left`, `move_right` | **W / S / A / D** | Locomoción básica.
| `sprint` | **Shift** | Activa sprint si hay stamina.
| `jump` | **Space** | Salto con buffer y coyote time.
| `crouch` | **C** | Sigilo/agacharse.
| `interact` | **E** | Interacción contextual (hablar, usar, abrir).
| `use` | **F** | Acción secundaria (reservada para herramientas).
| `build` | **B** | Conmutar modo de construcción.
| `attack_primary` | **Botón izquierdo** | Ataque principal.
| `attack_secondary` | **Botón derecho** | Defensa/apuntar.
| `pause` | **Esc** | Pausa y modo ratón.

El nodo bootstrap se elimina tras registrar las acciones, evitando repetir bindings cada carga.

---

## Data-driven y arquetipos
`ally_archetypes.json` sigue esta estructura:
```json
{
  "defaults": {
    "base": { "hp": 80, ... },
    "skills": { "war": { "swords": 0, ... }, ... },
    "growth": { "skill_gain_multiplier": 1.0, "soft_cap": 80 }
  },
  "archetypes": [
    {
      "id": "archer",
      "base": { "hp": 72, "stamina": 95, ... },
      "skills": { "war": { "ranged": 48, ... }, ... },
      "visual": {
        "preset": "res://models/...",
        "materials": { "Body": "..." },
        "tint": [0.85, 0.75, 0.65],
        "gear": { "head": "...", "back": "..." }
      },
      "growth": { "skill_gain_multiplier": 1.1, "soft_cap": 85 }
    }
  ]
}
```
`Data.gd` lee defaults, duplica los diccionarios y mezcla overrides por clave. `make_stats_from_archetype("archer")` produce un `AllyStats` listo para usar y `apply_visual_from_archetype` aplica preset, materiales, gear y tintado. Las capacidades (`capabilities`) permiten filtrar aliados por rol.

---

## Animaciones y modelos
- `player.tscn` instancia un `AnimationTree` con nodos `Locomotion`, `AirBlend`, `Jump`, `SprintScale` conectados al `AnimationPlayer` del modelo GLB (`art/characters/animations1.glb`).
- `AnimationCtrlModule` maneja los parámetros del árbol; comparte clips (`idle`, `walk`, `run`, `fall air loop`) con los aliados.
- `Ally.gd` busca automáticamente un `AnimationPlayer` en su jerarquía (`_bind_anim_player_from`), permitiendo reutilizar presets de Player. Las funciones `_swap_visual`, `_apply_material_overrides`, `_attach_gear` soportan hablar, sentarse, nadar, construir y atacar con animaciones específicas.
- Actualmente no hay `AnimationTree` dedicado para los aliados; se planea introducirlo en R4 para soportar blends complejos.

---

## Interfaz (HUD + EventBus)
`HUD.gd` (CanvasLayer) escucha `EventBus.hud_message` y muestra texto durante `seconds`. Usa un `SceneTreeTimer` para ocultar el mensaje y desconecta el timer previo si se emite otro mensaje. Ejemplo:
```gdscript
EventBus.post_hud("Guardado", 1.5)
```
Cualquier sistema puede publicar mensajes sin conocer la escena de HUD, manteniendo un diseño desacoplado. El bus también puede ampliarse con señales para stamina, guardado o muerte de aliados.

---

## Performance y escalabilidad
- **SimClock** agrupa módulos por cadencia, reduciendo coste cuando sistemas lejanos se mueven a capas regionales/globales. Permite pausar grupos enteros durante menús o cinemáticas.
- **FSM de aliados** usa lógica ligera por estado y evita nodos extra (un `CharacterBody3D` con animaciones directas).
- **Stats con DR** previenen exploits de farmeo repetitivo y mantienen progresión controlada sin introducir cálculos costosos.
- **Arquitectura modular** separa locomoción, animación y audio del orquestador, facilitando instanciar múltiples jugadores o NPCs reutilizando módulos existentes.

---

## Problemas comunes detectados en R3
- **Animaciones que no se reproducen:** asegurarse de que el `AnimationPlayer` esté bajo `Model` y que el nombre del clip coincida (ver exportados en `Ally.gd`).
- **Diferencias de indentación (tabs/espacios):** todos los scripts usan tabs; mezclar espacios produce errores en Godot 4.
- **`move_and_slide` sin `velocity`:** al pausar módulos (`should_skip_module_updates`) se debe limpiar la velocidad para evitar drift.
- **Scripts sin `class_name`:** añadirlo a recursos/módulos para aprovechar el autocompletado y registro en el editor.
- **Autoloads ausentes:** confirmar en `project.godot` que `Data`, `EventBus`, `SimClock`, `GameState`, `Save` están definidos antes de correr escenas aisladas.
- **Bootstrap duplicado:** eliminar instancias viejas de `core/one_shots/SetupInput.gd` cuando se use `scripts/bootstrap/InputSetup.gd` para evitar acciones en conflicto.

---

## Roadmap R3 → R4
1. Migrar absolutamente todos los sistemas de `_physics_process` a `SimClock` (Player ya soporta ambos caminos, Ally debe integrarse).
2. Implementar un `AnimationTree` compartido para Aliados con blend de contexto (sneak, swim, talk, sit) y control centralizado.
3. Diseñar IA enemiga con navegación regional y soporte de reputación/economía.
4. Completar pipeline de guardado/carga persistente (estado del jugador, aliados, mundo) usando `Save.gd` como backend.
5. Refactorizar la personalización visual de NPCs para admitir combinaciones dinámicas (materiales, gear modular, tintado runtime).
6. Limpiar escenas `world/` y preparar escenarios de benchmark para pruebas de rendimiento multitudes + clock regional.

