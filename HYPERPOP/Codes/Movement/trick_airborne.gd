extends BoardState
class_name TrickAirborne

@onready var player: BoardController = get_parent().get_parent()

@onready var trick_manager: TrickManager = player.get_node_or_null("TrickManager")

@export_group("Sonic Riders FOV")
@export var fov_standard: float = 75.0
@export var fov_launch_pop: float = 115.0
@export var fov_max_wind: float = 100.0
@export var camera_recover_speed: float = 3.5

@export_group("Cinematics & Juice")
@export var look_up_angle: float = -25.0
@export var look_down_angle: float = 20.0
@export var launch_hitstop: float = 0.05
@export var camera_tilt_intensity: float = 5.0
@export var apex_slow_mo: float = 0.9

var current_camera_pitch: float = 0.0
var current_dutch_roll: float = 0.0

func enter_state() -> void:

	player.is_trick_launch = true
	current_camera_pitch = look_up_angle
	
	var is_mega = player.target_visual_scale.y > 1.7 
	
	if trick_manager:
		trick_manager.start_tricks(is_mega)
	
	if launch_hitstop > 0:
		Engine.time_scale = 0.1
		await get_tree().create_timer(launch_hitstop * 0.1).timeout
		Engine.time_scale = 1.0
	if player.Cam:
		player.current_shake = 0.6 
		player.Cam.rotation_degrees.x = look_up_angle
		current_dutch_roll = randf_range(-camera_tilt_intensity, camera_tilt_intensity)
		
		player.Cam.fov = fov_launch_pop
		create_tween().tween_property(player.Cam, "fov", fov_standard + 10.0, 0.6)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func exit_state() -> void:
	player.is_trick_launch = false
	Engine.time_scale = 1.0
	
	if trick_manager:
		var rank = trick_manager.finish_tricks()
		_spawn_rank_feedback(rank) 
	
	if player.Cam:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(player.Cam, "rotation_degrees:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player.Cam, "rotation_degrees:z", 0.0, 0.5)
		tw.tween_property(player.Cam, "fov", fov_standard, 0.5)

func physics_process(delta: float) -> void:
	
	player._read_input(delta)
	
	player.velocity.y -= player.trick_custom_gravity * delta
	player.move_and_slide()
	
	if trick_manager:
		trick_manager.process_trick_input(delta)
	
	if abs(player.velocity.y) < 2.0:
		Engine.time_scale = lerp(Engine.time_scale, apex_slow_mo, 5.0 * delta)
	else:
		Engine.time_scale = lerp(Engine.time_scale, 1.0, 2.0 * delta)
	
	_handle_dynamic_air_juice(delta)
	
	if player.is_on_floor():
		loco_state_machine.change_state("Grounded")

func _handle_dynamic_air_juice(delta: float) -> void:
	if not player.Cam: return
	
	var target_pitch = look_up_angle if player.velocity.y > -5.0 else look_down_angle
	current_camera_pitch = lerp(current_camera_pitch, target_pitch, 3.0 * delta)
	player.Cam.rotation_degrees.x = current_camera_pitch
	
	var speed_percent = clamp(player.current_speed / player.max_speed, 0.0, 1.5)
	var target_fov = fov_standard + (speed_percent * (fov_max_wind - fov_standard))
	player.Cam.fov = lerp(player.Cam.fov, target_fov, camera_recover_speed * delta)
	
	player.Cam.rotation_degrees.z = lerp(player.Cam.rotation_degrees.z, current_dutch_roll, 4.0 * delta)

func _spawn_rank_feedback(rank: String) -> void:
	if rank != "NONE":
		print("POUSOU COM RANK: ", rank)
