# MyGame – Auditoría técnica R4

## Resumen ejecutivo
- **Motor comprobado:** Godot Engine 4.4 con renderer Forward+, según `project.godot` y los autoloads activos (`SimClock`, `EventBus`, `GameState`, `Save`, `Flags`).【F:project.godot†L1-L40】【F:Singletons/SimClock.gd†L1-L99】【F:Singletons/EventBus.gd†L1-L16】【F:Singletons/GameState.gd†L1-L46】【F:Singletons/Save.gd†L1-L32】
- **Estado jugable:** El jugador modular funciona en tercera persona con cámara orbital, sprint y salto variable. Ahora conserva `floor_snap` tras los saltos y adapta la velocidad a la pendiente antes de animar, manteniendo sincronía con stamina, combo y audio.【F:scenes/entities/player.gd†L229-L333】【F:Modules/Jump.gd†L118-L183】【F:Modules/Movement.gd†L56-L113】【F:Modules/AnimationCtrl.gd†L1-L200】
- **Sistemas activos:** Aliados con FSM y progresión data-driven, HUD desacoplado por bus de eventos, bootstrap automático de Input y scheduler multinivel por `SimClock`. El sigilo del jugador ahora incluye colisionador dinámico, control Toggle/Hold y audio calibrado.【F:scenes/entities/Ally.gd†L1-L330】【F:Modules/AllyFSMModule.gd†L1-L35】【F:Resources/AllyStats.gd†L1-L160】【F:Singletons/EventBus.gd†L1-L16】【F:scripts/bootstrap/InputSetup.gd†L1-L64】【F:Singletons/SimClock.gd†L1-L99】【F:scenes/entities/player.gd†L318-L590】【F:scripts/player/PlayerInputHandler.gd†L8-L116】【F:Modules/AudioCtrl.gd†L1-L123】

## Novedades desde R3
- **Movimiento adaptativo en pendientes:** `MovementModule` introduce curvas de aceleración/ralentización según el ángulo y dirección de la pendiente, mientras `OrientationModule` interpola la inclinación del modelo respetando un límite configurable.【F:Modules/Movement.gd†L15-L113】【F:Modules/Orientation.gd†L7-L87】
- **Restauración segura de `floor_snap`:** El módulo de salto guarda el valor previo y lo restablece al tocar suelo, evitando resbalones tras saltar.【F:Modules/Jump.gd†L118-L183】【F:Modules/State.gd†L14-L84】
- **Colisionador de sigilo dinámico:** El jugador cachea el `CapsuleShape3D`, ajusta altura/radio en tiempo real y sólo permite salir de sigilo si hay espacio libre sobre la cabeza.【F:scenes/entities/player.gd†L98-L590】
- **Input con modos Toggle/Hold:** `PlayerInputHandler` configura el modo de sigilo, integra un callback de validación y gestiona liberaciones diferidas cuando un techo bloquea la transición.【F:scripts/player/PlayerInputHandler.gd†L8-L116】
- **Audio contextual de pisadas:** `AudioCtrlModule` calibra pitch/volumen para caminar o sigilo y sincroniza el temporizador de pasos con la nueva velocidad sobre pendientes.【F:Modules/AudioCtrl.gd†L1-L123】
- **Prevención de doble tick:** `ModuleBase` expone `set_clock_subscription` y el jugador desuscribe sus módulos hijos para evitar registros duplicados en `SimClock`.【F:Modules/ModuleBase.gd†L1-L69】【F:scenes/entities/player.gd†L335-L365】

## Estado verificado del build R4
- Registro del jugador y módulos al `SimClock` local; el ciclo `physics_tick` centraliza movimiento, salto, animación, audio y seguimiento de stamina, ahora con módulos desuscritos del reloj global para evitar ticks dobles.【F:scenes/entities/player.gd†L229-L365】【F:Modules/ModuleBase.gd†L1-L69】
- Stamina con drenaje/regeneración configurable y consumo durante sprint controlado por estadísticas de aliados.【F:scripts/player/Stamina.gd†L1-L24】【F:scenes/entities/player.gd†L429-L478】【F:Resources/AllyStats.gd†L1-L120】
- Combo perfecto de salto con ventana de aterrizaje, multiplicadores de velocidad/altura y pruebas headless de regresión.【F:Modules/PerfectJumpCombo.gd†L1-L130】【F:tests/TestJumpCombo.gd†L1-L80】
- Aliados con estados `IDLE/MOVE/COMBAT/BUILD/SNEAK/SWIM/TALK/SIT`, manejo de animaciones y progresión de skills ligada a `AllyStats`.【F:scenes/entities/Ally.gd†L1-L320】【F:Resources/AllyStats.gd†L120-L260】
- HUD que sólo escucha `EventBus.hud_message`, con auto-ocultado mediante timers.【F:Singletons/EventBus.gd†L1-L16】【F:scenes/ui/HUD.gd†L1-L28】

