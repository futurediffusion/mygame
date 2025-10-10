# MyGame – Technical Overview

## Engine & Version
- Built with Godot 4.4 (Forward+ renderer) using the official project structure in `project.godot`.
- 3D character controller prototype with editor-exported parameters for gameplay tuning.

## Core Architecture
- Modular player character composed of dedicated systems instantiated as child Nodes and wired through `Player.gd`.
- Global services exposed as autoload singletons: `GameState` for pause/cinematic flags and `SimClock` for advanced tick scheduling.
- Support scripts for camera rigging and stamina live under `scripts/player`, keeping presentation and resource logic separated from core modules.

## Implemented Systems
- **MovementModule** – Handles horizontal velocity integration, acceleration/deceleration curves, and sprint speed targets with per-frame inputs provided by the player controller.【F:Modules/Movement.gd†L1-L80】
- **JumpModule** – Implements buffered jumps, coyote time, jump variable height, state-driven gravity delegation, animation triggers, and camera/audio hooks.【F:Modules/Jump.gd†L1-L117】
- **StateModule** – Centralizes gravity application, landing impact detection, slope/snap configuration, and emits landing signals for downstream consumers.【F:Modules/State.gd†L1-L56】
- **OrientationModule** – Rotates the visual model toward camera-relative input, respecting configurable lerp and mesh forward corrections.【F:Modules/Orientation.gd†L1-L32】
- **AnimationCtrlModule** – Drives AnimationTree blend positions, sprint timescale, and air-state blending based on cached per-frame context from the player.【F:Modules/AnimationCtrl.gd†L1-L112】
- **AudioCtrlModule** – Centralizes SFX playback (jump, land, footsteps) and optional timer-driven footsteps to keep audio logic decoupled from movement.【F:Modules/AudioCtrl.gd†L1-L45】
- **CameraRig** – Provides smooth orbit camera controls, zoom, input capture toggling, and FOV kick responses exposed via a public API.【F:scripts/player/CameraOrbit.gd†L1-L236】
- **Stamina** – Manages sprint resource drain/regeneration and gating for sprint activation.【F:scripts/player/Stamina.gd†L1-L26】
- **GameState Singleton** – Tracks pause/cinematic state and exposes signals to listeners.【F:Singletons/GameState.gd†L1-L19】
- **EventBus Singleton** – Broadcasts HUD, ally, save/load, and stamina signals to keep UI, audio, and gameplay notifications decoupled.【F:Singletons/EventBus.gd†L1-L14】
- **SimClock Service** – Authoritative scheduler with configurable per-group intervals, pause controls, and registry-driven tick dispatch for modules and orchestrators.【F:Singletons/SimClock.gd†L1-L139】

## Recent Fixes
- Clamped scheduler interval updates with `maxf` to keep type inference strict in Godot 4.4 while preserving safe lower bounds on group cadence edits.【F:Singletons/SimClock.gd†L50-L58】
- Relaxed the typed registry declaration in `SimClock` to avoid nested generic collection errors while keeping group iteration logic intact.【F:Singletons/SimClock.gd†L16-L118】

## Player Orchestration
- `Player.gd` exports tuning parameters, caches node references, and `setup()`-injects itself into each module on `_ready()` to keep module state synchronized.【F:scenes/entities/player.gd†L14-L96】
- `physics_tick()` caches camera-relative input, updates sprint eligibility, pushes per-frame context into modules, and prepares post-move work before the authoritative scheduler advances the local group.【F:scenes/entities/player.gd†L108-L161】
- Integrates with `SimClock` by registering as the lead local tick participant and finalizing movement once the scheduler has advanced child modules.【F:scenes/entities/player.gd†L88-L161】
- Delegates stamina consumption, camera feedback, and audio triggers through module APIs to keep orchestration lean and testable.【F:scenes/entities/player.gd†L188-L210】

## Completed Refactor (R2)
- Converted gravity, movement, jump, orientation, animation, and audio responsibilities into standalone modules invoked from the orchestrator, mirroring original mechanics while improving separation of concerns.【F:scenes/entities/player.gd†L81-L161】【F:Modules/Movement.gd†L1-L80】【F:Modules/Jump.gd†L1-L117】【F:Modules/State.gd†L1-L56】【F:Modules/AnimationCtrl.gd†L1-L112】【F:Modules/AudioCtrl.gd†L1-L45】
- Added stamina-driven sprint gating and camera rig hooks to preserve feel while isolating peripheral systems.【F:scenes/entities/player.gd†L188-L210】【F:scripts/player/Stamina.gd†L1-L26】【F:scripts/player/CameraOrbit.gd†L187-L236】
- Established `GameState` singleton for pause/cinematic gating and ensured modules respect global flags during ticking.【F:scenes/entities/player.gd†L119-L167】【F:Singletons/GameState.gd†L1-L19】
- Promoted `SimClock` to the authoritative scheduler with per-group intervals, pause controls, and registry-driven dispatch, plus module auto-registration via `ModuleBase` and player-led post-tick orchestration.【F:Singletons/SimClock.gd†L1-L139】【F:Modules/ModuleBase.gd†L1-L39】【F:scenes/entities/player.gd†L88-L161】

## Pending / Next Steps (R3 Plan)
- Extend multi-rate simulation by formalizing regional/global policies (e.g., AI and streaming cadence) and exposing editor tooling for cross-group coordination.【F:Singletons/SimClock.gd†L1-L139】
- Expand tick orchestration to support regional/global layers (e.g., cutscenes, AI, world streaming) once group policies are defined in `SimClock`.
- Audit remaining subsystems (e.g., stamina, camera) for tick group assignment and pause semantics to align with forthcoming layered simulation.
- Document regression coverage and author automated tests or in-editor validation for module interfaces before R3 changes.

## Dependencies & Tools
- **Engine**: Godot 4.4 with Forward+ renderer feature flag enabled in project settings.【F:project.godot†L1-L19】
- **Asset Pipeline**: `.glb` sources (Blender-friendly) imported via Godot's scene importer for character animations; maintaining `.glb` assets alongside `.import` metadata ensures reproducible re-imports.【F:art/characters/animations1.glb.import†L1-L33】
- **Audio**: Uses Godot `AudioStreamPlayer3D` nodes referenced by `Player.gd`; no external middleware required.【F:scenes/entities/player.gd†L4-L9】【F:Modules/AudioCtrl.gd†L6-L45】

## Contributing Notes
- New gameplay features should be delivered as modules conforming to the `physics_tick(delta)` contract and exposing a `tick_group` property for future `SimClock` scheduling.【F:Modules/ModuleBase.gd†L4-L31】【F:Singletons/SimClock.gd†L1-L139】
- Keep `Player.gd` focused on orchestration: prefer per-frame input caching plus module APIs rather than duplicating logic in the orchestrator.【F:scenes/entities/player.gd†L108-L161】
- Update `GameState` when introducing new global modes so pause/cinematic gating remains authoritative.【F:Singletons/GameState.gd†L1-L19】
- Maintain asset imports (`.glb` + `.import`) and register new singletons through `project.godot` autoloads for consistency.【F:project.godot†L12-L19】【F:art/characters/animations1.glb.import†L1-L33】
- `SimClock` autoload now instantiates the `SimClockScheduler` class to keep the singleton name collision-free while preserving typed module casts via `ModuleBase` helpers.【F:Singletons/SimClock.gd†L1-L139】【F:Modules/ModuleBase.gd†L1-L39】【F:scenes/entities/player.gd†L57-L167】
