# res://Scripts/DivisionData.gd
class_name DivisionData extends Resource

@export var name: String = "Infantry Division"
@export var type: String = "infantry" # infantry, tank, artillery
@export var hp: float = 100.0
@export var experience: float = 0.0 # 0.0 to 1.0

func get_attack_power() -> float:
	var base := 10.0
	match type:
		"infantry": base = 10.0
		"tank":     base = 25.0
		"artillery": base = 15.0
	
	# Experience gives up to +50% attack
	return base * (1.0 + (experience * 0.5))

func get_defense_power() -> float:
	var base := 10.0
	match type:
		"infantry": base = 15.0 # Infantry is good at holding
		"tank":     base = 10.0 
		"artillery": base = 5.0
	
	return base * (1.0 + (experience * 0.5))
