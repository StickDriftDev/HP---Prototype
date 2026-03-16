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
func _process(delta: float) -> void:
	pass
