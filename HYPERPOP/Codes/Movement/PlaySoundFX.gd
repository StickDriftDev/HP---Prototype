class_name PlaySoundsFX
extends Node

# =================================================
# REFERÊNCIAS
@onready var board_controller: BoardController = get_parent()

# =================================================
# CONFIG — AUDIO EXPORTS
@export_group("Movement & Engine")
@export var sfx_engine_loop: AudioStreamPlayer3D
@export var sfx_drift_loop: AudioStreamPlayer3D
@export var sfx_brake: AudioStreamPlayer3D
@export var sfx_dash: AudioStreamPlayer3D
@export var sfx_boost: AudioStreamPlayer3D

@export_group("Jump & Physics")
@export var sfx_jump_launch: AudioStreamPlayer3D
@export var sfx_jump_charge_loop: AudioStreamPlayer3D
@export var sfx_land: AudioStreamPlayer3D

@export_group("Tricks & Rank")
## Som curto de 'woosh' ou giro para cada 360
@export var sfx_trick_spin: AudioStreamPlayer3D
## Som de impacto/conquista quando o Rank sobe (C, B, A, S...)
@export var sfx_rank_up: AudioStreamPlayer # Recomendado ser 2D para impacto de UI
@export var sfx_land_perfect: AudioStreamPlayer3D

# =================================================
# ESTADO INTERNO
var current_jump_charge: float = 0.0
var max_charge_time: float = 0.8

# =================================================
# JUMP & LANDING
func _update_jump_charge(delta: float, is_charging_jump: bool, is_wall_running: bool) -> void:
	var grounded = board_controller.is_on_floor() || is_wall_running
	if is_charging_jump && grounded:
		current_jump_charge = move_toward(current_jump_charge, 1.0, delta / max_charge_time)
		_play(sfx_jump_charge_loop)
	else:
		current_jump_charge = 0.0
		_stop(sfx_jump_charge_loop)

func play_jump_launch() -> void:
	_play_once(sfx_jump_launch)

func play_land(perfect: bool = false) -> void:
	if perfect:
		_play_once(sfx_land_perfect)
	else:
		_play_once(sfx_land)

# =================================================
# ENGINE & MOVEMENT
func _update_engine_audio(current_speed: float, max_speed: float) -> void:
	if not sfx_engine_loop: return
	
	if current_speed > 1.0:
		_play(sfx_engine_loop)
		# O pitch sobe conforme a velocidade, criando sensação de aceleração
		sfx_engine_loop.pitch_scale = lerp(0.9, 1.6, clamp(current_speed / max_speed, 0.0, 2.0))
	else:
		_stop(sfx_engine_loop)

func play_dash() -> void:
	_play_once(sfx_dash)

func play_boost() -> void:
	_play_once(sfx_boost)

func play_drift_loop() -> void:
	_play(sfx_drift_loop)

func stop_drift_loop() -> void:
	_stop(sfx_drift_loop)

func play_brake() -> void:
	_play(sfx_brake)

func stop_brake() -> void:
	_stop(sfx_brake)

# =================================================
# TRICK SYSTEM (NEW)
## Chamado pelo TrickManager a cada rotação completa
func play_trick_spin(custom_pitch: float) -> void:
	if sfx_trick_spin:
		sfx_trick_spin.pitch_scale = custom_pitch
		_play_once(sfx_trick_spin)

## Chamado quando o jogador sobe de Rank (C -> B -> A...)
func play_rank_up(custom_pitch: float = 1.0) -> void:
	if sfx_rank_up:
		sfx_rank_up.pitch_scale = custom_pitch 
		sfx_rank_up.play()
# =================================================
# HELPERS (AUXILIARES)
## Toca um som em loop (se já não estiver tocando)
func _play(player: Node) -> void:
	if player and player.has_method("play") and not player.playing:
		player.play()

## Para um som que está em loop
func _stop(player: Node) -> void:
	if player and player.has_method("stop") and player.playing:
		player.stop()

## Toca um som de efeito (One-shot)
func _play_once(player: Node) -> void:
	if player and player.has_method("play"):
		# Se for 3D, podemos resetar o pitch antes de cada play para variação básica
		player.play()
