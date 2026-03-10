extends Control

@export var zoom_threshold: float = 5.0

func update_info(province):
	%LabelCountry.text = province.country
	%LabelMoney.text = "$%s" % province.gdp
	%LabelCity.text = province.city

func _process(_delta: float):
	global_position = get_viewport().get_mouse_position()

	var camera = get_viewport().get_camera_2d()
	if camera and camera.zoom.x < zoom_threshold:
		self.modulate.a = 0 # Transparent
	else:
		self.modulate.a = 1 # Opaque
