extends Control

@onready var div_button = %DivisionType 
@onready var templates = DivisionData.TEMPLATES
@onready var div_popup = %DivisionPopup 

var current_division_amount: int = 1
var current_selected_type: String = "infantry"

func _ready() -> void:
	_setup_division_menu()
	div_button.pressed.connect(_show_popup)
	
	#CountryManager.player_country.training_day_complete.connect(traini)
	
	%DivisionInput.text_changed.connect(_on_division_input_changed)
	%MinusButton.pressed.connect(_on_adjust_amount.bind(-1))
	%PlusButton.pressed.connect(_on_adjust_amount.bind(1))
	
	_select_default_type("infantry")
	%DivisionInput.text = str(current_division_amount)
	
	%TrainButton.pressed.connect(_train_troops);
	%CloseButton.pressed.connect(func():
		if get_parent().has_method("_close_submenu"):
			get_parent()._close_submenu()
	)

func _setup_division_menu() -> void:
	div_popup.clear()
	for type_name in templates.keys():
		var icon_path = "res://assets/icons/hoi4/%s.png" % type_name
		if ResourceLoader.exists(icon_path):
			div_popup.add_icon_item(load(icon_path), type_name.capitalize())
		else:
			div_popup.add_item(type_name.capitalize())
	
	div_popup.index_pressed.connect(_on_division_selected)

func _show_popup() -> void:
	div_popup.position = div_button.global_position + Vector2(0, div_button.size.y)
	div_popup.popup()

func _on_division_selected(index: int) -> void:
	var selected_text = div_popup.get_item_text(index)
	div_button.text = selected_text
	div_button.icon = div_popup.get_item_icon(index)
	
	current_selected_type = selected_text.to_lower()
	_refresh_ui()

func _refresh_ui() -> void:
	var stats = templates[current_selected_type]
	_update_stats_display(stats)

func _update_stats_display(stats: Dictionary):
	%hp_label.text = str(stats.hp)
	%attack_label.text = str(stats.attack)
	%defense_label.text = str(stats.defense)
	%speed_label.text = str(stats.speed)
	%cost_label.text = str(stats.cost * current_division_amount)
	%days_label.text = str(stats.days) 

func _on_adjust_amount(delta: int):
	current_division_amount = clampi(current_division_amount + delta, 1, 99)
	%DivisionInput.text = str(current_division_amount)
	_refresh_ui()

func _on_division_input_changed(new_text: String):
	var filtered = ""
	for c in new_text:
		if c in "0123456789":
			filtered += c
	
	if filtered != new_text:
		%DivisionInput.text = filtered
		%DivisionInput.caret_column = filtered.length()
	
	current_division_amount = clampi(filtered.to_int(), 1, 99)
	_refresh_ui()

func _train_troops():
	CountryManager.player_country.train_troops(current_division_amount, current_selected_type)
	_refresh_ui()
	
	

func _select_default_type(target_name: String) -> void:
	for i in div_popup.item_count:
		if div_popup.get_item_text(i).to_lower() == target_name.to_lower():
			_on_division_selected(i)
			break
