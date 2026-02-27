extends Node

enum Type { MENU, WORLD, EDITOR, SELECT_COUNTRY }

const SCENE_MAP = {
	Type.MENU: "res://Scenes/main_menu.tscn",
	Type.WORLD: "res://Scenes/world.tscn",
	Type.EDITOR: "res://Scenes/game_editor.tscn",
	Type.SELECT_COUNTRY: "res://Scenes/select_country.tscn"
}

var _current_type: int = -1

func switch_to(scene_type: Type) -> void:
	if scene_type == _current_type:
		return

	var main := get_tree().current_scene
	var container := main.get_node("CurrentScene")

	# 1️⃣ Remove and free old scene
	if container.get_child_count() > 0:
		var old_scene = container.get_child(0)
		container.remove_child(old_scene)
		old_scene.queue_free()   # ← IMPORTANT

	# 2️⃣ Instantiate fresh scene
	var path = SCENE_MAP.get(scene_type)
	if path == null:
		push_error("Invalid scene type.")
		return

	var packed_scene := load(path)
	if packed_scene == null:
		push_error("Failed to load scene path: ", path)
		return

	var next_scene = packed_scene.instantiate()

	# 3️⃣ Add to container
	container.add_child(next_scene)
	_current_type = scene_type
	if next_scene.has_method("initialize_world"):
		next_scene.initialize_world()

	print("Switched to: ", Type.keys()[scene_type])
