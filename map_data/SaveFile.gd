extends Resource
class_name SaveGame

# --- MapManager Data ---
@export var province_to_country: Dictionary = {}
@export var country_to_provinces: Dictionary = {}
@export var province_objects: Dictionary = {}  # Generic dict is safer

@export var troops: Array = []
@export var moving_troops: Array = []
@export var troops_by_province: Dictionary = {}
@export var troops_by_country: Dictionary = {}

@export var countries: Dictionary = {}
@export var player_country_name: String = ""
