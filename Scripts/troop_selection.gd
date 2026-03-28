extends Node2D
class_name TroopSelection

# --- Constants ---
const CLICK_THRESHOLD := 2.0  # pixels

# --- State ---
var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO

var selected_troops: Array[TroopData] = []

# Optional: If you want to draw the selection box directly from this script
func _process(_delta: float) -> void:
	if dragging:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if Console.is_visible():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_mouse(event)
			
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func deselect_all() -> void:
	selected_troops.clear()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if dragging:
		# Use event.position (Screen Space) instead of global world position
		drag_end = event.position 
		var drag_distance = drag_start.distance_to(drag_end)

		if drag_distance >= CLICK_THRESHOLD:
			_perform_selection()

func _handle_left_mouse(event: InputEventMouseButton) -> void:
	# If you have a UI block check, keep it here
	if !dragging and MapManager._is_mouse_over_ui():
		return
		
	if event.pressed:
		dragging = true
		drag_start = event.position # Screen coordinates
		drag_end = drag_start
	else:
		if not dragging:
			return
		
		dragging = false
		drag_end = event.position
		
		_perform_selection()
		queue_redraw() # Clear the drawn box
		
		if selected_troops.size() > 0:
			MusicManager.play_sfx(MusicManager.SFX.TROOP_SELECTED)

func _perform_selection() -> void:
	# 1. Create a clean rectangle out of the drag points (in Screen Space)
	var selection_rect = Rect2(drag_start, drag_end - drag_start).abs()

	# 2. Additive selection (holding Shift)
	var additive = Input.is_key_pressed(KEY_SHIFT)
	if not additive:
		selected_troops.clear()

	# 3. Get the canvas transform to convert World Position to Screen Position
	var canvas_transform = get_viewport().get_canvas_transform()

	for t in CountryManager.player_country.troops_country:
		# Convert the troop's world position to where it appears on your monitor
		var world_pos = t.position
		var screen_pos = canvas_transform * world_pos 
		
		# If the troop's screen position is inside the dragged box, select it!
		if selection_rect.has_point(screen_pos):
			if not selected_troops.has(t):
				selected_troops.append(t)

# --- Visualizing the Drag Box ---
func _draw() -> void:
	if dragging:
		# Since we are drawing in a Node2D, we need to convert the screen drag
		# coordinates back into local canvas coordinates so it draws in the right spot
		var canvas_transform = get_viewport().get_canvas_transform()
		var inverse_transform = canvas_transform.affine_inverse()
		
		var local_start = inverse_transform * drag_start
		var local_end = inverse_transform * drag_end
		
		var rect = Rect2(local_start, local_end - local_start).abs()
		
		draw_rect(rect, Color(1, 1, 1, 0.3), true) # Fill
		draw_rect(rect, Color(1, 1, 1, 1.0), false, 2.0) # Outline
