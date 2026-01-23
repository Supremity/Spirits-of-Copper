extends Node

# --- Constants ---
const BATTLE_TICK := 5.0  # How often battles update
const PROGRESS_MAX := 99.0
const MORALE_DECAY_RATE := 0.05
const BASE_DAMAGE_DIVISIONS := 1.0
const MORALE_BOOST_DEFENDER := 5.0
const HP_PER_DIVISION := 10.0

# --- State ---
var wars := {}
var active_battles := []


# --- Inner Class: Battle ---
class Battle:
	var attacker_pid: int
	var defender_pid: int
	var attacker_country: String
	var defender_country: String

	var attacker_stats: CountryData
	var defender_stats: CountryData

	var attack_progress := 0.0
	var att_morale: float
	var def_morale: float

	var province_hp: float
	var province_max_hp: float
	var total_initial_strength: float
	var timer := 0.0
	var position: Vector2
	var manager  # Reference to WarManager

	func _init(atk_pid: int, def_pid: int, atk_c: String, def_c: String, pos: Vector2, m):
		attacker_pid = atk_pid
		defender_pid = def_pid
		attacker_country = atk_c
		defender_country = def_c
		position = pos
		manager = m

		attacker_stats = CountryManager.get_country(attacker_country)
		defender_stats = CountryManager.get_country(defender_country)

		var att_divs = _get_divisions(attacker_pid, attacker_country)
		var def_divs = _get_divisions(defender_pid, defender_country)

		total_initial_strength = max(1.0, att_divs + def_divs)
		province_max_hp = max(1.0, def_divs * manager.HP_PER_DIVISION)
		province_hp = province_max_hp

		# Init Morale
		if attacker_stats:
			att_morale = attacker_stats.get_max_morale()
		else:
			att_morale = 80.0

		if defender_stats:
			def_morale = defender_stats.get_max_morale() + manager.MORALE_BOOST_DEFENDER
		else:
			def_morale = 80.0 + manager.MORALE_BOOST_DEFENDER

	func tick(delta: float):
		timer += delta
		if timer >= manager.BATTLE_TICK:
			timer -= manager.BATTLE_TICK
			_resolve_round()

	func _resolve_round():
		var att_troops = TroopManager.get_troops_in_province(attacker_pid).filter(func(t): return t.country_name == attacker_country)
		var def_troops = TroopManager.get_troops_in_province(defender_pid).filter(func(t): return t.country_name == defender_country)

		if att_troops.is_empty():
			manager.end_battle(self)
			return

		# 1. Sum up REAL stats from every division object
		var total_atk_power = 0.0
		for t in att_troops:
			for div in t.stored_divisions:
				# We multiply by (div.hp / 100.0) so damaged units deal less damage!
				total_atk_power += div.get_attack_power() * (div.hp / 100.0)

		var total_def_power = 0.0
		for t in def_troops:
			for div in t.stored_divisions:
				total_def_power += div.get_defense_power() * (div.hp / 100.0)

		# 2. Apply Morale and Country Modifiers
		var att_mult = attacker_stats.get_attack_efficiency() if attacker_stats else 1.0
		var def_mult = defender_stats.get_defense_efficiency() if defender_stats else 1.0

		var final_attack = total_atk_power * (att_morale / 100.0) * att_mult
		var final_defense = total_def_power * (def_morale / 100.0) * def_mult

		# 3. Damage Calculation
		# Damage the HP of the divisions (using your apply_casualties fix below)
		manager.apply_casualties(defender_pid, defender_country, final_attack * 0.5)
		manager.apply_casualties(attacker_pid, attacker_country, final_defense * 0.2)

		# 4. Morale Decay
		att_morale -= (final_defense * manager.MORALE_DECAY_RATE)
		def_morale -= (final_attack * manager.MORALE_DECAY_RATE)

		# Victory Check
		if province_hp <= 0 or def_morale <= 1.0:
			_defender_loses()
		elif att_morale <= 1.0:
			manager.end_battle(self)

	func _defender_loses():
		var troops = TroopManager.get_troops_in_province(defender_pid)
		var retreat_pid = _find_retreat_province(defender_pid, defender_country)

		for t in troops:
			if t.country_name != defender_country: continue

			if retreat_pid == -1 or randf() < 0.3: # 30% chance to get "Overrun" (destroyed)
				TroopManager.remove_troop(t)
			else:
				# RETREAT: They lose 20% of their divisions randomly
				var shatter_count = ceil(t.stored_divisions.size() * 0.2)
				for i in range(shatter_count):
					if not t.stored_divisions.is_empty():
						t.stored_divisions.remove_at(randi() % t.stored_divisions.size())
				
				if t.stored_divisions.is_empty():
					TroopManager.remove_troop(t)
				else:
					TroopManager.teleport_troop_to_province(t, retreat_pid)

		MapManager.transfer_ownership(defender_pid, attacker_country)
		manager._check_country_collapse(defender_country, attacker_country)
		manager.end_battle(self)

	func _find_retreat_province(from_pid: int, country: String) -> int:
		if not MapManager.adjacency_list.has(from_pid):
			return -1
		for n in MapManager.adjacency_list[from_pid]:
			var province_troops = TroopManager.troops_by_province.get(n, [])
			# Retreat to friendly province with no enemies
			if province_troops.is_empty() and MapManager.province_to_country[n] == country:
				return n
		return -1

	func _get_divisions(pid: int, country: String) -> float:
		return float(TroopManager.get_province_strength(pid, country))

	func get_player_relative_progress(player_country: String) -> float:
		return attack_progress if attacker_country == player_country else -attack_progress


