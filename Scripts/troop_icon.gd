extends Control

@onready var flag_rect = $PanelContainer/VBoxContainer/HBoxContainer/TextureRect
@onready var count_label = $PanelContainer/VBoxContainer/HBoxContainer/Label
@onready var hp_bar: ProgressBar = $PanelContainer/VBoxContainer/MarginContainer/ProgressBar
@onready var panel = $PanelContainer

var target_troop: TroopData

func setup(troop: TroopData):
	target_troop = troop
	update_visuals()

func update_visuals():
	count_label.text = str(target_troop.divisions_count)
	hp_bar.value = target_troop.get_average_hp_percent() * 100
	flag_rect.texture = TroopManager.get_flag(target_troop.country_name)
	
	var is_selected = TroopManager.troop_selection.selected_troops.has(target_troop)
	var style = panel.get_theme_stylebox("panel")
	style.border_color = Color.GREEN if is_selected else Color.WHITE
