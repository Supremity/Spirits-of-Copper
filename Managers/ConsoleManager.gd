extends Node


func _ready() -> void:
	Console.add_command("play_country", _play_country, ["country_name"], 1, "Change player country")
	Console.add_command("play_as", _play_country, ["country_name"], 1, "Change player country")
	Console.add_command("start_war", _start_war, ["a", "b"], 2, "Start a war between 2 countries")
	Console.add_command("annex", _annex, ["country_name"], 1, "Annex Country for Player")


func _annex(country_name: String) -> void:
	if CountryManager.countries.has(country_name):
		MapManager.annex_country(country_name)
		return

	Console.print_line("Unknown country: " + country_name)


func _play_country(country_name: String) -> void:
	if CountryManager.countries.has(country_name):
		CountryManager.set_player_country(country_name)
		return
	
	Console.print_line("Unknown country: " + country_name)


func _start_war(country_name1: String, country_name2: String) -> void:
	var country1 := CountryManager.get_country(country_name1)
	var country2 := CountryManager.get_country(country_name2)

	if country1 and country2:
		WarManager.declare_war(country1, country2)
		return

	if not country1:
		Console.print_line("Unknown country: " + country_name1)
	if not country2:
		Console.print_line("Unknown country: " + country_name2)
