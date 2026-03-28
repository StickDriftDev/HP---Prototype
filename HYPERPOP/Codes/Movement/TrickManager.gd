extends Node3D
class_name TrickManager

signal rank_up_achieved(new_rank: String)
signal trick_finished(final_rank: String, success: bool)

@onready var player: BoardController = get_parent()

# =================================================
# CONFIG — TARGETS & REFERENCES
@export_group("Customizable Targets")
@export var target_to_rotate: Node3D 
@export var sounds_fx: PlaySoundsFX 

# =================================================
# CONFIG — AUDIO LOGIC
@export_group("Audio Configs")
@export var spin_threshold_for_sound: float = 1.0 
@export var spin_sound_cooldown: float = 0.1 

# =================================================
# CONFIG — PHYSICS & FEEL
@export_group("Fluid & Dynamic Physics")
@export var base_spin_speed: float = 18.0
@export var base_acceleration: float = 15.0
@export var friction_air: float = 6.0
@export var roll_style_amount: float = 0.6

@export_group("Auto-Correction")
@export var auto_stabilize_speed: float = 4.5 

# =================================================
# CONFIG — JUICE & GAME FEEL
@export_group("Game Feel & Juice")
@export var enable_centrifugal_stretch: bool = true
@export var stretch_intensity: float = 0.015
@export var hitstop_on_high_rank: float = 0.05

# =================================================
# CONFIG — LANDING
@export_group("Landing Precision")
@export var safe_landing_threshold: float = 0.35 
@export var perfect_landing_threshold: float = 0.85

@export var rank_thresholds: Dictionary = {
	"C": 1.0, "B": 3.0, "A": 5.5, "S": 8.5, "X": 12.0
}

var rank_pitch_map: Dictionary = {
	"C": 1.0, "B": 1.1, "A": 1.25, "S": 1.45, "X": 1.7
}

# =================================================
# STATE VARIABLES
var is_active: bool = false
var total_spins_accumulated: float = 0.0
var _last_sound_spin_marker: float = 0.0 
var _last_sound_time: float = 0.0 
var current_points: float = 0.0

var jump_performance: float = 1.0 
var highest_rank_achieved: String = "C"

var current_spin_angles: Vector3 = Vector3.ZERO
var spin_velocity: Vector3 = Vector3.ZERO
var last_input_length: float = 0.0

# =================================================
# LIFECYCLE & CORE
func start_tricks(jump_power: float = 1.0) -> void:
	is_active = true
	total_spins_accumulated = 0.0
	_last_sound_spin_marker = 0.0
	_last_sound_time = 0.0
	current_spin_angles = Vector3.ZERO
	spin_velocity = Vector3.ZERO
	last_input_length = 0.0
	highest_rank_achieved = "C"
	jump_performance = max(1.0, jump_power)
	current_points = 0.0
	
	if jump_performance > 1.8:
		player.current_shake = 0.4 * jump_performance

func process_trick_input(delta: float) -> void:
	if not is_active: return

	var input_x = Input.get_action_strength("right") - Input.get_action_strength("left")
	var input_y = Input.get_action_strength("back") - Input.get_action_strength("forward")
	var input = Vector2(input_x, input_y)
	
	last_input_length = input.length()

	if last_input_length > 0.1:
		var dynamic_speed = base_spin_speed * jump_performance
		var torque = base_acceleration * jump_performance
		
		var target_vel = Vector3(
			input_y * dynamic_speed,
			-input_x * dynamic_speed,
			(input_x * input_y) * (base_spin_speed * roll_style_amount * jump_performance)
		)
		spin_velocity = spin_velocity.lerp(target_vel, torque * delta)
	else:
		spin_velocity = spin_velocity.lerp(Vector3.ZERO, friction_air * delta)

	_apply_rotation(delta)
	_apply_centrifugal_stretch(delta)

func _apply_rotation(delta: float) -> void:
	if not target_to_rotate: return
	
	var frame_spin_amount = (abs(spin_velocity.x) + abs(spin_velocity.y)) * delta
	var spins_this_frame = frame_spin_amount / TAU
	total_spins_accumulated += spins_this_frame
	
	current_points += spins_this_frame * 1000.0 * jump_performance
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if total_spins_accumulated - _last_sound_spin_marker >= spin_threshold_for_sound:
		if current_time - _last_sound_time >= spin_sound_cooldown:
			_last_sound_spin_marker = total_spins_accumulated
			_last_sound_time = current_time
			
			if sounds_fx:
				sounds_fx.play_trick_spin(1.0)

	current_spin_angles += spin_velocity * delta
	var target_quat = Quaternion.from_euler(current_spin_angles)

	if last_input_length < 0.1:
		target_to_rotate.quaternion = target_to_rotate.quaternion.slerp(Quaternion.IDENTITY, auto_stabilize_speed * delta)
		current_spin_angles = target_to_rotate.quaternion.get_euler()
	else:
		target_to_rotate.quaternion = target_quat

