extends BoardState
class_name Boost

@onready var player: BoardController = get_parent().get_parent()


func enter_state() -> void:
	print_debug("Enter Boost")

func exit_state() -> void:
	print_debug("Exit Boost")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func physics_process(delta: float) -> void:
	# # Process Boost first to influence speed
	_handle_boost_system(delta)


# =================================================
# BOOST SYSTEM CORE
func _handle_boost_system(delta: float) -> void:
	# 1. Gauge Regeneration (Drift vs Passive)
	if player.is_drifting:
		player.current_boost_segments += player.drift_boost_regen * delta
	else:
		player.current_boost_segments += player.passive_boost_regen * delta
		
	# Limits to not exceed the maximum (ex: 3.0)
	player.current_boost_segments = clamp(player.current_boost_segments, 0.0, float(player.max_boost_segments))
	
	# 2. Boost Activation
	# Requires you to have at least 1.0 integer to activate, and cannot be in boost yet
	if player.inp_boost and player.current_boost_segments >= 1.0 and not player.is_boosting:
		player.current_boost_segments -= 1.0 # Consome exato 1 segmento
		player.is_boosting = true
		player.boost_timer = player.boost_duration_per_segment
		
		player.current_speed = max(player.current_speed, player.boost_speed_target * 0.7)
		
		if player.PlayerSFX and player.PlayerSFX.has_method("play_boost"):
			player.PlayerSFX.play_boost()

	# 3. Duration management
	if player.is_boosting:
		player.boost_timer -= delta
		if player.boost_timer <= 0.0:
			player.is_boosting = false
