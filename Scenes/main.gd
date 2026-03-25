extends Node3D
class_name Main
@onready var culture_sprite: Sprite2D = $MapViewport/MapContainer/CultureSprite
@export var clock: GameClock
@onready var camera_controller: Node = $Camera3D/CameraController


func _enter_tree() -> void:
	GameState.main = self
	GameState.camera = camera_controller


func _ready() -> void:
	GameState.main.clock.pause()
