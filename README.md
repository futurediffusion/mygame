# MyGame – Auditoría técnica R3

## Resumen ejecutivo
- **Motor comprobado:** Godot Engine 4.4 con renderer Forward+, según `project.godot` y los autoloads activos (`SimClock`, `EventBus`, `GameState`, `Save`, `Flags`).【F:project.godot†L1-L40】【F:Singletons/SimClock.gd†L1-L99】【F:Singletons/EventBus.gd†L1-L16】【F:Singletons/GameState.gd†L1-L46】【F:Singletons/Save.gd†L1-L32】
- **Estado jugable:** El jugador modular funciona en tercera persona con cámara orbital, sprint y salto variable. Sneak, sprint, stamina, combo de salto y audio funcionan en conjunto con el reloj de simulación.【F:scenes/entities/player.gd†L1-L340】【F:scripts/player/Stamina.gd†L1-L24】【F:Modules/Movement.gd†L1-L86】【F:Modules/Jump.gd†L1-L130】【F:Modules/AnimationCtrl.gd†L1-L200】
- **Sistemas activos:** Aliados con FSM y progresión data-driven, HUD desacoplado por bus de eventos, bootstrap automático de Input y scheduler multinivel por `SimClock`.【F:scenes/entities/Ally.gd†L1-L330】【F:Modules/AllyFSMModule.gd†L1-L35】【F:Resources/AllyStats.gd†L1-L160】【F:Singletons/EventBus.gd†L1-L16】【F:scripts/bootstrap/InputSetup.gd†L1-L64】【F:Singletons/SimClock.gd†L1-L99】

## Estado verificado del build R3
- Registro del jugador y módulos al `SimClock` local; el ciclo `physics_tick` centraliza movimiento, salto, animación, audio y seguimiento de stamina.【F:scenes/entities/player.gd†L168-L271】
- Stamina con drenaje/regeneración configurable y consumo durante sprint controlado por estadísticas de aliados.【F:scripts/player/Stamina.gd†L1-L24】【F:scenes/entities/player.gd†L272-L333】【F:Resources/AllyStats.gd†L1-L120】
- Combo perfecto de salto con ventana de aterrizaje, multiplicadores de velocidad/altura y pruebas headless de regresión.【F:Modules/PerfectJumpCombo.gd†L1-L130】【F:tests/TestJumpCombo.gd†L1-L80】
- Aliados con estados `IDLE/MOVE/COMBAT/BUILD/SNEAK/SWIM/TALK/SIT`, manejo de animaciones y progresión de skills ligada a `AllyStats`.【F:scenes/entities/Ally.gd†L1-L320】【F:Resources/AllyStats.gd†L120-L260】
- HUD que sólo escucha `EventBus.hud_message`, con auto-ocultado mediante timers.【F:Singletons/EventBus.gd†L1-L16】【F:scenes/ui/HUD.gd†L1-L28】

## Arquitectura comprobada
### Reloj de simulación (`Singletons/SimClock.gd`)
- Scheduler por grupos (`local`, `regional`, `global`) que ordena módulos por prioridad y emite `physics_tick` custom en lugar de `_physics_process`. Maneja pausa por grupo y estadísticas de tick.【F:Singletons/SimClock.gd†L1-L82】

### Orquestador del jugador (`scenes/entities/player.gd`)
- Registra acciones de input (incluido bootstrap diferido), calcula dirección relativa a cámara, controla sprint, estado de contexto y conecta módulos antes de `move_and_slide()`. Maneja agua, sneak toggle y señales de interacción.【F:scenes/entities/player.gd†L29-L333】

### Módulos del jugador (`Modules/`)
- `MovementModule`: aceleración suelo/aire, fast fall y multiplicadores de combo.【F:Modules/Movement.gd†L1-L86】
- `JumpModule`: buffer + coyote, salto variable, animación/audio y combo.【F:Modules/Jump.gd†L1-L150】
- `StateModule`: gravedad, `floor_snap`, eventos de aterrizaje y fast fall.【F:Modules/State.gd†L1-L80】
- `OrientationModule`: rotación del modelo según input.【F:Modules/Orientation.gd†L1-L40】
- `AnimationCtrlModule`: controla AnimationTree (Locomotion/Sprint/Sneak/Air), OneShots de salto y blends de sigilo.【F:Modules/AnimationCtrl.gd†L1-L200】
- `AudioCtrlModule`: efectos de pasos, salto y aterrizaje con temporizador opcional.【F:Modules/AudioCtrl.gd†L1-L60】
- `PerfectJumpCombo`: seguimiento del combo y multiplicadores.【F:Modules/PerfectJumpCombo.gd†L1-L120】

### Aliados y FSM (`scenes/entities/Ally.gd` + `Modules/AllyFSMModule.gd`)
- Aliados registran `fsm_step` en el `SimClock` regional/local según `Flags.ALLY_TICK_GROUP`, evalúan comportamiento por estado y aplican animaciones/materiales/gear desde datos. El módulo `AllyFSMModule` permite delegar la lógica a un nodo padre manteniendo cadencia.【F:scenes/entities/Ally.gd†L1-L360】【F:Modules/AllyFSMModule.gd†L1-L35】【F:scripts/core/Flags.gd†L1-L4】

