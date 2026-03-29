extends MultiMeshInstance3D

@export var flags_map_path: String = "res://assets/flags_map.json"
@export var y_offset: float = 0.12
@export var marker_size: Vector2 = Vector2(0.20, 0.10)

var flags_map: Dictionary = {}
var _last_troop_count: int = -1

func _ready():
	load_flags_map()
	setup_multimesh()

func _process(_delta):
	update_troops()

func load_flags_map():
	if not FileAccess.file_exists(flags_map_path):
		push_error("flags_map.json not found: " + flags_map_path)
		return

	var file = FileAccess.open(flags_map_path, FileAccess.READ)
	if file == null:
		push_error("Could not open flags_map.json")
		return

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("Failed to parse flags_map.json")
		return

	flags_map = json.data
	print("Loaded flags map: ", flags_map.size(), " entries")

func setup_multimesh():
	if multimesh == null:
		multimesh = MultiMesh.new()

	# Must be 3D transforms
	multimesh.transform_format = MultiMesh.TRANSFORM_3D

	# VERY IMPORTANT
	multimesh.use_custom_data = true

	# Optional but nice if you ever want color tinting later
	multimesh.use_colors = false

func update_troops():
	if not Engine.is_editor_hint() and not has_node("/root/TroopManager"):
		return

	var troops = TroopManager.troops
	if troops == null:
		return

	# Resize only when needed
	if _last_troop_count != troops.size():
		multimesh.instance_count = troops.size()
		_last_troop_count = troops.size()

	for i in range(troops.size()):
		var troop = troops[i]
		if troop == null:
			continue

		update_single_troop(i, troop)

func update_single_troop(index: int, troop):
	# -----------------------------
	# 1) WORLD POSITION
	# -----------------------------
	var pos: Vector3 = troop.get_visual_position()
	pos.y += y_offset

	# Billboard shader will face camera automatically
	# We only care about size + position here
	var basis = Basis()
	basis = basis.scaled(Vector3(marker_size.x, marker_size.y, 1.0))

	var xform = Transform3D(basis, pos)
	multimesh.set_instance_transform(index, xform)

	# -----------------------------
	# 2) FLAG INDEX LOOKUP
	# -----------------------------
	var country_key := normalize_country_key(str(troop.country_name))
	var flag_index: int = 0

	if flags_map.has(country_key):
		flag_index = int(flags_map[country_key])
	else:
		# fallback if missing
		flag_index = 0
		# Uncomment if you want to debug missing flags:
		# print("Missing flag for: ", country_key)

	# -----------------------------
	# 3) TROOP COUNT + HP
	# -----------------------------
	var count: int = clamp(int(troop.divisions_count), 0, 99)
	var hp: float = clamp(float(troop.get_average_hp_percent()), 0.0, 1.0)

	# -----------------------------
	# 4) PACK DATA INTO INSTANCE_CUSTOM
	# -----------------------------
	# We store:
	# R = low byte of flag index
	# G = troop count
	# B = hp
	# A = high byte of flag index
	#
	# This supports >255 flags safely.

	var flag_low: int = flag_index % 256
	var flag_high: int = flag_index / 256

	var custom_data = Color(
		float(flag_low) / 255.0,
		float(count) / 255.0,
		hp,
		float(flag_high) / 255.0
	)

	multimesh.set_instance_custom_data(index, custom_data)

func normalize_country_key(name: String) -> String:
	return name.to_lower().strip_edges().replace(" ", "_")
