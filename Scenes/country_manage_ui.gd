extends CanvasLayer
class_name CountryManageUI

#region --- Theme Configuration ---
const COLOR_BG_GLASS = Color(0.08, 0.09, 0.11, 0.96) # Deep dark blue-grey
const COLOR_PANEL_INNER = Color(0.15, 0.16, 0.19, 1.0)
const COLOR_ACCENT = Color(0.24, 0.65, 0.85) # Tech Blue
const COLOR_TEXT_HEADER = Color(0.9, 0.9, 0.9)
const COLOR_TEXT_DIM = Color(0.6, 0.6, 0.6)
const COLOR_POSITIVE = Color(0.4, 0.8, 0.4)
const COLOR_NEGATIVE = Color(0.85, 0.3, 0.3)
const COLOR_WARNING = Color(0.9, 0.7, 0.2)
#endregion

#region --- Nodes ---
var main_container: MarginContainer
var laws_grid: GridContainer

# Dynamic Labels
var header_label: Label
var flag_rect: TextureRect
var pp_label: Label # Political Power display
var money_display: Label
var manpower_display: Label

# Composition Labels
var comp_infantry: Label
var comp_tank: Label
var comp_artillery: Label
var income_breakdown_label: RichTextLabel # For the detailed tooltip style text

# Data
var current_country: CountryData
var _update_timer: float = 0.0
#endregion

func _ready() -> void:
	visible = false
	_build_ui()

func open_menu(country: CountryData) -> void:
	current_country = country
	_refresh_full_data()
	show()

func close_menu() -> void:
	hide()

func _process(delta: float) -> void:
	if not visible or not current_country: return
	
	# Update stats every frame for smooth numbers, but heavy calcs (army count) less often
	money_display.text = "$%s" % _format_money(current_country.money)
	pp_label.text = "%.1f PP" % current_country.political_power
	
	_update_timer += delta
	if _update_timer > 1.0:
		_update_timer = 0.0
		_refresh_army_counts() # Only count army once per second

#region --- UI Construction ---
func _build_ui() -> void:
	# 1. Root Container with Padding
	main_container = MarginContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("margin_left", 40)
	main_container.add_theme_constant_override("margin_right", 40)
	main_container.add_theme_constant_override("margin_top", 40)
	main_container.add_theme_constant_override("margin_bottom", 40)
	add_child(main_container)

	# 2. Main Background Panel (Glass Look)
	var bg_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_GLASS
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.35, 0.4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	bg_panel.add_theme_stylebox_override("panel", style)
	main_container.add_child(bg_panel)

	# 3. Vertical Layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	# Inner padding for the content
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	content_margin.add_child(vbox)
	bg_panel.add_child(content_margin)

	# --- Header ---
	var header_hbox = HBoxContainer.new()
	
	flag_rect = TextureRect.new()
	flag_rect.custom_minimum_size = Vector2(100, 60)
	flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Fix Purple: Create a grey placeholder instead of default gradient
	var placeholder = GradientTexture2D.new()
	placeholder.fill_to = Vector2(1,1) # slight gradient
	placeholder.gradient = Gradient.new()
	placeholder.gradient.set_color(0, Color(0.2, 0.2, 0.2)) # Grey
	placeholder.gradient.set_color(1, Color(0.3, 0.3, 0.3)) # Lighter Grey
	flag_rect.texture = placeholder
	
	var title_vbox = VBoxContainer.new()
	header_label = Label.new()
	header_label.text = "COUNTRY NAME"
	header_label.add_theme_font_size_override("font_size", 28)
	header_label.add_theme_color_override("font_color", COLOR_TEXT_HEADER)
	
	pp_label = Label.new()
	pp_label.text = "100 PP"
	pp_label.add_theme_color_override("font_color", COLOR_WARNING)
	
	title_vbox.add_child(header_label)
	title_vbox.add_child(pp_label)
	
	var close_btn = Button.new()
	close_btn.text = " DISMISS "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	
	header_hbox.add_child(flag_rect)
	header_hbox.add_child(VSeparator.new())
	header_hbox.add_child(title_vbox)
	header_hbox.add_spacer(false) # Expands to push close button right
	header_hbox.add_child(close_btn)
	vbox.add_child(header_hbox)
	vbox.add_child(HSeparator.new())

	# --- Main Content Split (Stats Left, Laws Right) ---
	var split = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 30)
	vbox.add_child(split)

	# --- LEFT COLUMN: Statistics ---
	var left_col = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 0.4 # Takes 40% width
	split.add_child(left_col)

	_create_section_header(left_col, "Economic Status")
	money_display = _create_stat_row(left_col, "Treasury", "$0.00")
	income_breakdown_label = RichTextLabel.new()
	income_breakdown_label.fit_content = true
	income_breakdown_label.scroll_active = false
	income_breakdown_label.bbcode_enabled = true
	income_breakdown_label.text = "[color=#aaaaaa]Income Breakdown...[/color]"
	left_col.add_child(income_breakdown_label)
	
	left_col.add_child(HSeparator.new())
	
	_create_section_header(left_col, "Army Logistics")
	manpower_display = _create_stat_row(left_col, "Active Personnel", "0")
	
	# Composition Grid
	var comp_panel = PanelContainer.new()
	var comp_style = StyleBoxFlat.new()
	comp_style.bg_color = COLOR_PANEL_INNER
	comp_style.corner_radius_top_left = 4
	comp_style.corner_radius_top_right = 4
	comp_style.corner_radius_bottom_right = 4
	comp_style.corner_radius_bottom_left = 4
	comp_panel.add_theme_stylebox_override("panel", comp_style)
	left_col.add_child(comp_panel)
	
	var comp_vbox = VBoxContainer.new()
	comp_vbox.add_theme_constant_override("separation", 4)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	m.add_child(comp_vbox)
	comp_panel.add_child(m)
	
	var comp_lbl = Label.new()
	comp_lbl.text = "DIVISION COMPOSITION"
	comp_lbl.add_theme_font_size_override("font_size", 12)
	comp_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	comp_vbox.add_child(comp_lbl)
	
	comp_infantry = _create_simple_row(comp_vbox, "Infantry")
	comp_tank = _create_simple_row(comp_vbox, "Armor")
	comp_artillery = _create_simple_row(comp_vbox, "Artillery")

	# --- RIGHT COLUMN: Laws ---
	var right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.6
	split.add_child(right_col)

	_create_section_header(right_col, "Conscription Laws")
	
	var law_desc = Label.new()
	law_desc.text = "Select a conscription policy. Stricter laws increase manpower but harm economic efficiency."
	law_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	law_desc.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	law_desc.add_theme_font_size_override("font_size", 14)
	right_col.add_child(law_desc)
	right_col.add_child(HSeparator.new())

	laws_grid = GridContainer.new()
	laws_grid.columns = 1 # List view
	laws_grid.add_theme_constant_override("v_separation", 10)
	right_col.add_child(laws_grid)
	

	_add_law_option("Volunteer Only", 0.005, 0.0, 0, "Professional army only.")
	_add_law_option("Limited Conscription", 0.01, 0.05, 150, "Drafting young men.")
	_add_law_option("Extensive Conscription", 0.015, 0.15, 150, "Wide-scale mobilization.")
	_add_law_option("Service by Requirement", 0.02, 0.30, 150, "All eligible adults must serve.")
	_add_law_option("All Adult Serve", 0.4, 0.50, 150, "Scraping the barrel.")

