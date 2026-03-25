extends Node3D
class_name Main
@onready var culture_sprite: Sprite2D = $MapViewport/MapContainer/CultureSprite
@export var clock: GameClock
@onready var camera_3d: Camera3D = $Camera3D


func _enter_tree() -> void:
	GameState.main = self
	GameState.camera = camera_3d


func _ready() -> void:
	GameState.main.clock.pause()
