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
- Toggle de sigilo con la tecla `C` que activa el blend Sneak (`SneakEnter` → `SneakIdleWalk` → `SneakExit`) y bloquea el sprint mientras dura.
- Stamina jugable y seguimiento de ciclos de uso (`scripts/player/Stamina.gd`, `scenes/entities/player.gd`).
- FSM completa de aliados con progresión de habilidades, animaciones y personalización visual (`scenes/entities/Ally.gd`).
- Progresión basada en `AllyStats` y arquetipos data-driven (`Resources/AllyStats.gd`, `data/ally_archetypes.json`, `Singletons/Data.gd`).
- Autoloads de servicios (`SimClock`, `EventBus`, `GameState`, `Save`, `Flags`) configurados en `project.godot`.
- HUD reactivo basado en eventos (`scenes/ui/HUD.gd`).

### ¿Qué queda en prototipo o backlog para R4?
- Integrar AnimationTree avanzado compartido para Player y Ally (blendspaces contextuales).
- Instrumentar métricas editoriales para `SimClock` (contadores, tiempos promedio) y exponer cadencias en Project Settings.
- Implementar IA enemiga, reputación y economía sistémica.
- Sistema de guardado/carga integral (actualmente sólo persiste diccionarios sueltos).
- Modularidad visual de NPCs (materiales, gear y tintado todavía dependen de rutas estáticas).
- Optimización de escenas `world/` y limpieza de `.tmp` generados por el editor.

