extends Node3D

@onready var timer: Timer = $Timer

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	timer.wait_time = 0.5
	timer.start()

func _on_timer_timeout() -> void:
	queue_free()