#endregion

#region --- Logic & Data Refresh ---
func _refresh_full_data() -> void:
	if not current_country: return
	header_label.text = current_country.country_name.to_upper()
	
	# Attempt to load specific flag, fallback to grey placeholder
	var flag_path = "res://flags/%s.png" % current_country.country_name
	if ResourceLoader.exists(flag_path):
		flag_rect.texture = load(flag_path)
	
	_refresh_army_counts()
	_update_law_buttons_visuals()

func _refresh_army_counts() -> void:
	# Recalculate army composition
	var counts = {"infantry": 0, "tank": 0, "artillery": 0}
	
	# Assuming TroopManager has this function as per your previous code
	var troops = TroopManager.get_troops_for_country(current_country.country_name)
	var total_divs = 0
	
	for troop in troops:
		for div in troop.stored_divisions:
			total_divs += 1
			# Assuming 'type' is a string key
			if counts.has(div.type):
				counts[div.type] += 1
			else:
				# Handle types we didn't hardcode
				counts[div.type] = 1 
	
	comp_infantry.text = str(counts.get("infantry", 0))
	comp_tank.text = str(counts.get("tank", 0))
	comp_artillery.text = str(counts.get("artillery", 0))
	
	# Detailed Manpower String
	var max_man = int(current_country.total_population * current_country.military_size_ratio)
	manpower_display.text = "%s / %s" % [_format_number(current_country.manpower), _format_number(max_man)]

	# Detailed Income String using BBCode
	var txt = ""
	txt += "[color=#cccccc]Base Income:[/color] [color=#88ff88]+$%.1f[/color]\n" % (current_country.gdp / 8760.0 * 0.2)
	txt += "[color=#cccccc]Factories:[/color] [color=#88ff88]+$%.1f[/color]\n" % (current_country.factories_amount * 1000.0)
	
	if current_country.economy_law_penalty > 0:
		var pen_pct = current_country.economy_law_penalty * 100.0
		txt += "[color=#ff8888]Law Penalty (-%.0f%%):[/color] [color=#ff5555]-$%.1f[/color]\n" % [pen_pct, current_country.hourly_money_income * current_country.economy_law_penalty]
	
	txt += "[color=#cccccc]Army Upkeep:[/color] [color=#ff5555]-$%.1f[/color]" % current_country.army_cost
	
	income_breakdown_label.text = txt

