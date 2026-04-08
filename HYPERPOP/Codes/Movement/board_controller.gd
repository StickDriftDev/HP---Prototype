extends CharacterBody3D
class_name BoardController

signal boost_modified(segmentos_atuais: float, segmentos_maximos: int)
signal jumped()
signal landed(impact_strength: float)
@onready var trick_manager: TrickManager = $TrickManager
# =================================================
# LOCOMOTION STATE
@export var loco_state_machine: Node

# =================================================
# CONFIG — MOTION (SPEED & FLOW)
@export_category("Motion")
@export var max_speed: float = 200.0
@export var absolute_speed_cap: float = 300.0
@export var acceleration: float = 12.0
@export var braking: float = 50.0
@export var friction: float = 15.0
@export var air_drag: float = 5.0
@export var rotation_speed: float = 1.2
@export var rotation_smoothing: float = 12.0

# =================================================
# CONFIG — JUMP & PHYSICS JUICE
@export_category("Jump & Physics")
@export var min_jump_force: float = 12.0
@export var max_jump_force: float = 35.0
@export var jump_charge_drag: float = 0.2
@export var max_charge_time: float = 0.8
@export var gravity_mul: float = 4.0
@export var apex_float_multiplier: float = 0.6
@export var stick_force: float = 120.0
@export var slope_alignment_speed: float = 18.0
@export var snap_length: float = 0.8
@export var slope_launch_boost: float = 15.0
@export_flags_3d_physics var ignore_align_mask: int = 0
@export var slope_accel_strength: float = 25.0
@export var air_alignment_speed: float = 8.0

# =================================================
# CONFIG — WALL RUN & DRIFT
@export_group("Wall Running")
@export var enable_wall_running: bool = true
@export_flags_3d_physics var wall_run_layer: int = 5
@export var wall_run_min_speed: float = 40.0
@export var wall_stick_force: float = 320.0
@export var wall_gravity_mul: float = 0.2
@export var wall_run_cam_roll: float = 20.0
@export var wall_run_entry_shake: float = 0.25

@export_group("Drift Settings")
@export var drift_min_speed: float = 15.0
@export var drift_max_charge_time: float = 1.0
@export var drift_deceleration_rate: float = 8.0
@export var drift_dash_force: float = 60.0
@export var drift_dash_duration: float = 0.2
@export var drift_turn_multiplier: float = 2.5
var drift_charge: float = 0.0

# =================================================
# CONFIG — AIR CONTROLS
@export_category("Air Controls")
@export var air_rotation_multiplier: float = 2.5
@export var air_pitch_max_angle: float = 60.0
@export var air_pitch_responsiveness: float = 12.0
@export var air_pitch_return_speed: float = 5.0
@export var air_lateral_force: float = 20.0
@export var dive_speed_gain: float = 40.0
@export var pull_up_speed_loss: float = 25.0
@export var air_brake_force: float = 15.0

# =================================================
# CONFIG — VISUAL JUICE & CAMERA
@export_category("Visuals & Camera (JUICE)")
@export var board_target: Node3D
@export var Rider_Model: Node3D
@export var Cam: Camera3D
@export var PlayerSFX: Node

@export_group("Board Lean & Squash")
@export var max_lean_angle: float = 0.7
@export var drift_lean_multiplier: float = 1.8
@export var lean_responsiveness: float = 10.0
@export var crouch_tilt_amount: float = -0.15
@export var lean_speed_threshold: float = 50.0

@export_group("Camera Dynamics")
@export var dynamic_fov_influence: float = 0.25
@export var dash_fov_boost: float = 20.0
@export var fov_lerp_speed: float = 6.0
@export var fov_return_speed: float = 2.0
@export var camera_roll_intensity: float = 8.0

# =================================================
# CONFIG — BOOST SYSTEM
@export_category("Boost System")
@export var max_boost_segments: int = 4
@export var boost_speed_target: float = 340.0
@export var passive_boost_regen: float = 0.05
@export var drift_boost_regen: float = 0.8
@export var boost_accel: float = 100.0
@export var boost_duration_per_segment: float = 1.2
@export var boost_fov_kick: float = 20.0
var boost_timer: float = 0.0
var boost_regen_pendente: float = 0.0
@export var regen_speed: float = 1.5

