extends Node

var event_database: Dictionary = {
	"2010-01-02": [
		"print('hello')",
	],
	"2010-01-03": [
	],
	"2010-01-04": [
		"ConsoleManager._release_country('ottoman_empire')",
		"PopupManager.show_alert('event', CountryManager.countries['ottoman_empire'], null, 
			'Ottoman Empire miraculously came back!')"
	]
}

var current_game_date: String = "2010-01-01"

var managers: Dictionary

func _ready():
	managers = _get_autoloads()
	
func add_event(date: String, tasks: Variant, target_obj: Object = null) -> void:
	if not event_database.has(date):
		event_database[date] = []
	
	event_database[date].append({"code": tasks, "obj": target_obj})

func add_event_after_days(days: int, tasks: Variant, target_obj: Object = null) -> void:
	var target_date = _calculate_offset_date(current_game_date, days)
	add_event(target_date, tasks, target_obj)

func repeat_task_for_days(days:int, code: String, target_obj: Object = null) -> void:
	for i in range(days):
		var target_date = _calculate_offset_date(current_game_date, i)
		add_event(target_date, code, target_obj)

func process_day(today: String) -> void:
	current_game_date = today
	if event_database.has(today):
		# Create a copy so we can safely erase the original later
		var raw_tasks = event_database[today].duplicate()
		
		for task in raw_tasks:
			if task is Dictionary:
				# This handles items added via add_event() 
				# OR your custom {object: "code"} syntax
				if task.has("code"):
					_unpack_and_execute(task["code"], task.get("obj", null))
				else:
					# This handles the {self: "command"} syntax
					_unpack_and_execute(task, null)
			else:
				# This handles raw strings like "print('hello')" from your hardcoded dict
				_unpack_and_execute(task, null)
		
		event_database.erase(today)

func _unpack_and_execute(content: Variant, default_obj: Object) -> void:
	if content is String:
		_execute_command(content, default_obj)
		
	elif content is Array:
		for item in content:
			# Recursively unpack arrays (supports nested lists)
			_unpack_and_execute(item, default_obj)
			
	elif content is Dictionary:
		# If it's a Dictionary but NOT a system task (no "code" key),
		# treat it as {Object: "Command"}
		for obj in content.keys():
			var code = content[obj]
			if obj is Object and code is String:
				_execute_command(code, obj)
func _execute_command(command: String, target_obj: Object = null) -> void:
	var op = ""
	for test_op in ["+=", "-=", "="]:
		if test_op in command:
			if test_op == "=" and "==" in command: continue
			op = test_op
			break

	if op != "":
		_handle_assignment(command, op, target_obj)
	else:
		_run_pure_expression(command, target_obj)

func _handle_assignment(command: String, op: String, explicit_obj: Object = null) -> void:
	var parts = command.split(op)
	var left_side = parts[0].strip_edges()
	var right_side = parts[1].strip_edges()

	var actual_target: Object = explicit_obj
	var property_name: String = left_side

	# FALLBACK: If no object was passed, parse the string path like before
	if actual_target == null:
		var path_parts = left_side.rsplit(".", true, 1)
		if path_parts.size() >= 2:
			var target_obj_path = path_parts[0]
			property_name = path_parts[1]
			# Evaluate the path to find the target object
			actual_target = _run_pure_expression(target_obj_path) 
		else:
			actual_target = self # Fallback to EventManager itself

	if actual_target == null:
		push_error("EventManager: Could not find object for assignment: " + left_side)
		return

	# Evaluate the right side of the math
	# Use explicit_obj if provided, otherwise default to self
	var eval_base = explicit_obj if explicit_obj else self
	var value_to_apply = _run_pure_expression(right_side, eval_base)

	if value_to_apply == null:
		return # Execution failed, error already pushed by _run_pure_expression

	# Perform the math
	var current_val = actual_target.get(property_name)
	match op:
		"=": actual_target.set(property_name, value_to_apply)
		"+=": actual_target.set(property_name, current_val + value_to_apply)
		"-=": actual_target.set(property_name, current_val - value_to_apply)

func _run_pure_expression(command: String, target_obj: Object = null):
	var expr = Expression.new()
	var error = expr.parse(command, managers.keys())
	
	if error != OK:
		push_error("Parse Error: " + expr.get_error_text())
		return null

	# FALLBACK: If target_obj is null, run it on the EventManager (self)
	var base_instance = target_obj if target_obj != null else self
	var result = expr.execute(managers.values(), base_instance)

	if expr.has_execute_failed():
		push_error("Execute failed on command: " + command)
		return null

	return result


func _calculate_offset_date(start_date: String, days_to_add: int) -> String:
	var unix_time = Time.get_unix_time_from_datetime_string(start_date)
	var new_unix_time = unix_time + (days_to_add * 86400)
	var date_dict = Time.get_datetime_dict_from_unix_time(new_unix_time)
	return "%d-%02d-%02d" % [date_dict.year, date_dict.month, date_dict.day]

func _get_autoloads() -> Dictionary:
	var result := {}
	var root := get_tree().root
	
	for child in root.get_children():
		if child == get_tree().current_scene:
			continue
		if child.get_script() != null:
			result[child.name] = child
	
	return result
