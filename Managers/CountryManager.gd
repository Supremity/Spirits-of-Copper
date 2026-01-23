extends Node

signal player_country_changed
var countries: Dictionary[String, CountryData] = {}
var player_country: CountryData


func _on_hour_passed() -> void:
	for c_name: String in countries:
		var country_obj: CountryData = countries[c_name]
		country_obj.process_hour()


func _on_day_passed() -> void:
	for c_name: String in countries:
		var country_obj: CountryData = countries[c_name]
		country_obj.process_day()


func initialize_countries() -> void:
	countries.clear()

	var detected_countries = MapManager.country_to_provinces.keys()
	if detected_countries.is_empty():
		push_warning("CountryManager: No countries detected in MapManager!")
		detected_countries = MapManager.country_colors.keys()

	for country_name in detected_countries:
		var new_country := CountryData.new(country_name)
		countries[country_name] = new_country

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


# HELPER FUNCTIONS ==========================================


func get_country_population(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0
	var total_pop: int = 0
	var pids = MapManager.country_to_provinces[country_name]
	for pid in pids:
		if MapManager.province_objects.has(pid):
			total_pop += MapManager.province_objects[pid].population
	return total_pop


func get_country_gdp(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0

	var total_gdp: int = 0
	var pids = MapManager.country_to_provinces[country_name]

	for pid in pids:
		if MapManager.province_objects.has(pid):
			total_gdp += MapManager.province_objects[pid].gdp

	return total_gdp


func get_factories_amount(country_name: String) -> int:
	var provinces = MapManager.country_to_provinces.get(country_name, [])
	return provinces.reduce(
		func(accum, pid): return accum + (1 if MapManager.province_objects[pid].has_factory else 0),
		0
	)


# NOTE(pol): We should keep track of the manpower used instead of recalculating
# In CountryManager.gd (or wherever this static function lives)
static func get_country_used_manpower(country_obj: CountryData) -> int:
	var total_used: int = 0
	
	var active_troops = TroopManager.get_troops_for_country(country_obj.country_name)
	for troop in active_troops:
		for div in troop.stored_divisions:
			total_used += div.max_manpower
			
	for training in country_obj.ongoing_training:
		var stats = DivisionData.TEMPLATES.get(training.division_type)
		if stats:
			total_used += (training.divisions_count * stats["manpower"])

	for batch in country_obj.ready_troops:
		for div in batch.stored_divisions:
			total_used += div.max_manpower
			
	return total_used
	
