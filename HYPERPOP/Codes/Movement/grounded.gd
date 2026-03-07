## Grounded State
extends BoardState
class_name Grounded

@onready var player: BoardController = get_parent().get_parent()

# =================================================
# STATE

# =================================================
# CENTRALISED INPUT STATE — populated once per frame in _read_input()
var inp_throttle: float = 0.0
var inp_brake: float = 0.0
var inp_pitch: float = 0.0

func enter_state() -> void:
	print_debug("Enter Grounded")

func exit_state() -> void:
	print_debug("Exit Grounded")

func physics_process(delta: float) -> void:
	# 1. Update State & Inputs
	_read_input(delta)
	
	_update_speed(delta)
	
	player.move_and_slide()

# =================================================
# INPUT — single source of truth, pure reads only
func _read_input(delta: float) -> void:
	inp_throttle           = Input.get_action_strength("throttle")
	inp_brake              = Input.get_action_strength("brake")
	player.inp_steer       = Input.get_action_strength("left") - Input.get_action_strength("right")
	inp_pitch              = inp_throttle - inp_brake
	
	player.smoothed_input_x = lerp(player.smoothed_input_x, player.inp_steer, player.rotation_smoothing * delta)

# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	if inp_throttle > 0:
		player.current_speed = move_toward(player.current_speed, player.max_speed, player.acceleration * delta)
	elif inp_brake > 0:
		player.current_speed = move_toward(player.current_speed, 0.0, player.braking * delta)
	else:
		var drag: float = player.friction if player.is_on_floor() else player.air_drag
		player.current_speed = move_toward(player.current_speed, 0.0, drag * delta)
