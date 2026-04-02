extends Camera3D
class_name RidersProCameraController

@export var player: CharacterBody3D

@export_category("Distance and Height")
@export var distance: float = 10.0
@export var target_height: float = 2.5
@export var height_speed_gain: float = 2.0 

@export_category("FOV")
@export var base_fov: float = 75.0
@export var speed_fov_boost: float = 10.0 
@export var max_speed_reference: float = 50.0

@export_category("Boost")
@export var boost_distance_surge: float = 1.5 
@export var boost_return_speed: float = 8.0   

@export_category("Juice Effects")
@export var fov_boost_punch: float = 12.0
@export var acceleration_fov_influence: float = 0.15

@export_category("Speed Lean Limiter")
@export var lean_start_speed: float = 20.0
@export var max_lean_angle_degrees: float = 35.0
# -------------------------------------------------------

@export_category("Controls")
@export var mouse_sensitivity: float = 0.003
@export var stick_sensitivity: float = 4.0
@export var rotation_stiffness: float = 0.2 
@export var auto_center_speed: float = 3.5
@export var time_to_auto_center: float = 1.0
@export var follow_lerp: float = 15.0

var yaw: float = 0.0
var pitch: float = -0.15
var roll: float = 0.0
var focus_point: Vector3
var manual_timer: float = 0.0

var _boost_offset: float = 0.0
var _was_boosting: bool = false
var _current_fov_punch: float = 0.0
var _last_speed: float = 0.0

func _ready() -> void:
	top_level = true
	fov = base_fov
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player:
		yaw = player.global_rotation.y 
		focus_point = player.global_position + Vector3.UP * target_height

# --- Mouse Input  ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var speed = player.velocity.length()
		var speed_ratio = clamp(speed / max_speed_reference, 0.0, 1.0)
		var sens_mult = lerp(1.0, rotation_stiffness, speed_ratio)
		
		yaw -= event.relative.x * mouse_sensitivity * sens_mult
		pitch -= event.relative.y * mouse_sensitivity * sens_mult
		pitch = clamp(pitch, -1.0, 0.4)
		manual_timer = time_to_auto_center

func _physics_process(delta: float) -> void:
	if not player: return
	
	var is_boosting = player.get("dash_timer") > 0 if "dash_timer" in player else false
	
	_handle_stick_input(delta)
	_handle_auto_center(delta)
	_update_riders_logic(delta, is_boosting)

# --- Analog Input ---
func _handle_stick_input(delta: float) -> void:
	var axis = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if axis.length() > 0.1:
		var speed = player.velocity.length()
		var speed_ratio = clamp(speed / max_speed_reference, 0.0, 1.0)
		var sens_mult = lerp(1.0, rotation_stiffness, speed_ratio)
		
		yaw -= axis.x * stick_sensitivity * delta * sens_mult
		pitch -= axis.y * stick_sensitivity * delta * sens_mult
		pitch = clamp(pitch, -1.0, 0.4)
		manual_timer = time_to_auto_center

# --- Auto Center ---
func _handle_auto_center(delta: float) -> void:
	if manual_timer > 0.0:
		manual_timer -= delta
		return
	var speed = player.velocity.length()
	if speed > 2.0:
		var target_yaw = atan2(player.velocity.x, player.velocity.z) + PI
		yaw = lerp_angle(yaw, target_yaw, auto_center_speed * delta)
		pitch = lerp(pitch, -0.15, (auto_center_speed * 0.5) * delta)

func _update_riders_logic(delta: float, is_boosting: bool) -> void:
	var speed = player.velocity.length()
	var speed_ratio = clamp(speed / max_speed_reference, 0.0, 1.0)
	
	var acceleration = (speed - _last_speed) / delta
	_last_speed = speed

	if is_boosting and not _was_boosting:
		_boost_offset = boost_distance_surge
		_current_fov_punch = fov_boost_punch
		
	_was_boosting = is_boosting
	_boost_offset = lerp(_boost_offset, 0.0, boost_return_speed * delta)
	_current_fov_punch = lerp(_current_fov_punch, 0.0, (boost_return_speed * 0.6) * delta)

	var accel_fov_bonus = clamp(acceleration * acceleration_fov_influence, -5.0, 8.0)
	var target_fov = base_fov + (speed_fov_boost * speed_ratio) + _current_fov_punch + accel_fov_bonus
	var fov_lerp_weight = 8.0 if target_fov > fov else 3.0
	fov = lerp(fov, target_fov, fov_lerp_weight * delta)

	var dynamic_height = target_height + (speed_ratio * height_speed_gain)
	focus_point.x = player.global_position.x
	focus_point.z = player.global_position.z
	focus_point.y = lerp(focus_point.y, player.global_position.y + dynamic_height, follow_lerp * delta)

	var forward_yaw = atan2(player.velocity.x, player.velocity.z) + PI

	if speed > lean_start_speed:
		var lean_ratio = clamp((speed - lean_start_speed) / (max_speed_reference - lean_start_speed), 0.0, 1.0)
		
		var current_max_lean_rad = lerp(PI, deg_to_rad(max_lean_angle_degrees), lean_ratio)

		var angle_diff = wrap_angle(yaw - forward_yaw)
		
		var clamped_diff = clamp(angle_diff, -current_max_lean_rad, current_max_lean_rad)
		
		yaw = forward_yaw + clamped_diff
	# -------------------------------------------------------

	var cam_basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var final_dist = distance + _boost_offset
	
	global_position = focus_point + (cam_basis.z * final_dist)
	global_transform.basis = cam_basis

func wrap_angle(angle: float) -> float:
	while angle > PI: angle -= 2 * PI
	while angle < -PI: angle += 2 * PI
	return angle
