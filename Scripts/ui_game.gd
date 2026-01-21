extends CanvasLayer
class_name GameUI

# ── Enums ─────────────────────────────────────────────
enum Context { PLAYER_COUNTRY, ENEMY_COUNTRY, NEUTRAL_COUNTRY }
enum Category { GENERAL, ECONOMY, MILITARY }

# ── Top Bar Nodes ─────────────────────────────────────
@onready var nation_flag: TextureRect = $Control/Topbar/nation_flag
@onready var label_date: Label = $Control/Topbar/MarginContainer2/ColorRect/MarginContainer/label_date
@onready var stats_labels := {
	"pp": $Control/Topbar/MarginContainer/HBoxContainer/PoliticalPower/HBoxContainer/label_politicalpower,
	"manpower": $Control/Topbar/MarginContainer/HBoxContainer/Manpower/HBoxContainer/label_manpower,
	"money": $Control/Topbar/MarginContainer/HBoxContainer/Money/HBoxContainer/label_money,
	"industry": $Control/Topbar/MarginContainer/HBoxContainer/Industry/HBoxContainer/label_industry,
	"stability": $Control/Topbar/MarginContainer/HBoxContainer/Stability/HBoxContainer/label_stability
}

# ── Side Menu Nodes ───────────────────────────────────
@onready var sidemenu: Control = $Control/SidemenuBG
@onready
var sidemenu_flag: TextureRect = $Control/SidemenuBG/Sidemenu/PanelContainer/VBoxContainer/Flag/TextureRect
@onready var label_country_sidemenu: Label = $Control/SidemenuBG/Sidemenu/PanelContainer/VBoxContainer/Label
@onready var label_category: Label = $Control/SidemenuBG/Sidemenu/Panel/label_category
@onready var actions_container: VBoxContainer = $Control/SidemenuBG/Sidemenu/ScrollContainer/ActionsList
@onready var progress_bar: ProgressBar = $Control/Topbar/MarginContainer2/ColorRect/ProgressBar
@onready var troop_container: PanelContainer = $Control/TroopContainer


# Use the class_name of your action scene if available, or load strictly as packed scene
@export var action_scene: PackedScene

# ── Speed Controls ────────────────────────────────────
@onready var plus: Button = $Control/SpeedPanel/GameSpeedControl/PlusPanel/Plus
@onready var minus: Button = $Control/SpeedPanel/GameSpeedControl/MinusPanel/Minus

# ── State Variables ───────────────────────────────────
var selected_country: CountryData = null

# Animation State
@export var slide_duration: float = 0.2
var is_open := false
var pos_open := Vector2.ZERO
var pos_closed := Vector2.ZERO

# Navigation State
var current_context: Context = Context.PLAYER_COUNTRY
var current_category: Category = Category.GENERAL

@export var military_access_label: Label

@export var decision_tree: DecisionTree

var menu_actions = {
	# When clicking on player country
	Context.PLAYER_COUNTRY:
	{
		Category.GENERAL:
		[
			{"text": "Decisions", "func": "open_decisions_tree"},
			{"text": "Improve Stability", "cost": 25, "func": "improve_stability"},
			{"text": "Releasables", "func": "_improve_relations"}
		],
		Category.ECONOMY:
		[
			{"text": "Research", "cost": 0, "func": "open_research_tree"},
			{"text": "Build Factory", "cost": 0, "func": "_build_factory"},
			{"text": "Build Port", "cost": 0, "func": "_build_port"},
		],
		Category.MILITARY:
		[
			{"text": "Choose Deployment Province", "func": "_choose_deploy_city"},
			{
				"text": "Training (10k)",
				"func": "_conscript",
				"type": "training",
				"manpower": 10000
			},
			{
				"text": "Training (50k)",
				"func": "_conscript",
				"type": "training",
				"manpower": 50000
			}
		]
	},
	# When clicking on a country the player is at war with
	Context.ENEMY_COUNTRY:
	{
		Category.GENERAL:
		[
			{"text": "Propose Ceasefire", "cost": 50, "func": "_propose_peace"},
		],
		Category.MILITARY:
		[
			{"text": "Launch Nuke", "cost": 500, "func": "_launch_nuke"},
		]
	},
	# When clicking on a country the player isn't at war with
	Context.NEUTRAL_COUNTRY:
	{
		Category.GENERAL:
		[
			{"text": "Declare War", "cost": 50, "func": "_declare_war"},
			{"text": "Request Access", "cost": 25, "func": "_request_access"},
			{"text": "Improve Relations", "cost": 15, "func": "_improve_relations"},
			{"text": "Form Alliance", "cost": 80, "func": "_form_alliance"},
		],
		Category.ECONOMY:
		[
			{"text": "Demand Tribute", "cost": 40, "func": "_demand_tribute"},
			{"text": "Trade Deal", "cost": 10, "func": "_trade_deal"},
		]
	}
}


