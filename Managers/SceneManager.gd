extends Node

enum Type {
	MENU,
	WORLD,
	EDITOR
}

const SCENE_MAP = {
	Type.MENU: "res://Scenes/main_menu.tscn",
	Type.WORLD: "res://Scenes/world.tscn",
	Type.EDITOR: "res://Scenes/game_editor.tscn"
}

# This keeps the nodes in memory so they are never freed
var _instances: Dictionary = {}

func switch_to(scene_type: Type) -> void:

	var main := get_tree().current_scene   # This is Main
	var old_world := main.get_node_or_null("World")

	if old_world:
		old_world.queue_free()

	var path = SCENE_MAP.get(scene_type)
	var packed_scene = load(path)

	if packed_scene:
		var new_world = packed_scene.instantiate()
		new_world.name = "World"
		main.add_child(new_world)

	print("World switched → ", Type.keys()[scene_type])
