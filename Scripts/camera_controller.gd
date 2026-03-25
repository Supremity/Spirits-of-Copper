extends Node

# --- Node References ---
@export var camera: Camera3D
@export var map_plane: MeshInstance3D
@export var map_resolution: Vector2 = Vector2(4096, 2048) # Map pixel size
@export var base_speed: float = 20.0
@export var zoom_speed: float = 2.0
@export var min_height: float = 5.0
@export var max_height: float = 40.0

var is_dragging := false

# --- Cinematic Mode ---
var cinematic_mode := false
var auto_target := Vector3.ZERO
var auto_change_timer := 0.0
@export var auto_speed := 5.0
@export var auto_min_time := 3.0
@export var auto_max_time := 8.0

func _process(delta: float) -> void:
	if Console.is_visible() or GameState.decision_menu_open:
		return

	if cinematic_mode:
		_move_map_around(delta)
	else:
		_handle_keyboard_movement(delta)
		_handle_wrapping()

func _is_mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func _input(event: InputEvent) -> void:
	if Console.is_visible() or _is_mouse_over_ui():
		return

	# Middle Mouse Drag
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_dragging = event.pressed
		get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and is_dragging:
		var height_factor = camera.global_position.y / max_height
		camera.global_position.x -= event.relative.x * 0.02 * height_factor
		camera.global_position.z -= event.relative.y * 0.02 * height_factor

	# Scroll Zoom
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_perform_zoom(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_perform_zoom(-1)

	# Click / Hover
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_handle_raycast_click(event)


func _handle_keyboard_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var current_speed = base_speed * (camera.global_position.y / max_height)
	camera.global_position.x += input_dir.x * current_speed * delta
	camera.global_position.z += input_dir.y * current_speed * delta


func _perform_zoom(direction: int) -> void:
	# Move camera along its local Z (forward/back)
	var zoom_vector = camera.transform.basis.z * (-direction * zoom_speed)
	var new_pos = camera.global_position + zoom_vector
	if new_pos.y >= min_height and new_pos.y <= max_height:
		camera.global_position = new_pos


func _handle_raycast_click(event: InputEvent) -> void:
	if not map_plane: return
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 2000
	var plane = Plane(Vector3.UP, map_plane.global_position.y)
	var intersection = plane.intersects_ray(from, to)
	if intersection != null:
		var local_pos = map_plane.to_local(intersection)
		var plane_size = map_plane.mesh.size
		var uv = Vector2(
			(local_pos.x / plane_size.x) + 0.5,
			(local_pos.z / plane_size.y) + 0.5
		)
		var pixel_pos = Vector2(uv.x * map_resolution.x, uv.y * map_resolution.y)
		pixel_pos.x = wrapf(pixel_pos.x, 0.0, map_resolution.x)
		pixel_pos.y = clampf(pixel_pos.y, 0.0, map_resolution.y)
		_forward_to_map_manager(event, pixel_pos)


func _forward_to_map_manager(event: InputEvent, pos: Vector2) -> void:
	if not GameState.current_map: return
	var map_sprite = GameState.current_map.map_sprite
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			MapManager.handle_click_down(pos, map_sprite)
		else:
			MapManager.handle_click(pos, map_sprite)
	elif event is InputEventMouseMotion:
		MapManager.handle_hover(pos, map_sprite)


func _handle_wrapping() -> void:
	if not map_plane or not map_plane.mesh: return
	var world_width = map_plane.mesh.size.x
	# Horizontal wrap
	if camera.global_position.x > world_width / 2.0:
		camera.global_position.x -= world_width
	elif camera.global_position.x < -world_width / 2.0:
		camera.global_position.x += world_width
	# Vertical clamp
	var half_height = map_plane.mesh.size.y / 2.0
	camera.global_position.z = clamp(camera.global_position.z, -half_height, half_height)


func _move_map_around(delta: float) -> void:
	if not map_plane: return
	var map_width = map_plane.mesh.size.x
	var map_height = map_plane.mesh.size.y
	auto_change_timer -= delta
	if auto_change_timer <= 0.0:
		auto_target = Vector3(
			randf_range(-map_width * 0.5, map_width * 0.5),
			camera.global_position.y,
			randf_range(-map_height * 0.5, map_height * 0.5)
		)
		auto_change_timer = randf_range(auto_min_time, auto_max_time)
		if randi() % 3 == 0:
			auto_target.y = randf_range(min_height + 5, max_height - 5)
	camera.global_position = camera.global_position.lerp(auto_target, delta * 0.5)
