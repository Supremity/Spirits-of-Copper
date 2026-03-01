extends Control

@onready var button_container = %ButtonContainer
@onready var main_panel = $MainPanel
@onready var back_btn = $MainPanel/Margin/Layout/BackBtn

func _ready() -> void:
	_apply_hud_style()
	
	back_btn.pressed.connect(func():
		if get_parent().has_method("_close_submenu"):
			MapManager.show_countries_map()
			GameState.industry_building = GameState.IndustryType.DEFAULT
			get_parent()._close_submenu()
	)
	
	MapManager.show_industry_country(CountryManager.player_country.country_name)
	
	_setup_buttons()

func _setup_buttons() -> void:
	_add_industry_action("BUILD FACTORY", _on_factory)
	_add_industry_action("BUILD PORT", _on_port)
	_add_industry_action("INFRASTRUCTURE", _on_infra)
	_add_industry_action("DELETE", _on_delete, Color(0.4, 0.1, 0.1))


func _on_factory():
	GameState.industry_building = GameState.IndustryType.FACTORY

func _on_port():
	GameState.industry_building = GameState.IndustryType.PORT
	
func _on_infra(): print("Infra logic")
func _on_delete(): print("Delete logic")


func _add_industry_action(txt: String, call: Callable, color: Color = Color(1,1,1,0.05)) -> void:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(130, 50)
	btn.size_flags_vertical = 4 # Centered vertically
	
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(0) # Sharp
	s.border_width_bottom = 2
	s.border_color = Color(1,1,1,0.1)
	
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(call)
	button_container.add_child(btn)

func _apply_hud_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.98) # Match Bottom HUD
	style.set_corner_radius_all(0) # Sharp
	style.border_width_top = 1
	style.border_color = Color(0.3, 0.3, 0.3, 1.0) # Solid border
	main_panel.add_theme_stylebox_override("panel", style)
