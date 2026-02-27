extends Node2D
class_name Main

@export var clock: GameClock
func _enter_tree() -> void:
	GameState.main = self

func _ready() -> void:
	GameState.main.clock.pause()
