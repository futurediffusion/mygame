extends Node
class_name PhysicsLayers

# Collision layer slots. Values map directly to the project physics layers.
const L_PLAYER := 1
const L_ALLY := 2
const L_ENEMY := 3
const L_TERRAIN := 4
const L_INTERACTABLE := 5

# Bitmasks for the individual layers to make mask composition readable.
const LAYER_PLAYER := 1 << (L_PLAYER - 1)
const LAYER_ALLY := 1 << (L_ALLY - 1)
const LAYER_ENEMY := 1 << (L_ENEMY - 1)
const LAYER_TERRAIN := 1 << (L_TERRAIN - 1)
const LAYER_INTERACTABLE := 1 << (L_INTERACTABLE - 1)

# Expected collision masks per entity:
# - Player must collide with terrain for locomotion, plus allies, enemies, and
#   interactables for proximity logic.
# - Allies collide with terrain, the player, enemies, and interactables so they
#   share navigation constraints and interaction triggers.
# - Enemies collide with terrain, the player, and allies to participate in
#   combat navigation without pushing interactables.
# - Terrain bodies receive collisions from player, ally, and enemy actors.
# - Interactables react to player and ally bodies so either can trigger them.
const MASK_PLAYER := LAYER_TERRAIN | LAYER_ALLY | LAYER_ENEMY | LAYER_INTERACTABLE
const MASK_ALLY := LAYER_TERRAIN | LAYER_PLAYER | LAYER_ENEMY | LAYER_INTERACTABLE
const MASK_ENEMY := LAYER_TERRAIN | LAYER_PLAYER | LAYER_ALLY
const MASK_TERRAIN := LAYER_PLAYER | LAYER_ALLY | LAYER_ENEMY
const MASK_INTERACTABLE := LAYER_PLAYER | LAYER_ALLY

const MASK_BY_LAYER := {
	L_PLAYER: MASK_PLAYER,
	L_ALLY: MASK_ALLY,
	L_ENEMY: MASK_ENEMY,
	L_TERRAIN: MASK_TERRAIN,
	L_INTERACTABLE: MASK_INTERACTABLE,
}