func _process(delta: float):
	if active_battles.is_empty():
		return
	var current_intensity = delta * GameState.current_world.clock.time_scale
	if current_intensity <= 0:
		return

	for battle in active_battles:
		battle.tick(current_intensity)


func start_battle(attacker_pid: int, defender_pid: int):
	# Prevent duplicate battles
	for b in active_battles:
		if b.attacker_pid == attacker_pid and b.defender_pid == defender_pid:
			return

	var att_troops = TroopManager.get_troops_in_province(attacker_pid)
	var def_troops = TroopManager.get_troops_in_province(defender_pid)

	if att_troops.is_empty() or def_troops.is_empty():
		return

	var atk_country = att_troops[0].country_name
	var def_country = def_troops[0].country_name
	var midpoint = get_province_midpoint(attacker_pid, defender_pid)

	var battle = Battle.new(attacker_pid, defender_pid, atk_country, def_country, midpoint, self)
	active_battles.append(battle)


func end_battle(battle: Battle):
	if active_battles.has(battle):
		active_battles.erase(battle)


func apply_casualties(pid: int, country: String, damage_amount: float):
	var troops_list = TroopManager.get_troops_in_province(pid).filter(
		func(t): return t.country_name == country
	)
	if troops_list.is_empty() or damage_amount <= 0:
		return

	# Spread damage across all troops in the province
	var damage_per_troop = damage_amount / troops_list.size()

	for t in troops_list:
		if t.stored_divisions.is_empty(): continue
		
		# Spread damage across all divisions in this troop
		var damage_per_div = damage_per_troop / t.stored_divisions.size()
		
		# Loop backwards so we can safely remove dead divisions
		for i in range(t.stored_divisions.size() - 1, -1, -1):
			var div = t.stored_divisions[i]
			div.hp -= damage_per_div
			
			# Gain a little experience for fighting!
			div.experience = min(1.0, div.experience + 0.01)

			if div.hp <= 0:
				t.stored_divisions.remove_at(i)
		
		# If all divisions in the troop died, remove the troop from map
		if t.stored_divisions.is_empty():
			TroopManager.remove_troop(t)


func resolve_province_arrival(pid: int, troop: TroopData):
	var target_country = MapManager.province_to_country.get(pid)

	if target_country != troop.country_name and is_at_war_names(troop.country_name, target_country):
		var enemies = TroopManager.get_province_strength(pid, target_country)

		if enemies <= 0:
			MapManager.transfer_ownership(pid, troop.country_name)
			_check_country_collapse(target_country, troop.country_name)