### Log rápido (último cambio)
- `Modules/AnimationCtrl.gd` + `scenes/entities/player.tscn`: el árbol `LocomotionSpeed` ahora encadena `Locomotion → SprintSpeed → SneakBlend → SneakExit → AirBlend → Jump`, dispara `SneakEnter`/`SneakExit` vía `request` y sólo necesita animar `SneakBlend.blend` para alternar entre locomoción normal y sigilo.
- `Modules/AnimationCtrl.gd`: tipado explícito del resultado de `has_parameter` para evitar inferencias `Variant` al compilar en Godot 4.4 y mantener la detección de parámetros del AnimationTree.
- `scripts/bootstrap/InputSetup.gd` + `scenes/entities/player.gd`: retira los tipos anidados del diccionario de acciones para que Godot 4.4 vuelva a cargar el bootstrap de input y restablezca la precarga desde el Player.
- `Modules/AnimationCtrl.gd`: reorganiza `_update_exit_blend()` para eliminar el `else` problemático, Godot 4.4 vuelve a parsear `AnimationCtrlModule` y el toggle Sneak (tecla `C`) recupera su blend completo.
- `Modules/AnimationCtrl.gd`: corrige la indentación del bloque `_update_exit_blend()` para que Godot 4.4 vuelva a parsear `AnimationCtrlModule` y restablece el acceso tipado desde `player.gd`.
- `scenes/entities/player.gd` + `Modules/AnimationCtrl.gd`: Sneak se vuelve un toggle (tecla `C`), desactiva el sprint, reproduce `SneakEnter` vía OneShot y mezcla `SneakIdleWalk`/`SneakExit` antes de regresar a `LocomotionSpeed`.
- `Modules/AnimationCtrl.gd`: ahora dispara el `OneShot` de salto con el parámetro `Jump/request`, cachea los blends dentro de `LocomotionSpeed` y apaga el clip al aterrizar, manteniendo la mezcla Jump→Fall aun sin estados dedicados.
- `scenes/entities/player.tscn`: depurada la `AnimationTree` duplicada, se conserva un solo `LocomotionSpeed` con OneShot de salto (fade-in/out) y se eliminan subrecursos redundantes para que AirBlend responda al controlador.
- `scripts/player/CameraOrbit.gd`: el SpringArm compone la máscara con `PhysicsLayers` para conservar la capa por defecto sin invocar `set_collision_mask_value`, evitando el error en Godot 4.4.
- `Modules/AnimationCtrl.gd`: restaura los tiempos de crossfade dinámicos usando tanto `set_transition_blend_time` como `set_transition_duration`, garantizando que las transiciones Locomotion→Jump y Jump→Fall se suavicen en Godot 4.4.
- `Modules/AnimationCtrl.gd`: el estado de caída ahora solo se activa tras cruzar el apex (velocidad vertical ≤ 0) o alcanzar el umbral negativo configurado, permitiendo que la animación de salto se reproduzca completa antes de mezclar con la de caída.
- `Modules/PerfectJumpCombo.gd` + `tests/TestJumpCombo.gd`: el combo perfecto ahora escala en 100 niveles lineales hasta duplicar la altura base (200%) y la prueba headless verifica la progresión completa sin reinicios tempranos.
- `scenes/entities/player.gd`: la velocidad base de salto baja a 8.2 para suavizar el salto máximo cuando mantienes presionada la tecla.
- `Modules/Movement.gd` + `Modules/Jump.gd`: tipado explícito del combo del jugador al resolver `player.combo`, evitando el error de inferencia de Godot 4.4 y asegurando que el PerfectJumpCombo siga activo tras los FX.
- `Modules/Movement.gd` + `Modules/Jump.gd`: ajustado el acceso a `player.combo` usando variables sin inferencia para que Godot 4.4 deje de marcar error de tipado al resolver el combo perfecto.
- `Modules/AnimationCtrl.gd`: restaurada la indentación con tabs, limpiado el export `animation_tree_path` y reordenada la inicialización del AnimationTree para que Godot 4.4 vuelva a parsear el módulo y exponga correctamente la clase global al jugador.
- `Modules/AnimationCtrl.gd`: ahora calcula mezclas suaves por código para los saltos y caídas; expone tiempos de crossfade configurables, ajusta gradualmente el paso Jump→Fall y restaura la transición Locomotion→Jump en función de la velocidad.
- `Modules/State.gd`: tipado explícito de la gravedad extra en caída para que Godot 4.4 deje de inferir `Variant` y desaparezca el error al compilar el script.
- `Modules/State.gd` + `tests/TestFastFall.gd`: el fast fall ahora se activa en el mismo tick en que cruzas el apex incluso si mantienes pulsado el salto, y la prueba cubre la transición para evitar regresiones.
- `Modules/Movement.gd` + `scenes/entities/player.gd`: el fast fall del jugador ahora aplica un multiplicador de 1.5× tanto a la velocidad aérea como a la gravedad en caída, garantizando que descender sea un 50% más rápido y responda al combo perfecto.
- `Modules/Movement.gd` + `Modules/State.gd`: revalidado el fast fall tras la migración al StateMachine; `max_speed_air` se alinea con `run_speed`, `fall_gravity_scale` se clampa a ≥1.0 y `tests/TestFastFall.tscn` comprueba el 50% extra de caída.
- `Modules/PerfectJumpCombo.gd` + `Modules/Jump.gd`: se restauró la ventana `perfect` sin decaimiento temporal, aplicando multiplicadores curvos y reiniciando el combo inmediatamente cuando fallas el timing.
- `Modules/PerfectJumpCombo.gd` + `Modules/Jump.gd` + `Modules/Movement.gd`: referencias robustecidas al nodo `PerfectJumpCombo`, asegurando que el combo siga activo tras migrar el `AnimationTree` a StateMachine y que cualquier instancia hija pueda resolver su `CharacterBody3D` aunque el `owner` sea nulo.
- `tests/TestJumpCombo.gd` + `tests/TestJumpCombo.tscn`: nueva prueba headless que valida incremento, multiplicador y reinicio del combo perfecto usando el orden de tick del SimClock.
- `Modules/Jump.gd`: el salto variable ahora recorta la velocidad vertical con `release_velocity_scale` cuando sueltas antes del umbral, logrando saltos cortos consistentes sin romper el combo perfecto ni la ventana de coyote.
- `Singletons/GameState.gd` renombra su `class_name` a `GameStateAutoload` para evitar la colisión "Class hides an autoload singleton" en Godot 4.4 y `scenes/entities/player.gd` actualiza el tipado del autoload.
- `Singletons/GameState.gd`, `Modules/ModuleBase.gd`, `scenes/entities/player.gd`, `scenes/entities/Ally.gd` y `scenes/world/test_clock_benchmark.gd`: ahora precargan `SimClock.gd` antes de castear y validan el tipo del autoload para que Godot 4.4 registre `SimClockAutoload` sin advertencias ni errores de parseo.
- `Singletons/GameState.gd` y `Singletons/SimClock.gd`: se restauró el `class_name` y la indentación en tabs para que Godot 4.4 vuelva a exponer los autoloads `GameState` y `SimClockAutoload` sin errores de parseo ni advertencias de tipado al castear en el Player.
- `scenes/entities/player.gd`: se restauró la indentación en tabs de `_update_module_stats()` para que Godot 4.4 deje de marcar "Unexpected indent" al sincronizar exports de salto y movimiento durante la carga.

