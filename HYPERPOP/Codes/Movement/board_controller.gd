extends CharacterBody3D
class_name BoardController

signal boost_modified(segmentos_atuais: float, segmentos_maximos: int)
signal jumped()
signal landed(impact_strength: float)

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
@export var jump_charge_drag: float = 0.8
var current_jump_charge: float = 0.0
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
# CONFIG — EXTREME SPORTS (WALL RUN & DRIFT) — AJUSTADO PARA GRUDAR DE VERDADE
@export_category("Tricks & Tech")
@export_group("Wall Running — Bomb Rush Cyberfunk Style")
@export var enable_wall_running: bool = true
@export_flags_3d_physics var wall_run_layer: int = 4          # ← Layer das paredes (configure no collider das paredes!)
@export var wall_run_min_speed: float = 40.0
@export var wall_stick_force: float = 320.0                   # ← AUMENTADO (era 200) → agora gruda forte
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
var grounded_time: float = 0.0
var last_ground_position: Vector3 = Vector3.ZERO
var is_charging_jump: bool = false
var is_drifting: bool = false
var is_wall_running: bool = false
var was_wall_running: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var wall_side: float = 0.0
var current_tilt: float = 0.0
var current_air_pitch: float = 0.0
var dash_timer: float = 0.0
var dash_velocity: float = 0.0
var current_shake: float = 0.0
var can_jump: bool = false
var drift_input: bool = false
var base_fov: float = 75.0
var target_visual_scale: Vector3 = Vector3.ONE
var current_visual_scale: Vector3 = Vector3.ONE
var current_cam_roll: float = 0.0
var current_boost_segments: float = 3.0:
	set(value):
		current_boost_segments = clamp(value, 0.0, float(max_boost_segments))
		boost_modified.emit(current_boost_segments, max_boost_segments)
var is_boosting: bool = false
var inp_throttle: float = 0.0
var inp_brake: float = 0.0
var inp_steer: float = 0.0
var inp_drift: bool = false
var inp_jump_held: bool = false
var inp_pitch: float = 0.0
var inp_boost: bool = false

# =================================================
# LIFECYCLE
func _ready() -> void:
	if Cam:
		base_fov = Cam.fov
	if loco_state_machine == null:
		push_warning("[BoardController] Loco State Machine está faltando!")
	
	floor_max_angle = deg_to_rad(60)
	floor_snap_length = snap_length
	floor_stop_on_slope = false
	floor_block_on_wall = false
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_debug_ui()

func _physics_process(delta: float) -> void:
	_read_input(delta)
	
	# SFX Updates
	if PlayerSFX:
		if PlayerSFX.has_method("_update_jump_charge"):
			PlayerSFX._update_jump_charge(delta, is_charging_jump, is_wall_running)
		if PlayerSFX.has_method("_update_engine_audio"):
			PlayerSFX._update_engine_audio(current_speed, max_speed)
	
	_update_air_pitch(delta)
	_update_speed(delta)
	
	if is_on_floor():
		drift_input = inp_drift and abs(inp_steer) > 0.1
		can_jump = true
	
	_apply_slope_momentum(delta)
	_apply_surface_gravity(delta)
	_apply_rotation(delta)
	_apply_horizontal_movement(delta)
	
	# === NOVO: PROJEÇÃO DE WALL RUN ANTES DO MOVIMENTO (isso resolve o "não gruda" e o "atravessa")
	if is_wall_running:
		_apply_wall_run_projection(delta)
	
	_handle_surface_states(delta)
	
	if not is_charging_jump and (is_on_floor() or is_wall_running):
		apply_floor_snap()
	
	player_move_and_slide()          # movimento real acontece aqui
	
	# === DETECÇÃO AGORA DEPOIS DO move_and_slide (colisões frescas desta frame)
	_detect_wall_running()
	
	_apply_ramp_boost_on_leave()
	
	if velocity.length() > absolute_speed_cap:
		velocity = velocity.normalized() * absolute_speed_cap
	
	_handle_landing(delta)
	_update_visuals_and_juice(delta)
	_update_debug_ui()
	
	was_on_floor = is_on_floor()
	was_wall_running = is_wall_running
	if is_on_floor():
		last_ground_position = global_position

