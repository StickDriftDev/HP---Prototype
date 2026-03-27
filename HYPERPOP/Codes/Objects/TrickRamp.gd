extends Area3D
class_name TrickRamp

@export_group("Standard Launch (Passive)")
@export var dist_base: float = 50.0
@export var height_base: float = 12.0
@export var air_time_base: float = 1.3

@export_group("Efficient Launch (Active Charge)")
@export var efficiency_multiplier: float = 1.5  
@export var mid_efficiency_multiplier: float = 1.2 
@export var air_time_bonus: float = 0.7 

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is BoardController:
		_execute_launch(body)

func _execute_launch(player: BoardController) -> void:
	# --- 3 STATES LOGIC ---
	
	var multiplier: float = 1.0
	var final_air_bonus: float = 0.0
	
	if player.current_jump_charge > 0.1:
		if not Input.is_action_pressed("jump"):
			multiplier = efficiency_multiplier
			final_air_bonus = air_time_bonus
			_dbg_ramp("MEGA JUMP: Timing Perfeito!")
		
		else:
			multiplier = mid_efficiency_multiplier
			final_air_bonus = air_time_bonus * 0.4 
			_dbg_ramp("Pulo Fraco: Você não soltou o botão a tempo.")
	
	else:
		_dbg_ramp("Pulo Passivo: Sem carga.")

	var final_dist = dist_base * multiplier
	var final_height = height_base * multiplier
	var final_air_time = air_time_base + final_air_bonus
	
	var forward_dir = -global_transform.basis.z.normalized()
	
	var g = (8.0 * final_height) / (final_air_time * final_air_time)
	var v_y = (4.0 * final_height) / final_air_time
	var v_fwd = final_dist / final_air_time
	
	var launch_velocity = (forward_dir * v_fwd) + (Vector3.UP * v_y)
	
	var look_target = player.global_position + forward_dir
	look_target.y = player.global_position.y
	player.look_at(look_target, Vector3.UP)
	
	# 6. Envio para o Player
	if player.has_method("prepare_ramp_jump"):
		player.current_jump_charge = 0.0
		if "is_charging_jump" in player:
			player.is_charging_jump = false
			
		player.prepare_ramp_jump(launch_velocity, g, forward_dir)

func _dbg_ramp(msg: String):
	print("[TrickRamp] ", msg)