### Registro de mantenimiento reciente
- Ajustado el fast fall del jugador: Player exporta `fall_gravity_multiplier` y `fast_fall_speed_multiplier`, sincronizados con `Movement.gd` y `State.gd` para mantener la caída un 50% más rápida en aire sin romper el buffer de salto.
- `Modules/Jump.gd` introduce `release_velocity_scale` como export para sintonizar la altura del salto corto y corta la velocidad ascendente cuando el botón se suelta antes de agotar `max_hold_time`, manteniendo tabs para Godot 4.4.
- `_update_module_stats()` en `scenes/entities/player.gd` vuelve a usar tabs y repropaga `jump_speed`/`coyote_time` al módulo de salto y velocidades/aceleraciones al módulo de movimiento, eliminando los errores de parseo reportados en Godot 4.4.
- Reordenado el ciclo de salto: `InputBuffer.gd` guarda press/release con reloj compartido, `State.gd` aplica gravedad en `pre_move_update`/`post_move_update` y `Jump.gd` consume buffer + coyote + hold reduciendo gravedad antes de `move_and_slide()`.
- Actualizado `scripts/player/InputBuffer.gd` y `scenes/entities/player.gd`: el buffer escucha `_unhandled_input` como nodo hijo, conserva 120 ms y entrega el salto al tick del `SimClock` sin perder pulsaciones.
- Reescrito el trinomio de locomoción: `Modules/Jump.gd` usa buffer+coyote con `floor_snap` seguro y hold variable, `Modules/State.gd` reduce gravedad mientras se mantiene el salto y `Modules/Movement.gd` adopta aceleraciones 26/9.5 con fricción 10; `player.gd` sincroniza los nuevos exports (accel/air/fricción).
- Renombrado `class_name` de `Singletons/SimClock.gd` a `SimClockAutoload` y actualizados los casts tipados en `ModuleBase`, `GameState`, `player.gd`, `Ally.gd` y el benchmark para evitar la colisión con el autoload de Godot 4.4.
- Ajustado `ModuleBase` con constantes `DEFAULT_*` y `Modules/AllyFSMModule.gd` reasigna los defaults antes de `super._ready()` para eliminar la duplicación de exports (`sim_group`, `priority`) y mantener prioridad 15 para aliados.
- Restaurado `Singletons/SimClock.gd` con indentación a tabs, comparador tipado y limpieza de entradas para que Godot 4.4 vuelva a exponer la clase `SimClock` a `GameState` y al resto de autoloads.
- Priorización FSM→movimiento: `Modules/AllyFSMModule.gd` pasa a prioridad 15 y ahora invoca `fsm_step(dt)`; `scenes/entities/Ally.gd` mantiene prioridad 20, aplica el `move_and_slide()` final y conserva un fallback interno para aliados sin módulo.
- `Singletons/SimClock.gd` deja de usar `Dictionary.get_or_add` (inexistente en Godot 4.4), inicializa grupos con `_ensure_group_entry` y mantiene la iteración segura con `duplicate()` + limpieza en `tree_exited`.
- `Singletons/SimClock.gd` expone `get_group_tick_counter()` y `scenes/entities/Ally.gd` usa el contador para asegurar que cada tick se procese una sola vez sin `await`, evitando el falso positivo "Ally movido dos veces en el mismo tick" al cargar `test_ramps`.
- Cierre R3 duro: `Singletons/SimClock.gd` queda como scheduler determinista con prioridades, contadores de ticks y limpieza automática en `tree_exited` para todos los grupos (`local`, `regional`, `global`).
- Player y Allies migrados al `SimClock.register_module` con prioridades configurables; se eliminó `_physics_process` en aliados y módulos, consolidando el tick físico en `physics_tick(dt)`.
- `Modules/ModuleBase.gd` se redujo a suscripción automática y `Modules/AllyFSMModule.gd` ahora reinyecta `physics_tick` directo sobre el Ally dueño.
- `scenes/world/test_clock_benchmark.gd` quedó fijo en modo SimClock y sólo controla pausa de grupo; se añadió `tests/TestClock.tscn` para validar el orden de ejecución (A→B) en ticks locales.
- `scripts/core/Flags.gd` conserva únicamente `ALLY_TICK_GROUP`, retirando toggles heredados como `USE_SIMCLOCK_ALLY`.
- Normalizada la indentación con tabs en `scenes/entities/Ally.gd` para que Godot 4.4 procese correctamente `fsm_step` y el ciclo físico.
- Corregido el acceso al autoload `SimClock` en `Modules/ModuleBase.gd`, `scenes/entities/player.gd` y `scenes/entities/Ally.gd`, resolviendo el choque `class_name` vs singleton de Godot 4.4 antes de registrar módulos.
- Tipado el cálculo de aterrizaje en `Modules/State.gd` usando `absf`/`bool` para evitar errores de inferencia en Godot 4.4.
- Salto sostenido restaurado en Godot 4.4:
  - InputBuffer ahora tipado (float) y consulta de “mantener salto” en tick físico.
  - JumpModule consume buffer, aplica coyote (120 ms) y activa `_jump_held` con tope de 150 ms.
  - State aplica gravedad reducida durante `_jump_held` (extra_hold_gravity_scale), con tipados locales (Vector3, float) para evitar inferencia Variant.

