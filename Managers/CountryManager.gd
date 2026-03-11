extends Node

signal player_country_changed
var countries: Dictionary[String, CountryData] = {}
var player_country: CountryData

var _hour_process_index: int = 0
@export var clock: GameClock
@export var hours_per_full_country_tick: int = 5


func _on_hour_passed(_ticks) -> void:
	if GameState.is_loading_game:
		return

	var country_keys := countries.keys()
	var total := country_keys.size()
	if total == 0:
		return

	var countries_per_hour := int(ceil(float(total) / hours_per_full_country_tick))

	var processed := 0
	while processed < countries_per_hour and _hour_process_index < total:
		var c_name: String = country_keys[_hour_process_index]
		var country_obj: CountryData = countries[c_name]

		country_obj.process_hour()

		_hour_process_index += 1
		processed += 1

	if _hour_process_index >= total:
		_hour_process_index = 0


func _on_day_passed(_date) -> void:
	if GameState.is_loading_game:
		return

	for c_name: String in countries:
		var country_obj: CountryData = countries[c_name]
		country_obj.process_day()


func initialize_countries() -> void:
	if GameState.is_loading_game:
		print("CountryManager: Skipping initialization (loading save)")
		return
	countries.clear()

	var detected_countries = MapManager.country_to_provinces.keys()
	if detected_countries.is_empty():
		detected_countries = MapManager.country_colors.keys()

	for country_name in detected_countries:
		add_country(country_name)

	print("CountryManager: Initialized %d countries." % countries.size())


func get_country(c_name: String) -> CountryData:
	c_name = c_name.to_lower()
	if c_name == "sea":
		return null
	if countries.has(c_name):
		return countries[c_name]
	push_warning("CountryManager: Requested non-existent country '%s'" % c_name)
	return null


func set_player_country(country_name: String) -> void:
	var country := countries.get(country_name.to_lower()) as CountryData
	if !country:
		push_error("CountryManager: Requested non-existent country '%s'" % country_name)
		return

	if player_country:
		player_country.is_player = false

	player_country = country
	player_country.is_player = true

	print("Player is now playing as: ", country_name)
	emit_signal("player_country_changed")


func add_country(country_name: String) -> CountryData:
	if country_name == "sea":
		return
	var c_name_lower = country_name.to_lower()

	# 1. Check if it already exists
	if countries.has(c_name_lower):
		push_warning("CountryManager: Country '%s' already exists!" % country_name)
		return countries[c_name_lower]

	# 2. Check if the flag exists before proceeding
	var flag = TroopManager.get_flag(c_name_lower)
	if flag == null:
		push_error(
			"CountryManager: Cannot add '%s'. No flag found at res://assets/flags/" % country_name
		)
		return null

	# 3. If flag exists, create and store the country
	var new_country := CountryData.new(country_name)

	# NOTE Z21: Relations should be based on political affinity and stuff
	for existing_name in countries.keys():
		new_country.set_relation_with(existing_name, 50)
		countries[existing_name].set_relation_with(c_name_lower, 50)

	countries[c_name_lower] = new_country
	

	new_country.border_provinces = get_border_provinces_country(c_name_lower)
	new_country.enemy_border_provinces = get_neighbor_border_provinces(c_name_lower)
	new_country.neighbor_countries = get_neighboring_countries(c_name_lower)
	return new_country


# HELPER FUNCTIONS ==========================================
func get_border_provinces_country(country) -> Array[Province]:
	if !MapManager.country_to_provinces_obj.has(country):
		return []
	var border_provinces: Array[Province] = []
	for province in MapManager.country_to_provinces_obj[country]:
		if province.neighbors_obj.any(func(neighbor): return neighbor.country != country):
			border_provinces.append(province)
	return border_provinces


func get_neighbor_border_provinces(country) -> Array[Province]:
	if !MapManager.country_to_provinces_obj.has(country):
		return []

	var neighbor_provinces := {}

	for province in MapManager.country_to_provinces_obj[country]:
		for neighbor in province.neighbors_obj:
			if neighbor.country != country:
				neighbor_provinces[neighbor] = true

	var result: Array[Province] = []
	for p in neighbor_provinces.keys():
		result.append(p)

	return result


func get_neighboring_countries(country) -> Array[String]:
	if !MapManager.country_to_provinces_obj.has(country):
		return []

	var result: Array[String] = []

	for province in MapManager.country_to_provinces_obj[country]:
		for neighbor in province.neighbors_obj:
			if neighbor.country != country and neighbor.country not in result:
				result.append(neighbor.country)

	return result


func update_province_border_status(province: Province) -> void:
	var country = CountryManager.countries.get(province.country, null)
	if country == null:
		return

	var is_border := false
	var enemy_neighbors_to_add := []

	# Check neighbors
	for neighbor in province.neighbors_obj:
		if neighbor.country != province.country:  # province.country is string
			is_border = true
			if neighbor not in country.enemy_border_provinces:
				enemy_neighbors_to_add.append(neighbor)

	# --- Border provinces ---
	if is_border:
		if province not in country.border_provinces:
			country.border_provinces.append(province)
	else:
		country.border_provinces.erase(province)

	# --- Enemy border provinces ---
	for n in enemy_neighbors_to_add:
		country.enemy_border_provinces.append(n)

	# Remove old enemy neighbors that no longer border this country
# Remove old enemy neighbors that no longer border this country
	country.enemy_border_provinces = country.enemy_border_provinces.filter(
		func(p):
			# Determine the country name property safely
			var c_name = country.country_name if "country_name" in country else country.country

			# p is a Province object, compare its owner string
			return p.country != c_name
	)
	# --- Neighboring countries ---
	var neighbor_countries_set := {}
	for border_prov in country.border_provinces:
		for neighbor in border_prov.neighbors_obj:
			if neighbor.country != province.country:  # compare to province.country string
				neighbor_countries_set[neighbor.country] = true

	country.neighbor_countries = neighbor_countries_set.keys()


func get_country_population(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0
	var total_pop: int = 0
	var pids = MapManager.country_to_provinces[country_name]
	for pid in pids:
		if MapManager.province_objects.has(pid):
			total_pop += MapManager.province_objects[pid].population
	return total_pop

func get_factories_amount(country_name: String) -> int:
	var provinces = MapManager.country_to_provinces.get(country_name, [])
	var count = 0
	for pid in provinces:
		if MapManager.province_objects[pid].factory == Province.FACTORY_BUILT:
			count += 1
	return count


static func _get_manpower_from_template(type: String) -> int:
	var stats = DivisionData.TEMPLATES.get(type, DivisionData.TEMPLATES["infantry"])
	return stats["manpower"]


func _cleanup_empty_countries() -> void:
	var to_remove: Array[String] = []

	for c_name in countries.keys():
		var provinces = MapManager.country_to_provinces.get(countries[c_name].country_name, [])
		if provinces.is_empty():
			to_remove.append(c_name)

	for c_name in to_remove:
		print("CountryManager: Removing '%s' (No provinces found)." % c_name)
		countries.erase(c_name)
