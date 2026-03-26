extends BoardState
class_name WallRunning

@onready var player: BoardController = get_parent().get_parent()

const WALL_RUN_LAYER: int = 5

func enter_state() -> void:
	print_debug("Enter Wall_Running")
	player.is_wall_running = true
	
	player.velocity.y *= 0.1

func exit_state() -> void:
	print_debug("Exit Wall_Running")
	player.is_wall_running = false
	player.wall_normal = Vector3.ZERO
	player.wall_side = 0.0

func physics_process(delta: float) -> void:
	player._read_input(delta)
	
	_maintain_wall_speed(delta)
	
	_apply_wall_gravity(delta)
	player.move_and_slide()
	
	_check_wall_connection()
	_update_loco_state()

# =================================================
# LOCOMOTION STATE RESOLVER
func _update_loco_state() -> void:
	
	if player.is_wall_running:
		if player.can_jump and player.inp_jump_held:
			loco_state_machine.change_state("Jump_Charging")
		return  
	if player.is_on_floor():
		loco_state_machine.change_state("Grounded")
	else:
		loco_state_machine.change_state("Airborne")
			

# =================================================
# WALL RUNNING MATH
func _maintain_wall_speed(delta: float) -> void:
	if player.wall_normal == Vector3.ZERO:
		return

	var fwd: Vector3 = -player.global_transform.basis.z
	var wall_forward: Vector3 = player.wall_normal.cross(Vector3.UP).normalized()
	
	if fwd.dot(wall_forward) < 0:
		wall_forward = -wall_forward
	
	var current_fall = player.velocity.y
	player.velocity = wall_forward * player.current_speed
	player.velocity.y = current_fall
	
	var stick = player.wall_stick_force if "wall_stick_force" in player else player.stick_force
	player.velocity -= player.wall_normal * stick * delta

func _apply_wall_gravity(delta: float) -> void:
	var g = ProjectSettings.get_setting("physics/3d/default_gravity")
	var grav_mul = player.wall_gravity_mul if "wall_gravity_mul" in player else 0.2
	player.velocity.y -= (g * grav_mul) * delta

func _check_wall_connection() -> void:
	var found_wall: bool = false
	var best_normal: Vector3 = Vector3.ZERO
	
	for i in player.get_slide_collision_count():
		var collision = player.get_slide_collision(i)
		var n: Vector3 = collision.get_normal()
		
		if n.dot(Vector3.UP) > 0.7: 
			player.is_wall_running = false
			return

		if abs(n.dot(Vector3.UP)) < 0.3:
			var collider = collision.get_collider()
			if collider and collider.get_collision_layer_value(WALL_RUN_LAYER):
				best_normal = n
				found_wall = true
				break
	
	if found_wall:
		player.wall_normal = best_normal
		player.is_wall_running = true # Mantém o flag ativo
	else:
		player.is_wall_running = false
