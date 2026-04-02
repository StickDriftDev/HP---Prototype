extends BoardState
class_name WallRunning

@onready var player: BoardController = get_parent().get_parent()

@export var wall_group_name: String = "wall_run"
@export var detach_grace_time: float = 0.15 

var _detach_timer: float = 0.0

func enter_state() -> void:
	print_debug("Enter Wall_Running")
	player.is_wall_running = true
	player.velocity.y *= 0.1
	_detach_timer = detach_grace_time

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
	
	_check_wall_connection(delta)
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
	
	var stick = player.wall_stick_force if "wall_stick_force" in player else 20.0
	player.velocity -= player.wall_normal * stick * delta

func _apply_wall_gravity(delta: float) -> void:
	var g = ProjectSettings.get_setting("physics/3d/default_gravity")
	var grav_mul = player.wall_gravity_mul if "wall_gravity_mul" in player else 0.2
	player.velocity.y -= (g * grav_mul) * delta

# =================================================
func _check_wall_connection(delta: float) -> void:
	var found_wall: bool = false
	var best_normal: Vector3 = Vector3.ZERO
	
	for i in player.get_slide_collision_count():
		var collision = player.get_slide_collision(i)
		var n = collision.get_normal()
		
		if abs(n.dot(Vector3.UP)) < 0.3:
			var collider = collision.get_collider()
			if collider and collider.is_in_group(wall_group_name):
				best_normal = n
				found_wall = true
				break
	
	if not found_wall and player.wall_normal != Vector3.ZERO:
		var space_state = player.get_world_3d().direct_space_state
		var probe_distance: float = 0.5 
		
		var query = PhysicsRayQueryParameters3D.create(
			player.global_position, 
			player.global_position - (player.wall_normal * probe_distance)
		)
		query.exclude = [player.get_rid()]
		
		var result = space_state.intersect_ray(query)
		if result and result.collider.is_in_group(wall_group_name):
			var n = result.normal
			if abs(n.dot(Vector3.UP)) < 0.3:
				best_normal = n
				found_wall = true

	if found_wall:
		player.wall_normal = best_normal
		player.is_wall_running = true
		_detach_timer = detach_grace_time 
	else:
		_detach_timer -= delta
		if _detach_timer <= 0.0:
			player.is_wall_running = false