# =================================================
#code by greeny - https://www.youtube.com/channel/UC0rQ3oO5pNaugwhNAD79qsw
#--RAIL GRINDING VARIABLES--
@onready var countdown_for_next_grind = 1.0
@onready var countdown_for_next_grind_time_left = 1.0
@onready var grind_timer_complete = true
@onready var start_grind_timer = false
@export var grindrays: ShapeCast3D
@export var lerp_speed = 40
@export var detach_jump_force: float = 12.0

# =================================================
# DEBUG
@export_category("Debug")
@export var debug_enabled: bool = true

# =================================================
# STATE VARIABLES
var current_speed: float = 0.0
var input_dir: Vector2 = Vector2.ZERO
var smoothed_input_x: float = 0.0
var was_on_floor: bool = true
var last_surface_normal: Vector3 = Vector3.UP
var smoothed_normal: Vector3 = Vector3.UP
var air_time: float = 0.0
var last_ground_position: Vector3 = Vector3.ZERO

var is_charging_jump: bool = false
var can_jump: bool = false
var current_jump_charge: float = 0.0
var drift_input: bool = false
var grounded_time: float = 0.0

var is_trick_launch: bool = false
var trick_custom_gravity: float = 0.0

# RAMP VARIABLES
var _can_ramp_jump: bool = false
var _ramp_launch_vel: Vector3 = Vector3.ZERO
var _ramp_dir: Vector3 = Vector3.ZERO
var custom_ramp_gravity: float = 10
var trick_rotation_multiplier: float = 1.0

var is_drifting: bool = false
var is_wall_running: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var wall_side: float = 0.0
var current_tilt: float = 0.0
var current_air_pitch: float = 0.0
var dash_timer: float = 0.0
var dash_velocity: float = 0.0
var current_shake: float = 0.0
var base_fov: float = 75.0
var target_visual_scale: Vector3 = Vector3.ONE
var current_visual_scale: Vector3 = Vector3.ONE
var current_cam_roll: float = 0.0
var is_boosting: bool = false

var current_boost_segments: float = 3.0:
	set(value):
		current_boost_segments = clamp(value, 0.0, float(max_boost_segments))
		boost_modified.emit(current_boost_segments, max_boost_segments)

var inp_throttle: float = 0.0
var inp_brake: float = 0.0
var inp_steer: float = 0.0
var inp_drift: bool = false
var inp_jump_held: bool = false
var inp_pitch: float = 0.0
var inp_boost: bool = false

func _process(delta: float) -> void:
	if boost_regen_pendente > 0:
		var recarga = regen_speed * delta
		recarga = min(recarga, boost_regen_pendente)
		var anterior = current_boost_segments
		current_boost_segments = min(current_boost_segments + recarga, max_boost_segments)
		boost_regen_pendente -= recarga
		if anterior != current_boost_segments:
			boost_modified.emit(current_boost_segments, max_boost_segments)
			
func adicionar_regeneracao_boost(quantidade: float):
	boost_regen_pendente += quantidade

# =================================================
# LIFECYCLE
func _ready() -> void:
	if Cam: base_fov = Cam.fov
	if not loco_state_machine:
		push_warning("[BoardController] Loco State Machine is missing!")
	floor_max_angle = deg_to_rad(60)
	floor_snap_length = snap_length
	floor_stop_on_slope = false
	floor_block_on_wall = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_debug_ui()

func _physics_process(delta: float) -> void:
	_read_input(delta)
	
	if _can_ramp_jump:
		if Input.is_action_just_released("jump"):
			_execute_special_ramp_launch()
	
	if _can_ramp_jump and is_charging_jump:
		if Input.is_action_just_released("jump"):
			_execute_special_ramp_launch()
	
	if is_on_floor():
		drift_input = inp_drift and abs(inp_steer) > 0.1
		can_jump = true
		grounded_time += delta
	else:
		can_jump = false
		drift_input = false
		grounded_time = 0.0
	
	if PlayerSFX:
		if PlayerSFX.has_method("_update_jump_charge"):
			PlayerSFX._update_jump_charge(delta, is_charging_jump, is_wall_running)
		if PlayerSFX.has_method("_update_engine_audio"):
			PlayerSFX._update_engine_audio(current_speed, max_speed)
	
	_update_air_pitch(delta)
	_update_speed(delta)
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	_apply_horizontal_movement()

	if is_wall_running:
		_apply_wall_run_projection(delta)
	_handle_surface_states(delta)
		
	if not is_charging_jump and (is_on_floor() or is_wall_running) and not is_trick_launch:
		apply_floor_snap()
		
	move_and_slide()
	_detect_wall_running()
	_apply_ramp_boost_on_leave()
	
	if velocity.length() > absolute_speed_cap:
		velocity = velocity.limit_length(absolute_speed_cap)
	
	_handle_landing(delta)
	_update_visuals_and_juice(delta)
	_update_debug_ui()
	
	was_on_floor = is_on_floor()
	if was_on_floor:
		last_ground_position = global_position
	
	grind_timer(delta)

