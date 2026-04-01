extends Control

@export var player_controller: BoardController
@export var alarm_player: AudioStreamPlayer2D
@export var progress_bar: TextureProgressBar

@onready var original_position: Vector2 = position
@onready var original_scale: Vector2 = scale

@export_category("Boost Colors")
@export var color_full: Color = Color("00f2ff")
@export var color_empty: Color = Color("ff2151")
@export var color_flash: Color = Color.WHITE

var _tween_value: Tween
var _tween_juice: Tween
var _tween_critical: Tween

var _is_critical: bool = false
var _impact_shake: float = 0.0
var _previous_visual_value: float = 100.0


func _ready() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.step = 0.0
	
	if player_controller:
		player_controller.boost_modified.connect(_on_boost_modified)
	else:
		push_warning("Warning: BoardController not configured!")


func _process(delta: float) -> void:
	if _is_critical:
		position = original_position + Vector2(randf_range(-3.5, 3.5), randf_range(-3.5, 3.5))
	elif _impact_shake > 0:
		position = original_position + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * _impact_shake * 18.0
		_impact_shake = lerpf(_impact_shake, 0.0, delta * 14.0)
		
		if _impact_shake < 0.01:
			_impact_shake = 0.0
			position = original_position


func _on_boost_modified(segmentos_atuais: float, segmentos_maximos: int) -> void:
	var max_seg = float(segmentos_maximos) if segmentos_maximos > 0 else 4.0
	var perc = clampf(float(segmentos_atuais) / max_seg, 0.0, 1.0)
	var target_value = perc * 100.0
	
	var spent_boost = target_value < _previous_visual_value
	var filled_maximum = target_value >= 99.0
	
	_animate_bar(target_value, perc)
	_apply_juice(spent_boost, filled_maximum)
	
	if perc <= 0.25:
		_enter_critical_state()
	else:
		_exit_critical_state()
	
	_previous_visual_value = target_value


func _animate_bar(target: float, perc: float) -> void:
	if _tween_value:
		_tween_value.kill()
	
	_tween_value = create_tween().set_parallel(true)
	_tween_value.tween_property(progress_bar, "value", target, 0.05)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	var target_color = color_empty.lerp(color_full, perc)
	_tween_value.tween_property(progress_bar, "tint_progress", target_color, 0.2)


func _apply_juice(spent: bool, maximum: bool) -> void:
	if _tween_juice:
		_tween_juice.kill()
	
	_tween_juice = create_tween().set_parallel(true)
	
	if maximum:
		scale = original_scale * 1.08
		progress_bar.modulate = color_full.lightened(0.5)
		_impact_shake = 0.7
		
	elif spent:
		scale = original_scale * 0.95 
		progress_bar.modulate = color_flash
		_impact_shake = 0.15
		position = original_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 4.0
		
	else:
		scale = original_scale * 1.06
		_impact_shake = 0.35
	
	_tween_juice.tween_property(self, "scale", original_scale, 0.45)\
		.set_trans(Tween.TRANS_SPRING)\
		.set_ease(Tween.EASE_OUT)
	
	_tween_juice.tween_property(progress_bar, "modulate", Color.WHITE, 0.3)


func _enter_critical_state() -> void:
	if _is_critical:
		return
	
	_is_critical = true
	
	if alarm_player and not alarm_player.playing:
		alarm_player.play()
	
	if _tween_critical:
		_tween_critical.kill()
	
	_tween_critical = create_tween().set_loops()
	_tween_critical.tween_property(progress_bar, "modulate", color_flash, 0.05)
	_tween_critical.tween_property(progress_bar, "modulate", color_empty, 0.15)


func _exit_critical_state() -> void:
	if not _is_critical:
		return
	
	_is_critical = false
	
	if alarm_player:
		alarm_player.stop()
	
	if _tween_critical:
		_tween_critical.kill()
	
	create_tween().tween_property(progress_bar, "modulate", Color.WHITE, 0.12)
	position = original_position
