extends Node2D
class_name MapContainer

@onready var map_sprite: Sprite2D = $CultureSprite as Sprite2D

@export var map_shader: Shader
@export var clock: GameClock

var water_offset: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	GameState.current_map = self

func _ready() -> void:
	# Reference the clock from GameState since the node tree has changed	
	_setup_shader_material()

func _process(_delta: float) -> void:
	# We only need to update the animated water offset here.
	# The 3D camera handles scrolling and wrapping now!
	if map_sprite.material and is_instance_valid(clock) and !clock.paused:
		var move_amount = clock.time_scale * 0.001 * _delta
		water_offset.x += move_amount
		map_sprite.material.set_shader_parameter("ocean_offset", water_offset)

func _setup_shader_material() -> void:
	if not MapManager.id_map_image:
		push_error("MapContainer: MapManager.id_map_image is null!")
		return

	var map_width := MapManager.id_map_image.get_width()
	var map_height := MapManager.id_map_image.get_height()

	var mat := ShaderMaterial.new()
	mat.shader = map_shader
	
	# 1. Setup Textures
	var id_tex := ImageTexture.create_from_image(MapManager.id_map_image)
	mat.set_shader_parameter("region_id_map", id_tex)
	mat.set_shader_parameter("state_colors", MapManager.state_color_texture)

	var type_tex = MapManager.generate_type_mask()
	mat.set_shader_parameter("type_map", type_tex)

	# 2. Setup Water Noise
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

	# 3. Setup Constants
	mat.set_shader_parameter("original_texture", map_sprite.texture)
	mat.set_shader_parameter("sea_speed", 0.00) 
	mat.set_shader_parameter("tex_size", Vector2(map_width, map_height))
	mat.set_shader_parameter("country_border_color", Color.BLACK)

	map_sprite.material = mat
	
	# NOTE: We no longer call _create_ghost_map here.
	# The 3D GameBoard material handles infinite wrapping by repeating the texture!
