extends BoardState
class_name TrickAirborne

@onready var player: BoardController = get_parent().get_parent()
@onready var trick_manager: TrickManager = player.get_node_or_null("TrickManager")

# =================================================
# CONFIG — TRICK CAMERA
@export_group("Riders Camera Settings")
@export var fov_base: float = 75.0
@export var fov_max_stretch: float = 115.0 
@export var cam_stiffness: float = 10.0
@export var tilt_intensity: float = 1.5

# =================================================
# CONFIG — PHYSICS & LANDING
@export_group("Landing & Gravity")
@export var fall_gravity_multiplier: float = 1.6 
@export var trick_input_delay: float = 0.2 

var _is_exiting: bool = false
var _current_trick_delay: float = 0.0 

func enter_state() -> void:
	_is_exiting = false
	player.is_trick_launch = true
	
	_current_trick_delay = trick_input_delay
	
	var jump_quality = 2.5 if player.target_visual_scale.y > 1.7 else 1.2
	
	if trick_manager:
		trick_manager.start_tricks(jump_quality)
		if not trick_manager.rank_up_achieved.is_connected(_on_rank_up):
			trick_manager.rank_up_achieved.connect(_on_rank_up)
	
	_play_launch_vfx(jump_quality)

func exit_state() -> void:
	player.is_trick_launch = false
	Engine.time_scale = 1.0 
	
	if trick_manager:
		var rank = trick_manager.finish_tricks()
		_handle_landing_juice(rank)
		if trick_manager.rank_up_achieved.is_connected(_on_rank_up):
			trick_manager.rank_up_achieved.disconnect(_on_rank_up)

func physics_process(delta: float) -> void:
	# 1. GROUND DETECTION
	if player.is_on_floor() and not _is_exiting:
		_is_exiting = true
		loco_state_machine.change_state("Grounded")
		return

	# 2. INPUT & MOVIMENT
	player._read_input(delta)
	var gravity_mod = 1.0 if player.velocity.y > 0 else fall_gravity_multiplier
	player.velocity.y -= player.trick_custom_gravity * gravity_mod * delta
	player.move_and_slide()

	# 3. TRICK ENGINE WITH DELAY
	if trick_manager and not _is_exiting:
		if _current_trick_delay > 0:
			_current_trick_delay -= delta
		else:
			trick_manager.process_trick_input(delta)
	
	# 4. CAMERA
	_update_riders_flow(delta)

# =================================================
# TRICK SYSTEM METHODS
# =================================================

func _update_riders_flow(delta: float) -> void:
	if not player.Cam or _is_exiting: return

	if abs(player.velocity.y) < 4.0:
		Engine.time_scale = lerp(Engine.time_scale, 0.85, 4.0 * delta)
	else:
		Engine.time_scale = lerp(Engine.time_scale, 1.0, 2.0 * delta)

	# CAMERA FOV & TILT
	var speed_percent = player.velocity.length() / 50.0
	var target_fov = fov_base + (speed_percent * 15.0)
	
	if trick_manager and _current_trick_delay <= 0:
		var spin_energy = trick_manager.spin_velocity.length() * 0.04
		target_fov += (spin_energy * 10.0)
		
		var target_z = -trick_manager.spin_velocity.y * tilt_intensity
		player.Cam.rotation_degrees.z = lerp(player.Cam.rotation_degrees.z, target_z, 5.0 * delta)

	player.Cam.fov = lerp(player.Cam.fov, target_fov, cam_stiffness * delta)

func _play_launch_vfx(power: float) -> void:
	player.current_shake = 0.8 * power
	
	if player.Cam:
		player.Cam.fov = fov_max_stretch
		player.Cam.rotation_degrees.z = randf_range(-5, 5)

func _handle_landing_juice(rank: String) -> void:
	if rank == "FAIL":
		player.current_shake = 1.5
		return

	var intensity = {"Z":1.0, "B":1.4, "A":1.8, "S":2.5, "X":3.5}.get(rank, 1.0)
	
	Engine.time_scale = 0.05
	player.current_shake = 0.4 * intensity
	
	if player.Cam:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(Engine, "time_scale", 1.0, 0.3).set_trans(Tween.TRANS_QUINT)
		tw.tween_property(player.Cam, "fov", fov_base, 0.4).set_trans(Tween.TRANS_BACK)

func _on_rank_up(new_rank: String) -> void:
	player.current_shake = 0.3
