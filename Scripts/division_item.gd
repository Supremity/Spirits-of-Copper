extends Control

signal clicked(div_data, card_node)

@onready var color_rect: ColorRect = $ColorRect
@onready var texture_rect: TextureRect = $ColorRect/TextureRect
@onready var progress_bar: ProgressBar = $ColorRect/ProgressBar
@onready var label_division: Label = $ColorRect/label_division
@onready var label_attack: Label = $ColorRect/label_attack
@onready var label_defense: Label = $ColorRect/label_defense
@onready var label_experience: Label = $ColorRect/label_experience

var data: DivisionData
var is_selected: bool = false

# Colors
const COLOR_NORMAL = Color(0.1, 0.1, 0.1, 0.7)
const COLOR_SELECTED = Color(0.1, 0.4, 0.6, 0.9)
# This creates a color 30% lighter than the normal one
const COLOR_HOVER = Color(0.2, 0.2, 0.2, 0.8) 

func _ready():
	# 1. CRITICAL: Make the root sensitive to mouse
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. CRITICAL: Make children transparent to mouse so they don't block clicks
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in color_rect.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		

func setup(div: DivisionData, currently_selected: bool) -> void:
	data = div
	is_selected = currently_selected
	
	label_division.text = data.name
	label_attack.text = str(data.get_attack_power())
	label_defense.text = str(data.get_defense_power())
	label_experience.text = "%d%%" % int(data.experience * 100)
	progress_bar.value = data.hp
	
	var icon_path = "res://assets/icons/hoi4/%s.png" % data.type.to_lower()
	if ResourceLoader.exists(icon_path):
		texture_rect.texture = load(icon_path)
	
	update_visuals()

func update_visuals():
	# Use a border or a distinct color change
	if is_selected:
		color_rect.color = COLOR_SELECTED
	else:
		color_rect.color = COLOR_NORMAL

func _on_mouse_entered():
	if not is_selected:
		# Lighten the background on hover
		color_rect.color = COLOR_HOVER

func _on_mouse_exited():
	update_visuals()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Tell the UI we were clicked
			clicked.emit(data, self)
			# Consuming the event so it doesn't click things behind the UI
			get_viewport().set_input_as_handled()
