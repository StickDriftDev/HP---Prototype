extends BoardState
class_name Drifting

@onready var player: BoardController = get_parent().get_parent()

@export var dash_boost_cost: float = 0.4 

func enter_state() -> void:
	player.is_drifting = true
	player.drift_charge = 0.0
	
	player.current_shake = 0.12
	
	if player.PlayerSFX and player.PlayerSFX.has_method("play_drift_loop"):
		player.PlayerSFX.play_drift_loop()

func exit_state() -> void:
	player.is_drifting = false
	if player.PlayerSFX and player.PlayerSFX.has_method("stop_drift_loop"):
		player.PlayerSFX.stop_drift_loop()

func physics_process(delta: float) -> void:
	player._read_input(delta)
	
	_handle_drift_mechanics(delta)
	_apply_extreme_juice(delta)
	
	_update_loco_state()
	player.move_and_slide()

func _handle_drift_mechanics(delta: float) -> void:
	player.current_speed = move_toward(player.current_speed, player.drift_min_speed, player.drift_deceleration_rate * delta)
	
	player.drift_charge = move_toward(player.drift_charge, 1.0, delta / player.drift_max_charge_time)
	
	if "drift_boost_regen" in player:
		player.current_boost_segments += player.drift_boost_regen * delta

func _apply_extreme_juice(delta: float) -> void:
	var steer_dir = sign(player.inp_steer)
	var target_roll = -steer_dir * 18.0 
	player.current_cam_roll = lerp(player.current_cam_roll, target_roll, 8.0 * delta)
	
	if player.Cam:
		var target_fov = player.base_fov + (10.0 * player.drift_charge)
		player.Cam.fov = lerp(player.Cam.fov, target_fov, 5.0 * delta)
	
	if player.drift_charge >= 1.0:
		player.current_shake = move_toward(player.current_shake, 0.05, delta)

func _handle_drift_dash() -> void:
	if player.drift_charge >= 0.5:
		var power = player.drift_charge
		
		player.current_boost_segments -= dash_boost_cost * power
		
		player.dash_velocity = player.current_speed + (player.drift_dash_force * power)
		player.dash_timer = player.drift_dash_duration
		
		if player.Cam:
			player.Cam.fov += 15.0 * power
		player.current_shake = 0.3 * power
		
		if player.PlayerSFX and player.PlayerSFX.has_method("play_dash"):
			player.PlayerSFX.play_dash()

	player.drift_charge = 0.0

func _update_loco_state() -> void:
	if not player.is_on_floor():
		loco_state_machine.change_state("Airborne")
		return
	
	if player.current_speed < (player.drift_min_speed * 0.4):
		loco_state_machine.change_state("Grounded")
		return

	if not player.inp_drift:
		_handle_drift_dash()
		loco_state_machine.change_state("Grounded")
