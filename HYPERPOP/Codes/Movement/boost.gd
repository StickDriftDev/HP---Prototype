extends BoardState
class_name Boost

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	if player.current_boost_segments < 1.0:
		loco_state_machine.change_state("Grounded")
		return
		
	player.current_boost_segments -= 1.0
	player.is_boosting = true
	player.boost_timer = player.boost_duration_per_segment
	
	player.current_speed += 20.0 
	player.current_shake = 0.4 
	
	player.target_visual_scale = Vector3(0.7, 0.7, 1.5)
	
	# Juice: FOV Kick Imediato
	if player.Cam:
		player.Cam.fov += player.boost_fov_kick
	
	_play_boost_effects()

func exit_state() -> void:
	player.is_boosting = false
	player.target_visual_scale = Vector3.ONE
	
	if player.PlayerSFX and player.PlayerSFX.has_method("stop_boost"):
		player.PlayerSFX.stop_boost()

func physics_process(delta: float) -> void:
	player._read_input(delta)
	
	player.current_speed = lerp(player.current_speed, player.boost_speed_target, player.boost_accel * delta)
	
	_apply_boost_vfx(delta)
	
	player.boost_timer -= delta
	if player.boost_timer <= 0.0:
		_finish_boost()
	
	player.move_and_slide()

func _apply_boost_vfx(delta: float) -> void:
	if player.Cam:
		var target_fov = player.base_fov + player.boost_fov_kick
		player.Cam.fov = lerp(player.Cam.fov, target_fov, 4.0 * delta)
	
	player.current_shake = move_toward(player.current_shake, 0.08, delta)
	
	var target_roll = -player.inp_steer * 15.0
	player.current_cam_roll = lerp(player.current_cam_roll, target_roll, 10.0 * delta)

func _finish_boost() -> void:
	if player.is_on_floor():
		loco_state_machine.change_state("Grounded")
	else:
		loco_state_machine.change_state("Airborne")

func _play_boost_effects() -> void:
	if player.PlayerSFX and player.PlayerSFX.has_method("play_boost"):
		player.PlayerSFX.play_boost()
	