- PerfectJumpCombo re-integrado:
  - Ventana de aterrizaje de 60 ms que se abre al tocar suelo y se cierra al intentar saltar; sólo incrementa el combo si aciertas el salto `perfect`.
  - Multiplicadores curvos (gamma 0.5) que escalan hasta 3× velocidad y 2× altura; Movement y Jump los consultan cada tick para modular aceleración y salto base.
  - El combo se reinicia al fallar la ventana sin decaimiento temporal para evitar pérdidas silenciosas de stacks.

- Tipado estricto Godot 4.4:
  - Variables y temporales relevantes anotados (float, Vector3, JumpModule, PerfectJumpCombo) para eliminar warnings “inferred Variant”.
  - Tabs para indentación y orden de paso: módulos → move_and_slide().

Pruebas:
- Revalidado salto corto vs. largo al mantener/soltar salto con el recorte `release_velocity_scale`.
- Verificado combo: incremento al acertar la ventana perfecta y reinicio inmediato al fallar el timing.
- Test headless `res://tests/TestJumpCombo.tscn` garantiza que el módulo `PerfectJumpCombo` siga funcionando tras la migración al StateMachine.

Checklist rápido para Codex

 Jump.gd usa InputBuffer.is_jump_down() y corta _jump_held al soltar o al agotar jump_hold_time.

 State.gd reduce gravedad si _jump_held (tipos locales: var g: float, var v: Vector3).

 PerfectJumpCombo.gd presente y conectado: on_landed() + register_perfect() en la ventana.

 Movement.gd y Jump.gd aplican combo.speed_multiplier() y combo.jump_multiplier().

 Tabs, no espacios. Sin velocity * dt y move_and_slide() una vez al final del tick.


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
         ├─ InputBuffer.gd (buffer de salto desacoplado del tick)
         └─ Stamina.gd (recurso de resistencia del jugador)
