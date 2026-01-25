extends Node2D
class_name World

@onready var map_sprite: Sprite2D = $MapContainer/CultureSprite as Sprite2D
@onready var camera: Camera2D = $Camera2D as Camera2D
@onready var troop_renderer: CustomRenderer = $MapContainer/CustomRenderer as CustomRenderer

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
	CountryManager.set_player_country("peru")
	# For debugging purposes. Create some troops first
	MapManager.force_bidirectional_connections()

	var map_width := MapManager.id_map_image.get_width()
	var map_height := MapManager.id_map_image.get_height()

	var mat := ShaderMaterial.new()
	mat.shader = map_shader
	var id_tex := ImageTexture.create_from_image(MapManager.id_map_image)
	mat.set_shader_parameter("region_id_map", id_tex)
	mat.set_shader_parameter("state_colors", MapManager.state_color_texture)

	# @warning_ignore("narrowing_conversion")
	var type_img := Image.create_empty(map_width, map_height, false, Image.FORMAT_L8)
	var uncertain_pixels := []
# --- PASS 1: Direct Mapping ---
	for y in range(map_height):
		for x in range(map_width):
			var pid = MapManager._get_pid_fast(x, y)
			var province = MapManager.province_objects.get(pid)

			if province:
				if province.type == 0: # SEA
					type_img.set_pixel(x, y, Color(0, 0, 0))
				else: # LAND
					type_img.set_pixel(x, y, Color(1, 1, 1))
			else:
				# It's a border (PID 1 or null). Mark as uncertain for now.
				uncertain_pixels.append(Vector2i(x, y))

	# --- PASS 2: Intelligent Flood-Check ---
	for pos in uncertain_pixels:
		var touches_land = false
		var touches_sea = false
		
		# Check 8-way neighbors (Radius 1 ONLY - very important)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0: continue
				
				var nx = pos.x + dx
				var ny = pos.y + dy
				
				if nx >= 0 and nx < map_width and ny >= 0 and ny < map_height:
					var nid = MapManager._get_pid_fast(nx, ny)
					if nid > 1:
						var n_prov = MapManager.province_objects.get(nid)
						if n_prov:
							if n_prov.type != 0: touches_land = true
							else: touches_sea = true
		

		if touches_land:
			type_img.set_pixel(pos.x, pos.y, Color(1, 1, 1)) 
		else:
			# If it only touches sea (or nothing), it's a Sea Grid/Open Water
			type_img.set_pixel(pos.x, pos.y, Color(0, 0, 0))

	var type_tex = ImageTexture.create_from_image(type_img)
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
	$MapContainer.add_child(ghost)


func _input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and !event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		MapManager.handle_click(get_global_mouse_position(), map_sprite)
	if event is InputEventMouseMotion:
		MapManager.handle_hover(get_global_mouse_position(), map_sprite)