func _enter_tree() -> void:
	GameState.game_ui = self


func _ready() -> void:
	pos_open = sidemenu.position
	pos_closed = Vector2(pos_open.x - sidemenu.size.x, pos_open.y)
	sidemenu.position = pos_closed

	GameState.game_ui = self

	MapManager.country_clicked.connect(_on_province_clicked)
	MapManager.close_sidemenu.connect(close_menu)

	KeyboardManager.toggle_menu.connect(toggle_menu)

	GameState.current_world.clock.hour_passed.connect(_on_hour_passed)
	CountryManager.player_country_changed.connect(_on_player_change)
	updateProgressBar()

	var clock := GameState.current_world.clock
	clock.hour_passed.connect(_on_time_passed)
	plus.pressed.connect(clock.increase_speed)
	minus.pressed.connect(clock.decrease_speed)
	label_date.text = clock.get_datetime_string()


func _on_player_change() -> void:
	_update_flag()
	update_topbar_stats()


func _on_province_clicked(country_name: String) -> void:
	selected_country = CountryManager.get_country(country_name)

	sidemenu_flag.texture = TroopManager.get_flag(country_name)
	label_country_sidemenu.text = country_name.capitalize().replace("_", " ")

	if !GameState.choosing_deploy_city || GameState.industry_building == GameState.IndustryType.DEFAULT:
		var new_context = Context.NEUTRAL_COUNTRY

		if country_name == CountryManager.player_country.country_name:
			new_context = Context.PLAYER_COUNTRY
		elif WarManager.is_at_war(CountryManager.player_country, selected_country):
			new_context = Context.ENEMY_COUNTRY

		var has_military_access := selected_country.country_name in CountryManager.player_country.allowedCountries
		self.military_access_label.text = "Military Access: " + String("Yes" if has_military_access else "No")

		open_menu(new_context, Category.GENERAL)


func toggle_menu(context := Context.PLAYER_COUNTRY) -> void:
	if is_open:
		close_menu()
	else:
		selected_country = CountryManager.player_country
		label_country_sidemenu.text = CountryManager.player_country.country_name
		sidemenu_flag.texture = nation_flag.texture
		open_menu(context, Category.GENERAL)


func open_menu(context: Context, category: Category) -> void:
	if GameState.choosing_deploy_city or GameState.industry_building != GameState.IndustryType.DEFAULT:
		return
	current_context = context
	current_category = category

	_build_action_list()

	if !is_open:
		MusicManager.play_sfx(MusicManager.SFX.OPEN_MENU)
		slide_in()


func _on_tab_changed(new_category_index: int) -> void:
	current_category = new_category_index as Category
	_build_action_list()
	MusicManager.play_sfx(MusicManager.SFX.HOVERED)


