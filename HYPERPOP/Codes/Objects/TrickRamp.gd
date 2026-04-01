extends Area3D
class_name TrickRamp

@export_group("Activation Settings")
@export var require_jump_charge: bool = false 

@export_group("Physics Launch Base")
@export var base_dist: float = 40.0
@export var base_height: float = 10.0
@export var base_air_time: float = 1.1
@export_range(0, 1) var momentum_retention: float = 0.8

@export_group("Jump Multipliers (Tiers)")
@export var passive_mult: float = 1.0
@export var failed_release_mult: float = 1.15
@export var good_launch_mult: float = 1.35
@export var mega_launch_mult: float = 1.6

@export_group("Trick Speed Multipliers")
@export var trick_speed_passive: float = 1.0
@export var trick_speed_failed: float = 1.2
@export var trick_speed_good: float = 1.6
@export var trick_speed_mega: float = 2.2

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is BoardController:
		_execute_launch(body)

func _execute_launch(player: BoardController) -> void:
	if require_jump_charge and player.current_jump_charge <= 0.1:
		_dbg_ramp("Ignored: Requires charge.")
		return

	var multiplier: float = passive_mult
	var trick_speed_mult: float = trick_speed_passive
	var is_mega_jump: bool = false
	var jump_type_name: String = "PASSIVE"

	# --- JUMP TIERS LOGIC ---
	
	var charge = player.current_jump_charge
	var is_holding = Input.is_action_pressed("jump")

	if charge > 0.1:
		if is_holding:
			# CASE 1: Loaded but did not release ("Heavy"/Failed Jump)
			multiplier = failed_release_mult
			trick_speed_mult = trick_speed_failed
			jump_type_name = "FAILED RELEASE (STALE)"
		else:
			# The player released the button. Now we check the intensity.
			if charge < 0.7:
				# CASE 2: Released early or with little load (Good Jump)
				multiplier = good_launch_mult
				trick_speed_mult = trick_speed_good
				jump_type_name = "GOOD JUMP"
			else:
				# CASE 3: High load and release (Mega Jump)
				multiplier = mega_launch_mult
				trick_speed_mult = trick_speed_mega
				is_mega_jump = true
				jump_type_name = "!!! MEGA JUMP !!!"
	else:
		jump_type_name = "PASSIVE JUMP"

	# --- PHYSICS MATH ---
	var forward_dir = -global_transform.basis.z.normalized()
	var player_velocity = player.velocity if "velocity" in player else Vector3.ZERO
	var entry_speed = player_velocity.dot(forward_dir)
	
	var final_dist = base_dist * multiplier
	var final_height = base_height * multiplier
	var final_air_time = base_air_time
	
	if is_mega_jump: final_air_time += 0.4

	var target_v_fwd = (final_dist / final_air_time)
	var boost_v_fwd = max(target_v_fwd, entry_speed * momentum_retention)
	
	var g = (8.0 * final_height) / (final_air_time * final_air_time)
	var v_y = (4.0 * final_height) / final_air_time
	
	var launch_velocity = (forward_dir * boost_v_fwd) + (Vector3.UP * v_y)
	
	# --- ALIGNMENT ---
	var look_target = player.global_position + forward_dir
	look_target.y = player.global_position.y
	player.look_at(look_target, Vector3.UP)
	
	# --- SEND TO THE PLAYER ---
	if player.has_method("prepare_ramp_jump"):
		player.current_jump_charge = 0.0
		if "is_charging_jump" in player:
			player.is_charging_jump = false
			
		player.prepare_ramp_jump(launch_velocity, g, forward_dir, is_mega_jump, trick_speed_mult)
		_dbg_ramp("Type: %s | Speed Mult: %.2f" % [jump_type_name, trick_speed_mult])

func _dbg_ramp(msg: String):
	if OS.is_debug_build():
		print("[TrickRamp] ", msg)