func _apply_centrifugal_stretch(delta: float) -> void:
	if not enable_centrifugal_stretch or not target_to_rotate: return
	
	var speed = spin_velocity.length()
	var stretch = 1.0 + clamp(speed * stretch_intensity, 0.0, 0.6)
	var squash = 1.0 / stretch
	
	var target_scale = Vector3(squash, stretch, squash) if last_input_length > 0.1 else Vector3.ONE
	target_to_rotate.scale = target_to_rotate.scale.lerp(target_scale, 8.0 * delta)

func finish_tricks() -> String:
	is_active = false
	var alignment = _get_alignment()
	var is_safe = alignment >= safe_landing_threshold
	
	if spin_velocity.length() > (base_spin_speed * 0.4):
		is_safe = false
		
	var final_rank = get_current_rank() if is_safe else "FAIL"
	highest_rank_achieved = final_rank
	
	var is_perfect = is_safe and (alignment >= perfect_landing_threshold)
	
	# --- DEBUG LOG ---
	if player and player.debug_enabled:
		var status_text = "PEFECT LANDING!" if is_perfect else ("SUCESS" if is_safe else "CRASH/FAIL")
		print_debug("[TrickManager] Result: %s | Final Rank : %s | Points: %.0f" % [status_text, final_rank, current_points])
	# -----------------
	
	if is_safe:
		_process_rewards(final_rank, is_perfect)
		
		if sounds_fx:
			var target_pitch = rank_pitch_map.get(final_rank, 1.0)
			sounds_fx.play_rank_up(target_pitch)
			sounds_fx.play_land(is_perfect)
			
		if is_perfect or final_rank in ["S", "X"]:
			_trigger_hitstop(hitstop_on_high_rank, 0.2)
	else:
		_process_crash()
	
	_visual_reset(is_perfect, is_safe)
	trick_finished.emit(final_rank, is_safe)
	return final_rank

func _get_alignment() -> float:
	if not target_to_rotate: return 1.0
	var model_up = target_to_rotate.global_transform.basis.y.normalized()
	var world_up = player.global_transform.basis.y.normalized()
	return model_up.dot(world_up)

func _process_rewards(rank: String, perfect: bool) -> void:
	var boost_gain = 0.0
	var speed_mult = 1.0
	
	match rank:
		"C": boost_gain = 0.5; speed_mult = 1.05
		"B": boost_gain = 1.5; speed_mult = 1.15
		"A": boost_gain = 3.0; speed_mult = 1.3
		"S": boost_gain = 5.0; speed_mult = 1.5
		"X": boost_gain = 8.0; speed_mult = 1.8

	if perfect:
		speed_mult += 0.4
		player.current_shake = 0.8
	
	player.current_boost_segments += boost_reward_scaled(boost_gain)
	if "current_speed" in player:
		player.current_speed *= speed_mult

func boost_reward_scaled(base_reward: float) -> float:
	return base_reward * (0.5 + jump_performance * 0.5)

func _process_crash() -> void:
	if "current_speed" in player:
		player.current_speed *= 0.1 
	player.current_shake = 1.5
	
	if sounds_fx:
		sounds_fx.play_land(false)

func _visual_reset(perfect: bool, safe: bool) -> void:
	if not target_to_rotate: return
	var dur = 0.1 if perfect else (0.3 if safe else 0.5)
	var trans = Tween.TRANS_QUART if perfect else Tween.TRANS_BACK
	if not safe: trans = Tween.TRANS_ELASTIC 
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(target_to_rotate, "quaternion", Quaternion.IDENTITY, dur)\
		.set_trans(trans).set_ease(Tween.EASE_OUT)
	
	if perfect:
		target_to_rotate.scale = Vector3(1.2, 0.8, 1.2)
	tween.tween_property(target_to_rotate, "scale", Vector3.ONE, dur * 1.5)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _check_rank_up() -> void:
	pass

func get_current_rank() -> String:
	var rank = "C"
	for r in ["C", "B", "A", "S", "X"]:
		if total_spins_accumulated >= rank_thresholds[r]:
			rank = r
	return rank

func _trigger_hitstop(duration: float, time_scale: float) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale, true, false, true).timeout
	Engine.time_scale = 1.0
