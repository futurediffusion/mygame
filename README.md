# MyGame – Technical Overview

## Engine & Version
- Built with Godot 4.4 (Forward+ renderer) using the official project structure in `project.godot`.
- 3D character controller prototype with editor-exported parameters for gameplay tuning.

## Core Architecture
- Modular player character composed of dedicated systems instantiated as child Nodes and wired through `Player.gd`.
- Global services exposed as autoload singletons: `GameState` for pause/cinematic flags and `SimClock` for advanced tick scheduling.
- Support scripts for camera rigging and stamina live under `scripts/player`, keeping presentation and resource logic separated from core modules.

## Implemented Systems
- **MovementModule** – Handles horizontal velocity integration, acceleration/deceleration curves, and sprint speed targets with per-frame inputs provided by the player controller.【F:Modules/Movement.gd†L1-L78】
- **JumpModule** – Implements buffered jumps, coyote time, jump variable height, state-driven gravity delegation, animation triggers, and camera/audio hooks.【F:Modules/Jump.gd†L1-L115】
- **StateModule** – Centralizes gravity application, landing impact detection, slope/snap configuration, and emits landing signals for downstream consumers.【F:Modules/State.gd†L1-L54】
- **OrientationModule** – Rotates the visual model toward camera-relative input, respecting configurable lerp and mesh forward corrections.【F:Modules/Orientation.gd†L1-L30】
- **AnimationCtrlModule** – Drives AnimationTree blend positions, sprint timescale, and air-state blending based on cached per-frame context from the player.【F:Modules/AnimationCtrl.gd†L1-L108】
- **AudioCtrlModule** – Centralizes SFX playback (jump, land, footsteps) and optional timer-driven footsteps to keep audio logic decoupled from movement.【F:Modules/AudioCtrl.gd†L1-L47】
- **CameraRig** – Provides smooth orbit camera controls, zoom, input capture toggling, and FOV kick responses exposed via a public API.【F:scripts/player/CameraOrbit.gd†L1-L236】
- **Stamina** – Manages sprint resource drain/regeneration and gating for sprint activation.【F:scripts/player/Stamina.gd†L1-L26】
- **GameState Singleton** – Tracks pause/cinematic state and exposes signals to listeners.【F:Singletons/GameState.gd†L1-L19】
- **SimClock Service** – Tick scheduler prepared for multi-group fixed stepping with per-module accumulators and pause controls.【F:Singletons/SimClock.gd†L1-L83】

## Player Orchestration
- `Player.gd` exports tuning parameters, caches node references, and `setup()`-injects itself into each module on `_ready()` to keep module state synchronized.【F:scenes/entities/player.gd†L14-L80】
- `_physics_process()` gathers camera-relative input, resolves sprint eligibility, injects per-frame context into modules, evaluates `GameState` pause/cinematic flags, and ticks systems in canonical order before calling `move_and_slide()`.【F:scenes/entities/player.gd†L85-L118】
- Integrates with `SimClock` when available, allowing modules to be scheduled by tick group without duplicating rate logic in each system.【F:scenes/entities/player.gd†L121-L128】
- Delegates stamina consumption, camera feedback, and audio triggers through module APIs to keep orchestration lean and testable.【F:scenes/entities/player.gd†L147-L169】

## Completed Refactor (R2)
- Converted gravity, movement, jump, orientation, animation, and audio responsibilities into standalone modules invoked from the orchestrator, mirroring original mechanics while improving separation of concerns.【F:scenes/entities/player.gd†L59-L113】【F:Modules/Movement.gd†L1-L78】【F:Modules/Jump.gd†L1-L115】【F:Modules/State.gd†L1-L54】【F:Modules/AnimationCtrl.gd†L1-L108】【F:Modules/AudioCtrl.gd†L1-L47】
- Added stamina-driven sprint gating and camera rig hooks to preserve feel while isolating peripheral systems.【F:scenes/entities/player.gd†L147-L169】【F:scripts/player/Stamina.gd†L1-L26】【F:scripts/player/CameraOrbit.gd†L187-L236】
- Established `GameState` singleton for pause/cinematic gating and ensured modules respect global flags during ticking.【F:scenes/entities/player.gd†L98-L113】【F:Singletons/GameState.gd†L1-L19】
- Implemented preliminary `SimClock` service with tick groups (`global`, `regional`, `local`) and per-module pause/reset controls, already integrated behind the player `_tick_module` helper.【F:Singletons/SimClock.gd†L1-L83】【F:scenes/entities/player.gd†L121-L128】

## Pending / Next Steps (R3 Plan)
- Finalize multi-rate simulation by promoting `SimClock` from optional helper to authoritative scheduler (populate interval tuning, ensure all modules declare appropriate `tick_group`, and add editor tooling for configuration).【F:Singletons/SimClock.gd†L4-L83】【F:Modules/Movement.gd†L4-L43】
- Expand tick orchestration to support regional/global layers (e.g., cutscenes, AI, world streaming) once group policies are defined in `SimClock`.
- Audit remaining subsystems (e.g., stamina, camera) for tick group assignment and pause semantics to align with forthcoming layered simulation.
- Document regression coverage and author automated tests or in-editor validation for module interfaces before R3 changes.

## Dependencies & Tools
- **Engine**: Godot 4.4 with Forward+ renderer feature flag enabled in project settings.【F:project.godot†L1-L19】
- **Asset Pipeline**: `.glb` sources (Blender-friendly) imported via Godot's scene importer for character animations; maintaining `.glb` assets alongside `.import` metadata ensures reproducible re-imports.【F:art/characters/animations1.glb.import†L1-L33】
- **Audio**: Uses Godot `AudioStreamPlayer3D` nodes referenced by `Player.gd`; no external middleware required.【F:scenes/entities/player.gd†L4-L9】【F:Modules/AudioCtrl.gd†L6-L47】

## Contributing Notes
- New gameplay features should be delivered as modules conforming to the `physics_tick(delta)` contract and exposing a `tick_group` property for future `SimClock` scheduling.【F:Modules/Movement.gd†L4-L43】【F:Singletons/SimClock.gd†L1-L83】
- Keep `Player.gd` focused on orchestration: prefer per-frame input caching plus module APIs rather than duplicating logic in the orchestrator.【F:scenes/entities/player.gd†L85-L128】
- Update `GameState` when introducing new global modes so pause/cinematic gating remains authoritative.【F:Singletons/GameState.gd†L1-L19】
- Maintain asset imports (`.glb` + `.import`) and register new singletons through `project.godot` autoloads for consistency.【F:project.godot†L12-L19】【F:art/characters/animations1.glb.import†L1-L33】
