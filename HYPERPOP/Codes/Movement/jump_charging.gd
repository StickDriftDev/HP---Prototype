extends BoardState
class_name JumpCharging

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	player.is_charging_jump = true
	player.current_jump_charge = 0.0
	if player.PlayerSFX and player.PlayerSFX.has_method("play_charge_start"):
		player.PlayerSFX.play_charge_start()

func exit_state() -> void:
	player.is_charging_jump = false

func physics_process(delta: float) -> void:
	player._read_input(delta)
	
	_handle_charging_logic(delta)
	_apply_visual_tension(delta)
	
	player.current_speed = lerp(player.current_speed, 0.0, player.jump_charge_drag * delta)
	
	if not player.is_on_floor() and not player.is_wall_running:
		_release_jump()
		return

	_update_loco_state()
	player.move_and_slide()

func _handle_charging_logic(delta: float) -> void:
	if player.inp_jump_held:
		player.current_jump_charge = move_toward(player.current_jump_charge, 1.0, delta / player.max_charge_time)
		
		if player.current_jump_charge > 0.5:
			player.Rider_Model.position.x = randf_range(-0.02, 0.02) * player.current_jump_charge
	else:
		_release_jump()

func _apply_visual_tension(delta: float) -> void:

	var squash = player.current_jump_charge * 0.4
	player.target_visual_scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)
	
	if player.Cam:
		var target_fov = player.base_fov - (5.0 * player.current_jump_charge)
		player.Cam.fov = lerp(player.Cam.fov, target_fov, 10.0 * delta)

func _release_jump() -> void:
	player._execute_jump()
	
	if player.Cam:
		player.Cam.fov += 10.0 
	
	loco_state_machine.change_state("Airborne")

func _update_loco_state() -> void:
	if not player.inp_jump_held:
		loco_state_machine.change_state("Grounded")
