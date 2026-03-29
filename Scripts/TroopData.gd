extends Node
class_name TroopData

# --- Core Properties ---
var country_name: String
var country_obj: Resource  # Changed to Resource/Object for safety
var province_id: int
var position: Vector2

var stored_divisions: Array[DivisionData] = []

var divisions_count: int:
	get:
		return stored_divisions.size()
	set(value):
		_adjust_divisions_to_match_count(value)

var is_moving: bool = false
var path: Array = []
var target_position: Vector2 = Vector2.ZERO
var progress: float = 0.0


func _init(
	p_country: String = "",
	p_province_id: int = -1,
	p_divisions: int = 0,
	p_position: Vector2 = Vector2.ZERO,
	p_flag: Texture2D = null
) -> void:
	if p_country == "":
		return
	country_name = p_country
	province_id = p_province_id
	position = p_position

	for i in range(p_divisions):
		var div = DivisionData.new()
		div.name = "Division %d" % (i + 1)
		stored_divisions.append(div)

func get_visual_position() -> Vector3:
	var map_res = Vector2(1275, 625)
	var uv = Vector2(position.x / map_res.x, position.y / map_res.y)
	
	var plane_size = Vector2(12.75, 6.25)
	var local_x = (uv.x - 0.5) * plane_size.x
	var local_z = (uv.y - 0.5) * plane_size.y
	
	var board_global_pos = GameState.game_board.global_position
	var global_pos = board_global_pos + Vector3(local_x, 0, local_z)
	
	# --- NEW: SAMPLE HEIGHTMAP ---
	var y_height = 0.01  # fallback in case height_map is missing
	if GameState.game_board:
		y_height += GameState.game_board.get_height_at_pos(global_pos)
	
	return global_pos + Vector3(0, y_height, 0)

func _adjust_divisions_to_match_count(target_count: int):
	var current = stored_divisions.size()
	if target_count > current:
		for i in range(target_count - current):
			stored_divisions.append(DivisionData.new())
	elif target_count < current:
		stored_divisions.resize(target_count)


func get_average_hp_percent() -> float:
	if stored_divisions.is_empty():
		return 0.0
	var total_hp = 0.0
	var total_max = 0.0
	for div in stored_divisions:
		total_hp += div.hp
		total_max += div.max_hp
	return total_hp / total_max if total_max > 0 else 0.0


func get_main_type() -> String:
	if stored_divisions.is_empty():
		return "infantry"
	return stored_divisions[0].type
