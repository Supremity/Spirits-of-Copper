extends Node2D
class_name World

# Updated path: World is now inside CurrentScene, which is a sibling to MapContainer
@onready var map_sprite: Sprite2D = $"../../MapViewport/MapContainer/CultureSprite"
@onready var troop_renderer: CustomRenderer = $CustomRenderer as CustomRenderer

func _enter_tree() -> void:
	GameState.current_world = self

var _first_time_setup_done := false

func _ready() -> void:
	TroopManager.troop_selection = $TroopSelection as TroopSelection

	# --- Country Initialization ---
	if CountryManager.player_country != null:
		CountryManager.set_player_country(CountryManager.player_country.country_name)
	else:
		CountryManager.set_player_country("brazil")
	
	# --- Signal Connections ---
	# (Keeping your existing logic for clock signals)
	var clock = GameState.main.clock
	if not clock.hour_passed.is_connected(CountryManager._on_hour_passed):
		clock.hour_passed.connect(CountryManager._on_hour_passed)
	if not clock.day_passed.is_connected(CountryManager._on_day_passed):
		clock.day_passed.connect(CountryManager._on_day_passed)
	if not clock.day_passed.is_connected(EventManager.process_day):
		clock.day_passed.connect(EventManager.process_day)

	if not _first_time_setup_done:
		# Wait for the SubViewport to stabilize before drawing troops
		await get_tree().process_frame
		initialize_world()

	_first_time_setup_done = true

func initialize_world():
	for t_obj in TroopManager.troops:
		t_obj.position = MapManager.province_centers.get(t_obj.province_id, Vector2.ZERO)

# --- IMPORTANT: _input REMOVED ---
# We removed the _input function here because the Camera3D script 
# now calculates the correct "Tilted" mouse position and sends 
# it directly to MapManager.