## Arquitectura comprobada
### Reloj de simulación (`Singletons/SimClock.gd`)
- Scheduler por grupos (`local`, `regional`, `global`) que ordena módulos por prioridad y emite `physics_tick` custom en lugar de `_physics_process`. Maneja pausa por grupo y estadísticas de tick.【F:Singletons/SimClock.gd†L1-L82】

### Orquestador del jugador (`scenes/entities/player.gd`)
- Registra acciones de input (incluido bootstrap diferido), calcula dirección relativa a cámara, controla sprint, estado de contexto y conecta módulos antes de `move_and_slide()`. Maneja agua, sneak toggle/hold, colisionador dinámico y señales de interacción.【F:scenes/entities/player.gd†L29-L590】

### Módulos del jugador (`Modules/`)
- `MovementModule`: aceleración suelo/aire, fast fall, multiplicadores de combo y ajuste progresivo de velocidad según pendiente.【F:Modules/Movement.gd†L1-L113】
- `JumpModule`: buffer + coyote, salto variable, animación/audio, combo y restauración de `floor_snap` tras despegar.【F:Modules/Jump.gd†L1-L183】
- `StateModule`: gravedad, `floor_snap`, eventos de aterrizaje y fast fall, exponiendo setters para sincronizar con el jugador.【F:Modules/State.gd†L1-L92】
- `OrientationModule`: rotación del modelo según input con corrección de inclinación limitada al ángulo máximo del jugador.【F:Modules/Orientation.gd†L1-L87】
- `AnimationCtrlModule`: controla AnimationTree (Locomotion/Sprint/Sneak/Air), OneShots de salto y blends de sigilo.【F:Modules/AnimationCtrl.gd†L1-L200】
- `AudioCtrlModule`: efectos de pasos, salto y aterrizaje con temporizador opcional y perfiles de pitch/volumen para caminar o sigilo.【F:Modules/AudioCtrl.gd†L1-L123】
- `PerfectJumpCombo`: seguimiento del combo y multiplicadores.【F:Modules/PerfectJumpCombo.gd†L1-L120】

### Aliados y FSM (`scenes/entities/Ally.gd` + `Modules/AllyFSMModule.gd`)
- Aliados registran `fsm_step` en el `SimClock` regional/local según `Flags.ALLY_TICK_GROUP`, evalúan comportamiento por estado y aplican animaciones/materiales/gear desde datos. El módulo `AllyFSMModule` permite delegar la lógica a un nodo padre manteniendo cadencia.【F:scenes/entities/Ally.gd†L1-L360】【F:Modules/AllyFSMModule.gd†L1-L35】【F:scripts/core/Flags.gd†L1-L4】

### Datos y progresión (`Singletons/Data.gd`, `Resources/AllyStats.gd`, `data/ally_archetypes.json`)
- `Data` carga arquetipos JSON, fusiona defaults y fabrica `AllyStats` completos (base + skills + crecimiento). `AllyStats` gestiona límites, decaimientos por repetición y registro de ciclos de stamina. `TestDataIsolation` asegura respuestas inmutables.【F:Singletons/Data.gd†L1-L160】【F:Resources/AllyStats.gd†L1-L260】【F:data/ally_archetypes.json†L1-L120】【F:tests/TestDataIsolation.gd.uid†L1-L1】

### UI y eventos (`Singletons/EventBus.gd`, `scenes/ui/HUD.gd`)
- `EventBus` define señales globales (HUD, stamina, guardado) y `HUD` sólo se conecta al mensaje correspondiente, garantizando desacoplamiento.【F:Singletons/EventBus.gd†L1-L16】【F:scenes/ui/HUD.gd†L1-L28】

### Bootstrap de Input (`scripts/bootstrap/InputSetup.gd`)
- Limpia acciones obsoletas, define bindings predeterminados para teclado/ratón y evita duplicados asignando códigos físicos directamente.【F:scripts/bootstrap/InputSetup.gd†L1-L64】
- `PlayerInputHandler` extiende la configuración con modos Toggle/Hold y callback al jugador para validar la salida de sigilo.【F:scripts/player/PlayerInputHandler.gd†L8-L116】

