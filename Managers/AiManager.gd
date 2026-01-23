extends Node
class_name AIController

# --- TUNING ---
const TICK_RATE_PEACE := 120  # Slower thinking in peace time
const TICK_RATE_WAR := 20     # Think fast during war
const SATURATION_IDEAL := 1.0 # Target: At least 1 division equivalent per province
const SATURATION_MAX := 4.0   # Avoid overstacking; redistribute if exceeding
const ATTACK_WEIGHT := 2.0    # Multiplier for provinces with enemy troops
const DEFENSE_WEIGHT := 1.5   # Multiplier for defending own borders under threat
const CITY_BONUS := 50.0      # Extra score for cities
const DISTANCE_PENALTY := 0.1 # Reduce score per unit distance to discourage far moves
const MIN_DIVISIONS_PER_SPLIT := 1  # Smallest split size
const MAX_SPLITS_PER_TROOP := 10    # Limit splits to prevent micro-management overhead

func ai_tick(country: CountryData) -> void:
	var tick_rate = TICK_RATE_WAR if _is_at_war(country) else TICK_RATE_PEACE
	if Engine.get_frames_drawn() % tick_rate != 0:
		return

	_manage_recruitment(country)
	_handle_deployment(country)
	_manage_frontline_logic(country)

# --- THE FRONTLINE LOGIC ---
func _manage_frontline_logic(country: CountryData) -> void:
	var my_troops = TroopManager.get_troops_for_country(country.country_name)
	var idle_troops = my_troops.filter(func(t): return not t.is_moving)
	if idle_troops.is_empty(): return

	var enemies = WarManager.get_enemies_of(country.country_name)
	if enemies.is_empty(): 
		_handle_peace_movement(country, idle_troops)
		return

	# 1. Analyze the front: find cities, enemy units, and empty gaps
	var frontline_targets = _analyze_frontline_targets(country, enemies)
	if frontline_targets.is_empty(): return

	var move_payload = []
	
	# 2. Assigning logic: spread idle troops across the closest targets
	for troop in idle_troops:
		var troop_pos = MapManager.province_centers[troop.province_id]
		
		# Sort targets by distance to THIS specific troop
		frontline_targets.sort_custom(func(a, b):
			var dist_a = troop_pos.distance_to(MapManager.province_centers[a.id])
			var dist_b = troop_pos.distance_to(MapManager.province_centers[b.id])
			return dist_a < dist_b
		)

		# How many ways should we split this troop?
		# A troop with 10 divs can fill up to 5 gaps (2 divs each)
		var max_splits = clampi(floor(troop.divisions_count / 2.0), 1, 6)
		var assigned_count = 0

		for target in frontline_targets:
			if assigned_count >= max_splits: break
			
			# If the target is already being addressed by another troop, skip it
			if target.virtual_strength >= SATURATION_IDEAL:
				continue

			# Add to the payload. 
			# If the same troop appears 3 times here, your command_move_assigned 
			# logic will handle splitting the divisions into 3 new troops.
			move_payload.append({
				"troop": troop, 
				"province_id": target.id
			})

			# Mark the province as "covered"
			target.virtual_strength += (troop.divisions_count / max_splits)
			assigned_count += 1

	# 3. Fire the move command
	if not move_payload.is_empty():
		TroopManager.command_move_assigned(move_payload)

