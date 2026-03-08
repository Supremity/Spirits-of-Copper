class_name CountryAI

var country: CountryData

var personality := {"economy": 1.0, "military": 1.0, "aggression": 1.0}


func _init(_country: CountryData):
	country = _country


func think_hour():
	var actions = [{"score": _score_frontline(), "action": _execute_frontline}]
	_execute_best(actions)


func think_day():
	var actions = [
		{"score": _score_factory(), "action": _execute_factory},
		{"score": _score_train(), "action": _execute_train},
		{"score": _score_war(), "action": _execute_war}
	]
	_execute_best(actions)


func _execute_best(actions: Array):
	actions.sort_custom(func(a, b): return a.score > b.score)
	if actions.size() == 0:
		return
	if actions[0].score > 0:
		actions[0].action.call()


func _score_factory() -> float:
	return 1.0 * personality.economy


func _score_train() -> float:
	return 1.0 * personality.military


func _score_war() -> float:
	return 1.0 * personality.aggression


func _score_frontline() -> float:
	return 1.0


func _execute_factory():
	pass


func _execute_train():
	pass


func _execute_war():
	pass


func _execute_frontline():
	pass