### Datos y progresión (`Singletons/Data.gd`, `Resources/AllyStats.gd`, `data/ally_archetypes.json`)
- `Data` carga arquetipos JSON, fusiona defaults y fabrica `AllyStats` completos (base + skills + crecimiento). `AllyStats` gestiona límites, decaimientos por repetición y registro de ciclos de stamina.【F:Singletons/Data.gd†L1-L160】【F:Resources/AllyStats.gd†L1-L260】【F:data/ally_archetypes.json†L1-L120】

### UI y eventos (`Singletons/EventBus.gd`, `scenes/ui/HUD.gd`)
- `EventBus` define señales globales (HUD, stamina, guardado) y `HUD` sólo se conecta al mensaje correspondiente, garantizando desacoplamiento.【F:Singletons/EventBus.gd†L1-L16】【F:scenes/ui/HUD.gd†L1-L28】

### Bootstrap de Input (`scripts/bootstrap/InputSetup.gd`)
- Limpia acciones obsoletas, define bindings predeterminados para teclado/ratón y evita duplicados asignando códigos físicos directamente.【F:scripts/bootstrap/InputSetup.gd†L1-L64】

### Audio, cámara y utilidades
- El jugador encapsula nodos de audio, cámara orbital (`CameraRig`) y áreas de agua; `AudioCtrlModule` y `player.gd` exponen hooks (`_play_footstep_audio`, `camera_rig._on_player_landed`).【F:scenes/entities/player.gd†L45-L166】【F:Modules/AudioCtrl.gd†L1-L60】
- `scripts/core/PhysicsLayers.gd` documenta capas y máscaras de colisión usadas por entidades.【F:scripts/core/PhysicsLayers.gd†L1-L40】

## Recursos y estructura relevante
```
res://
 ├─ Modules/ (módulos del jugador y aliados)
 ├─ Singletons/ (SimClock, Data, EventBus, GameState, Save)
 ├─ Resources/AllyStats.gd (recurso de estadísticas)
 ├─ scripts/bootstrap/InputSetup.gd (bootstrap InputMap)
 ├─ scripts/player/ (CameraOrbit, InputBuffer, Stamina)
 ├─ scenes/entities/ (Player y Ally, más módulos instanciados)
 ├─ scenes/ui/HUD.tscn (HUD desacoplado)
 ├─ scenes/world/*.tscn (arenas de prueba)
 ├─ data/ally_archetypes.json (arquetipos data-driven)
 ├─ tests/ (escenas headless para SimClock, FastFall, JumpCombo)
```

## Pruebas y validación disponibles
- `res://tests/TestClock.tscn`: comprueba orden de prioridad del `SimClock` mediante módulos dummy.【F:tests/TestClock.gd†L1-L28】
- `res://tests/TestFastFall.tscn`: valida multiplicadores de caída rápida y velocidades horizontal/terrestre.【F:tests/TestFastFall.gd†L1-L70】
- `res://tests/TestJumpCombo.tscn`: asegura progresión del combo perfecto hasta nivel 100 y reseteos correctos.【F:tests/TestJumpCombo.gd†L1-L80】

Ejecuta cada prueba en modo headless con:
```
godot --headless --run res://tests/TestFastFall.tscn
```
(Cambia el path por la escena de prueba deseada).

## Convenciones detectadas
- GDScript con `class_name` en scripts reutilizables y módulos que heredan `ModuleBase`, registrándose al `SimClock` en `_ready()`. Evita reintroducir `_physics_process` en estos nodos.【F:Modules/ModuleBase.gd†L1-L47】【F:Modules/Movement.gd†L1-L49】
- Indentación con tabs en GDScript para mantener compatibilidad con el proyecto (ver módulos y `player.gd`).【F:Modules/Movement.gd†L1-L86】【F:scenes/entities/player.gd†L1-L340】
- HUD y UI consumen eventos mediante `EventBus`; no acoplar escenas directamente.【F:Singletons/EventBus.gd†L1-L16】【F:scenes/ui/HUD.gd†L1-L28】
- Datos de aliados se modifican vía JSON + `Data.gd`, no hardcodeando stats en lógica.【F:Singletons/Data.gd†L1-L160】【F:data/ally_archetypes.json†L1-L120】
- Tests críticos corren en headless (`TestFastFall`, `TestJumpCombo`) y dependen del orden de tick del `SimClock`. Manténlos actualizados tras tocar prioridades o física.【F:tests/TestFastFall.gd†L1-L70】【F:tests/TestJumpCombo.gd†L1-L80】

## Limitaciones y backlog identificados
- IA enemiga y sistemas de reputación/economía aún no existen en el código; sólo hay aliados y jugador.【F:scenes/entities/Ally.gd†L1-L360】【F:Modules/Movement.gd†L1-L86】
- `Save.gd` guarda/carga diccionarios comprimidos, pero no hay orquestación de slots ni serialización completa del mundo.【F:Singletons/Save.gd†L1-L32】
- No hay integración de AnimationTree compartido entre jugador y aliados; cada uno depende de su propia configuración en escenas y presets externos.【F:Modules/AnimationCtrl.gd†L1-L200】【F:scenes/entities/Ally.gd†L1-L360】
- Escenas de mundo (`scenes/world/`) son arenas de prueba sin lógica de gameplay avanzada.【F:scenes/world/test_world.tscn†L1-L20】【F:scenes/world/test_clock_benchmark.tscn†L1-L20】

Mantén este README sincronizado cuando agregues sistemas nuevos o cambies el flujo del SimClock.
