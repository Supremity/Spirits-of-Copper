extends MeshInstance3D

# --- Existing Texture Exports ---
@export var grass_tex: Texture2D
@export var forest_tex: Texture2D
@export var sand_tex: Texture2D
@export var rock_tex: Texture2D
@export var ice_tex: Texture2D

# --- NEW: Spawner Exports ---
@export_group("Spawner Settings")
@export var tree_density: int = 3000 # Max attempts to plant
@export var biome_map: Texture2D     # Drag res://maps/biomes_id.png here
@export var height_map: Texture2D    # Drag res://maps/heightmap.png here

func _ready():
	GameState.game_board = self
	setup_texture_array()
	
	#MultiMeshInstance3D, target_id: float, density: int, chance: float, min_scale: float, max_scale: float
	spawn_objects(%ForestMultiMesh, 60, 3000, 0.7, 0.005, 0.01)
	spawn_grid(%MountainMultiMesh, 120, 150, 0.7, 0.009, 0.01) 

func setup_texture_array():
	var mat = get_surface_override_material(0)
	if not mat is ShaderMaterial:
		return

	var save_path = "res://textures/biome_texture_array.res"

	# --- STEP 1: CHECK IF FILE EXISTS ---
	if FileAccess.file_exists(save_path):
		print("Resource exists at ", save_path, ". Loading existing array...")
		var existing_array = load(save_path)
		mat.set_shader_parameter("terrain_textures", existing_array)
		return # This safely exits JUST this function now.

	# --- STEP 2: GENERATE ONLY IF MISSING ---
	print("No texture array found. Generating new one...")
	var texture_list = [grass_tex, forest_tex, sand_tex, rock_tex, ice_tex]
	var images: Array[Image] = []

	for i in range(texture_list.size()):
		var tex = texture_list[i]
		if tex:
			var img = tex.get_image()
			if img.is_compressed():
				img.decompress()
			
			img.clear_mipmaps()
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			images.append(img)
		else:
			push_error("Slot %d is empty!" % i)
			return

	var tex_array = Texture2DArray.new()
	var error = tex_array.create_from_images(images)
	
	if error == OK:
		# Save it so we never have to run this loop again
		ResourceSaver.save(tex_array, save_path)
		mat.set_shader_parameter("terrain_textures", tex_array)
		print("Success: New Texture Array saved and assigned.")
	else:
		push_error("Failed to create Texture2DArray. Error: ", error)

func spawn_objects(node: MultiMeshInstance3D, target_id: float, density: int, chance: float, min_scale: float, max_scale: float):
	var mm = node.multimesh
	var b_img = biome_map.get_image()
	var h_img = height_map.get_image()
	
	b_img.decompress()
	h_img.decompress()
	
	var plane_size = mesh.size 
	var current_height_range = 0.4 # Match your shader
	
	mm.instance_count = density
	var placed_count = 0
	
	for i in range(density):
		var uv = Vector2(randf(), randf())
		var px = clamp(int(uv.x * b_img.get_width()), 0, b_img.get_width() - 1)
		var py = clamp(int(uv.y * b_img.get_height()), 0, b_img.get_height() - 1)
		
		var red_val = b_img.get_pixel(px, py).r * 255.0
		
		# Check if we are in the right biome
		if abs(red_val - target_id) < 5.0:
			if randf() < chance:
				var x_pos = (uv.x - 0.5) * plane_size.x
				var z_pos = (uv.y - 0.5) * plane_size.y
				var y_pos = h_img.get_pixel(px, py).r * current_height_range
				
				var pos = Vector3(x_pos, y_pos, z_pos)
				var basis = Basis().rotated(Vector3.UP, randf_range(0, TAU))
				basis = basis.scaled(Vector3.ONE * randf_range(min_scale, max_scale))
				
				mm.set_instance_transform(placed_count, Transform3D(basis, pos))
				placed_count += 1
				
	mm.visible_instance_count = placed_count
	print("Spawned ", placed_count, " items for ID ", target_id)
	
func spawn_grid(node: MultiMeshInstance3D, target_id: float, grid_res: int, spawn_chance: float, min_scale: float, max_scale: float):
	var mm = node.multimesh
	var b_img = biome_map.get_image()
	var h_img = height_map.get_image()
	
	# Essential for reading pixels
	b_img.decompress()
	h_img.decompress()
	
	var plane_size = mesh.size
	var current_height_range = 0.4
	
	# Set total possible slots (Grid X * Grid Z)
	mm.instance_count = grid_res * grid_res
	var placed_count = 0

	for x in range(grid_res):
		for z in range(grid_res):
			# 1. Calculate the base UV for this grid cell
			var uv = Vector2(float(x) / grid_res, float(z) / grid_res)
			
			# 2. Add "Jitter" (Randomness) so it looks natural
			# This moves the object slightly off the perfect grid center
			var jitter = Vector2(randf_range(-0.5, 0.5) / grid_res, randf_range(-0.5, 0.5) / grid_res)
			var final_uv = (uv + jitter).clamp(Vector2.ZERO, Vector2(0.99, 0.99))

			# 3. Check Biome Map
			var px = int(final_uv.x * b_img.get_width())
			var py = int(final_uv.y * b_img.get_height())
			var red_val = b_img.get_pixel(px, py).r * 255.0
			
			if abs(red_val - target_id) < 5.0:
				# 4. Roll the dice (Density/Chance)
				if randf() < spawn_chance:
					# Calculate 3D Position
					var x_pos = (final_uv.x - 0.5) * plane_size.x
					var z_pos = (final_uv.y - 0.5) * plane_size.y
					var y_pos = h_img.get_pixel(px, py).r * current_height_range
					
					# Create Transform (Rotation + Scale)
					var basis = Basis().rotated(Vector3.UP, randf_range(0, TAU))
					var s = randf_range(min_scale, max_scale)
					basis = basis.scaled(Vector3(s, s, s))
					
					mm.set_instance_transform(placed_count, Transform3D(basis, Vector3(x_pos, y_pos, z_pos)))
					placed_count += 1
					
	# Hide the empty slots we didn't use
	mm.visible_instance_count = placed_count
	print("Done! Placed ", placed_count, " objects for ID ", target_id)
