extends Node
# Autoload Name: DecisionManager

var categories: Dictionary = {}
var active_decisions: Dictionary = {} # { "Germany": { "eco_1": 5 } }
var ui_overlay = null 

func _ready():
	var file = FileAccess.get_file_as_string("res://decisions.json")
	if file: categories = JSON.parse_string(file).get("categories", {})

# --- TICKING SYSTEM ---
func process_country_day(country: CountryData):
	if not active_decisions.has(country.country_name): return
	
	var tasks = active_decisions[country.country_name]
	var finished = []
	
	for key in tasks.keys():
		tasks[key] -= 1
		if tasks[key] <= 0:
			finished.append(key)
			_finalize_decision(country, key)
	
	for key in finished: tasks.erase(key)
	
	if ui_overlay and ui_overlay.visible and country.is_player:
		ui_overlay.refresh_status_only() # Efficient refresh

# --- ACTIONS ---
func can_take_decision(country: CountryData, cat: String, index: int) -> bool:
	var data = categories[cat][index]
	var id = data["id"]
	
	# 1. NEW: Check if busy with ANY decision
	if is_country_busy(country):
		return false
		
	# 2. Check if already done or currently this specific one (redundant but safe)
	if country.has_meta("finished_" + id) or is_in_progress(country, id): return false
	
	# 3. Check Prerequisite
	if data.has("prereq"):
		var parent_id = data["prereq"]
		if not country.has_meta("finished_" + parent_id): return false
	
	# 4. Check Cost
	if country.political_power < data.get("cost_pp", 0): return false
	
	return true

func start_decision(country: CountryData, cat: String, index: int):
	if not can_take_decision(country, cat, index): return
	
	var data = categories[cat][index]
	country.political_power -= data.get("cost_pp", 0)
	
	if not active_decisions.has(country.country_name):
		active_decisions[country.country_name] = {}
		
	active_decisions[country.country_name][data["id"]] = data.get("days", 5)
	
	if ui_overlay and country.is_player: ui_overlay.refresh_status_only()

func _finalize_decision(country: CountryData, id: String):
	country.set_meta("finished_" + id, true)
	
	# Find the data to get the action (Slow search, but happens rarely)
	for cat in categories:
		for node in categories[cat]:
			if node["id"] == id:
				_apply_reward(country, node.get("action", {}))
				return

func _apply_reward(country: CountryData, action: Dictionary):
	match action.get("type", ""):
		"increase_hourly_money": country.hourly_money_income += action.get("amount", 0)
		"increase_manpower": country.manpower += action.get("amount", 0)
		"increase_daily_pp": country.daily_pp_gain += action.get("amount", 0)
		"increase_stability": country.stability = min(1.0, country.stability + action.get("amount", 0))
		"army_level_up": country.army_level += 1
		"build_factory": country.factories_amount += action.get("amount", 1)

# --- HELPERS ---
func is_in_progress(country: CountryData, id: String) -> bool:
	return active_decisions.get(country.country_name, {}).has(id)

func get_days_left(country: CountryData, id: String) -> int:
	return active_decisions.get(country.country_name, {}).get(id, 0)
	
# Add/Update these functions in DecisionManager.gd

# Check if the country has ANY active timers
func is_country_busy(country: CountryData) -> bool:
	if not active_decisions.has(country.country_name):
		return false
	return not active_decisions[country.country_name].is_empty()