func _on_menu_button_button_up(_menu_index: int) -> void:
	current_category = _menu_index as Category
	if _menu_index == Category.ECONOMY:
		MapManager.show_industry_country(CountryManager.player_country.country_name)
	else:
		MapManager.set_country_color(CountryManager.player_country.country_name, Color.TRANSPARENT)
		GameState.industry_building = GameState.IndustryType.DEFAULT
		MapManager.show_countries_map()
	_build_action_list()


func _build_action_list() -> void:
	for child in actions_container.get_children():
		child.queue_free()

	label_category.text = Category.keys()[current_category].capitalize()

	for item in (menu_actions[current_context] as Dictionary[int, Array]).get(current_category, []):
		var new_btn = action_scene.instantiate()

		var call_ref = Callable(self, item.func)
		if item.func == "_conscript":
			call_ref = call_ref.bind(item)

		new_btn.setup(item, call_ref)
		actions_container.add_child(new_btn)

	if current_context == Context.PLAYER_COUNTRY and current_category == Category.MILITARY:
		var player = CountryManager.player_country

		for troop in player.ongoing_training:
			var btn = action_scene.instantiate()
			actions_container.add_child(btn)
			btn.setup_training(troop)
			# We connect the signal emitted by ActionRow when days_left <= 0
			if not btn.training_finished.is_connected(_build_action_list):
				btn.training_finished.connect(_build_action_list)

		# Ready to Deploy
		for troop in player.ready_troops:
			var btn = action_scene.instantiate()
			actions_container.add_child(btn)
			# Callable points to deploy_troop, passing the specific troop object
			var deploy_call = Callable(self, "deploy_troop").bind(troop)
			btn.setup_ready(troop, deploy_call)


func update_topbar_stats() -> void:
	if !CountryManager.player_country:
		return
	stats_labels.pp.text = str(floori(CountryManager.player_country.political_power))
	stats_labels.stability.text = str(round(CountryManager.player_country.stability * 100)) + "%"
	stats_labels.manpower.text = format_number(CountryManager.player_country.manpower)
	stats_labels.money.text = "$" + format_number(CountryManager.player_country.money)
	stats_labels.industry.text = str(CountryManager.player_country.factories_amount)


func _on_hour_passed() -> void:
	update_topbar_stats()


func format_number(value: float) -> String:
	var abs_val = abs(value)
	var sign_str = "-" if value < 0 else ""
	if abs_val >= 1_000_000_000:
		return sign_str + "%.2fB" % (abs_val / 1_000_000_000.0)
	elif abs_val >= 1_000_000:
		return sign_str + "%.2fM" % (abs_val / 1_000_000.0)
	elif abs_val >= 1_000:
		return sign_str + "%.1fK" % (abs_val / 1_000.0)
	return sign_str + str(floori(abs_val))


func _on_time_passed() -> void:
	label_date.text = GameState.current_world.clock.get_datetime_string()


func updateProgressBar():
	var clock = GameState.current_world.clock
	progress_bar.value = (clock.time_scale / clock.MAX_SPEED) * 100.0
	var bg_style = progress_bar.get_theme_stylebox("background")
	if clock.paused:
		bg_style.border_color = Color.DARK_RED
		label_date.add_theme_color_override("font_color", Color.RED)
	else:
		bg_style.border_color = Color.DARK_CYAN
		label_date.add_theme_color_override("font_color", Color.WHITE)


func _update_flag() -> void:
	if !CountryManager.player_country:
		return
	var path = "res://assets/flags/%s_flag.png" % CountryManager.player_country.country_name.to_lower()
	if ResourceLoader.exists(path):
		nation_flag.texture = load(path)


func close_menu() -> void:
	if is_open:
		MusicManager.play_sfx(MusicManager.SFX.CLOSE_MENU)
	GameState.reset_industry_building()
	slide_out()


func slide_in() -> void:
	if is_open:
		return
	is_open = true
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sidemenu, "position", pos_open, slide_duration)