### Audio, cámara y utilidades
- El jugador encapsula nodos de audio, cámara orbital (`CameraRig`) y áreas de agua; `AudioCtrlModule` y `player.gd` exponen hooks (`_play_footstep_audio`, `camera_rig._on_player_landed`).【F:scenes/entities/player.gd†L45-L166】【F:Modules/AudioCtrl.gd†L1-L123】
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
- GDScript con `class_name` en scripts reutilizables y módulos que heredan `ModuleBase`, registrándose al `SimClock` en `_ready()`. Cuando el jugador los orquesta manualmente deben permanecer desuscritos usando `set_clock_subscription(false)`. Evita reintroducir `_physics_process` en estos nodos.【F:Modules/ModuleBase.gd†L1-L69】【F:scenes/entities/player.gd†L335-L365】
- Indentación con tabs en GDScript para mantener compatibilidad con el proyecto (ver módulos y `player.gd`).【F:Modules/Movement.gd†L1-L113】【F:scenes/entities/player.gd†L1-L590】
- HUD y UI consumen eventos mediante `EventBus`; no acoplar escenas directamente.【F:Singletons/EventBus.gd†L1-L16】【F:scenes/ui/HUD.gd†L1-L28】
- Datos de aliados se modifican vía JSON + `Data.gd`, no hardcodeando stats en lógica.【F:Singletons/Data.gd†L1-L160】【F:data/ally_archetypes.json†L1-L120】
- Tests críticos corren en headless (`TestFastFall`, `TestJumpCombo`, `TestDataIsolation`) y dependen del orden de tick del `SimClock`. Manténlos actualizados tras tocar prioridades, física o manejo de datos.【F:tests/TestFastFall.tscn†L1-L8】【F:tests/TestJumpCombo.tscn†L1-L8】【F:tests/TestDataIsolation.gd.uid†L1-L1】

## Limitaciones y backlog identificados
### Pendientes globales
- IA enemiga y sistemas de reputación/economía aún no existen en el código; sólo hay aliados y jugador.【F:scenes/entities/Ally.gd†L1-L360】【F:Modules/Movement.gd†L1-L113】
- `Save.gd` guarda/carga diccionarios comprimidos, pero no hay orquestación de slots ni serialización completa del mundo.【F:Singletons/Save.gd†L1-L32】
- No hay integración de AnimationTree compartido entre jugador y aliados; cada uno depende de su propia configuración en escenas y presets externos.【F:Modules/AnimationCtrl.gd†L1-L200】【F:scenes/entities/Ally.gd†L1-L360】
- Escenas de mundo (`scenes/world/`) son arenas de prueba sin lógica de gameplay avanzada.【F:scenes/world/test_world.tscn†L1-L20】【F:scenes/world/test_clock_benchmark.tscn†L1-L20】

### Backlog documentado R4
1. **Fase 1 – Blindaje del SimClock (completada)**
- Se depuraron nodos nulos dentro de `SimClock._tick_group()` antes de invocar `_on_clock_tick`, evitando referencias zombi al reciclar escenas.
- `SimClock.unregister_module(module: ModuleBase)` quedó expuesto y `ModuleBase._unsubscribe_clock()` ahora lo invoca para retirar módulos correctamente.
2. **Fase 2 – Saneado básico de estadísticas (completada)**
- `AllyStats.gd.gain_base_stat` valida las claves aceptadas y centraliza los rangos permitidos, eliminando clamps duplicados.
3. **Fase 3 – Documentación y asserts en APIs públicas (completada)**
- `MovementModule.set_frame_input`, `OrientationModule.set_frame_input` y `AnimationCtrlModule.set_frame_anim_inputs` quedaron documentadas con parámetros esperados y `assert`s que alertan inputs fuera de rango.
4. **Fase 4 – Consolidación de constantes de gameplay (completada)**
- Tiempos de coyote, umbrales de sprint, ventanas de blend y demás constantes usadas por `player.gd`, `Jump.gd` y `AnimationCtrl.gd` se centralizaron en un punto común.
5. **Fase 5 – Mini-logger unificado (opcional, completada)**
- Se creó un autoload `Logger` con niveles configurables y se sustituyeron `push_warning/print` dispersos en módulos sensibles (p.ej., `AnimationCtrl`, `player.gd`).
6. **Fase 6 – Refactors a medio plazo (completada)**
- **6A.** Los setters `_set_locomotion_blend`, `_set_air_blend` y `_set_sprint_scale` en `AnimationCtrlModule` se factorizaron mediante un helper común.
- **6B.** `player.gd` se descompuso en componentes dedicados para caché de input y detección de contexto, manteniendo el orden de módulos del `SimClock`.

7. **Fase 7 – Copias defensivas de arquetipos (completada)**
- `Data.get_archetype_entry()` y `Data.get_archetype_visual()` ahora devuelven duplicados profundos para impedir que los consumidores muten la caché interna.
- Se añadió la prueba headless `TestDataIsolation.tscn` para asegurar que las respuestas de `Data` permanecen inmutables entre llamadas.

Mantén este README sincronizado cuando agregues sistemas nuevos o cambies el flujo del SimClock. Actualiza el backlog cuando se complete trabajo adicional o se registren hallazgos relevantes.
