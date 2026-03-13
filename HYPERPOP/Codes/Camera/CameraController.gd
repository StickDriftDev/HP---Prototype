extends Camera3D
class_name CameraController

@export var player: CharacterBody3D
@export var target_height: float = 1.5
@export var camera_node: Camera3D

@export_category("Dynamics")
@export var move_lerp_speed: float = 20.0
@export var rotation_lerp_speed: float = 15.0
@export var auto_align_speed: float = 8.0
@export var stick_sensitivity: float = 3.0
@export var mouse_sensitivity: float = 0.002

@export_category("Distance & Height")
@export var idle_distance: float = 9
@export var normal_distance: float = 10
@export var max_distance: float = 14
@export var base_height: float = 7.0
@export var distance_smooth: float = 12.0
@export var absolute_max_limit: float = 12.0

@export_category("FOV Settings")
@export var fov_idle: float = 70.0
@export var fov_speed: float = 100.0
@export var fov_boost: float = 125.0
@export var fov_lerp_speed: float = 8.0

@export_category("Cinematic & Roll")
@export var look_ahead_strength: float = 6.0
@export var turn_roll_strength: float = 0.45
@export var drift_roll_multiplier: float = 3.5
@export var inertia_strength: float = 5.0

var yaw := 0.0
var pitch := -0.1
var roll := 0.0

var current_distance := 5.0
var current_height := 2.0
var velocity_offset := Vector3.ZERO
var base_fov: float = 70.0

func _ready() -> void:
	if camera_node:
		base_fov = camera_node.fov
	top_level = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player:
		yaw = player.global_rotation.y + PI
	current_height = base_height

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -0.6, 0.5)

func _physics_process(delta: float) -> void:
	if not player:
		return

	_handle_input(delta)
	_auto_align(delta)
	_update_transform(delta)
	
	var is_drifting = player.get("is_drifting") if "is_drifting" in player else false
	var is_dashing = (player.get("dash_timer") > 0) if "dash_timer" in player else false
	
	_update_effects(delta, is_drifting or is_dashing)

func _handle_input(delta: float) -> void:
	var axis = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if axis.length() > 0.1:
		yaw -= axis.x * stick_sensitivity * delta
		pitch -= axis.y * stick_sensitivity * delta

func _auto_align(delta: float) -> void:
	var speed = player.velocity.length()
	if speed > 2.0:
		var target_yaw = player.global_rotation.y + PI
		# Scales alignment strength based on speed for that tight racing feel
		var align_factor = clamp(speed / 20.0, 0.2, 1.0)
		yaw = lerp_angle(yaw, target_yaw, auto_align_speed * align_factor * delta)

func _update_transform(delta: float) -> void:
	var speed = player.velocity.length()
	var speed_ratio = clamp(speed / 50.0, 0.0, 1.0)

	var target_dist = normal_distance
	if speed < 1.0:
		target_dist = idle_distance
	else:
		target_dist = lerp(normal_distance, max_distance, speed_ratio)

	current_distance = lerp(current_distance, target_dist, distance_smooth * delta)
	current_height = lerp(current_height, base_height, 10.0 * delta)

	var dir = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var target_pos = player.global_position + Vector3.UP * current_height
	target_pos -= dir * current_distance

	# Pulls camera slightly opposite to velocity for acceleration lag
	var desired_offset = -player.velocity * 0.015
	velocity_offset = velocity_offset.lerp(desired_offset, inertia_strength * delta)
	target_pos += velocity_offset

	global_position = global_position.lerp(target_pos, move_lerp_speed * delta)
	
	var actual_dist = global_position.distance_to(player.global_position)
	if actual_dist > absolute_max_limit:
		var back_dir = (global_position - player.global_position).normalized()
		global_position = player.global_position + back_dir * absolute_max_limit

	var look_target = player.global_position + Vector3.UP * target_height
	if speed > 2.0:
		look_target += player.velocity.normalized() * look_ahead_strength * speed_ratio

	look_at(look_target, Vector3.UP)

	var turn_amount = wrapf((player.global_rotation.y + PI) - yaw, -PI, PI)
	var is_drifting = player.get("is_drifting") if "is_drifting" in player else false
	var drift_mult = drift_roll_multiplier if is_drifting else 1.0

	var target_roll = -turn_amount * turn_roll_strength * drift_mult
	roll = lerp(roll, target_roll, 8.0 * delta)
	
	var view_dir = (look_target - global_position).normalized()
	if view_dir.length() > 0.1:
		global_transform.basis = global_transform.basis.rotated(view_dir, roll)

func _update_effects(delta: float, is_boosted: bool) -> void:
	if not camera_node: return
	
	var speed = player.velocity.length()
	var speed_ratio = clamp(speed / 50.0, 0.0, 1.0)
	
	var target_fov = lerp(fov_idle, fov_speed, speed_ratio)
	if is_boosted:
		target_fov = fov_boost
	
	camera_node.fov = lerp(camera_node.fov, target_fov, fov_lerp_speed * delta)
	
	var target_quat = global_transform.basis.get_rotation_quaternion()
	var current_quat = camera_node.global_transform.basis.get_rotation_quaternion()
	camera_node.global_transform.basis = Basis(current_quat.slerp(target_quat, rotation_lerp_speed * delta))

	camera_node.global_position = camera_node.global_position.lerp(global_position, 40.0 * delta)
	
	if camera_node.global_position.distance_to(global_position) > 0.2:
		camera_node.global_position = global_position
