extends Resource
class_name CountryData

signal process_day_complete

const BASE_ARMY_COST := 20

# Important
var country_name: String
var is_player: bool = false
var ai_controller: CountryAI = null

var allowedCountries: Array[String] = []  # Countries allowed to have Troop Presence

# Useful for AI and other things in the future
var border_provinces = []
var enemy_border_provinces = []
var neighbor_countries = []

# ------
var economy_law_penalty: float = 0.0  # 0.10 means 10% income loss
var army_composition_cache: Dictionary = {"infantry": 0, "tank": 0, "artillery": 0}
#region --- Configuration & Constants ---
var military_size_ratio := 0.005
#endregion

#region --- ECONOMY ---
var money: float = 10000.0
var gdp: int = 0
var income: float = 0.0
var factories_amount: int = 0
var factory_income = 100
var hourly_money_income: float = 0.0  # Calculated value

#region --- POLITICAL ---
var political_power: float = 5000.0
var daily_pp_gain: float = 0.04
var stability: float = 0.5
var war_support: float = 0.5
var relations: Dictionary = {}

# Population & Manpower
var total_population: int = 0
var manpower: int = 100

#region --- MILITARY ---
var army_level: int = 1
var army_cost: float = 0.0
var troop_speed_modifier: float = 1.0

var deploy_pid: int = -1  # ID of province to deploy to
#endregion

var enemies = []

var ongoing_training: Array[Training.TroopTraining] = []
var ready_troops: Array[Training.ReadyTroop] = []
var troops_country: Array[TroopData] = []


func setup_ai():
	if not is_player:
		ai_controller = CountryAI.new(self)


#region --- Lifecycle ---
func _init(p_country_name: String = "") -> void:
	if p_country_name != "":
		country_name = p_country_name
		
	allowedCountries.append_array([p_country_name, "sea"])
	total_population = CountryManager.get_country_population(self.country_name)

	setup_ai()


func process_hour() -> void:


	political_power += daily_pp_gain
	update_manpower_pool()
	var base_income = (gdp / 8760.0) * 0.2
	var factory_income = factories_amount * factory_income
	var gross_income = base_income + factory_income
	hourly_money_income = gross_income * (1.0 - economy_law_penalty)
	income = hourly_money_income - army_cost
	money += income

	troop_speed_modifier = 1.0 + (army_level * 0.1)

	ai_controller.think_hour()


func process_day() -> void:

	# Refresh stats that change daily/weekly
	_process_training()
	_process_reinforcements()

	DecisionManager.process_country_day(self)
	process_day_complete.emit()
	if not is_player:
		pass
	ai_controller.think_day()


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
	var training_batch = Training.TroopTraining.new(count, type, template["days"], template["cost"])
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


func _graduate_troops(training: Training.TroopTraining) -> void:
	var new_divisions: Array[DivisionData] = []
	for d in range(training.divisions_count):
		new_divisions.append(DivisionData.create_division(training.division_type))

	ready_troops.append(Training.ReadyTroop.new(new_divisions))


#endregion


#region --- Stats & Manpower ---
func update_manpower_pool() -> void:
	var max_allowed_manpower = int(total_population * military_size_ratio)
	if manpower < max_allowed_manpower:
		var increase = int(max_allowed_manpower * military_size_ratio * 0.1)
		manpower += increase
	manpower = min(manpower, max_allowed_manpower)
	manpower = max(0, manpower)


func get_army_pressure() -> float:
	var army_size = 0
	for troop in TroopManager.get_troops_for_country(country_name):
		army_size += troop.divisions  # assuming .divisions property exists on TroopData

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
func deploy_ready_troop(troop: Training.ReadyTroop, specific_pid: int = -1) -> bool:
	var index = ready_troops.find(troop)
	if index == -1:
		return false

	var target_pid = specific_pid

	# If no specific ID provided, pick random
	if target_pid == -1:
		var provinces = MapManager.country_to_provinces.get(country_name, [])
		if provinces.is_empty():
			return false
		target_pid = provinces.pick_random()

	TroopManager.deploy_specific_divisions(country_name, troop.stored_divisions, target_pid)
	ready_troops.remove_at(index)
	return true


#endregion

var cached_garrison_hubs: Array = []

# Regenerates Army. Needs Money and Manpower
func _process_reinforcements():
	var all_my_troops = TroopManager.get_troops_for_country(country_name)

	for troop in all_my_troops:
		if troop.is_moving:
			continue

		for div in troop.stored_divisions:
			if div.hp < div.max_hp:
				var template = DivisionData.TEMPLATES[div.type]
				var men_needed = int(template["manpower"] * 0.05)  # 5% reinforcement

				# REINFORCEMENT SAFETY: Stop if it would drop us below zero
				if manpower >= men_needed and money >= (template["cost"] * 0.05):
					money -= (template["cost"] * 0.05)
					manpower -= men_needed
					div.hp = min(div.max_hp, div.hp + 5.0)


func set_relation_with(other_country_name: String, value: int) -> void:
	other_country_name = other_country_name.to_lower()
	relations[other_country_name] = clampi(value, 0, 100)


func get_relation_with(other_country_name: String) -> int:
	other_country_name = other_country_name.to_lower()
	return relations.get(other_country_name, 50)