func slide_out() -> void:
	if not is_open:
		return
	is_open = false
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(sidemenu, "position", pos_closed, slide_duration)


func _choose_deploy_city():
	GameState.choosing_deploy_city = true


func _declare_war():
	WarManager.declare_war(CountryManager.player_country, selected_country)

	var has_military_access := selected_country.country_name in CountryManager.player_country.allowedCountries
	GameState.game_ui.military_access_label.text = "Military Access: " + String("Yes" if has_military_access else "No")

	open_menu(Context.ENEMY_COUNTRY, Category.GENERAL)


func _conscript(data: Dictionary):
	var manpower = data.manpower / 10000
	CountryManager.player_country.train_troops(manpower, 1, 1000)
	update_topbar_stats()
	_build_action_list()


# Troop argument comes from .bind(troop)
func deploy_troop(troop):
	if CountryManager.player_country.deploy_pid == -1:
		CountryManager.player_country.deploy_ready_troop_to_random(troop)
	else:
		CountryManager.player_country.deploy_ready_troop_to_pid(troop)
	_build_action_list()


func improve_stability():
	CountryManager.player_country.stability += 0.02
	update_topbar_stats()


func _build_factory():
	GameState.industry_building = GameState.IndustryType.FACTORY
	#MapManager.show_industry_country(player.country_name)


func _build_port():
	GameState.industry_building = GameState.IndustryType.PORT
	#MapManager.show_industry_country(player.country_name)


func _request_access():
	pass


func _improve_relations():
	print("Improving relations")


func _propose_peace():
	print("Proposing peace")


func _launch_nuke():
	print("NUKE!")


func _form_alliance():
	print("Alliance formed")


func _demand_tribute():
	print("Pay up!")


func _trade_deal():
	print("Trading...")


func open_research_tree():
	print("Opening Research")


func open_decisions_tree():
	decision_tree.show()

	GameState.current_world.set_process(false)
	GameState.current_world.clock.set_process(false)
	TroopManager.set_process(false)
	GameState.current_world.find_child("CameraController").set_process(false)


func _on_log_button_up() -> void:
	GameState.game_log.visible = !GameState.game_log.visible
	MusicManager.play_sfx(MusicManager.SFX.OPEN_MENU)
	


# Note (Z21) 
# Everything below is made by a Clanker. I am way too lazy for UI stuff
@onready var troop_list_parent: VBoxContainer = $Control/TroopContainer/ScrollContainer/VBoxContainer

# Theme colors for the military look

# 1. Add this variable at the top with your other @onready variables
var selected_division_objects: Array[DivisionData] = []

# 2. Add these helper colors (optional, but makes code cleaner)
const COLOR_NORMAL = Color(0.1, 0.1, 0.1, 0.7)
const COLOR_HOVER = Color(0.088, 0.153, 0.51, 0.9) # Dark olive highlight
const COLOR_SELECTED = Color(0.1, 0.4, 0.6, 0.9) # A nice blueprint blue

# ... your make_troop_container and other functions ...

func _on_division_card_clicked(div: DivisionData, panel: PanelContainer):
	if div in selected_division_objects:
		selected_division_objects.erase(div)
	else:
		selected_division_objects.append(div)
	
	# Refresh the look immediately
	_update_card_visuals(div, panel)

# New helper to centralize the look of the card
func _update_card_visuals(div: DivisionData, panel: PanelContainer):
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if div in selected_division_objects:
		style.bg_color = COLOR_SELECTED
		style.border_width_left = 8
		style.border_color = Color.CYAN
	else:
		style.bg_color = COLOR_NORMAL
		style.border_width_left = 4
		style.border_color = Color.DARK_GRAY
func close_troop_container() -> void:
	troop_container.visible = false

