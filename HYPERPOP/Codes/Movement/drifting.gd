extends BoardState
class_name Drifting

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Drifting")

func exit_state() -> void:
	print_debug("Exit Drifting")

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
	pass
