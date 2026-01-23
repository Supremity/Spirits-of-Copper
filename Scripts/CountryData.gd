extends Resource
class_name CountryData

#region --- Configuration & Constants ---
const MANPOWER_RECOVERY_PER_YEAR := 0.10 
const MANPOWER_RECOVERY_PER_DAY := MANPOWER_RECOVERY_PER_YEAR / 365.0
const MILITARY_SIZE_RATIO := 0.005 # 0.5% of population recruitable
const BASE_ARMY_COST := 100.0      # Multiplied by army level
#endregion

#region --- Properties ---
var country_name: String
var is_player: bool = false

# Economy
var money: float = 0.0
var gdp: int = 0
var income: float = 0.0
var factories_amount: int = 0
var hourly_money_income: float = 0.0 # Calculated value

# Politics
var political_power: float = 50.0
var daily_pp_gain: float = 0.04
var stability: float = 0.5
var war_support: float = 0.5

# Population & Manpower
var total_population: int = 0
var manpower: int = 0

# Military State
var army_level: int = 1
var army_cost: float = 0.0
var troop_speed_modifier: float = 1.0

# Deployment & Training State
var allowedCountries: Array[String] = []
var ongoing_training: Array[TroopTraining] = []
var ready_troops: Array[ReadyTroop] = []
var deploy_pid: int = -1 # ID of province to deploy to
#endregion

#region --- Inner Classes ---
class TroopTraining:
	var divisions_count: int
	var division_type: String
	var days_left: int
	var daily_cost: float
	
	func _init(_count: int, _type: String, _days: int, _cost: float):
		divisions_count = _count
		division_type = _type
		days_left = _days
		daily_cost = _cost

class ReadyTroop:
	var stored_divisions: Array[DivisionData] = []
	func _init(_divisions_array: Array[DivisionData]):
		stored_divisions = _divisions_array
#endregion

#region --- Lifecycle ---
func _init(p_country_name: String) -> void:
	country_name = p_country_name
	allowedCountries.append_array([p_country_name, "sea"])
	_refresh_economic_stats()
	
	# Initial Manpower Calculation
	var manpower_used = CountryManager.get_country_used_manpower(self)
	manpower = int((total_population * MILITARY_SIZE_RATIO) - manpower_used)

func process_hour() -> void:
	political_power += daily_pp_gain
	
	# Economic Cycle
	# (GDP / Hours in a year) * Tax Rate + Factory Output
	var base_income = (gdp / 8760.0) * 0.2 
	var factory_income = factories_amount * 1000.0
	
	hourly_money_income = base_income + factory_income
	army_cost = calculate_army_upkeep()
	
	income = hourly_money_income - army_cost
	money += income
	
	troop_speed_modifier = 1.0 + (army_level * 0.1)

	update_manpower_pool()
	
	if not is_player:
		AiManager.ai_handle_deployment(self)
		AiManager.ai_consider_recruitment(self)

func process_day() -> void:
	# Refresh stats that change daily/weekly
	_refresh_economic_stats()
	_process_training()
	
	if not is_player:
		AiManager.evaluate_frontline_moves(self)
	#	AiManager.manage_military_readiness(self)

func _refresh_economic_stats() -> void:
	total_population = CountryManager.get_country_population(country_name)
	factories_amount = CountryManager.get_factories_amount(country_name)
	# GDP calculation based on population (Simplified for performance)
	gdp = int(CountryManager.get_country_gdp(country_name) * total_population * 0.000001)
#endregion

#region --- Military Management ---
func train_troops(count: int, type: String = "infantry") -> bool:
	var template = DivisionData.TEMPLATES.get(type)
	if not template:
		push_error("Unknown division type: %s" % type)
		return false

	var total_manpower_needed = count * template["manpower"]
	var daily_cost = count * template["cost"]
	
	# Check affordability (Manpower + First day of cost)
	if manpower < total_manpower_needed or money < daily_cost:
		return false

	manpower -= total_manpower_needed
	
	# Add to training queue
	var training_batch = TroopTraining.new(count, type, template["days"], template["cost"])
	ongoing_training.append(training_batch)
	return true

