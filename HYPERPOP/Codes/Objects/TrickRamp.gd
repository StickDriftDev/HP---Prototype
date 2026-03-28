extends Area3D
class_name TrickRamp

@export_group("Standard Launch (Passive)")
@export var base_dist: float = 50.0
@export var base_height: float = 12.0
@export var base_air_time: float = 1.3

@export_group("Efficient Launch (Active Charge)")
@export var efficiency_multiplier: float = 1.5  
@export var mid_efficiency_multiplier: float = 1.2 
@export var air_time_bonus: float = 0.7 

@export_group("Trick Speed Multipliers")
@export var trick_speed_passive: float = 1.0
@export var trick_speed_weak: float = 1.4
@export var trick_speed_mega: float = 2.0

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is BoardController:
		_execute_launch(body)

func _execute_launch(player: BoardController) -> void:
	var multiplier: float = 1.0
	var final_air_bonus: float = 0.0
	var trick_speed_mult: float = trick_speed_passive
	var is_mega_jump: bool = false 
	
	# --- CHARGE LOGIC AND TIMING ---
	if player.current_jump_charge > 0.1:
		if not Input.is_action_pressed("jump"):
			multiplier = efficiency_multiplier
			final_air_bonus = air_time_bonus
			trick_speed_mult = trick_speed_mega
			is_mega_jump = true
			_dbg_ramp("MEGA JUMP: Perfect Timing!")
		else:
			multiplier = mid_efficiency_multiplier
			final_air_bonus = air_time_bonus * 0.4 
			trick_speed_mult = trick_speed_weak
			_dbg_ramp("Weak Jump: You didn't release the button in time.")
	else:
		_dbg_ramp("Passive Jump: No charge.")

	# --- PHYSICS CALCULATION ---
	var final_dist = base_dist * multiplier
	var final_height = base_height * multiplier
	var final_air_time = base_air_time + final_air_bonus
	
	var forward_dir = -global_transform.basis.z.normalized()
	
	# Parabola Calculation
	var g = (8.0 * final_height) / (final_air_time * final_air_time)
	var v_y = (4.0 * final_height) / final_air_time
	var v_fwd = final_dist / final_air_time
	var launch_velocity = (forward_dir * v_fwd) + (Vector3.UP * v_y)
	
	# --- VISUAL ALIGNMENT ---
	var look_target = player.global_position + forward_dir
	look_target.y = player.global_position.y
	player.look_at(look_target, Vector3.UP)
	
	# --- SEND TO PLAYER ---
	if player.has_method("prepare_ramp_jump"):
		player.current_jump_charge = 0.0
		if "is_charging_jump" in player:
			player.is_charging_jump = false
			
		player.prepare_ramp_jump(launch_velocity, g, forward_dir, is_mega_jump, trick_speed_mult)

func _dbg_ramp(msg: String):
	if OS.is_debug_build():
		print("[TrickRamp] ", msg)
