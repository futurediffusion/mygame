extends ModuleBase
class_name AttackModule

const PARAM_PUNCH_ACTIVE := "parameters/Punch1/active"
const PARAM_DODGE_ACTIVE := "parameters/Dodge/active"

var animation_tree: AnimationTree

# TODO: Combo system
# - Detectar segundo click durante Punch1
# - Lanzar Punch2 si está dentro de la ventana de tiempo

func _ready() -> void:
	super._ready()
	set_process_input(true)
	set_clock_subscription(false)

func _input(event: InputEvent) -> void:
	if animation_tree == null or not is_instance_valid(animation_tree):
		return
	if not Input.is_action_just_pressed("attack"):
		return
	if puede_atacar():
		reproducir_golpe()

func puede_atacar() -> bool:
	if animation_tree == null or not is_instance_valid(animation_tree):
		return false
	if bool(animation_tree.get(PARAM_DODGE_ACTIVE)):
		return false
	if bool(animation_tree.get(PARAM_PUNCH_ACTIVE)):
		return false
	return true

func reproducir_golpe() -> void:
	if animation_tree == null or not is_instance_valid(animation_tree):
		return
	animation_tree.set(PARAM_PUNCH_ACTIVE, true)