func _update_law_buttons_visuals() -> void:
	for btn in laws_grid.get_children():
		# Safety check: make sure this child has the metadata we expect
		if not btn.has_meta("ratio"): 
			continue
			
		var law_ratio = btn.get_meta("ratio")
		var cost = btn.get_meta("cost")
		var is_active = is_equal_approx(current_country.military_size_ratio, law_ratio)
		
		# Look for nodes using the exact internal path we built
		# Note: The MarginContainer we created didn't have a name, 
		# so Godot likely named it "MarginContainer" or "@MarginContainer@..."
		# To be safe, we'll find them by their class or specific names.
		var hbox = btn.get_child(0).get_child(0) # Panel -> MarginContainer -> HBox
		
		var title_lbl = hbox.get_node("Title")
		var status_lbl = hbox.get_node("Status")
		var cost_lbl = hbox.get_node("Cost")
		
		# Reset Style
		var style = btn.get_theme_stylebox("panel").duplicate()
		
		if is_active:
			style.bg_color = Color(0.2, 0.4, 0.2, 0.9) # Dark Green
			style.border_color = COLOR_POSITIVE
			status_lbl.text = " ACTIVE"
			status_lbl.add_theme_color_override("font_color", COLOR_POSITIVE)
			cost_lbl.visible = false
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			style.bg_color = COLOR_PANEL_INNER
			style.border_color = Color(0.3, 0.3, 0.3)
			status_lbl.text = ""
			cost_lbl.visible = true
			
			if current_country.political_power >= cost:
				cost_lbl.add_theme_color_override("font_color", COLOR_WARNING)
				btn.modulate = Color(1, 1, 1, 1)
				btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				cost_lbl.add_theme_color_override("font_color", COLOR_NEGATIVE)
				btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
				btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
				
		btn.add_theme_stylebox_override("panel", style)
#endregion

#region --- Helper Builders ---
func _create_section_header(parent: Node, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	parent.add_child(lbl)

func _create_stat_row(parent: Node, title: String, start_val: String) -> Label:
	var hbox = HBoxContainer.new()
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	var v = Label.new()
	v.text = start_val
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 18)
	
	hbox.add_child(t)
	hbox.add_child(v)
	parent.add_child(hbox)
	return v

func _create_simple_row(parent: Node, title: String) -> Label:
	var hbox = HBoxContainer.new()
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	
	var v = Label.new()
	v.text = "0"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	hbox.add_child(t)
	hbox.add_child(v)
	parent.add_child(hbox)
	return v

func _add_law_option(name: String, ratio: float, eco_penalty: float, cost: int, tooltip: String) -> void:
	var btn_panel = PanelContainer.new()
	btn_panel.custom_minimum_size = Vector2(0, 50)
	
	# Metadata storage for logic
	btn_panel.set_meta("ratio", ratio)
	btn_panel.set_meta("penalty", eco_penalty)
	btn_panel.set_meta("cost", cost)
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	btn_panel.add_theme_stylebox_override("panel", style)
	
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 15)
	m.add_theme_constant_override("margin_right", 15)
	btn_panel.add_child(m)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	m.add_child(hbox)
	
	var title = Label.new()
	title.name = "Title"
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Effect info (small text)
	var effect_lbl = Label.new()
	effect_lbl.text = "Pop: %.2f%% | Eco: -%.0f%%" % [ratio * 100.0, eco_penalty * 100.0]
	effect_lbl.add_theme_font_size_override("font_size", 12)
	effect_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	
	var cost_lbl = Label.new()
	cost_lbl.name = "Cost"
	cost_lbl.text = "%d PP" % cost
	
	var status_lbl = Label.new()
	status_lbl.name = "Status"
	status_lbl.text = "" 
	status_lbl.add_theme_font_size_override("font_size", 12)
	
	hbox.add_child(title)
	hbox.add_child(effect_lbl)
	hbox.add_child(VSeparator.new())
	hbox.add_child(cost_lbl)
	hbox.add_child(status_lbl)
	
	# Make it clickable
	btn_panel.gui_input.connect(_on_law_gui_input.bind(btn_panel))
	
	laws_grid.add_child(btn_panel)

#endregion

#region --- Interactions ---
func _on_law_gui_input(event: InputEvent, btn: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ratio = btn.get_meta("ratio")
		var penalty = btn.get_meta("penalty")
		var cost = btn.get_meta("cost")
		
		# 1. Is this already active?
		if is_equal_approx(current_country.military_size_ratio, ratio):
			return # Do nothing
			
		# 2. Can we afford it?
		if current_country.political_power >= cost:
			# Execute Change
			current_country.political_power -= cost
			current_country.military_size_ratio = ratio
			current_country.economy_law_penalty = penalty
			
			current_country.update_manpower_pool() # Recalc based on new ratio
			
			# Refresh UI
			_update_law_buttons_visuals()
			_refresh_full_data()
			print("Law enacted: ", ratio)
		else:
			# Optional: Shake animation or error sound
			print("Not enough Political Power!")

# Utils
func _format_money(amount: float) -> String:
	if amount >= 1000000:
		return "%.2fM" % (amount / 1000000.0)
	elif amount >= 1000:
		return "%.2fK" % (amount / 1000.0)
	return "%.2f" % amount

func _format_number(amount: int) -> String:
	if amount >= 1000000:
		return "%.1fM" % (amount / 1000000.0)
	elif amount >= 1000:
		return "%.1fK" % (amount / 1000.0)
	return str(amount)
#endregion
