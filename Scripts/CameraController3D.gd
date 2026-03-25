extends Node3D

# --- References ---
@export_group("Nodes")
@export var map_plane: MeshInstance3D
@export var map_resolution: Vector2 = Vector2(4096, 2048)

@onready var camera: Camera3D = get_parent()

# --- Speed & Feel ---
@export_group("Movement")
@export var base_speed: float = 120.0     # FAST base speed
@export var acceleration: float = 12.0    # How fast it hits top speed
@export var friction: float = 10.0        # How fast it stops
@export var zoom_speed: float = 45.0      # Zoom "jump" distance

@export_group("Zoom & Tilt")
@export var min_height: float = 5.0
@export var max_height: float = 60.0
@export var tilt_near: float = -30.0      # Angle when zoomed in
@export var tilt_far: float = -85.0       # Angle when zoomed out

# --- Internal Variables ---
var target_pos: Vector3
var target_height: float
var velocity: Vector3 = Vector3.ZERO
var is_dragging := false

func _ready() -> void:
	target_pos = camera.global_position
	target_height = camera.global_position.y

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
		# Dragging speed scales with height
		var zoom_factor = (camera.global_position.y / max_height)
		target_pos.x -= event.relative.x * 0.05 * zoom_factor
		target_pos.z -= event.relative.y * 0.05 * zoom_factor

	# Zoom (Scroll Wheel)
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_height -= zoom_speed * 0.2
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_height += zoom_speed * 0.2
		
		target_height = clamp(target_height, min_height, max_height)

	# Click Translation (Forwarding to MapManager)
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_handle_raycast_click(event)

func _handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Move faster when zoomed out, slower when zoomed in
	var zoom_factor = (camera.global_position.y / max_height)
	var speed_multiplier = base_speed * (0.5 + zoom_factor)
	
	var desired_velocity = Vector3(input_dir.x, 0, input_dir.y) * speed_multiplier
	
	if desired_velocity.length() > 0:
		velocity = velocity.lerp(desired_velocity, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, friction * delta)
	
	target_pos += velocity * delta

func _apply_smoothing(delta: float) -> void:
	# 1. Smoothly transition position
	camera.global_position.x = lerp(camera.global_position.x, target_pos.x, 15.0 * delta)
	camera.global_position.z = lerp(camera.global_position.z, target_pos.z, 15.0 * delta)
	camera.global_position.y = lerp(camera.global_position.y, target_height, 10.0 * delta)

	# 2. Dynamic Tilt Calculation
	# 0.0 = Near, 1.0 = Far
	var zoom_t = (camera.global_position.y - min_height) / (max_height - min_height)
	
	# We use a curve (pow) so it stays tilted longer, then flattens quickly at the top
	var tilt_curve = pow(zoom_t, 1.2) 
	var current_tilt = lerp(tilt_near, tilt_far, tilt_curve)
	
	camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, current_tilt, 8.0 * delta)

func _handle_raycast_click(event: InputEvent) -> void:
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 2000
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
	if camera.global_position.x > world_width / 2.0:
		camera.global_position.x -= world_width
		target_pos.x -= world_width # Sync target to prevent snap-back
	elif camera.global_position.x < -world_width / 2.0:
		camera.global_position.x += world_width
		target_pos.x += world_width

func _is_mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null
