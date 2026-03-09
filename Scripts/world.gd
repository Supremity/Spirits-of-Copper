extends Node2D
class_name World

@onready var map_sprite: Sprite2D = $"../../MapContainer/CultureSprite" as Sprite2D
@onready var camera: Camera2D = $"../../Camera2D"
@onready var troop_renderer: CustomRenderer = $CustomRenderer as CustomRenderer


func _enter_tree() -> void:
	GameState.current_world = self


var _first_time_setup_done := false


func _ready() -> void:
	TroopManager.troop_selection = $TroopSelection as TroopSelection

	# Note z21: Needs to be a better way to do this
	if CountryManager.player_country != null:
		CountryManager.set_player_country(CountryManager.player_country.country_name)
	else:
		CountryManager.set_player_country("brazil")
	# Prevent signal double-connection
	if not GameState.main.clock.hour_passed.is_connected(CountryManager._on_hour_passed):
		GameState.main.clock.hour_passed.connect(CountryManager._on_hour_passed)

	if not GameState.main.clock.day_passed.is_connected(CountryManager._on_day_passed):
		GameState.main.clock.day_passed.connect(CountryManager._on_day_passed)

	if not GameState.main.clock.day_passed.is_connected(EventManager.process_day):
		GameState.main.clock.day_passed.connect(EventManager.process_day)

	if not _first_time_setup_done:
		await get_tree().process_frame
		initialize_world()

	_first_time_setup_done = true

func initialize_world():
	# Safety check for MapManager data
	if not MapManager.id_map_image:
		push_error("MapManager image is null during initialization!")
		return

	if troop_renderer:
		troop_renderer.map_sprite = map_sprite
		troop_renderer.map_width = MapManager.id_map_image.get_width()
		# Explicitly tell the renderer to boot up
		# note z21: This might all not be needed..
		troop_renderer.rebuild_troops()

	# Reset troop positions for the new map instance
	for t_obj in TroopManager.troops:
		t_obj.position = MapManager.province_centers.get(t_obj.province_id, Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			MapManager.handle_click_down(get_global_mouse_position(), map_sprite)
		else:
			MapManager.handle_click(get_global_mouse_position(), map_sprite)
	if event is InputEventMouseMotion:
		MapManager.handle_hover(get_global_mouse_position(), map_sprite)