# =================================================
# TRICK RAMP RECEPTION LOGIC

func prepare_ramp_jump(launch_vel: Vector3, custom_grav: float, ramp_dir: Vector3, is_perfect: bool, trick_speed: float) -> void:
	velocity = launch_vel
	trick_manager.start_tricks(1.0, trick_speed) 
	var look_target = global_position + ramp_dir
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)
	
	velocity = launch_vel
	trick_custom_gravity = custom_grav
	current_speed = Vector2(velocity.x, velocity.z).length()
	
	is_trick_launch = true
	if loco_state_machine and loco_state_machine.has_method("change_state"):
		loco_state_machine.change_state("TrickAirborne")
	
	if trick_manager:
		trick_manager.start_tricks(1.0, trick_speed)
	
	if is_perfect:
		target_visual_scale = Vector3(0.4, 1.8, 0.4) 
		current_shake = 0.3
	else:
		target_visual_scale = Vector3(0.5, 1.6, 0.5)

	if PlayerSFX and PlayerSFX.has_method("play_jump_launch"): 
		PlayerSFX.play_jump_launch()
	
	await get_tree().create_timer(0.25).timeout
	_can_ramp_jump = false
	
func _execute_special_ramp_launch() -> void:
	_can_ramp_jump = false 
	
	velocity.y *= 1.35 
	velocity.x *= 1.25
	velocity.z *= 1.25 
	
	if inp_throttle > 0.1:
		velocity *= 1.15 
		
	current_speed = Vector2(velocity.x, velocity.z).length()
	
	is_charging_jump = false
	current_jump_charge = 0.0
	
	_dbg_log("RAMP: MEGA LAUNCH ACTIVATED!")
	
	target_visual_scale = Vector3(0.4, 1.8, 0.4) 
	if PlayerSFX and PlayerSFX.has_method("play_jump_launch"): 
		PlayerSFX.play_jump_launch()

func apply_ramp_launch(launch_velocity: Vector3, custom_gravity: float, ramp_dir: Vector3) -> void:
	var look_target = global_position + ramp_dir
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)
	
	velocity = launch_velocity
	trick_custom_gravity = custom_gravity
	current_speed = Vector2(velocity.x, velocity.z).length()
	
	is_trick_launch = true
	if loco_state_machine and loco_state_machine.has_method("change_state"):
		loco_state_machine.change_state("TrickAirborne")
	
	target_visual_scale = Vector3(0.5, 1.6, 0.5)
	if PlayerSFX and PlayerSFX.has_method("play_jump_launch"): 
		PlayerSFX.play_jump_launch()

# =================================================
# TRICK SYSTEM 
func pulse_trick_juice() -> void:
	current_visual_scale = Vector3(0.6, 1.5, 0.6)
	target_visual_scale = Vector3(1.1, 0.9, 1.1)
	current_shake = max(current_shake, 0.15)
	
	if Cam:
		Cam.fov = min(Cam.fov + 12.0, base_fov + 45.0)

# =================================================
# CORE LOGIC

func _apply_wall_run_projection(delta: float) -> void:
	if not is_wall_running: return
	velocity = velocity.slide(wall_normal).normalized() * current_speed
	velocity -= wall_normal * wall_stick_force * delta

