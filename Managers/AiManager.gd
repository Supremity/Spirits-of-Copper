extends Node

const MIN_MONEY_RESERVE := 25000.0
const RECRUIT_MANPOWER_THRESHOLD := 15000
const PEACETIME_TICK_RATE := 120 # Only re-evaluate movement every 120 frames at peace
const GARRISON_HUB_COUNT := 3    # Keep units in exactly 3 spots during peace


func ai_handle_deployment(country: CountryData) -> void:
	if country.ready_troops.is_empty():
		return
	
	var hubs = _get_stable_hubs(country)
	
	for troop in country.ready_troops.duplicate():
		# Priority 1: Specifically requested deployment
		if country.deploy_pid != -1:
			country.deploy_ready_troop(troop)
		# Priority 2: Use stable hubs (keeps the map clean)
		elif not hubs.is_empty():
			var target_id = hubs.pick_random()
			TroopManager.deploy_specific_divisions(
				country.country_name, 
				troop.stored_divisions, 
				target_id
			)
			country.ready_troops.erase(troop)
		# Fallback: Default deployment
		else:
			country.deploy_ready_troop(troop)


func ai_consider_recruitment(country: CountryData) -> void:
	# 1. Calculate how many "Infantry" we can actually afford right now
	var template = DivisionData.TEMPLATES["infantry"]
	var cost_per = template["cost"]
	var man_per = template["manpower"]
	
	# 2. Check Financial/Manpower headroom
	var army_base_cost := 100.0
	var total_divs := 0
	for troop in TroopManager.get_troops_for_country(country.country_name):
		total_divs += troop.divisions_count
	
	var upkeep_buffer := (total_divs * army_base_cost) * 24
	var available_money = country.money - (MIN_MONEY_RESERVE + upkeep_buffer)
	var available_manpower = country.manpower - RECRUIT_MANPOWER_THRESHOLD
	
	# 3. Determine Batch Size
	if available_money < cost_per or available_manpower < man_per:
		return
		
	var can_afford_money = floor(available_money / cost_per)
	var can_afford_manpower = floor(available_manpower / man_per)
	
	# We train in batches of up to 5 at a time to keep it "calm"
	var batch_size = int(min(can_afford_money, can_afford_manpower))
	batch_size = clamp(batch_size, 1, 5) 

	country.train_troops(batch_size, "infantry")

func evaluate_frontline_moves(country: CountryData):
	var enemies = WarManager.get_enemies_of(country.country_name)
	var is_peace = enemies.is_empty()

	if is_peace and Engine.get_frames_drawn() % PEACETIME_TICK_RATE != 0:
		return

	var ai_troops = TroopManager.get_troops_for_country(country.country_name)
	var idle_troops = ai_troops.filter(func(t): return not t.is_moving)
	if idle_troops.is_empty(): return

	var move_payload = []

	if is_peace:
		var hubs = _get_stable_hubs(country)
		for troop in idle_troops:
			if not hubs.has(troop.province_id):
				move_payload.append({"troop": troop, "province_id": hubs.pick_random()})
	else:
		# --- WARTIME: MULTI-TARGET SPLITTING ---
		# 1. Get ALL possible targets (Cities, Armies, and Frontline neighbors)
		var all_targets = _find_tactical_targets(country.country_name)
		if all_targets.is_empty(): return

		for troop in idle_troops:
			# Determine how much this specific troop stack should "fan out"
			# More divisions = more splitting
			var max_splits = 1
			if troop.divisions_count >= 15:
				max_splits = 4 # Big army? Go 4 directions
			elif troop.divisions_count >= 6:
				max_splits = 2 # Medium army? Go 2 directions
			
			# Shuffle targets for this specific troop to ensure variety
			all_targets.shuffle()
			var chosen_for_this_troop = 0
			
			for target_id in all_targets:
				if chosen_for_this_troop >= max_splits: break
				
				# SATURATION CHECK:
				# Only send a split if the target isn't already heavily occupied by us
				var our_strength = TroopManager.get_province_strength(target_id, country.country_name)
				if our_strength < 5.0: # Cap: Don't send more if ~5 divs are already going there
					move_payload.append({"troop": troop, "province_id": target_id})
					chosen_for_this_troop += 1

	# Your command_move_assigned logic handles the actual division splitting
	if not move_payload.is_empty():
		TroopManager.command_move_assigned(move_payload)


func _find_tactical_targets(ai_country_name: String) -> Array:
	var targets: Array = []
	var enemies = WarManager.get_enemies_of(ai_country_name)

	if not enemies.is_empty():
		for enemy in enemies:
			# 1. Find our provinces that touch the enemy
			var our_frontline = MapManager.get_provinces_bordering_enemy(ai_country_name, enemy)

			# 2. For every frontline province we own, find the enemy neighbor to attack
			for our_pid in our_frontline:
				var province_data = MapManager.province_objects.get(our_pid)
				for neighbor_id in province_data.neighbors:
					# Is this neighbor owned by the enemy?
					if MapManager.province_to_country.get(neighbor_id) == enemy:
						if not targets.has(neighbor_id):
							targets.append(neighbor_id)

	# Fallback to defense if no enemy targets found
	if targets.is_empty():
		targets = MapManager.get_border_provinces(ai_country_name)

	return targets

func _get_stable_hubs(country: CountryData) -> Array:
	# Use a static property check to avoid the crash. 
	# If you haven't added the var to CountryData, it uses a fallback.
	if "cached_garrison_hubs" in country and not country.cached_garrison_hubs.is_empty():
		return country.cached_garrison_hubs

	var borders = MapManager.get_border_provinces(country.country_name)
	if borders.is_empty():
		return MapManager.get_cities_province_country(country.country_name).slice(0, 1)

	# Seed ensures hubs don't change every time we check
	seed(country.country_name.hash())
	borders.shuffle()
	var hubs = borders.slice(0, GARRISON_HUB_COUNT)
	seed(Time.get_ticks_msec())

	if "cached_garrison_hubs" in country:
		country.cached_garrison_hubs = hubs
	return hubs
