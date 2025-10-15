# AGENTS.md — Guía operativa tras auditoría R4

## 2. Reglas imprescindibles
1. **Motor objetivo: Godot 4.4 (Forward+).** Revisa APIs antes de usar funciones nuevas o sintaxis de 4.5+. Evita dependencias que requieran ramas nightly.
2. **Indentación con tabs en GDScript.** Evita mezclar espacios; el proyecto ya se normalizó así y los linters internos lo exigen.
3. **Mantén compatibilidad con `SimClock`.** Los módulos deben seguir heredando `ModuleBase` y usar `physics_tick(dt)` en lugar de `_physics_process`.

## Arquitectura clave
- Todo módulo derivado de `ModuleBase` se registra en `SimClock` y recibe ticks por grupo/priority. No reintroduzcas `_physics_process` en módulos; usa `physics_tick(dt)` y deja que el `SimClock` llame al flujo correcto.【F:Modules/ModuleBase.gd†L1-L47】【F:Singletons/SimClock.gd†L1-L82】
- El jugador orquesta a sus módulos en este orden: `State.pre_move_update()` → `Jump.physics_tick()` → `Movement.physics_tick()` → `Orientation.physics_tick()` → `AnimationCtrl.physics_tick()` → `move_and_slide()` → `State.post_move_update()` → `AudioCtrl.physics_tick()`. Respeta el orden para conservar coyote, fast fall y sincronía de animaciones.【F:scenes/entities/player.gd†L200-L286】
- Aliados ejecutan su FSM en `fsm_step(dt)` y recién después hacen `move_and_slide()` en `physics_tick()`. No llames `move_and_slide()` desde la FSM.【F:scenes/entities/Ally.gd†L60-L160】

## Buenas prácticas a mantener
- Usa `class_name` en scripts reutilizables (módulos, recursos, autoloads) y conserva la indentación con tabs en GDScript.【F:Modules/Movement.gd†L1-L86】【F:Resources/AllyStats.gd†L1-L120】
- Bootstrap de input: cualquier acción nueva debe agregarse en `scripts/bootstrap/InputSetup.gd`. El Player invoca este nodo diferido; evita duplicar lógica de InputMap en otros sitios.【F:scripts/bootstrap/InputSetup.gd†L1-L64】【F:scenes/entities/player.gd†L95-L140】
- La UI se comunica por `EventBus`; conecta nuevas capas al bus y evita referencias directas entre HUD y gameplay.【F:Singletons/EventBus.gd†L1-L16】【F:scenes/ui/HUD.gd†L1-L28】
- Stats y progresión vienen de `AllyStats` + `Data.gd`. Si ajustas atributos/skills, modifica `ally_archetypes.json` y deja que `Data.make_stats_from_archetype()` aplique defaults y overrides.【F:Singletons/Data.gd†L1-L160】【F:data/ally_archetypes.json†L1-L120】
- Mantén el combo de salto (`PerfectJumpCombo`) conectado cuando cambies saltos/velocidades: Player delega a `combo.register_jump()` y las pruebas headless lo cubren.【F:Modules/PerfectJumpCombo.gd†L1-L120】【F:tests/TestJumpCombo.gd†L1-L80】
- Usa `Flags.ALLY_TICK_GROUP` para módulos de aliados y valida prioridades antes de registrar nuevos nodos en el reloj.【F:scripts/core/Flags.gd†L1-L4】【F:Modules/AllyFSMModule.gd†L1-L35】