func _read_input(delta: float) -> void:
	inp_throttle = Input.get_action_strength("throttle")
	inp_brake = Input.get_action_strength("brake")
	inp_steer = Input.get_action_strength("left") - Input.get_action_strength("right")
	inp_drift = Input.is_action_pressed("drift")
	inp_jump_held = Input.is_action_pressed("jump")
	inp_boost = Input.is_action_just_pressed("boost")
	inp_pitch = inp_throttle - inp_brake
	
	if is_trick_launch:
		smoothed_input_x = lerp(smoothed_input_x, 0.0, 15.0 * delta)
	else:
		smoothed_input_x = lerp(smoothed_input_x, inp_steer, rotation_smoothing * delta)
	
	input_dir.x = inp_steer

func _update_speed(delta: float) -> void:
	var target_accel = acceleration
	if dash_timer > 0.0:
		dash_timer -= delta
		current_speed = dash_velocity
	elif is_boosting:
		current_speed = move_toward(current_speed, boost_speed_target, acceleration * boost_accel * delta)
	elif is_charging_jump and is_on_floor():
		current_speed = lerp(current_speed, current_speed * 0.8, jump_charge_drag * delta)
	elif is_on_floor():
		if inp_throttle > 0:
			current_speed = move_toward(current_speed, max_speed, target_accel * delta)
		elif inp_brake > 0:
			current_speed = move_toward(current_speed, 0.0, braking * delta)
		else:
			current_speed = move_toward(current_speed, 0.0, friction * delta)
	elif not is_trick_launch:
		current_speed = move_toward(current_speed, 0.0, air_drag * delta)
	
	var current_cap = boost_speed_target if is_boosting else max_speed
	if dash_timer <= 0.0:
		current_speed = clamp(current_speed, 0.0, current_cap)

func _apply_horizontal_movement() -> void:
	if is_wall_running: return
	var target_vel = -global_transform.basis.z * current_speed
	if is_trick_launch: return
	
	if not is_on_floor() and not is_trick_launch:
		target_vel += global_transform.basis.x * smoothed_input_x * air_lateral_force
	velocity.x = target_vel.x
	velocity.z = target_vel.z
func _apply_rotation(delta: float) -> void:
	if is_trick_launch: return
	var turn_scale = 1.0
	if is_charging_jump: turn_scale = 0.4
	elif is_drifting: turn_scale *= drift_turn_multiplier
	elif not is_on_floor(): turn_scale = air_rotation_multiplier
	if is_boosting: turn_scale *= 0.7
	rotate_object_local(Vector3.UP, smoothed_input_x * rotation_speed * turn_scale * delta)

func _apply_slope_momentum(delta: float) -> void:
	if not is_on_floor(): return
	var n = get_floor_normal()
	var slope = 1.0 - n.dot(Vector3.UP)
	if slope >= 0.02:
		var downhill_force = Vector3.DOWN.slide(n).normalized().dot(-global_transform.basis.z)
		current_speed += downhill_force * slope_accel_strength * slope * delta

func _apply_surface_gravity(delta: float) -> void:
	var g: float = trick_custom_gravity if is_trick_launch else ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if is_wall_running and not is_trick_launch: g *= wall_gravity_mul
		
	var sn = wall_normal if is_wall_running else (last_surface_normal if is_on_floor() else Vector3.UP)
	velocity -= sn * g * delta

func _handle_surface_states(delta: float) -> void:
	var current_align_speed := slope_alignment_speed
	if is_wall_running:
		smoothed_normal = smoothed_normal.lerp(wall_normal, 20.0 * delta)
		up_direction = wall_normal
		floor_snap_length = 0.0
		current_align_speed = 25.0
	elif is_on_floor():
		var raw_normal = get_floor_normal()
		smoothed_normal = smoothed_normal.lerp(raw_normal, slope_alignment_speed * delta)
		last_surface_normal = raw_normal
		air_time = 0.0
		up_direction = Vector3.UP
		velocity -= last_surface_normal * stick_force * delta 
	else:
		smoothed_normal = smoothed_normal.lerp(Vector3.UP, air_alignment_speed * delta)
		up_direction = Vector3.UP
		air_time += delta
		current_align_speed = air_alignment_speed
		if air_time >= 20.0 and last_ground_position != Vector3.ZERO:
			global_position = last_ground_position
			velocity = Vector3.ZERO
			current_speed = 0.0
			is_trick_launch = false
	_align_to_surface(delta, smoothed_normal, current_align_speed)

