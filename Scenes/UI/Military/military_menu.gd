extends Control

@onready var div_button = %DivisionType 
@onready var templates = DivisionData.TEMPLATES

@onready var div_popup = %DivisionPopup 

func _ready() -> void:
	_setup_division_menu()
	div_button.pressed.connect(_show_popup)

func _setup_division_menu() -> void:
	div_popup.clear()
	
	for type_name in templates.keys():
		var icon_path = "res://assets/icons/hoi4/%s.png" % type_name
		if ResourceLoader.exists(icon_path):
			div_popup.add_icon_item(load(icon_path), type_name.capitalize())
		else:
			div_popup.add_item(type_name.capitalize())
	
	div_popup.index_pressed.connect(_on_division_selected)
	_select_default_type("infantry")

func _show_popup() -> void:
	var popup_pos = div_button.global_position
	popup_pos.y += div_button.size.y # Move it to the bottom edge
	
	div_popup.position = popup_pos
	div_popup.popup()

func _on_division_selected(index: int) -> void:
	var selected_text = div_popup.get_item_text(index)
	var selected_icon = div_popup.get_item_icon(index)
	
	div_button.text = selected_text
	div_button.icon = selected_icon
	
	var template_key = selected_text.to_lower()
	var stats = templates[template_key]
	print("Switched to %s. Defense is: %s" % [template_key, stats.defense])
	
func _select_default_type(target_name: String) -> void:
	for i in div_popup.item_count:
		if div_popup.get_item_text(i).to_lower() == target_name.to_lower():
			_on_division_selected(i)
			break
