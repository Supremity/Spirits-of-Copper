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

var managers: Dictionary

func _ready():
	managers = _get_autoloads()
	
func add_event(date: String, code: String) -> void:
	if not event_database.has(date):
		event_database[date] = []
		
	event_database[date].append(code)

func process_day(current_date: String) -> void:
	if event_database.has(current_date):
		for cmd in event_database[current_date]:
			_execute_command(cmd)

func _execute_command(command: String) -> void:
	# Clean up the command (handle +=, -=, =)
	var op = ""
	for test_op in ["+=", "-=", "="]:
		if test_op in command:
			# Safety: Check if it's '=' and not '=='
			if test_op == "=" and "==" in command: continue
			op = test_op
			break

	if op != "":
		_handle_assignment(command, op)
	else:
		_run_pure_expression(command)

func _handle_assignment(command: String, op: String) -> void:
	var parts = command.split(op)
	var left_side = parts[0].strip_edges()
	var right_side = parts[1].strip_edges()

	# HACK: Use the Expression engine to get the TARGET object
	# Instead of manual string splitting, we let Godot find the object
	var path_parts = left_side.rsplit(".", true, 1) # Split at the LAST dot
	if path_parts.size() < 2:
		push_error("Invalid assignment path: " + left_side)
		return
	
	var target_obj_path = path_parts[0] # e.g. "CountryManager.player_country"
	var property_name = path_parts[1]   # e.g. "political_power"

	var target_obj = _run_pure_expression(target_obj_path)
	var value_to_apply = _run_pure_expression(right_side)

	if target_obj == null:
		push_error("EventManager: Could not find object at " + target_obj_path)
		return

	# Perform the math
	var current_val = target_obj.get(property_name)
	match op:
		"=": target_obj.set(property_name, value_to_apply)
		"+=": target_obj.set(property_name, current_val + value_to_apply)
		"-=": target_obj.set(property_name, current_val - value_to_apply)
	
	print("EventManager: Successfully updated ", left_side)

func _run_pure_expression(command: String):
	var expr = Expression.new()

	var error = expr.parse(command, managers.keys())
	if error != OK:
		push_error("Parse Error: " + expr.get_error_text())
		return null

	var result = expr.execute(managers.values(), self)

	if expr.has_execute_failed():
		push_error("Execute failed")
		return null

	return result

func _get_autoloads() -> Dictionary:
	var result := {}
	var root := get_tree().root
	
	for child in root.get_children():
		if child == get_tree().current_scene:
			continue
		if child.get_script() != null:
			result[child.name] = child
	
	return result
