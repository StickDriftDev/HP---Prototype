extends BoardState
class_name JumpCharging

@onready var player: BoardController = get_parent().get_parent()

@export var jump_charge_boost_cost: float = 0.2

func enter_state() -> void:
	player.is_charging_jump = true
	player.current_jump_charge = 0.0
	if player.PlayerSFX and player.PlayerSFX.has_method("play_charge_start"):
		player.PlayerSFX.play_charge_start()
	print_debug("Enter Jump Charging - Com Visual Juice")

func exit_state() -> void:
	player.is_charging_jump = false
	if player.Rider_Model:
		player.Rider_Model.position.x = 0

func physics_process(delta: float) -> void:
	player._read_input(delta)
	
	_handle_charging_logic(delta)
	_apply_visual_tension(delta)
	
	player.current_speed = lerp(player.current_speed, 0.0, player.jump_charge_drag * delta)
	
	if not player.is_on_floor() and not player.is_wall_running:
		_release_jump()
		return

	player._apply_surface_gravity(delta)
	player.move_and_slide()

func _handle_charging_logic(delta: float) -> void:
	if player.inp_jump_held:
		if player.current_boost_segments > 0:
			player.current_boost_segments -= jump_charge_boost_cost * delta
		
		player.current_jump_charge = move_toward(player.current_jump_charge, 1.0, delta / player.max_charge_time)
		
		if player.current_jump_charge > 0.5:
			player.Rider_Model.position.x = randf_range(-0.02, 0.02) * player.current_jump_charge
	else:
		_release_jump()

func _apply_visual_tension(delta: float) -> void:
	var squash = player.current_jump_charge * 0.4
	player.target_visual_scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)
	
	if player.Cam:
		var target_fov = player.base_fov - (2.0 * player.current_jump_charge)
		player.Cam.fov = lerp(player.Cam.fov, target_fov, 10.0 * delta)

func _release_jump() -> void:
	var was_trick_jump = player._execute_jump()
	
	if player.Cam:
		player.Cam.fov += 10.0 
	
	if was_trick_jump:
		loco_state_machine.change_state("TrickAirborne")
	else:
		loco_state_machine.change_state("Airborne")