# =================================================
# WALL RUN PROJECTION (novo - aplicado ANTES do move_and_slide)
func _apply_wall_run_projection(delta: float) -> void:
	if not is_wall_running:
		return
	
	# Lógica idêntica ao Bomb Rush Cyberfunk:
	# 1. Mantém velocidade constante no plano da parede
	# 2. Aplica força forte de "grudar" (stick) para dentro da parede
	velocity = velocity.slide(wall_normal).normalized() * current_speed
	velocity -= wall_normal * wall_stick_force * delta

# =================================================
# CORE LOGIC
func _read_input(delta: float) -> void:
	inp_throttle = Input.get_action_strength("throttle")
	inp_brake = Input.get_action_strength("brake")
	inp_steer = Input.get_action_strength("left") - Input.get_action_strength("right")
	inp_drift = Input.is_action_pressed("drift")
	inp_jump_held = Input.is_action_pressed("jump")
	inp_boost = Input.is_action_just_pressed("boost")
	inp_pitch = inp_throttle - inp_brake
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
	else:
		current_speed = move_toward(current_speed, 0.0, air_drag * delta)
	
	var current_cap = boost_speed_target if is_boosting else max_speed
	if dash_timer <= 0.0:
		current_speed = clamp(current_speed, 0.0, current_cap)

func _apply_horizontal_movement(delta: float) -> void:
	if is_wall_running:
		return
	
	var fwd = -global_transform.basis.z
	var rgt = global_transform.basis.x
	var target_vel = fwd * current_speed
	
	if not is_on_floor():
		target_vel += rgt * smoothed_input_x * air_lateral_force
	
	velocity.x = target_vel.x
	velocity.z = target_vel.z

# =================================================
# PHYSICS & JUICE DYNAMICS
func _apply_rotation(delta: float) -> void:
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
	if slope < 0.02: return
	var downhill_force = Vector3.DOWN.slide(n).normalized().dot(-global_transform.basis.z)
	current_speed += downhill_force * slope_accel_strength * slope * delta

func _apply_surface_gravity(delta: float) -> void:
	var g = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_mul
	if is_wall_running:
		g *= wall_gravity_mul
	var sn = wall_normal if is_wall_running else (last_surface_normal if is_on_floor() else Vector3.UP)
	velocity += -sn * g * delta

func _apply_floor_stick(delta: float) -> void:
	if is_wall_running:
		return  
	var sn = last_surface_normal
	velocity += -sn * stick_force * delta

# =================================================
# SURFACE ALIGNMENTS & STATES
func _handle_surface_states(delta: float) -> void:
	var current_align_speed: float = slope_alignment_speed
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
		grounded_time += delta
		up_direction = Vector3.UP
		_apply_floor_stick(delta)
		current_align_speed = slope_alignment_speed
	else:
		smoothed_normal = smoothed_normal.lerp(Vector3.UP, air_alignment_speed * delta)
		up_direction = Vector3.UP
		grounded_time = 0.0
		air_time += delta
		if air_time >= 20.0 and last_ground_position != Vector3.ZERO:
			_teleport_to_last_ground()
		current_align_speed = air_alignment_speed
	
	_align_to_surface(delta, smoothed_normal, current_align_speed)

func _align_to_surface(delta: float, target_normal: Vector3, align_speed: float) -> void:
	var current_basis = global_transform.basis
	var current_up = current_basis.y
	if current_up.distance_squared_to(target_normal) > 0.0001:
		var rotation_axis = current_up.cross(target_normal).normalized()
		if rotation_axis.length_squared() > 0.001:
			var angle = current_up.angle_to(target_normal)
			var alignment_rotation = Basis(rotation_axis, angle)
			var target_basis = (alignment_rotation * current_basis).orthonormalized()
			global_transform.basis = current_basis.slerp(target_basis, align_speed * delta).orthonormalized()

