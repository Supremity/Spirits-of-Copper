extends Resource
class_name Province

enum { SEA = 0, LAND = 1 }
enum {
	NO_FACTORY = 0,
	NO_PORT = 0,
	FACTORY_BUILDING = 1,
	PORT_BUILDING = 1,
	FACTORY_BUILT = 2,
	PORT_BUILT = 2
}

@export var type: int = LAND
@export var id: int
@export var country: String
@export var city: String
@export var population: int = 0
@export var ethnicity = {}
@export var factory: int = NO_FACTORY
@export var port: int = NO_PORT
@export var gdp: int = 1000
@export var center: Vector2
@export var neighbors: Array[int] = []
@export var neighbors_obj: Array = []
@export var claims = []
@export var troops_here = []
@export var r_color = null

#var country_obj: CountryData  # (for save/loading stuff)
