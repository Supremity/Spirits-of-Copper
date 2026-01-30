extends CanvasLayer
class_name SystemMenuUI

# --- Theme ---
const COLOR_BG = Color(0.06, 0.07, 0.09, 0.98)
const COLOR_ACCENT = Color(0.24, 0.65, 0.85)
var custom_font = load("res://font/Google_Sans/GoogleSans-VariableFont_GRAD,opsz,wght.ttf")

# --- Nodes ---
var main_panel: PanelContainer
var content_area: VBoxContainer

# Values for the sliders (0.0 to 1.0)
var master_music_mult: float = 1.0
var master_sfx_mult: float = 1.0

enum Section { SAVE, AUDIO, SETTINGS, EXIT }

func _ready() -> void:
	visible = false
	_build_ui()

func toggle_menu() -> void:
	visible = !visible
	if visible:
		# Center every time it opens just in case window resized
		main_panel.set_anchors_preset(Control.PRESET_CENTER)
		_switch_section(Section.AUDIO)
		MusicManager.play_sfx(MusicManager.SFX.OPEN_MENU)

#region --- UI Construction ---

func _build_ui() -> void:
	# Dimmer background
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Main Window centered
	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(750, 500)
	
	# This ensures it stays in the middle
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -375)
	main_panel.set_anchor_and_offset(SIDE_TOP, 0.5, -250)
	
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_top = 4
	style.border_color = COLOR_ACCENT
	style.set_corner_radius_all(8)
	style.shadow_size = 20
	style.shadow_color = Color(0, 0, 0, 0.5)
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)

	var h_split = HBoxContainer.new()
	main_panel.add_child(h_split)

	# Sidebar
	var sidebar_margin = MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_all", 25)
	h_split.add_child(sidebar_margin)

	var side_vbox = VBoxContainer.new()
	side_vbox.custom_minimum_size = Vector2(200, 0)
	side_vbox.add_theme_constant_override("separation", 12)
	sidebar_margin.add_child(side_vbox)

	_add_tab_btn(side_vbox, "SAVE & LOAD", Section.SAVE)
	_add_tab_btn(side_vbox, "AUDIO SETTINGS", Section.AUDIO)
	_add_tab_btn(side_vbox, "GAME SETTINGS", Section.SETTINGS)
	_add_tab_btn(side_vbox, "EXIT TO DESKTOP", Section.EXIT)

	# Content
	var content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_all", 40)
	h_split.add_child(content_margin)

	content_area = VBoxContainer.new()
	content_area.add_theme_constant_override("separation", 25)
	content_margin.add_child(content_area)

func _add_tab_btn(parent: Node, txt: String, sec: Section) -> void:
	var b = Button.new()
	b.text = txt
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if custom_font: b.add_theme_font_override("font", custom_font)
	b.pressed.connect(_switch_section.bind(sec))
	parent.add_child(b)

#endregion

#region --- Audio Logic using your Maps ---

func _draw_audio_menu() -> void:
	_add_header("Audio Mix")

	# ScrollContainer is necessary because "literally all of them" is a long list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 350
	content_area.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 15)
	scroll.add_child(list)

	# --- MUSIC SECTION ---
	_add_sub_header(list, "Music Themes")
	for track_key in MusicManager.music_volume_map.keys():
		var track_name = MusicManager.MUSIC.keys()[track_key].capitalize().replace("_", " ")
		_add_map_slider_row(list, track_name, MusicManager.music_volume_map[track_key], 2.0, 
			func(v): 
				MusicManager.music_volume_map[track_key] = v
				# Update current playing track volume immediately
				if MusicManager.current_track_type == track_key:
					MusicManager.music_player.volume_db = linear_to_db(v)
		)

	list.add_child(HSeparator.new())

	# --- SFX SECTION ---
	_add_sub_header(list, "Sound Effects")
	for sfx_key in MusicManager.sfx_volume_map.keys():
		# Converts SFX.TROOP_MOVE to "Troop Move"
		var sfx_name = MusicManager.SFX.keys()[sfx_key].capitalize().replace("_", " ")
		_add_map_slider_row(list, sfx_name, MusicManager.sfx_volume_map[sfx_key], 2.0, 
			func(v): MusicManager.sfx_volume_map[sfx_key] = v
		)
#endregion

#region --- Helpers ---

func _switch_section(sec: Section) -> void:
	for c in content_area.get_children(): c.queue_free()
	
	match sec:
		Section.AUDIO: _draw_audio_menu()
		Section.SAVE: _add_header("Save Game")
		Section.EXIT: _draw_exit_confirm()

func _add_map_slider_row(parent: Node, label: String, current_val: float, max_v: float, callback: Callable) -> void:
	var row_vbox = VBoxContainer.new()
	
	var lbl = Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.8, 0.8, 0.8)
	if custom_font: lbl.add_theme_font_override("font", custom_font)

	var hbox = HBoxContainer.new()
	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = max_v # Allow going up to 200% volume for quiet files
	slider.step = 0.01
	slider.value = current_val
	
	var val_text = Label.new()
	val_text.custom_minimum_size = Vector2(40, 0)
	val_text.text = str(int((current_val / max_v) * 100)) + "%"
	
	slider.value_changed.connect(callback)
	slider.value_changed.connect(func(v): val_text.text = str(int((v / max_v) * 100)) + "%")
	
	hbox.add_child(slider)
	hbox.add_child(val_text)
	row_vbox.add_child(lbl)
	row_vbox.add_child(hbox)
	parent.add_child(row_vbox)

func _add_sub_header(parent: Node, txt: String) -> void:
	var l = Label.new()
	l.text = txt
	l.modulate = COLOR_ACCENT
	if custom_font: l.add_theme_font_override("font", custom_font)
	parent.add_child(l)
func _add_header(txt: String) -> void:
	var l = Label.new()
	l.text = txt
	if custom_font: l.add_theme_font_override("font", custom_font)
	l.add_theme_font_size_override("font_size", 24)
	l.modulate = COLOR_ACCENT
	content_area.add_child(l)

func _draw_exit_confirm() -> void:
	_add_header("Exit")
	var btn = Button.new()
	btn.text = "Exit the Game"
	btn.modulate = Color(1, 0.3, 0.3)
	btn.pressed.connect(get_tree().quit)
	content_area.add_child(btn)
#endregion