func _align_to_surface(delta: float, target_normal: Vector3, align_speed: float) -> void:
	var current_basis = global_transform.basis
	var current_up = current_basis.y
	if current_up.distance_squared_to(target_normal) > 0.0001:
		var rotation_axis = current_up.cross(target_normal).normalized()
		if rotation_axis.length_squared() > 0.001:
			var angle = current_up.angle_to(target_normal)
			var target_basis = (Basis(rotation_axis, angle) * current_basis).orthonormalized()
			global_transform.basis = current_basis.slerp(target_basis, align_speed * delta).orthonormalized()

func _detect_wall_running() -> void:
	if not enable_wall_running or is_on_floor() or current_speed < wall_run_min_speed:
		if is_wall_running: _on_wall_run_exit()
		return
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var n: Vector3 = collision.get_normal()
		if abs(n.dot(Vector3.UP)) < 0.3:
			var collider = collision.get_collider()
			if collider is CollisionObject3D and (collider.collision_layer & wall_run_layer) != 0:
				wall_normal = n
				wall_side = sign(n.dot(global_transform.basis.x))
				if not is_wall_running: _on_wall_run_enter()
				is_wall_running = true
				return
	if is_wall_running: _on_wall_run_exit()

func _on_wall_run_enter() -> void:
	current_shake = max(current_shake, wall_run_entry_shake)
	target_visual_scale = Vector3(1.2, 0.8, 1.2)

func _on_wall_run_exit() -> void:
	is_wall_running = false
	last_surface_normal = Vector3.UP
	up_direction = Vector3.UP
	wall_side = 0.0
	wall_normal = Vector3.ZERO

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor and not is_on_floor() and not is_trick_launch:
		var angle_factor: float = 1.0 - last_surface_normal.dot(Vector3.UP)
		if angle_factor > 0.15 and current_speed > (max_speed * 0.4):
			velocity += velocity.normalized() * slope_launch_boost * angle_factor * 2.0
			velocity.y += slope_launch_boost * angle_factor * 15.0

func _execute_jump() -> bool:
	var charge_val: float = PlayerSFX.current_jump_charge if PlayerSFX and "current_jump_charge" in PlayerSFX else 1.0
	var force = lerp(min_jump_force, max_jump_force, charge_val)
	floor_snap_length = 0.0
	if is_wall_running and wall_normal != Vector3.ZERO:
		velocity += wall_normal * force * 1.5
		velocity.y += force * 0.6
		_on_wall_run_exit()
	else:
		velocity += Vector3.UP * force
		velocity -= global_transform.basis.z * (force * 0.2)
	target_visual_scale = Vector3(0.7, 1.4, 0.7)
	jumped.emit()
	if PlayerSFX:
		if PlayerSFX.has_method("play_jump_launch"): PlayerSFX.play_jump_launch()
		PlayerSFX.current_jump_charge = 0.0
	return false

func _handle_landing(_delta: float) -> void:
	if is_wall_running or not is_on_floor() or get_floor_normal().dot(Vector3.UP) < 0.5: return
	if not was_on_floor:
		is_trick_launch = false
		floor_snap_length = snap_length
		if air_time > 0.15:
			var impact = clamp(air_time * 2.0, 0.0, 1.0)
			current_shake = max(current_shake, impact * 0.3)
			target_visual_scale = Vector3(1.3, 0.6, 1.3)
			landed.emit(impact)
			if PlayerSFX and PlayerSFX.has_method("play_land"): PlayerSFX.play_land()

func ChangeVelocity(vec: Vector3, force: float) -> void:
	velocity += vec * force

func _update_air_pitch(delta: float) -> void:
	var target = inp_pitch * deg_to_rad(air_pitch_max_angle) if not is_on_floor() else 0.0
	current_air_pitch = lerp(current_air_pitch, target, (air_pitch_responsiveness if not is_on_floor() else air_pitch_return_speed) * delta)

# =================================================
# Rail Grinding Timer
func grind_timer(delta):
	if start_grind_timer:
		if countdown_for_next_grind_time_left > 0:
			countdown_for_next_grind_time_left -= delta
			if countdown_for_next_grind_time_left <= 0:
				if Input.is_action_pressed("forward"):
					Input.action_release("forward")
				countdown_for_next_grind_time_left = countdown_for_next_grind
				grind_timer_complete = true
				start_grind_timer = false