## Prácticas a evitar
- No accedas a autoloads sin validar su tipo: precarga el script (`preload("res://Singletons/SimClock.gd")`) y verifica con `is`. Evita castings directos sin checar.【F:Modules/ModuleBase.gd†L1-L47】【F:scenes/entities/player.gd†L45-L94】
- Evita hardcodear animaciones/blends fuera de `AnimationCtrlModule`; usa sus helpers (`_set_sprint_scale`, `_set_sneak_blend_target`) en vez de setear parámetros manualmente.【F:Modules/AnimationCtrl.gd†L1-L200】
- No manipules stamina ni stats desde scripts externos si ya existe API (`Stamina.consume_for_sprint`, `AllyStats.note_stamina_cycle`, `gain_skill`). Usa los métodos públicos.【F:scripts/player/Stamina.gd†L1-L24】【F:Resources/AllyStats.gd†L120-L220】
- No omitas el bootstrap de input ni borres acciones en caliente; `InputSetup` se destruye después de configurar bindings para evitar fugas.【F:scripts/bootstrap/InputSetup.gd†L1-L64】

## Pruebas recomendadas
- `godot --headless --run res://tests/TestFastFall.tscn` — valida fast fall, gravedad y velocidades.【F:tests/TestFastFall.gd†L1-L70】
- `godot --headless --run res://tests/TestJumpCombo.tscn` — comprueba la progresión del combo perfecto.【F:tests/TestJumpCombo.gd†L1-L80】
- `godot --headless --run res://tests/TestClock.tscn` — confirma prioridades de `SimClock`.【F:tests/TestClock.gd†L1-L28】

## Checklist antes de comitear
1. Tabs consistentes en GDScript y `class_name` presente cuando aplique.【F:Modules/Movement.gd†L1-L86】
2. `SimClock.register_module()` llamado con grupo/prioridad correctos, sin `await` ni `yield`.【F:Modules/ModuleBase.gd†L1-L47】
3. HUD y eventos pasan por `EventBus`; no hay acoplamientos directos.【F:Singletons/EventBus.gd†L1-L16】
4. Cambios en estadísticas reflejados en JSON + `Data.gd`; sin hardcodear valores en lógica.【F:Singletons/Data.gd†L1-L160】
5. Pruebas headless relevantes ejecutadas si se tocó física, SimClock o combo.【F:tests/TestFastFall.gd†L1-L70】【F:tests/TestJumpCombo.gd†L1-L80】
6. Player y aliados siguen registrándose al `SimClock`; valida orden de módulos en `player.gd` tras cualquier refactor.【F:scenes/entities/player.gd†L168-L286】

## Seguimiento de backlog
- Mantén sincronizada la sección "Backlog documentado R4" del README cuando se completen nuevas fases o se registren hallazgos relevantes; conserva contexto, riesgos y resultados.
- Si se añaden automatizaciones (p.ej., `SimClock.unregister_module`, logger global), detalla el uso esperado y limitaciones en este AGENTS.md para futuros mantenedores.

## Recomendaciones nuevas tras auditoría R4
- Los módulos hijos del Player derivados de `ModuleBase` deben permanecer desuscritos del `SimClock` (usa `module.set_clock_subscription(false)`); el `player.gd` orquesta su ciclo manualmente y evita ticks duplicados.【F:scenes/entities/player.gd†L335-L365】【F:Modules/ModuleBase.gd†L56-L69】
- Para ajustar el sigilo modifica el colisionador mediante `_apply_sneak_collider`/`_set_capsule_dimensions` y consulta `can_exit_sneak()` en lugar de manipular `CollisionShape3D` directamente, así se mantiene `floor_snap` y el offset base coherente.【F:scenes/entities/player.gd†L509-L590】
- Cualquier nueva fuente de input debe integrarse con `PlayerInputHandler.set_exit_sneak_callback()` y respetar los modos Toggle/Hold al cambiar sigilo.【F:scripts/player/PlayerInputHandler.gd†L8-L116】
- Los ajustes de pendientes dependen de `max_slope_deg` ≤ 50°; si se necesita más inclinación revisa `_update_slope_speed` y `_clamp_surface_normal` para evitar velocidades divergentes.【F:Modules/Movement.gd†L15-L113】【F:Modules/Orientation.gd†L7-L87】