# =================================================
# WALL RUNNING 
func _detect_wall_running() -> void:
	if not enable_wall_running or is_on_floor() or current_speed < wall_run_min_speed:
		if is_wall_running:
			_on_wall_run_exit()
		return
	
	var found_wall = false
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var n: Vector3 = collision.get_normal()
		
		if abs(n.dot(Vector3.UP)) < 0.3:
			if collider is CollisionObject3D and (collider.collision_layer & wall_run_layer) != 0:
				wall_normal = n
				var right_dir = global_transform.basis.x
				wall_side = sign(n.dot(right_dir))
				found_wall = true
				
				if not is_wall_running:
					_on_wall_run_enter()
					_dbg_log("EVENT: Wall run START — speed: %.1f | normal: %s | layer: %d" % [current_speed, wall_normal, wall_run_layer])
				is_wall_running = true
				return
	
	if not found_wall and is_wall_running:
		_on_wall_run_exit()

func _on_wall_run_enter() -> void:
	current_shake = max(current_shake, wall_run_entry_shake)
	target_visual_scale = Vector3(1.2, 0.8, 1.2)

func _on_wall_run_exit() -> void:
	is_wall_running = false
	last_surface_normal = Vector3.UP
	up_direction = Vector3.UP
	wall_side = 0.0
	wall_normal = Vector3.ZERO

func player_move_and_slide() -> void:
	move_and_slide()

func _apply_ramp_boost_on_leave() -> void:
	if was_on_floor and not is_on_floor():
		var angle_factor: float = 1.0 - last_surface_normal.dot(Vector3.UP)
		if angle_factor > 0.15 and current_speed > (max_speed * 0.4):
			velocity += velocity.normalized() * slope_launch_boost * angle_factor * 2.0
			velocity.y += slope_launch_boost * angle_factor * 12.0
			_dbg_log("EVENT: Ramp boost — angle_factor: %.2f" % angle_factor)

# =================================================
# ACTIONS (Called by State Machine)
func _execute_jump() -> void:
	var charge_val: float = PlayerSFX.current_jump_charge if PlayerSFX and "current_jump_charge" in PlayerSFX else 1.0
	var force = lerp(min_jump_force, max_jump_force, charge_val)
	floor_snap_length = 0.0
	
	if is_wall_running and wall_normal != Vector3.ZERO:
		velocity += wall_normal * force * 1.5
		velocity.y += force * 0.6
		_on_wall_run_exit()
	else:
		velocity += Vector3.UP * force
		velocity += -global_transform.basis.z * (force * 0.2)
	
	target_visual_scale = Vector3(0.7, 1.4, 0.7)
	jumped.emit()
	if PlayerSFX and PlayerSFX.has_method("play_jump_launch"):
		PlayerSFX.play_jump_launch()
	PlayerSFX.current_jump_charge = 0.0

func _handle_landing(_delta: float) -> void:
	if is_wall_running: 
		return
	if not is_on_floor(): 
		return
	if get_floor_normal().dot(Vector3.UP) < 0.5:
		return
	if not was_on_floor:
		floor_snap_length = snap_length
		if air_time > 0.15: 
			var impact = clamp(air_time * 2.0, 0.0, 1.0)
			current_shake = impact * 0.3
			target_visual_scale = Vector3(1.3, 0.6, 1.3)
			landed.emit(impact)
			if PlayerSFX and PlayerSFX.has_method("play_land"):
				PlayerSFX.play_land()

func ChangeVelocity(vec: Vector3, force: float) -> void:
	velocity += vec * force

