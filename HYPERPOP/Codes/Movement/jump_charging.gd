extends BoardState
class_name JumpCharging

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Jump_Charging")

func exit_state() -> void:
	print_debug("Exit Jump_Charging")

func physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	_read_input(delta)
	
	_update_speed(delta)
	player.move_and_slide()

# =================================================
# INPUT — single source of truth, pure reads only
func _read_input(delta: float) -> void:
	pass

# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	player.current_speed = lerp(player.current_speed, 0.0, player.jump_charge_drag * delta)