func _update_visuals_and_juice(delta: float) -> void:
	current_visual_scale = current_visual_scale.lerp(target_visual_scale, 15.0 * delta)
	target_visual_scale = target_visual_scale.lerp(Vector3.ONE, 8.0 * delta)
	if Rider_Model: Rider_Model.scale = current_visual_scale
	if board_target:
		if not is_trick_launch:
			var speed_lean_factor = clamp(current_speed / lean_speed_threshold, 0.0, 1.0)
			var target_tilt = -smoothed_input_x * (max_lean_angle * speed_lean_factor)
			if is_drifting: target_tilt *= drift_lean_multiplier
			current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)
			var crouch = crouch_tilt_amount if is_charging_jump else 0.0
			var final_basis = Basis.IDENTITY.rotated(Vector3.FORWARD, current_tilt).rotated(Vector3.RIGHT, crouch + current_air_pitch)
			board_target.transform.basis = board_target.transform.basis.slerp(final_basis, 18.0 * delta)
			
	if Cam:
		var dashing = dash_timer > 0.0 or is_boosting
		var target_fov = base_fov + ((current_speed / max_speed) * base_fov * dynamic_fov_influence)
		if dashing: target_fov += dash_fov_boost
		if is_wall_running: target_fov += 10.0
		Cam.fov = lerp(Cam.fov, target_fov, (fov_lerp_speed if dashing else fov_return_speed) * delta)
		var target_roll = -smoothed_input_x * camera_roll_intensity
		if is_drifting: target_roll *= 1.5
		if is_wall_running: target_roll = wall_side * wall_run_cam_roll
		current_cam_roll = lerp(current_cam_roll, target_roll, 8.0 * delta)
		Cam.rotation_degrees.z = current_cam_roll
		if dashing and is_on_floor(): current_shake = max(current_shake, 0.05)
		if current_shake > 0:
			Cam.h_offset = randf_range(-current_shake, current_shake)
			Cam.v_offset = randf_range(-current_shake, current_shake)
			current_shake = move_toward(current_shake, 0.0, delta * 2.0)
		else:
			Cam.h_offset = 0; Cam.v_offset = 0

func _setup_debug_ui() -> void:
	if not debug_enabled: return
	var canvas := CanvasLayer.new(); canvas.name = "DebugCanvas"; add_child(canvas)
	var label := RichTextLabel.new(); label.name = "DebugLabel"; label.bbcode_enabled = true
	label.set_anchors_preset(Control.PRESET_TOP_LEFT); label.position = Vector2(10, 10); label.size = Vector2(450, 350) 
	label.add_theme_color_override("default_color", Color(0.9, 1.0, 0.9)); canvas.add_child(label)

func _dbg_log(message: String) -> void:
	if debug_enabled: print_debug("[PlayerLog]: ", message)

func _update_debug_ui() -> void:
	if not debug_enabled: return
	var label = get_node_or_null("DebugCanvas/DebugLabel")
	if label:
		var full_segments = floor(current_boost_segments)
		var state = "WallRun" if is_wall_running else "Air" if not is_on_floor() else "Ground"
		label.text = "[b]SPEED:[/b] %.1f\n" % current_speed
		label.text += "[b]BOOST SEGMENTS:[/b] %d\n" % full_segments
		label.text += "[b]STATE:[/b] %s\n" % state
		var tm = get_node_or_null("TrickManager") 
		if tm:
			if tm.is_active:
				label.text += "\n\n[color=YELLOW][b]>> PERFORMING TRICKS <<[/b][/color]"
				label.text += "\n[b]PONITS:[/b] [color=WHITE]%d[/color]" % tm.current_points
				label.text += "\n[b]TRICKS:[/b] %.2f" % tm.total_spins_accumulated
			elif is_on_floor() and tm.highest_rank_achieved != "C":
				var color = "CYAN" if tm.highest_rank_achieved != "FAIL" else "RED"
				label.text += "\n\n[color=ORANGE][b]>> LAST TRICK RESULT <<[/b][/color]"
				label.text += "\n[b]FINAL RANK :[/b] [color=%s][i]%s[/i][/color]" % [color, tm.highest_rank_achieved]
				label.text += "\n[b]TOTAL POINTS :[/b] %d" % tm.current_points
