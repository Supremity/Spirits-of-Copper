extends CanvasLayer
class_name CustomRenderer

@export var icon_scene: PackedScene = preload("res://Scenes/troop_icon.tscn")
var icons = {} 
@onready var camera = get_viewport().get_camera_3d()

func _process(_delta):
	sync_icons()
	update_icon_positions()

func sync_icons():
	for troop in TroopManager.troops:
		if not icons.has(troop):
			var new_icon = icon_scene.instantiate()
			add_child(new_icon)
			new_icon.setup(troop)
			icons[troop] = new_icon
			print("DEBUG: Spawned icon for troop in province ", troop.province_id) 
	for troop in icons.keys():
		if not is_instance_valid(troop) or not TroopManager.troops.has(troop):
			icons[troop].queue_free()
			icons.erase(troop)
		
func update_icon_positions():
	if not camera: camera = get_viewport().get_camera_3d()
	if not camera: return
	
	for troop in icons.keys():
		var icon = icons[troop]
		var world_pos = troop.get_visual_position()
		if camera.is_position_behind(world_pos):
			icon.visible = false
			continue
		var screen_pos = camera.unproject_position(world_pos)
		icon.global_position = screen_pos
		icon.visible = true

		var dist = camera.global_position.distance_to(world_pos)
		var scale_factor = clamp(8.0 / dist, 0.5, 1.0) 
		icon.scale = Vector2.ONE * scale_factor
