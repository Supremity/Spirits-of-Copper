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

var heightmap_image: Image = null
func _ready():
	GameState.game_board = self
	setup_texture_array()
	generate_files()
	
	#MultiMeshInstance3D, target_id: float, density: int, chance: float, min_scale: float, max_scale: float
	spawn_objects(%ForestMultiMesh, 60, 3000, 0.7, 0.005, 0.01)
	spawn_grid(%MountainMultiMesh, 120, 150, 0.7, 0.009, 0.01) 
	
	if height_map:
		heightmap_image = height_map.get_image()
		if heightmap_image.is_compressed():
			heightmap_image.decompress()

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
	
func get_height_at_pos(global_pos: Vector3) -> float:
	if not heightmap_image:
		return 0.0

	# 1. Convert global 3D pos to UV
	var plane_size = mesh.size
	var uv_x = (global_pos.x / plane_size.x) + 0.5
	var uv_z = (global_pos.z / plane_size.y) + 0.5

	var px = clamp(int(uv_x * heightmap_image.get_width()), 0, heightmap_image.get_width() - 1)
	var py = clamp(int(uv_z * heightmap_image.get_height()), 0, heightmap_image.get_height() - 1)

	var current_height_range = 0.4
	return heightmap_image.get_pixel(px, py).r * current_height_range
	
	

func generate_files():
	# 1. THE SAFETY LOCK
	# If we are currently IN the Godot Editor (not the running game), STOP.
	if Engine.is_editor_hint():
		return

	var folder_path = "res://assets/flags/"
	var array_save_path = "res://assets/flags_texture_array.res"
	var json_save_path = "res://assets/flags_map.json"
	
	# 2. Check if files exist
	if FileAccess.file_exists(array_save_path) and FileAccess.file_exists(json_save_path):
		print("[Runtime] Flag files found. Assigning to TroopRenderer...")
		assign_to_troop_shader(array_save_path)
		return

	# 3. If files are missing, generate them (This will only happen the first time you play)
	print("[Runtime] Flag files missing. Generating for the first time...")
	
	var images: Array[Image] = []
	var mapping: Dictionary = {}
	var target_size = Vector2i.ZERO
	var current_index = 0
	
	var dir = DirAccess.open(folder_path)
	if !dir: 
		push_error("Flag directory not found at " + folder_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".png"):
			var tex = load(folder_path + file_name) as Texture2D
			if tex:
				var country_key = file_name.get_basename().trim_suffix("_flag")
				var img = tex.get_image()
				
				# Ensure all images match the first image's size
				if target_size == Vector2i.ZERO: target_size = img.get_size()
				if img.get_size() != target_size:
					img.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
				
				images.append(img)
				mapping[country_key] = current_index
				current_index += 1
		file_name = dir.get_next()

	# 4. Create and Save
	var tex_array = Texture2DArray.new()
	var err = tex_array.create_from_images(images)
	if err == OK:
		ResourceSaver.save(tex_array, array_save_path)
		
		var file = FileAccess.open(json_save_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(mapping, "\t"))
			file.close()
		
		assign_to_troop_shader(array_save_path)
		print("[Runtime] Flag generation successful.")

# Helper to update the TroopRenderer's ShaderMaterial
func assign_to_troop_shader(path: String):
	# Wait one frame to ensure the unique name is registered in the scene tree
	await get_tree().process_frame 
	
	var troop_renderer = get_node_or_null("%TroopRenderer3D")
	if not troop_renderer:
		push_warning("Could not find %TroopRenderer3D in the scene!")
		return
		
	var tex = load(path)
	
	# Check Material Override first (best practice)
	if troop_renderer.material_override is ShaderMaterial:
		troop_renderer.material_override.set_shader_parameter("flags", tex)
	# Check the Mesh surface material fallback
	elif troop_renderer.multimesh and troop_renderer.multimesh.mesh:
		var mat = troop_renderer.multimesh.mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("flags", tex)