func _process_training() -> void:
	# Loop backwards so we can safely remove finished batches
	for i in range(ongoing_training.size() - 1, -1, -1):
		var training = ongoing_training[i]
		var batch_daily_cost = training.divisions_count * training.daily_cost
		
		if money >= batch_daily_cost:
			money -= batch_daily_cost
			training.days_left -= 1
		
		if training.days_left <= 0:
			_graduate_troops(training)
			ongoing_training.remove_at(i)

func _graduate_troops(training: TroopTraining) -> void:
	var new_divisions: Array[DivisionData] = []
	for d in range(training.divisions_count):
		new_divisions.append(DivisionData.create_division(training.division_type))
	
	ready_troops.append(ReadyTroop.new(new_divisions))

#endregion

#region --- Stats & Manpower ---
func update_manpower_pool() -> void:
	var base_reservoir = int(total_population * MILITARY_SIZE_RATIO)
	var max_cap = int(base_reservoir * 1.5)
	var used = CountryManager.get_country_used_manpower(self)
	var current_total = manpower + used

	if current_total < max_cap:
		var gain = max(1, int(base_reservoir * MANPOWER_RECOVERY_PER_DAY))
		manpower += gain
	
	# Hard cap check
	if (manpower + used) > max_cap:
		manpower = max(0, max_cap - used)

func get_army_pressure() -> float:
	var army_size = 0
	for troop in TroopManager.get_troops_for_country(country_name):
		army_size += troop.divisions # assuming .divisions property exists on TroopData
	
	var capacity = max(1.0, (gdp * 0.03) + factories_amount * 5)
	return army_size / capacity

func get_max_morale() -> float:
	var base = 60.0 + (stability * 40.0) + (army_level * 5.0)
	return base * 0.5 if money < 0 else base

func get_attack_efficiency() -> float:
	var eff = 0.9 + (war_support * 0.3) + (army_level * 0.05)
	return eff * 0.7 if money < 0 else eff

func get_defense_efficiency() -> float:
	var eff = 1.0 + (stability * 0.15) + (army_level * 0.05)
	return eff * 0.8 if money < 0 else eff
#endregion

#region --- Deployment Helper ---
func deploy_ready_troop(troop: ReadyTroop, specific_pid: int = -1) -> bool:
	var index = ready_troops.find(troop)
	if index == -1: return false
	
	var target_pid = specific_pid
	
	# If no specific ID provided, pick random
	if target_pid == -1:
		var provinces = MapManager.country_to_provinces.get(country_name, [])
		if provinces.is_empty(): return false
		target_pid = provinces.pick_random()

	TroopManager.deploy_specific_divisions(country_name, troop.stored_divisions, target_pid)
	ready_troops.remove_at(index)
	return true
#endregion


var cached_garrison_hubs: Array = []
func demobilize_troop(troop: TroopData, count: int = -1) -> void:
	if not troop or troop.country_name != country_name:
		return

	var divs_to_reserve: Array[DivisionData] = []
	
	if count == -1 or count >= troop.divisions_count:
		# Full Demobilization
		divs_to_reserve = troop.stored_divisions.duplicate()
		TroopManager.remove_troop(troop)
	else:
		# Partial Demobilization (Peel off the surplus)
		for i in range(count):
			divs_to_reserve.append(troop.stored_divisions.pop_back())
		# Update the TroopManager's view of this troop (re-calculate strength)
		# No need to remove from map, just update the existing object.

	if not divs_to_reserve.is_empty():
		var reserve = ReadyTroop.new(divs_to_reserve)
		ready_troops.append(reserve)


## Enhanced upkeep: Reserves cost 25% of active troops
func calculate_army_upkeep() -> float:
	var active_divisions = 0
	for troop in TroopManager.get_troops_for_country(country_name):
		active_divisions += troop.divisions_count
	
	var reserve_divisions = 0
	for rt in ready_troops:
		reserve_divisions += rt.stored_divisions.size()
	
	var active_cost = active_divisions * (army_level * BASE_ARMY_COST)
	var reserve_cost = reserve_divisions * (army_level * BASE_ARMY_COST * 0.25)
	
	return active_cost + reserve_cost
