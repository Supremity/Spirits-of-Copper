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

# --- AI DIPLOMACY/WAR LOGIC---
const DECLARE_WAR_COOLDOWN_FRAMES := 60 * 10
const MIN_STRENGTH_RATIO := 1.1
const MAX_PARALLEL_WARS := 2
const WAR_SCORE_THRESHOLD := 0.6
const MAX_WAR_DECLARATIONS_PER_TICK := 1

const WAR_PROBABILITY_BASE := 0.1 
const MIN_ECONOMY_FOR_WAR := 15000.0 
const TENSION_AGGRESSION_FACTOR := 2.0 

var _last_declare_frame: Dictionary = {}
var world_tension = 1

func increase_world_tension(amount: float) -> void:
	world_tension = clamp(world_tension + amount, 0.1, 1.0)
	print(world_tension)

func ai_tick(country: CountryData) -> void:
	var tick_rate = TICK_RATE_WAR if _is_at_war(country) else TICK_RATE_PEACE
	if Engine.get_frames_drawn() % tick_rate != 0:
		return

	_manage_recruitment(country)
	_handle_deployment(country)
	_manage_frontline_logic(country)
	_consider_declaring_war(country)

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
		
		if deploy_id:
			TroopManager.deploy_specific_divisions(country.country_name, troop_data.stored_divisions, deploy_id)
		country.ready_troops.erase(troop_data)


# -- War Declaration Logic -- #
func _consider_declaring_war(country: CountryData) -> void:
	# 1. THE STOCHASTIC GATE (Randomness + World Tension)
	# If tension is 0.1, chance is roughly 10%. If tension is 1.0, it's 100%.
	var current_tension = world_tension # Assuming this exists
	var roll = randf()
	
	# Only proceed if we pass the probability check
	if roll > (current_tension * TENSION_AGGRESSION_FACTOR):
		if roll > WAR_PROBABILITY_BASE: # Even at 0 tension, a small base chance
			return

	# 2. COOLDOWNS & OVEREXTENSION (Existing)
	var frame_now = Engine.get_frames_drawn()
	var last_frame = _last_declare_frame.get(country.country_name, -999999)
	if frame_now - last_frame < DECLARE_WAR_COOLDOWN_FRAMES:
		return

	if WarManager.get_enemies_of(country.country_name).size() >= MAX_PARALLEL_WARS:
		return

	# 3. ECONOMIC PRUDENCE
	# AI won't start a war if they can't afford to sustain it
	if country.money < MIN_ECONOMY_FOR_WAR:
		return

	var candidates = _get_neighbor_countries(country)
	if candidates.is_empty(): return

	var best_score = -INF
	var best_target = null

	for target_name in candidates:
		if WarManager.is_at_war_names(country.country_name, target_name):
			continue

		# 4. STRENGTH & DISTANCE ANALYSIS
		var my_strength = _estimate_country_strength(country.country_name)
		var their_strength = _estimate_country_strength(target_name)
		var ratio = my_strength / max(1.0, their_strength)

		if ratio < MIN_STRENGTH_RATIO: continue

		# 5. DYNAMIC SCORING
		var score = (ratio - 1.0) * 2.0
		
		# Economic Gain: Is this neighbor rich? (GDP check)
		# Assuming you have access to target's money or GDP
		var target_data = CountryManager.get_country(target_name)
		if target_data:
			score += (target_data.money / 50000.0) # Prefer rich targets
			
		# Target Cities (Existing)
		var target_cities = MapManager.get_cities_province_country(target_name)
		score += min(target_cities.size(), 3) * 0.5

		# 6. FINAL THRESHOLD
		# We add a bit of randomness to the score so it's not always the same neighbor
		score += randf_range(-0.5, 0.5)

		if score > best_score and score > WAR_SCORE_THRESHOLD:
			best_score = score
			best_target = target_name

	# 7. EXECUTION
	if best_target:
		_execute_war_declaration(country, best_target, frame_now)

func _execute_war_declaration(country: CountryData, target_name: String, frame: int):
	var target_data = CountryManager.get_country(target_name)
	if target_data:
		WarManager.declare_war(country, target_data)
		# Increasing tension on every war slows down/speeds up the global state
		world_tension += 0.02 
		
		_last_declare_frame[country.country_name] = frame

# --- Utility routines for country strength and neighbors ---

func _estimate_country_strength(country_name: String) -> float:
	var total = 0.0
	var c = CountryManager.get_country(country_name)
	if c:
		
		total += float(c.manpower)
		total += float(c.money) * 0.1
	if TroopManager.has_method("get_troops_for_country"):
		var troops = TroopManager.get_troops_for_country(country_name)
		for t in troops:
			for div in t.stored_divisions:
				total += float(div.max_manpower)
				total += float(div.hp)
	return max(0.1, total)

func _get_neighbor_countries(country: CountryData) -> Array:
	var neighbors := {}
	var provs = MapManager.country_to_provinces.get(country.country_name, [])
	for pid in provs:
		var adj = MapManager.adjacency_list.get(pid, [])
		for nid in adj:
			var owner = MapManager.province_to_country.get(nid)
			if owner and owner != country.country_name:
				neighbors[owner] = true
	return neighbors.keys()
