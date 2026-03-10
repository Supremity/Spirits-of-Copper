class_name CountryAI

var country: CountryData

var personality := {"economy": 1.0, "military": 1.0, "aggression": 1.0}
var ai_logs = []


func _init(_country: CountryData):
	country = _country

func think_hour():
	var actions = [{"id": "move_troops", "score": _score_frontline(), "action": _execute_frontline}]
	_execute_best(actions)


func think_day():
	var actions = [
		{"id": "factory", "score": _score_factory(), "action": _execute_factory},
		{"id": "train", "score": _score_train(), "action": _execute_train},
		{"id": "war", "score": _score_war(), "action": _execute_war}
	]
	_execute_best(actions, true)


func _execute_best(actions: Array, should_log: bool = false):
	if actions.is_empty():
		if should_log:
			ai_logs.append("[%s] No actions provided." % country.country_name)
		return
	actions.sort_custom(func(a, b): return a.score > b.score)
	var best = actions[0]
	if best.score > 0:
		best.action.call()
		if should_log:
			var action_id = best.get("id", "unknown_action")
			ai_logs.append("[%s] %s (Score: %.2f)" % [country.country_name, action_id, best.score])
	else:
		if should_log:
			ai_logs.append(
				"[%s] Decision: Idle (Best score: %.2f)" % [country.country_name, best.score]
			)

func _score_factory() -> float:
	var score := 0.0
	if country.factories_available <= 0:
		return 0.0
	score += 0.5
	
	if country.money >= 5000:
		score += 0.5
	return score * personality.economy
	
func _score_train() -> float:
	return 1.0 * personality.military


func _score_war() -> float:
	return 1.0 * personality.aggression


func _score_frontline() -> float:
	return 1.0


func _execute_factory():
	if not MapManager.country_to_provinces_obj.has(country.country_name):
		return

	for province in MapManager.country_to_provinces_obj[country.country_name]:
		if province.factory > 0:
			continue
		country.build_factory(province)
		break

func _execute_train():
	pass

func _execute_war():
	pass
	
func _execute_frontline():
	pass
