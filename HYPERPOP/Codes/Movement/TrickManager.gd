extends Node3D
class_name TrickManager

@onready var player: BoardController = get_parent()

@export_group("Trick Settings")
@export var spin_acceleration: float = 25.0    
@export var max_spin_speed: float = 20.0      
@export var spin_friction: float = 4.0        
@export var safe_landing_threshold: float = 0.4 

@export var rank_thresholds: Dictionary = {
	"C": 1.0,  
	"B": 2.5, 
	"A": 4.0,
	"S": 6.0,
	"X": 9.0
}

var is_active: bool = false
var total_spins_accumulated: float = 0.0
var current_spin_vel: Vector2 = Vector2.ZERO
var trick_speed_mult: float = 1.0

func start_tricks(is_mega_launch: bool) -> void:
	is_active = true
	total_spins_accumulated = 0.0
	current_spin_vel = Vector2.ZERO
	trick_speed_mult = 1.3 if is_mega_launch else 1.0

func process_trick_input(delta: float) -> void:
	if not is_active: return

	var input_vec = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("brake") - Input.get_action_strength("throttle") # Throttle costuma inclinar pra frente
	)

	# Se o jogador está movendo o analógico, acelera o giro
	if input_vec.length() > 0.1:
		current_spin_vel.x += input_vec.y * spin_acceleration * trick_speed_mult * delta # Pitch (Giro Frontal/Backflip)
		current_spin_vel.y += -input_vec.x * spin_acceleration * trick_speed_mult * delta # Yaw/Roll (Giro Lateral/Saca-rolhas)
	else:
		# Desacelera quando solta, permitindo mirar para pousar
		current_spin_vel = current_spin_vel.lerp(Vector2.ZERO, spin_friction * delta)

	current_spin_vel.x = clamp(current_spin_vel.x, -max_spin_speed * trick_speed_mult, max_spin_speed * trick_speed_mult)
	current_spin_vel.y = clamp(current_spin_vel.y, -max_spin_speed * trick_speed_mult, max_spin_speed * trick_speed_mult)

	_update_visual_rotation(delta)

func _update_visual_rotation(delta: float) -> void:
	if not player.board_target: return
	
	var rot_speed = current_spin_vel.length()
	
	if rot_speed > 0.01:
		var spin_axis = Vector3(current_spin_vel.x, current_spin_vel.y, 0).normalized()
		
		var spin_quat = Quaternion(spin_axis, rot_speed * delta)
		player.board_target.quaternion = player.board_target.quaternion * spin_quat
		
		total_spins_accumulated += (rot_speed * delta) / TAU

func finish_tricks() -> String:
	is_active = false
	var final_rank = "FAIL"
	
	if _evaluate_landing():
		final_rank = get_current_rank()
		_apply_boost_reward(final_rank)
		player.current_shake = 0.25 
	else:
		final_rank = "C" 
		_penalize_momentum()
		
	_reset_rider_rotation()
	return final_rank

func _evaluate_landing() -> bool:
	if not player.board_target: return true
	
	var model_up = player.board_target.global_transform.basis.y.normalized()
	var reference_up = player.global_transform.basis.y.normalized() 
	
	var alignment = model_up.dot(reference_up)
	return alignment >= safe_landing_threshold

func _penalize_momentum() -> void:
	if "velocity" in player:
		player.velocity *= 0.2
	if "current_speed" in player:
		player.current_speed *= 0.2
	player.current_shake = 0.5

func _reset_rider_rotation() -> void:
	if not player.board_target: return
	
	var tween = create_tween()
	tween.tween_property(player.board_target, "quaternion", Quaternion.IDENTITY, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func get_current_rank() -> String:
	var rank = "C"
	for r in ["C", "B", "A", "S", "X"]:
		if total_spins_accumulated >= rank_thresholds[r]:
			rank = r
	return rank

func _apply_boost_reward(rank: String) -> void:
	var reward = 0.0
	match rank:
		"C": reward = 0.2
		"B": reward = 0.5
		"A": reward = 1.0
		"S": reward = 2.0
		"X": reward = 4.0
	
	player.current_boost_segments += reward