# --- ANALYSIS: OFFENSIVE AND DEFENSIVE GAPS ---
func _analyze_frontline_targets(country: CountryData, enemies: Array) -> Array:
	var targets = []
	var seen = {}

	for enemy_name in enemies:
		var border_pids = MapManager.get_provinces_bordering_enemy(country.country_name, enemy_name)
		
		for my_pid in border_pids:
			# Defensive targets: My own border provinces under threat
			if not seen.has(my_pid):
				seen[my_pid] = true
				var enemy_threat = 0.0
				var neighbors = MapManager.adjacency_list.get(my_pid, [])
				for n_id in neighbors:
					if MapManager.province_to_country.get(n_id) == enemy_name:
						enemy_threat += TroopManager.get_province_strength(n_id, enemy_name)
				
				if enemy_threat > 0:
					var current_str = TroopManager.get_province_strength(my_pid, country.country_name)
					var score = enemy_threat * DEFENSE_WEIGHT
					if my_pid in MapManager.all_cities: score += CITY_BONUS
					
					targets.append({
						"id": my_pid,
						"virtual_strength": current_str,
						"score": score,
						"is_defensive": true
					})
			
			# Offensive targets: Enemy provinces bordering mine
			var neighbors = MapManager.adjacency_list.get(my_pid, [])
			for n_id in neighbors:
				if MapManager.province_to_country.get(n_id) == enemy_name and not seen.has(n_id):
					seen[n_id] = true
					var enemy_str = TroopManager.get_province_strength(n_id, enemy_name)
					var current_friendly = TroopManager.get_province_strength(n_id, country.country_name)  # Likely 0 if enemy-owned
					
					var score = 10.0
					if enemy_str > 0: score *= ATTACK_WEIGHT
					if n_id in MapManager.all_cities: score += CITY_BONUS
					
					targets.append({
						"id": n_id,
						"virtual_strength": current_friendly,
						"score": score,
						"is_defensive": false
					})

	# Adjust scores for distance (global adjustment assuming average, or per-troop later)
	# For now, skip per-distance as we sort globally and then closest troop
	
	return targets

# --- PEACE / DEPLOYMENT HELPERS ---
func _handle_peace_movement(country: CountryData, idle_troops: Array) -> void:
	var hubs = _get_peace_hubs(country)
	var move_payload = []
	for troop in idle_troops:
		if not hubs.has(troop.province_id):
			# Choose closest hub to avoid unnecessary long moves
			var troop_pos = MapManager.province_centers[troop.province_id]
			hubs.sort_custom(func(a, b):
				var dist_a = troop_pos.distance_to(MapManager.province_centers[a])
				var dist_b = troop_pos.distance_to(MapManager.province_centers[b])
				return dist_a < dist_b
			)
			move_payload.append({"troop": troop, "province_id": hubs[0]})
	if not move_payload.is_empty(): TroopManager.command_move_assigned(move_payload)

func _get_peace_hubs(country: CountryData) -> Array:
	if "cached_garrison_hubs" in country and not country.cached_garrison_hubs.is_empty():
		return country.cached_garrison_hubs
	var cities = MapManager.get_cities_province_country(country.country_name)
	if cities.is_empty(): 
		cities = MapManager.country_to_provinces.get(country.country_name, []).slice(0, 5)  # More hubs for larger countries
	cities.shuffle()
	country.cached_garrison_hubs = cities.slice(0, mini(5, cities.size()))
	return country.cached_garrison_hubs

func _is_at_war(country: CountryData) -> bool:
	return not WarManager.get_enemies_of(country.country_name).is_empty()

func _manage_recruitment(country: CountryData) -> void:
	# Improved: Recruit based on current needs (e.g., more if at war)
	var template = DivisionData.TEMPLATES["infantry"]  # Could vary templates based on tech/manpower
	var cost_per = template["cost"]
	var mp_per = template["manpower"]
	var max_affordable = mini(int(country.money / cost_per), int(country.manpower / mp_per))
	if max_affordable < 1: return
	
	var target_recruit = clampi(max_affordable, 1, 10)
	if _is_at_war(country): target_recruit *= 2  # Recruit more aggressively in war
	target_recruit = mini(target_recruit, max_affordable)
	
	country.train_troops(target_recruit, "infantry")

func _handle_deployment(country: CountryData) -> void:
	if country.ready_troops.is_empty(): return
	
	var enemies = WarManager.get_enemies_of(country.country_name)
	var targets = _analyze_frontline_targets(country, enemies)
	if not targets.is_empty():
		targets.sort_custom(func(a, b): return a.score > b.score)
	
	for troop_data in country.ready_troops.duplicate():
		var deploy_id
		if not targets.is_empty():
			# Deploy to highest-score target
			deploy_id = targets[0].id
			# Update virtual to avoid over-deploying (though deployments are instant?)
			targets[0].virtual_strength += troop_data.stored_divisions.size()
		else:
			deploy_id = _get_peace_hubs(country).pick_random()
		
		TroopManager.deploy_specific_divisions(country.country_name, troop_data.stored_divisions, deploy_id)
		country.ready_troops.erase(troop_data)