# =================================================
# VISUAL JUICE & CAMERA
func _update_air_pitch(delta: float) -> void:
	var target = inp_pitch * deg_to_rad(air_pitch_max_angle) if not is_on_floor() else 0.0
	var speed = air_pitch_responsiveness if not is_on_floor() else air_pitch_return_speed
	current_air_pitch = lerp(current_air_pitch, target, speed * delta)

func _update_visuals_and_juice(delta: float) -> void:
	current_visual_scale = current_visual_scale.lerp(Vector3.ONE, 10.0 * delta)
	if Rider_Model: Rider_Model.scale = current_visual_scale
	if board_target: board_target.scale = current_visual_scale
	
	if board_target:
		var target_tilt = -smoothed_input_x * (max_lean_angle * (drift_lean_multiplier if is_drifting else 1.0))
		current_tilt = lerp(current_tilt, target_tilt, lean_responsiveness * delta)
		var crouch = crouch_tilt_amount if is_charging_jump else 0.0
		var final_basis = Basis.IDENTITY.rotated(Vector3.FORWARD, current_tilt).rotated(Vector3.RIGHT, crouch + current_air_pitch)
		board_target.transform.basis = board_target.transform.basis.slerp(final_basis, 18.0 * delta)
	
	if Cam:
		var dashing = dash_timer > 0.0 or is_boosting
		var speed_ratio = current_speed / max_speed
		var dynamic_fov = base_fov + (speed_ratio * base_fov * dynamic_fov_influence)
		var target_fov = dynamic_fov + (dash_fov_boost if dashing else 0.0)
		if is_wall_running: target_fov += 10.0
		Cam.fov = lerp(Cam.fov, target_fov, (fov_lerp_speed if dashing else fov_return_speed) * delta)
		
		var target_roll = -smoothed_input_x * camera_roll_intensity
		if is_drifting: target_roll *= 1.5
		if is_wall_running:
			target_roll = wall_side * wall_run_cam_roll
		current_cam_roll = lerp(current_cam_roll, target_roll, 8.0 * delta)
		Cam.rotation_degrees.z = current_cam_roll
		
		if dashing and is_on_floor():
			current_shake = max(current_shake, 0.05)
		if current_shake > 0:
			Cam.h_offset = randf_range(-current_shake, current_shake)
			Cam.v_offset = randf_range(-current_shake, current_shake)
			current_shake = move_toward(current_shake, 0.0, delta * 2.0)
		else:
			Cam.h_offset = 0
			Cam.v_offset = 0

func _teleport_to_last_ground() -> void:
	global_position = last_ground_position
	velocity = Vector3.ZERO
	current_speed = 0.0

# =================================================
# DEBUG
func _setup_debug_ui() -> void:
	if debug_enabled:
		var canvas := CanvasLayer.new()
		canvas.name = "DebugCanvas"
		add_child(canvas)
		var label := RichTextLabel.new()
		label.name = "DebugLabel"
		label.bbcode_enabled = true
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.position = Vector2(10, 10)
		label.size = Vector2(420, 320)
		label.add_theme_color_override("default_color", Color(0.9, 1.0, 0.9))
		label.add_theme_font_size_override("normal_font_size", 14)

func _dbg_log(message: String) -> void:
	if debug_enabled:
		print_debug("[PlayerLog]: ", message)

func _update_debug_ui() -> void:
	if debug_enabled and has_node("DebugCanvas/DebugLabel"):
		var label = get_node("DebugCanvas/DebugLabel")
		var full_segments = floor(current_boost_segments)
		var percentage = (current_boost_segments - full_segments) * 100
		label.text = "[b]SPEED:[/b] %.1f\n" % current_speed
		label.text += "[b]BOOST:[/b] %d / %d (%.0f%%) | Active: %s\n" % [full_segments, max_boost_segments, percentage, str(is_boosting)]
		label.text += "[b]STATE:[/b] %s\n" % ("WallRun" if is_wall_running else "Air" if not is_on_floor() else "Ground")
