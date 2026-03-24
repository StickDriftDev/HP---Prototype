extends BoardState
class_name Boost

# Sinal para avisar a UI
signal boost_consumido(segmentos_restantes: float)

@onready var player: BoardController = get_parent().get_parent()

func enter_state() -> void:
	print_debug("Enter Boost")
	
	# Consome o boost
	player.current_boost_segments -= 1.0
	boost_consumido.emit(player.current_boost_segments)
	
	player.is_boosting = true
	player.boost_timer = player.boost_duration_per_segment
	
	# Ajuste de velocidade inicial do boost
	player.current_speed = max(player.current_speed, player.boost_speed_target * 0.7)
	
	# Toca o som de boost
	_play_boost_sound()

func exit_state() -> void:
	print_debug("Exit Boost")
	player.is_boosting = false
	
	# Para o som de boost se ele for um loop (opcional)
	_stop_boost_sound()

func physics_process(delta: float) -> void:
	_handle_boost_system(delta)

# =================================================
# AUXILIARES DE SOM
# =================================================
func _play_boost_sound() -> void:
	# Verifica se a referência PlayerSFX existe no seu BoardController
	if player.get("PlayerSFX") and player.PlayerSFX.has_method("play_boost"):
		player.PlayerSFX.play_boost()

func _stop_boost_sound() -> void:
	# Útil se o seu boost tiver um som de "cauda" ou for um loop
	if player.get("PlayerSFX") and player.PlayerSFX.has_method("stop_boost"):
		player.PlayerSFX.stop_boost()

# =================================================
# BOOST SYSTEM CORE
# =================================================
func _handle_boost_system(delta: float) -> void:
	player.boost_timer -= delta
	if player.boost_timer <= 0.0:
		loco_state_machine.change_state("Grounded")