func make_troop_container(selected_troops: Array[TroopData]) -> void:
	troop_container.visible = true
	for child in troop_list_parent.get_children():
		child.queue_free()
	
	for troop in selected_troops:
		# --- Stack Header ---
		var header_panel = PanelContainer.new()
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = Color(0.05, 0.05, 0.05, 0.8)
		h_style.border_width_bottom = 2
		h_style.border_color = Color.GOLD
		header_panel.add_theme_stylebox_override("panel", h_style)
		
		var header_label = Label.new()
		header_label.text = " PROVINCE %d " % troop.province_id
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_panel.add_child(header_label)
		troop_list_parent.add_child(header_panel)

		for div in troop.stored_divisions:
			var div_card = _create_division_card(div, troop)
			troop_list_parent.add_child(div_card)

func _create_division_card(div: DivisionData, parent_troop: TroopData) -> PanelContainer:
	var panel = PanelContainer.new()
	
	# 1. Base Styling
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_NORMAL
	style.set_content_margin_all(5)
	style.border_width_left = 4
	style.border_color = Color.DARK_GRAY
	panel.add_theme_stylebox_override("panel", style)

	# 2. Layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# 3. Unit Icon with Tooltip
	var icon = TextureRect.new()
	var icon_path = "res://assets/icons/hoi4/%s.png" % div.type.to_lower()
	icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# TOOLTIP: Show detailed stats on hover
	panel.tooltip_text = "%s\nType: %s\nAttack: %.1f\nDefense: %.1f\nExp: %d%%" % [
		div.name, div.type.capitalize(), div.get_attack_power(), div.get_defense_power(), int(div.experience * 100)
	]
	hbox.add_child(icon)

	# 4. Info Vertical Stack (Name + Health Bar)
	var v_info = VBoxContainer.new()
	v_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(v_info)

	var name_label = Label.new()
	name_label.text = div.name
	name_label.add_theme_font_size_override("font_size", 14)
	v_info.add_child(name_label)

	var hp_bar = ProgressBar.new()
	hp_bar.value = div.hp
	hp_bar.custom_minimum_size.y = 6
	hp_bar.show_percentage = false
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = Color.SPRING_GREEN.lerp(Color.RED, 1.0 - (div.hp/100.0))
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	v_info.add_child(hp_bar)

	# 5. Exp Stars
	var stars = Label.new()
	stars.text = "★" + str(int(div.experience * 5 + 1))
	stars.modulate = Color.GOLD
	hbox.add_child(stars)

	# 6. DISBAND BUTTON
	var disband_btn = Button.new()
	disband_btn.text = " ✘ "
	disband_btn.flat = true
	disband_btn.modulate = Color.INDIAN_RED
	disband_btn.tooltip_text = "Disband Division"
	disband_btn.pressed.connect(func(): _on_disband_pressed(div, parent_troop, panel))
	hbox.add_child(disband_btn)

	# --- INTERACTIVITY SIGNALS ---
# --- INTERACTIVITY SIGNALS ---
	panel.mouse_entered.connect(func(): 
		style.bg_color = COLOR_HOVER
		style.border_color = Color.ANTIQUE_WHITE
	)

	panel.mouse_exited.connect(func(): 
		# ONLY revert if it's not in our selection list
		if not div in selected_division_objects:
			style.bg_color = COLOR_NORMAL
			style.border_color = Color.DARK_GRAY
		else:
			# Keep the selection look if it IS selected
			style.bg_color = COLOR_SELECTED
			style.border_color = Color.CYAN
	)
	
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_division_card_clicked(div, panel)
	)
	
	return panel

func _on_disband_pressed(div: DivisionData, troop: TroopData, ui_node: Control):
	# Remove from data
	troop.stored_divisions.erase(div)
	# Remove from UI with a small effect
	var tween = create_tween()
	tween.tween_property(ui_node, "modulate:a", 0.0, 0.2)
	tween.finished.connect(ui_node.queue_free)
	
	# If troop is now empty, remove it from map
	if troop.stored_divisions.is_empty():
		TroopManager.remove_troop(troop)
