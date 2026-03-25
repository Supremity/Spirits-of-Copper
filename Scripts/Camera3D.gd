extends Camera3D # Changed from Node3D to Camera3D for direct control

# --- References ---
@export_group("Nodes")
@export var map_plane: MeshInstance3D
@export var map_resolution: Vector2 = Vector2(1275, 625)

# --- Speed & Feel ---
@export_group("Movement")
@export var base_speed: float = 30.0
@export var acceleration: float = 6.0
@export var friction: float = 10.0

@export_group("Zoom & Tilt")
@export var zoom_speed: float = 0.4        # Amount to move per scroll
@export var min_height: float = 0.5        # Closest you can get
@export var max_height: float = 10.0       # Furthest you can pull back
@export var tilt_near: float = -50.0    
@export var tilt_far: float = -90.0 

# --- Internal Variables ---
var target_pos: Vector3
var target_height: float
var velocity: Vector3 = Vector3.ZERO
var is_dragging := false

func _ready() -> void:
	# Force current height into the limits immediately
	global_position.y = clamp(global_position.y, min_height, max_height)
	
	target_pos = global_position
	target_height = global_position.y
	
	print("Camera Bound to: ", target_height)

func _process(delta: float) -> void:
	if Console.is_visible() or GameState.decision_menu_open:
		return

	_handle_movement(delta)
	_apply_smoothing(delta)
	_handle_wrapping()

func _input(event: InputEvent) -> void:
	if Console.is_visible() or _is_mouse_over_ui():
		return

	# Middle Mouse Drag
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_dragging = event.pressed
		get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and is_dragging:
		var zoom_factor = (global_position.y / max_height)
		target_pos.x -= event.relative.x * 0.05 * zoom_factor
		target_pos.z -= event.relative.y * 0.05 * zoom_factor

	# Zoom
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_height -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_height += zoom_speed
		
		target_height = clamp(target_height, min_height, max_height)

	# Raycasting
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_handle_raycast_click(event)

func _handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var zoom_factor = (global_position.y / max_height)
	var speed_multiplier = base_speed * (0.5 + zoom_factor)
	
	var desired_velocity = Vector3(input_dir.x, 0, input_dir.y) * speed_multiplier
	
	if desired_velocity.length() > 0:
		velocity = velocity.lerp(desired_velocity, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, friction * delta)
	
	target_pos += velocity * delta

func _apply_smoothing(delta: float) -> void:
	# 1. Smooth Position
	global_position.x = lerp(global_position.x, target_pos.x, 15.0 * delta)
	global_position.z = lerp(global_position.z, target_pos.z, 15.0 * delta)
	global_position.y = lerp(global_position.y, target_height, 10.0 * delta)

	# 2. Dynamic Tilt
	var zoom_t = (global_position.y - min_height) / (max_height - min_height)
	var tilt_curve = pow(zoom_t, 1.2) 
	var current_tilt = lerp(tilt_near, tilt_far, tilt_curve)
	
	rotation_degrees.x = lerp(rotation_degrees.x, current_tilt, 8.0 * delta)

func _handle_raycast_click(event: InputEvent) -> void:
	if not map_plane: return
	var from = project_ray_origin(event.position)
	var to = from + project_ray_normal(event.position) * 2000
	var plane = Plane(Vector3.UP, map_plane.global_position.y)
	var intersection = plane.intersects_ray(from, to)
	
	if intersection != null:
		var local_pos = map_plane.to_local(intersection)
		var plane_size = map_plane.mesh.size
		var uv = Vector2((local_pos.x / plane_size.x) + 0.5, (local_pos.z / plane_size.y) + 0.5)
		var pixel_pos = Vector2(uv.x * map_resolution.x, uv.y * map_resolution.y)
		pixel_pos.x = wrapf(pixel_pos.x, 0.0, map_resolution.x)
		pixel_pos.y = clampf(pixel_pos.y, 0.0, map_resolution.y)
		_forward_to_map_manager(event, pixel_pos)

func _forward_to_map_manager(event: InputEvent, pos: Vector2) -> void:
	if not GameState.current_map: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: MapManager.handle_click_down(pos, GameState.current_map.map_sprite)
		else: MapManager.handle_click(pos, GameState.current_map.map_sprite)
	elif event is InputEventMouseMotion:
		MapManager.handle_hover(pos, GameState.current_map.map_sprite)

func _handle_wrapping() -> void:
	if not map_plane or not map_plane.mesh: return
	var world_width = map_plane.mesh.size.x 
	if global_position.x > world_width / 2.0:
		global_position.x -= world_width
		target_pos.x -= world_width
	elif global_position.x < -world_width / 2.0:
		global_position.x += world_width
		target_pos.x += world_width

func _is_mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null
