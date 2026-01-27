extends CanvasLayer

var sidebar_panel: PanelContainer
var summary_label: Label
var loser_label: Label

var current_winner: CountryData
var current_loser: CountryData
var provinces_to_take: Array = []
var hovered_pid: int = -1

func _ready() -> void:
	_setup_ui_elements()
	self.hide()

func _setup_ui_elements():
	# Sidebar Setup (Left 25%)
	sidebar_panel = PanelContainer.new()
	sidebar_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	var screen_width = get_viewport().get_visible_rect().size.x
	sidebar_panel.custom_minimum_size.x = screen_width * 0.25
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_width_right = 2
	style.border_color = Color(0.8, 0.7, 0.3)
	sidebar_panel.add_theme_stylebox_override("panel", style)
	add_child(sidebar_panel)

	var margin = MarginContainer.new()
	margin.set_indexed("theme_override_constants/margin_left", 20)
	margin.set_indexed("theme_override_constants/margin_top", 40)
	sidebar_panel.add_child(margin)

	var v_box = VBoxContainer.new()
	v_box.set_indexed("theme_override_constants/separation", 20)
	margin.add_child(v_box)

	loser_label = Label.new()
	loser_label.add_theme_font_size_override("font_size", 22)
	v_box.add_child(loser_label)

	summary_label = Label.new()
	v_box.add_child(summary_label)

	var confirm_btn = Button.new()
	confirm_btn.text = "SIGN TREATY"
	confirm_btn.custom_minimum_size.y = 50
	confirm_btn.pressed.connect(_on_confirm_pressed)
	v_box.add_child(confirm_btn)

func _input(event: InputEvent) -> void:
	if not self.visible: return
	
	# 1. Ignore input if clicking on the sidebar itself
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos.x < sidebar_panel.size.x: return

	# 2. Convert Screen position to Map/World position
	# We use the World's camera to get the correct global coordinates
	var world = GameState.current_world
	if not world: return
	
	var map_pos = world.get_global_mouse_position()

	# 3. Handle Hover/Click using the world-mapped coordinates
	if event is InputEventMouseMotion:
		_process_hover(map_pos)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_process_click(map_pos)

func _process_hover(map_pos: Vector2):
	# 1. Get the PID using your radius logic
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)
		
	if pid != hovered_pid:
		# 2. Reset the visual of the PREVIOUS hovered province
		if hovered_pid > 1:
			_reset_province_visual(hovered_pid)
		
		hovered_pid = pid
		
		# 3. Apply NEW hover visual (if it's a valid land province belonging to the loser)
		if hovered_pid > 1:
			var owner = MapManager.province_to_country.get(hovered_pid, "")
			if owner == current_loser.country_name:
				_update_map_visual(hovered_pid, Color(1.5, 1.5, 1.5)) 
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process_click(map_pos: Vector2):
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)
	if pid <= 1: return 

	var owner_name = MapManager.province_to_country.get(pid, "")
	if owner_name != current_loser.country_name: return 

	if provinces_to_take.has(pid):
		provinces_to_take.erase(pid)
		# On deselect, return to hover state or normal state
		_update_map_visual(pid, Color(1.5, 1.5, 1.5)) 
	else:
		provinces_to_take.append(pid)
		# On select, make it a distinct color (e.g., Cyan or the Player's color)
		_update_map_visual(pid, Color(0.0, 1.0, 1.0)) 
	
	_update_summary()

# --- Logic & Integration ---

func open_menu(winner: CountryData, loser: CountryData):
	self.show()
	current_winner = winner
	current_loser = loser
	provinces_to_take.clear()
	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui: game_ui.visible = false
	GameState.current_world.clock.pause()
	loser_label.text = "Negotations: %s" % loser.country_name
	GameState.in_peace_process = true
	_update_summary()
	
func _update_summary():
	summary_label.text = "Selected Provinces: %d" % provinces_to_take.size()

func _on_confirm_pressed():
	for pid in provinces_to_take:
		MapManager.transfer_ownership(pid, current_winner.country_name)
	
	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui: game_ui.visible = true
	GameState.in_peace_process = false
	GameState.current_world.clock.resume()

	self.hide()

# Your existing logic function
func get_province_with_radius(global_pos: Vector2, map_sprite: Sprite2D, radius: int) -> int:
	# This uses the code logic you already have in MapManager
	return MapManager.get_province_with_radius(global_pos, map_sprite, radius)

func _update_map_visual(pid: int, color: Color):
	# We call MapManager's lookup update to refresh the shader texture
	if MapManager.has_method("_update_lookup"):
		MapManager._update_lookup(pid, color)

func _reset_province_visual(pid: int):
	# If it's currently selected, keep the selected color
	if provinces_to_take.has(pid):
		_update_map_visual(pid, Color(0.0, 1.0, 1.0))
	else:
		# Otherwise, revert to the original country color
		var country = MapManager.province_to_country[pid]
		if country != "sea":
			var original_color = MapManager.country_colors[country]
			_update_map_visual(pid, original_color)
