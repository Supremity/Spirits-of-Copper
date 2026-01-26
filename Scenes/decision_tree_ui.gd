extends CanvasLayer

# --- CONFIGURATION ---
const MOVE_SPEED = 800.0   
const GRID_SIZE = 60.0     
const LINE_WIDTH = 4.0
const NODE_SIZE = Vector2(220, 90)

# Colors (No transparency)
const COL_BG = Color(0.05, 0.05, 0.05, 1.0) # Solid Black-Grey
const COL_GRID = Color(0.2, 0.2, 0.2, 1.0)  # Visible Grey Grid
const COL_LINE_INACTIVE = Color(0.3, 0.3, 0.3)
const COL_LINE_ACTIVE = Color(0.2, 0.8, 0.2)

# --- NODES ---
var tree_canvas: Control      
var tabs_container: HBoxContainer
var info_text: RichTextLabel
var info_panel: Panel

var current_category: String = "Economy"
var node_buttons: Dictionary = {} 
var connection_lines: Array = [] 

func _ready():
	layer = 100
	hide()
	DecisionManager.ui_overlay = self
	_create_full_ui()

func _process(delta: float) -> void:
	if visible:
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input != Vector2.ZERO:
			tree_canvas.position -= input * MOVE_SPEED * delta
			tree_canvas.queue_redraw()

func _create_full_ui():
	# 1. SOLID BACKGROUND
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 2. THE MOVABLE CANVAS
	tree_canvas = Control.new()
	tree_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_canvas.draw.connect(_on_draw_canvas)
	add_child(tree_canvas)
	
	# 3. STATIC UI LAYER (Header/Footer)
	var ui_layer = Control.new()
	ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)
	
	# --- HEADER ---
	var header = Panel.new()
	header.custom_minimum_size.y = 80
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ui_layer.add_child(header)
	
	tabs_container = HBoxContainer.new()
	tabs_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	tabs_container.position = Vector2(20, 0)
	tabs_container.add_theme_constant_override("separation", 15)
	header.add_child(tabs_container)
	
	# --- CLOSE BUTTON (Reliable Placement) ---
	var close_btn = Button.new()
	close_btn.text = "  CLOSE MENU [X]  "
	close_btn.custom_minimum_size = Vector2(150, 40)
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.position.x -= 20 # Offset from right edge
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	header.add_child(close_btn)
	
	# --- FOOTER (The Description Box) ---
	info_panel = Panel.new()
	info_panel.custom_minimum_size.y = 160
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ui_layer.add_child(info_panel)
	
	info_text = RichTextLabel.new()
	info_text.bbcode_enabled = true
	info_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Add some internal margin
	info_text.offset_left = 30
	info_text.offset_top = 20
	info_text.offset_right = -30
	info_text.offset_bottom = -10
	info_text.text = "[center][color=gray]Hover over a node to see info[/color][/center]"
	info_panel.add_child(info_text)

# --- LOGIC ---
func open_menu():
	show()
	_rebuild_tabs()
	_load_category(current_category)
	GameState.decision_menu_open = true
	_toggle_pause(true)

func close_menu():
	hide()
	GameState.decision_menu_open = false
	_toggle_pause(false)

func _toggle_pause(pause: bool):
	var world = GameState.current_world
	if world:
		world.set_process(!pause)
		world.clock.set_process(!pause)
		var cam = world.find_child("CameraController", true, false)
		if cam: cam.set_process(!pause)
	TroopManager.set_process(!pause)

func _rebuild_tabs():
	for c in tabs_container.get_children(): c.queue_free()
	for cat in DecisionManager.categories.keys():
		var btn = Button.new()
		btn.text = " " + cat.to_upper() + " "
		btn.toggle_mode = true
		btn.button_pressed = (cat == current_category)
		btn.pressed.connect(func(): 
			current_category = cat
			_rebuild_tabs() 
			_load_category(cat)
		)
		tabs_container.add_child(btn)

