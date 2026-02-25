extends Node2D
class_name World

@onready var map_sprite: Sprite2D = $"../MapContainer/CultureSprite" as Sprite2D
@onready var camera: Camera2D = $"../Camera2D"
@onready var troop_renderer: CustomRenderer = $CustomRenderer as CustomRenderer

@export var map_shader: Shader
@export var clock: GameClock

var water_offset: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	var map_width := MapManager.id_map_image.get_width()
	if camera.position.x > map_sprite.position.x + map_width:
		camera.position.x -= map_width
	elif camera.position.x < map_sprite.position.x - map_width:
		camera.position.x += map_width
	if map_sprite.material and !clock.paused:
		var move_amount = clock.time_scale * 0.001 * _delta
		water_offset.x += move_amount
		map_sprite.material.set_shader_parameter("ocean_offset", water_offset)


func _enter_tree() -> void:
	GameState.current_world = self


func _ready() -> void:
	TroopManager.troop_selection = $TroopSelection as TroopSelection

	# TODO(pol): Load CountryManager after map instead of an autoload to avoid this.
	clock.hour_passed.connect(CountryManager._on_hour_passed)
	clock.day_passed.connect(CountryManager._on_day_passed)

	MapManager.load_country_data()

	print("World: Map is ready -> configuring visuals...")

	MapManager.all_cities = MapManager.get_all_cities()
	CountryManager.initialize_countries()
	CountryManager.set_player_country("brazil")
	# For debugging purposes. Create some troops first
	MapManager._build_global_registry()
	var map_width := MapManager.id_map_image.get_width()
	var map_height := MapManager.id_map_image.get_height()

	var mat := ShaderMaterial.new()
	mat.shader = map_shader
	var id_tex := ImageTexture.create_from_image(MapManager.id_map_image)
	mat.set_shader_parameter("region_id_map", id_tex)
	mat.set_shader_parameter("state_colors", MapManager.state_color_texture)

	var type_tex = MapManager.generate_type_mask()
	mat.set_shader_parameter("type_map", type_tex)

	var noise = FastNoiseLite.new()
	noise.seed = randi()

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	noise.frequency = 0.005

	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5

	var noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.noise = noise

	await noise_tex.changed
	mat.set_shader_parameter("ocean_noise", noise_tex)

	mat.set_shader_parameter("original_texture", map_sprite.texture)
	mat.set_shader_parameter("sea_speed", 0.00)  # Changed by MainClock
	mat.set_shader_parameter("tex_size", Vector2(map_width, MapManager.id_map_image.get_height()))
	mat.set_shader_parameter("country_border_color", Color.BLACK)

	map_sprite.material = mat

	for i in [-2, -1, 1, 2]:
		_create_ghost_map(Vector2(i * map_width, 0), mat)

	if troop_renderer:
		troop_renderer.map_sprite = map_sprite
		troop_renderer.map_width = map_width
	else:
		push_error("CustomRenderer node not found!")


func _create_ghost_map(offset: Vector2, p_material: ShaderMaterial) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = map_sprite.texture
	ghost.centered = map_sprite.centered
	ghost.material = p_material
	ghost.position = map_sprite.position + offset
	add_child(ghost)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			MapManager.handle_click_down(get_global_mouse_position(), map_sprite)
		else:
			MapManager.handle_click(get_global_mouse_position(), map_sprite)
	if event is InputEventMouseMotion:
		MapManager.handle_hover(get_global_mouse_position(), map_sprite)


