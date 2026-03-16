extends BoardState
class_name Boost

@onready var player: BoardController = get_parent().get_parent()


func enter_state() -> void:
	print_debug("Enter Boost")
	
	player.current_boost_segments -= 1.0 # Consome exato 1 segmento
	player.is_boosting = true
	player.boost_timer = player.boost_duration_per_segment
	
	player.current_speed = max(player.current_speed, player.boost_speed_target * 0.7)
	
	if player.PlayerSFX and player.PlayerSFX.has_method("play_boost"):
		player.PlayerSFX.play_boost()

func exit_state() -> void:
	print_debug("Exit Boost")
	player.is_boosting = false

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
	player.boost_timer -= delta
	if player.boost_timer <= 0.0:
		player.is_boosting = false
		loco_state_machine.change_state("Grounded")