func _load_category(cat_name: String):
	for c in tree_canvas.get_children(): c.queue_free()
	node_buttons.clear()
	connection_lines.clear()
	tree_canvas.position = Vector2.ZERO
	
	var nodes = DecisionManager.categories[cat_name]
	var player = CountryManager.player_country
	
	for i in range(nodes.size()):
		_create_node(nodes[i], i, player)
	
	for node in nodes:
		if node.has("prereq"):
			var start = _get_node_center(nodes, node["prereq"])
			var end = Vector2(node["pos"][0], node["pos"][1]) + (NODE_SIZE/2)
			if start != Vector2.ZERO:
				connection_lines.append({"from": start, "to": end, "active": player.has_meta("finished_" + node["prereq"])})
	tree_canvas.queue_redraw()

func _create_node(data: Dictionary, idx: int, player: CountryData):
	var btn = Button.new()
	btn.position = Vector2(data["pos"][0], data["pos"][1])
	btn.custom_minimum_size = NODE_SIZE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP # Ensures hover works
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Events
	btn.mouse_entered.connect(func(): _show_info(data))
	btn.mouse_exited.connect(func(): _reset_info())
	btn.pressed.connect(func(): DecisionManager.start_decision(player, current_category, idx))
	
	_apply_node_style(btn, data, player)
	btn.set_meta("id", data["id"])
	btn.set_meta("idx", idx)
	node_buttons[data["id"]] = btn
	tree_canvas.add_child(btn)

func _show_info(data: Dictionary):
	info_text.text = "[b][font_size=26][color=yellow]%s[/color][/font_size][/b]\n" % data["title"]
	info_text.text += "[font_size=18][i]%s[/i][/font_size]\n\n" % data.get("desc", "")
	info_text.text += "[color=orange]Time: %d Days | Cost: %d Political Power[/color]" % [data["days"], data["cost_pp"]]

func _reset_info():
	info_text.text = "[center][color=gray]Hover over a node to see info[/color][/center]"

func _apply_node_style(btn: Button, data: Dictionary, player: CountryData):
	var id = data["id"]
	var finished = player.has_meta("finished_" + id)
	var progressing = DecisionManager.is_in_progress(player, id)
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_bottom = 4
	
	if finished:
		btn.text = data["title"] + "\n[DONE]"
		style.bg_color = Color(0.1, 0.4, 0.1)
		btn.disabled = true
	elif progressing:
		var days_left = DecisionManager.get_days_left(player, id)
		btn.text = data["title"] + "\n⌛ %d Days" % days_left
		style.bg_color = Color(0.1, 0.2, 0.5) # Dark Blue
		btn.disabled = true
	else:
		btn.text = data["title"] + "\n%d PP" % data["cost_pp"]
		style.bg_color = Color(0.2, 0.2, 0.2)
		btn.disabled = player.political_power < data["cost_pp"]
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("hover", style)

func _on_draw_canvas():
	var vp_size = get_viewport().size
	var cam_offset = -tree_canvas.position   

	var start_x = int(floor(cam_offset.x / GRID_SIZE)) - 2
	var end_x   = start_x + int(vp_size.x / GRID_SIZE) + 4
	var start_y = int(floor(cam_offset.y / GRID_SIZE)) - 2
	var end_y   = start_y + int(vp_size.y / GRID_SIZE) + 4

	# --- GRID ---
	for x in range(start_x, end_x):
		var lx = x * GRID_SIZE
		tree_canvas.draw_line(
			Vector2(lx, cam_offset.y - 10000),
			Vector2(lx, cam_offset.y + 10000),
			COL_GRID,
			1.0
		)

	for y in range(start_y, end_y):
		var ly = y * GRID_SIZE
		tree_canvas.draw_line(
			Vector2(cam_offset.x - 10000, ly),
			Vector2(cam_offset.x + 10000, ly),
			COL_GRID,
			1.0
		)

	# --- CONNECTIONS ---
	for line in connection_lines:
		var col = COL_LINE_ACTIVE if line["active"] else COL_LINE_INACTIVE
		tree_canvas.draw_line(line["from"], line["to"], col, LINE_WIDTH)


func _get_node_center(nodes: Array, id: String) -> Vector2:
	for n in nodes:
		if n["id"] == id: return Vector2(n["pos"][0], n["pos"][1]) + (NODE_SIZE/2)
	return Vector2.ZERO

func refresh_status_only():
	if not visible: return
	var player = CountryManager.player_country
	var nodes = DecisionManager.categories[current_category]
	for btn in node_buttons.values():
		_apply_node_style(btn, nodes[btn.get_meta("idx")], player)
	tree_canvas.queue_redraw()