func save_game_rebel(slot: String):
	var save_data = {
		"player_country": CountryManager.player_country.country_name,
		"countries": {},
		"troops": [],
		"map_state":  # Start empty
		{"country_to_provinces": MapManager.country_to_provinces.duplicate(), "provinces": {}}
	}

	# CORRECTED: Collect Province Data as Raw Dictionaries
	for p_id in MapManager.province_objects:
		var p_obj = MapManager.province_objects[p_id]
		save_data["map_state"]["provinces"][p_id] = p_obj.get_raw_state()

	# Collect Countries
	for c_name in CountryManager.countries:
		save_data["countries"][c_name] = CountryManager.countries[c_name].get_raw_state()

	# Collect Troops
	for troop in TroopManager.troops:
		save_data["troops"].append(troop.get_raw_state())

	var file = FileAccess.open("user://saves/" + slot + ".dat", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()
	print("Rebel Save (Corrected) Complete.")


func load_game_rebel(slot: String):
	var path = "user://saves/" + slot + ".dat"
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var data = file.get_var()
	file.close()

	# 1. PURGE (Visuals and Managers)
	_purge_game_state()

	# 2. RESTORE MAP & PROVINCES
	if data.has("map_state"):
		MapManager.country_to_provinces = data["map_state"]["country_to_provinces"]

		var p_data_map = data["map_state"]["provinces"]
		for p_id in p_data_map:
			# Godot might load keys as Strings or Ints depending on the version
			# We cast to int to be safe
			var id_int = int(p_id)
			if MapManager.province_objects.has(id_int):
				var p_obj = MapManager.province_objects[id_int]
				_apply_raw_data(p_obj, p_data_map[p_id])
				p_obj.troops_here = []  # Clear the old troop list

	# 3. RESTORE COUNTRIES
	for c_name in data["countries"]:
		var country_obj = CountryData.new(c_name)
		_apply_raw_data(country_obj, data["countries"][c_name])
		CountryManager.countries[c_name] = country_obj

	# 4. RESTORE TROOPS
	for t_raw in data["troops"]:
		var t_obj = load("res://Scripts/TroopData.gd").new()
		_apply_raw_data(t_obj, t_raw)

		t_obj.country_obj = CountryManager.get_country(t_obj.country_name)
		TroopManager.troops.append(t_obj)
		TroopManager._add_troop_to_indexes(t_obj)

		if t_obj.is_moving:
			TroopManager.moving_troops.append(t_obj)
		else:
			# Snap position
			var center = MapManager.province_centers.get(t_obj.province_id, t_obj.position)
			t_obj.position = center
			t_obj.set_meta("start_pos", center)

	# --- PHASE 5: THE FINAL RE-LINK ---
	for p_id in MapManager.province_objects:
		var p_obj = MapManager.province_objects[p_id]

		# Only try to link if there is an owner name
		if p_obj.country != "" and p_obj.country != null:
			var found_country = CountryManager.get_country(p_obj.country)

			if found_country != null:
				# Now this works because we added 'country_obj' to Province.gd
				p_obj.country_obj = found_country
			else:
				# If it's a sea province or unclaimed land, set it to null safely
				p_obj.country_obj = null
		else:
			p_obj.country_obj = null

	CountryManager.set_player_country(data["player_country"])
	if MapManager.has_method("refresh_all_province_colors"):
		MapManager.refresh_all_province_colors()

	print("Full Rebel Load Complete. Factories and Ports restored.")


# Helper to apply data and metadata safely
func _apply_raw_data(obj: Object, raw_data: Variant):
	if raw_data == null:
		return

	# If it's a Dictionary (The Rebel Way)
	if raw_data is Dictionary:
		for key in raw_data:
			if key == "_metadata":
				for m_key in raw_data[key]:
					obj.set_meta(m_key, raw_data[key][m_key])
			else:
				obj.set(key, raw_data[key])

	# If it's an Object (The Godot Resource Way - Fallback)
	elif raw_data is Object:
		for prop in raw_data.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				obj.set(prop.name, raw_data.get(prop.name))


func _purge_game_state():
	# Clear visuals
	if has_node("TroopRenderer"):
		for child in get_node("TroopRenderer").get_children():
			child.queue_free()

	# Clear Logic
	CountryManager.countries.clear()
	TroopManager.troops.clear()
	TroopManager.moving_troops.clear()
	#TroopManager.troops_by_country.clear()
	for p in MapManager.province_objects.values():
		p.troops_here = []
