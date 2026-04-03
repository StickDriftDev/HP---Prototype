extends BoardState
class_name Airborne

@export var grind_rail_cast:RayCast3D
@onready var player: BoardController = get_parent().get_parent()

var air_time_bonus: float = 0.0

func enter_state() -> void:
	if player.Rider_Model:
		player.target_visual_scale = Vector3(0.8, 1.3, 0.8)
	air_time_bonus = 0.0

func exit_state() -> void:
	player.current_air_pitch = 0.0

func physics_process(delta: float) -> void:
	player._read_input(delta)
	_update_loco_state()
	
	_handle_air_physics(delta)
	_update_air_visuals(delta)
	
	player.move_and_slide()

func _handle_air_physics(delta: float) -> void:
	var dive_factor: float = sin(player.current_air_pitch)
	
	if dive_factor > 0.1: 
		player.current_speed += player.dive_speed_gain * dive_factor * delta
		player.current_shake = move_toward(player.current_shake, 0.15 * dive_factor, delta)
	elif dive_factor < -0.1: 
		player.current_speed -= player.pull_up_speed_loss * abs(dive_factor) * delta
		player.velocity.y += abs(dive_factor) * 2.0 * delta 
	
	if player.inp_brake > 0:
		player.current_speed = move_toward(player.current_speed, 0.0, player.air_brake_force * delta)
	
	var side_dir = player.global_transform.basis.x
	player.velocity += side_dir * player.inp_steer * player.air_lateral_force * delta

	player.current_speed = max(player.current_speed, 5.0) 

func _update_air_visuals(delta: float) -> void:
	var target_roll = -player.inp_steer * 25.0 
	player.Cam.rotation_degrees.z = lerp(player.Cam.rotation_degrees.z, target_roll, 5.0 * delta)
	
	if player.Cam:
		var dive_fov_boost = clamp(sin(player.current_air_pitch) * 15.0, 0.0, 15.0)
		player.Cam.fov = lerp(player.Cam.fov, player.base_fov + dive_fov_boost, 4.0 * delta)

func _update_loco_state() -> void:
	if player.is_wall_running:
		loco_state_machine.change_state("Wall_Running")
		return

	if player.is_on_floor():
		if player.inp_jump_held:
			loco_state_machine.change_state("Jump_Charging")
		elif player.inp_drift:
			loco_state_machine.change_state("Drifting")
		else:
			loco_state_machine.change_state("Grounded")
	
	for grind_ray in player.grindrays.get_children():
		if grind_ray.is_colliding() and grind_ray.get_collider() and grind_ray.get_collider().is_in_group("rail"):
			loco_state_machine.change_state("Rail_Glide")

# Rail Landing and board state change
func _landing_on_rail():
	pass