func declare_war(a: CountryData, b: CountryData) -> void:
	var ok := add_war_silent(a, b)
	if not ok:
		return


	PopupManager.show_alert("war", a, b)
	if (a.is_player):
		MusicManager.play_music(MusicManager.MUSIC.BATTLE_THEME)
		MusicManager.play_sfx(MusicManager.SFX.DECLARE_WAR)


func add_war_silent(a: CountryData, b: CountryData) -> bool:
	if a == b or is_at_war(a, b):
		return false
	if not wars.has(a):
		wars[a] = {}
	if not wars.has(b):
		wars[b] = {}

	wars[a][b] = true
	wars[b][a] = true

	if not a.allowedCountries.has(b.country_name):
		a.allowedCountries.append(b.country_name)
	if not b.allowedCountries.has(a.country_name):
		b.allowedCountries.append(a.country_name)
	
	return true


func is_at_war(a: CountryData, b: CountryData) -> bool:
	return wars.has(a) and wars[a].has(b)


func is_country_at_war(country_name: String) -> bool:
	var country_data = CountryManager.get_country(country_name)
	if not country_data:
		return false

	return wars.has(country_data) and not wars[country_data].is_empty()

func is_at_war_names(a_name: String, b_name: String) -> bool:
	if not CountryManager:
		return false
	var a_data = CountryManager.get_country(a_name)
	var b_data = CountryManager.get_country(b_name)
	if a_data and b_data:
		return is_at_war(a_data, b_data)
	return false


# API for AI Manager
func get_countries_at_war() -> Array:
	return wars.keys()


## Returns an array of country names that are currently at war with the given country name
func get_enemies_of(country_name: String) -> Array[String]:
	var enemies: Array[String] = []
	var country_data = CountryManager.get_country(country_name)

	if not country_data or not wars.has(country_data):
		return enemies

	# wars[country_data] returns a Dictionary where keys are enemy CountryData objects
	for enemy_data in wars[country_data].keys():
		enemies.append(enemy_data.country_name)

	MapManager.get_cities_province_country(country_name)

	return enemies


func get_province_midpoint(pid1: int, pid2: int) -> Vector2:
	if not MapManager:
		return Vector2.ZERO
	var c1 = MapManager.province_centers.get(pid1, Vector2.ZERO)
	var c2 = MapManager.province_centers.get(pid2, Vector2.ZERO)
	return (c1 + c2) * 0.5


func _check_country_collapse(country_name: String, victor_name: String):
	var cities = MapManager.get_cities_province_country(country_name)

	if cities.size() == 0:
		_handle_total_collapse(country_name, victor_name)


func _handle_total_collapse(fallen_country_name: String, victor_country_name: String):

	# 1. Get all provinces owned by the fallen country
	var all_provinces = MapManager.country_to_provinces.get(fallen_country_name, []).duplicate()

	# 2. Transfer every single one to the victor
	for pid in all_provinces:
		MapManager.transfer_ownership(pid, victor_country_name)

	# 3. Wipe any remaining troops of the fallen country from the map
	var remaining_troops = TroopManager.get_troops_for_country(fallen_country_name).duplicate()
	for t in remaining_troops:
		TroopManager.remove_troop(t)

	# 4. Remove the country from all active wars
	var fallen_data = CountryManager.get_country(fallen_country_name)
	if wars.has(fallen_data):
		wars.erase(fallen_data)

	# Clean up other countries' war lists
	for country_obj in wars:
		if wars[country_obj].has(fallen_data):
			wars[country_obj].erase(fallen_data)

	if fallen_country_name == CountryManager.player_country.country_name:
		MusicManager.play_sfx(MusicManager.SFX.GAME_OVER)
		PopupManager.show_alert(
			"game_over", CountryManager.player_country, CountryManager.player_country
		)
		MusicManager.play_music(MusicManager.MUSIC.MAIN_THEME)
	elif victor_country_name == CountryManager.player_country.country_name:
		if !is_country_at_war(victor_country_name):
			MusicManager.play_music(MusicManager.MUSIC.MAIN_THEME)
			pass
		pass
		
	MusicManager.play_sfx(MusicManager.SFX.POPUP)
	PopupManager.show_alert(
		"capitulated", CountryManager.get_country(fallen_country_name), CountryManager.get_country(fallen_country_name)
	)
