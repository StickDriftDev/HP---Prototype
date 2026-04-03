extends BoardState
class_name RailGlide


@onready var player: BoardController = get_parent().get_parent()


#code by greeny - https://www.youtube.com/channel/UC0rQ3oO5pNaugwhNAD79qsw
#--RAIL GRINDING VARIABLES--
var rail_grind_node = null
var detached_from_rail: bool = false


func enter_state() -> void:
	print_debug("Enter Rail_Glide")
	if player.detach_jump_force < player.min_jump_force or player.detach_jump_force > player.max_jump_force:
		push_warning("detach_jump_force ", player.detach_jump_force," is less or more than min or max ")


func exit_state() -> void:
	print_debug("Exit Rail_Glide")
	pass


func physics_process(delta: float) -> void:
	player._read_input(delta)
	rail_grinding(delta)


#GRINDING
func rail_grinding(delta):
	if player.grind_timer_complete:
		var grind_ray = get_valid_grind_ray()
		print_debug("grind_ray", grind_ray)
		if grind_ray:
			start_grinding(grind_ray, delta)
	
	player.grind_timer_complete = false
	rail_grind_node.chosen = true
	if not rail_grind_node.direction_selected:
		rail_grind_node.forward = is_facing_same_direction(player, rail_grind_node)
		rail_grind_node.direction_selected = true
	update_player_position(delta)
	if rail_grind_node.detach or Input.is_action_pressed("jump"):
		detach_from_rail()

#enables you to use multiple rays
func get_valid_grind_ray():
	for grind_ray in player.grindrays.get_children():
		print_debug("if ", grind_ray.is_colliding(), grind_ray.get_collider(), grind_ray.get_collider().is_in_group("rail"))
		if grind_ray.is_colliding() and grind_ray.get_collider() and grind_ray.get_collider().is_in_group("rail"):
			return grind_ray
	return null

func start_grinding(grind_ray, delta):
	var grind_rail = grind_ray.get_collider().get_parent()
	player.gravity_mul = 0.0
	print_debug("grind_rail", grind_rail)
	print_debug(player.global_position)
	rail_grind_node = find_nearest_rail_follower(player.global_position, grind_rail)
	player.position = lerp(player.position, rail_grind_node.position, delta * player.lerp_speed)

func update_player_position(delta):
	player.position = lerp(player.position, rail_grind_node.position, delta * player.lerp_speed)

func detach_from_rail():
	detached_from_rail = true
	player.velocity.y = player.detach_jump_force #jump_velocity
	rail_grind_node.detach = false
	reset_player_states_after_detach()

func reset_player_states_after_detach():
	detach_rail() #needed regardless of state machine
	loco_state_machine.change_state("Airborne")

func detach_rail():
	rail_grind_node.chosen = false
	rail_grind_node.detach = false
	player.position = rail_grind_node.global_position
	player.gravity_mul = 4.0 #gravity_default
	player.start_grind_timer = true
	rail_grind_node.progress = rail_grind_node.origin_point
	detached_from_rail = false

func is_facing_same_direction(node, path_follow: PathFollow3D) -> bool:
	var player_forward = -node.global_transform.basis.z.normalized()
	var path_follow_forward = -path_follow.global_transform.basis.z.normalized()
	var dot_product = player_forward.dot(path_follow_forward)
	const THRESHOLD = 0.5
	return abs(dot_product - 1.0) < THRESHOLD

func grind_timer(delta):
	print_debug("Timer", player.countdown_for_next_grind_time_left)
	if player.start_grind_timer:
		print_debug("1 Timer after", player.countdown_for_next_grind_time_left)
		if player.countdown_for_next_grind_time_left > 0:
			print_debug("Timer after", player.countdown_for_next_grind_time_left)
			player.countdown_for_next_grind_time_left -= delta
			if player.countdown_for_next_grind_time_left <= 0:
				if Input.is_action_pressed("forward"):
					Input.action_release("forward")
				player.countdown_for_next_grind_time_left = player.countdown_for_next_grind
				player.grind_timer_complete = true
				player.start_grind_timer = false

func find_nearest_rail_follower(player_position, rail_node):
	var nearest_node = null
	var min_distance = INF
	for node in rail_node.get_children():
		if node.is_in_group("rail follower"):
			var distance = player_position.distance_to(node.global_transform.origin)
			if distance < min_distance:
				min_distance = distance
				nearest_node = node
	return nearest_node

#END GRINDING
