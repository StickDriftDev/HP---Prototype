extends BoardState
class_name Drifting

@onready var player: BoardController = get_parent().get_parent()

# =================================================
# CENTRALISED INPUT STATE — populated once per frame in _read_input()
var inp_drift: bool = false

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
	inp_drift              = Input.is_action_pressed("drift")
	
	player.smoothed_input_x = lerp(player.smoothed_input_x, player.inp_steer, player.rotation_smoothing * delta)

# =================================================
# SPEED
func _update_speed(delta: float) -> void:
	pass

# =================================================
# DRIFT & DASH
func _update_drift(delta: float) -> void:
	if !player.is_on_floor() || player.current_speed < player.drift_min_speed:
		player.is_drifting = false
		player.drift_charge = 0.0
		if player.PlayerSFX: player.PlayerSFX.stop_drift_loop()
		return

	player.is_drifting = player.inp_drift and abs(player.inp_steer) > 0.1
	if player.is_drifting:
		player.current_speed = move_toward(player.current_speed, 0.0, player.drift_deceleration_rate * delta)
		player.drift_charge = move_toward(player.drift_charge, 1.0, delta / player.drift_max_charge_time)
		if player.PlayerSFX: player.PlayerSFX.play_drift_loop()
	else:
		if player.PlayerSFX: player.PlayerSFX.stop_drift_loop()
		if player.drift_charge >= 1.0:
			player.dash_velocity = player.current_speed + player.drift_dash_force
			player.dash_timer = player.drift_dash_duration
			player._dbg_log("EVENT: Drift DASH released — dash_velocity: %.1f" % player.dash_velocity)
			if player.PlayerSFX: player.PlayerSFX.play_dash()
			player.drift_charge = 0.0