```

### Capas de física (World Layers)
- `L_TERRAIN` corresponde al slot 4 y su máscara binaria es `1 << 3` (= 8). Todas las colisiones del mundo (`scenes/world/*.tscn`) usan esta capa.
- El jugador y aliados conservan la capa por defecto (`L_PLAYER`, `L_ALLY`) para detectar interacciones locales, pero los volúmenes auxiliares (como el SpringArm de cámara) deben incluir `LAYER_TERRAIN` cuando requieran bloquearse contra el entorno.

---

## Arquitectura general
La simulación gira alrededor del `SimClock` (`Singletons/SimClock.gd`), un scheduler que agrupa nodos por cadencias (`local`, `regional`, `global`). Cada módulo (`Modules/ModuleBase.gd`) se registra automáticamente y recibe `physics_tick(dt)` directo. El jugador (`scenes/entities/player.gd`) y los aliados (`scenes/entities/Ally.gd`) consumen el mismo tick local, cachean input/estado y finalizan con `move_and_slide` antes de evaluar stamina y progresión.

Los aliados (`scenes/entities/Ally.gd`) usan un FSM explícito con estados `IDLE`, `MOVE`, `COMBAT_*`, `BUILD`, `SNEAK`, `SWIM`, `TALK`, `SIT`. Cada estado aplica animaciones y actualiza estadísticas mediante `AllyStats`, el Resource que encapsula atributos base, skills y reglas de progresión (`Resources/AllyStats.gd`). Las estadísticas se generan desde la singleton `Data.gd`, que parsea `data/ally_archetypes.json`, fusiona defaults, crecimiento y configuración visual; ese mismo diccionario controla presets de materiales y gear en tiempo de ejecución.

Los autoloads (`EventBus`, `Data`, `SimClock`, `GameState`, `Save`, `Flags`) se comunican vía señales: `EventBus` difunde mensajes de HUD y eventos de gameplay; `GameState` expone flags globales de pausa/cinemática para que Player module el input; `Save` aporta utilidades de persistencia; `Data` abastece instancias `AllyStats` y presets visuales; `Flags` centraliza constantes ligeras como `ALLY_TICK_GROUP` para no duplicar `StringName` en escenas. El HUD (`scenes/ui/HUD.gd`) sólo escucha `EventBus.hud_message`, manteniendo la UI desacoplada de la lógica. El bootstrap de input (`scripts/bootstrap/InputSetup.gd`) ejecuta una sola vez al inicio y garantiza que todas las acciones (movimiento, combate, construcción) estén registradas incluso en proyectos clonados.

---

## Sistemas implementados

### Player Orchestrator (`scenes/entities/player.gd`)
Gestiona el ciclo físico del jugador, cachea el input y propaga el contexto a los módulos. Expone señales (`context_state_changed`, `talk_requested`, `sit_toggled`, `interact_requested`, `combat_mode_switched`, `build_mode_toggled`) que permiten a otros sistemas reaccionar sin acceder al input bruto. En cada tick llama a `_manual_tick_modules` y `_finish_physics_step`, aplica `move_and_slide`, sincroniza stamina y reporta ciclos a `AllyStats` mediante `note_stamina_cycle`. Además actualiza `PerfectJumpCombo` para coordinar coyote, buffer y multiplicadores de salto/velocidad mientras detecta contacto con áreas de agua y cambia `ContextState` para el HUD o IA.

### Módulos del jugador (`Modules/`)
- **MovementModule (`Movement.gd`)**: recibe la dirección normalizada y el flag de sprint desde el Player, calcula la velocidad horizontal objetivo y aplica aceleración/decadencia separada para suelo/aire.
- **JumpModule (`Jump.gd`)**: administra coyote time, jump buffer, salto variable y disparo de animaciones/audio; emite efectos de cámara cuando procede.
- **StateModule (`State.gd`)**: centraliza la gravedad (con multiplicador de caída), configura `floor_max_angle`/`floor_snap_length` y emite las señales `jumped`, `left_ground` y `landed` al detectar transiciones aéreas.
- **OrientationModule (`Orientation.gd`)**: interpola la rotación del modelo hacia el input de locomoción respetando la corrección de forward.
- **AnimationCtrlModule (`AnimationCtrl.gd`)**: actualiza el `AnimationTree` (`LocomotionSpeed/Locomotion`, `AirBlend`, `LocomotionSpeed/SprintSpeed`) y bloquea locomoción en aire mientras gobierna un StateMachine `Jump → Fall → Land/LocomotionSpeed`.
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
Scheduler determinista con acumuladores por grupo (`local`, `regional`, `global`). Ordena por prioridad, invoca `_on_clock_tick(group, dt)` en cada módulo y actualiza contadores expuestos por `get_group_stats()`. Admite pausa por grupo, cadencias exportadas (`fixed_dt_*`) y emite la señal `ticked` para debugging opcional.

### Loop de Simulación
- **Emisión de ticks:** `Singletons/SimClock.gd` procesa acumuladores por grupo (`local`, `regional`, `global`), ordena los módulos por prioridad y llama a `_on_clock_tick(group, dt)` de forma determinista; `get_group_stats()` expone contadores y simulación acumulada.
- **Módulos suscritos:** Cualquier nodo puede registrarse en la instancia autoload `SimClock` (vía `/root/SimClock`) y llamar `register_module(self, group, priority)`. `ModuleBase` automatiza la búsqueda del autoload para `Modules/*`, mientras que `player.gd` y `Ally.gd` reciben ticks locales directos vía `physics_tick(dt)` sin señales intermedias.
- **Pausa por grupo:** `Singletons/GameState.gd` pausa o reanuda grupos con `SimClock.pause_group(StringName, bool)`; el `StringName` por defecto vive en `Flags.ALLY_TICK_GROUP` para escenas que necesiten reconfigurar el grupo de aliados.
- **Orden de actualización:** El `SimClock` ordena suscripción de módulos según la prioridad registrada (por defecto FIFO) antes de emitir `ticked`. Primero se resuelven los módulos locales (jugador, aliados, HUD reactivo), luego los regionales (sistemas de zona) y al final los globales (economía, telemetría). La migración R3→R4 mantiene el orden determinista al reutilizar la misma cola para AllyFSMModule y Player.

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
- `player.tscn` instancia un `AnimationTree` (nodo `StateMachine`) cuyo estado `LocomotionSpeed` es un `AnimationNodeBlendTree` que encapsula el `BlendSpace1D` `Locomotion` y el `TimeScale` `SprintSpeed`, además de los estados `Jump` y `FallAnim` conectados al `AnimationPlayer` del modelo GLB (`art/characters/animations1.glb`).
- `AnimationCtrlModule` maneja los parámetros del árbol; comparte clips (`idle`, `walk`, `run`, `fall air loop`) con los aliados.
- El módulo detecta automáticamente el BlendSpace original si existe (para backups) y ajusta el `SprintSpeed/scale` para conservar la aceleración de sprint en la animación de carrera.
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
- **Tipado explícito en AnimationCtrl:** las advertencias de Variant se evitan asignando tipo `float` a las duraciones de tweens y `Variant` a resultados de `AnimationTree.get`; Godot 4.4 deja de marcar error en build headless.
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

