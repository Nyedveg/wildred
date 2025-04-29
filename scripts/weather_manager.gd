extends Node

## Weather Manager manages weather patterns, scheduling, and transitions
## This script should be attached to a node in your scene

@export_group("Weather Resources")
@export var clear_weather: WeatherResource
@export var rain_weather: WeatherResource
@export var storm_weather: WeatherResource
@export var snow_weather: WeatherResource
@export var fog_weather: WeatherResource

@export_group("Weather Controller")
@export var weather_controller_path: NodePath
@export var daytime_cycle_path: NodePath

@export_group("Weather Pattern Settings")
@export var enable_auto_weather: bool = true
@export_range(60, 3600, 1) var min_weather_duration: int = 300  # 5 minutes minimum
@export_range(60, 7200, 1) var max_weather_duration: int = 900  # 15 minutes maximum
@export var seasonal_variations: bool = true

# Weighted probabilities for each weather type (will be adjusted based on season/time)
var weather_weights = {
	"clear": 60,
	"rain": 15,
	"storm": 5,
	"snow": 10,
	"fog": 10
}

var current_weather_name: String = "clear"
var weather_controller: Node
var daytime_cycle: Node
var next_weather_change: float = 0.0
var rng = RandomNumberGenerator.new()

# Weather scheduling
var weather_schedule = []  # List of scheduled weather events
var current_schedule_index = -1

# Seasonal adjustments
var season_modifiers = {
	"spring": {
		"clear": 40,
		"rain": 30,
		"storm": 15,
		"snow": 5,
		"fog": 10
	},
	"summer": {
		"clear": 65,
		"rain": 15,
		"storm": 15,
		"snow": 0,
		"fog": 5
	},
	"autumn": {
		"clear": 45,
		"rain": 25,
		"storm": 10,
		"snow": 5,
		"fog": 15
	},
	"winter": {
		"clear": 30,
		"rain": 10,
		"storm": 5,
		"snow": 40,
		"fog": 15
	}
}

var debug_weather_types = ["clear", "rain", "storm", "snow", "fog"]
var debug_weather_index := 0
var debug_input_cooldown := 0.0
const DEBUG_INPUT_DELAY := 0.3  # Prevent rapid cycling when holding the key

func _ready():
	rng.randomize()
	
	# Get references to nodes
	if weather_controller_path:
		weather_controller = get_node(weather_controller_path)
	
	if daytime_cycle_path:
		daytime_cycle = get_node(daytime_cycle_path)
	
	# Initialize weather system
	if weather_controller and clear_weather:
		weather_controller.set_weather_resource(clear_weather)
		current_weather_name = "clear"
		
	# Schedule next weather change
	_schedule_next_weather()

func _process(delta):
	if enable_auto_weather:
		# Check if it's time to change weather
		if Time.get_unix_time_from_system() >= next_weather_change:
			_change_weather_by_schedule()
	
	debug_input_cooldown -= delta
	if Input.is_action_pressed("Rain") and debug_input_cooldown <= 0:
		# Disable auto weather while debugging
		enable_auto_weather = false
		
		debug_weather_index = (debug_weather_index + 1) % debug_weather_types.size()
		var weather_to_set = debug_weather_types[debug_weather_index]
		_change_to_weather_type(weather_to_set)
		
		debug_input_cooldown = DEBUG_INPUT_DELAY

# Weather scheduling methods
func _schedule_next_weather():
	var duration = rng.randi_range(min_weather_duration, max_weather_duration)
	next_weather_change = Time.get_unix_time_from_system() + duration
	
func _get_current_season() -> String:
	if not daytime_cycle:
		return "summer"  # Default if no daytime cycle
	
	# Assuming daytime_cycle has a day_of_year property
	var day = daytime_cycle.day_of_year
	
	# Simple seasonal calculation (Northern Hemisphere)
	if day >= 1 and day <= 59:  # Winter (Jan-Feb)
		return "winter"
	elif day >= 60 and day <= 151:  # Spring (Mar-May)
		return "spring"
	elif day >= 152 and day <= 243:  # Summer (Jun-Aug)
		return "summer"
	elif day >= 244 and day <= 334:  # Autumn (Sep-Nov)
		return "autumn"
	else:  # Winter (Dec)
		return "winter"

func _get_random_weighted_weather() -> String:
	var weights = weather_weights.duplicate()
	
	# Apply seasonal modifiers if enabled
	if seasonal_variations and daytime_cycle:
		var season = _get_current_season()
		var modifiers = season_modifiers[season]
		
		for weather in modifiers:
			weights[weather] = modifiers[weather]
	
	# Calculate total weight
	var total_weight = 0
	for w in weights.values():
		total_weight += w
	
	# Get random value within total weight
	var random_value = rng.randi_range(0, total_weight)
	
	# Find which weather type was selected
	var cumulative_weight = 0
	for weather_type in weights:
		cumulative_weight += weights[weather_type]
		if random_value <= cumulative_weight:
			return weather_type
	
	# Fallback to clear
	return "clear"

# Changes weather based on weighted probability and season
func _change_weather_random():
	var next_weather = _get_random_weighted_weather()
	_change_to_weather_type(next_weather)
	_schedule_next_weather()

# Changes weather based on predefined schedule if available
func _change_weather_by_schedule():
	if weather_schedule.size() > 0 and current_schedule_index < weather_schedule.size() - 1:
		current_schedule_index += 1
		var weather_event = weather_schedule[current_schedule_index]
		_change_to_weather_type(weather_event.weather_type)
		next_weather_change = Time.get_unix_time_from_system() + weather_event.duration
	else:
		# Fall back to random if schedule is completed or empty
		_change_weather_random()

# Public methods
func change_weather(weather_name: String, transition_duration: float = -1):
	if weather_controller:
		_change_to_weather_type(weather_name, transition_duration)
		
func set_weather_schedule(schedule: Array):
	weather_schedule = schedule
	current_schedule_index = -1  # Reset schedule index
	next_weather_change = Time.get_unix_time_from_system()  # Trigger immediate weather change

func toggle_auto_weather(enabled: bool):
	enable_auto_weather = enabled

# Implementation methods
func _change_to_weather_type(weather_name: String, transition_duration: float = -1):
	var weather_resource = null
	
	match weather_name:
		"clear":
			weather_resource = clear_weather
		"rain":
			weather_resource = rain_weather
		"storm":
			weather_resource = storm_weather
		"snow":
			weather_resource = snow_weather
		"fog":
			weather_resource = fog_weather
			
	if weather_resource and weather_controller:
		weather_controller.set_weather_resource(weather_resource, transition_duration)
		current_weather_name = weather_name
		
		print("Weather changed to: ", weather_name)

func _on_daytime_cycle_day_changed(new_day: int) -> void:
	# Optionally adjust weather probabilities based on new day
	if seasonal_variations:
		# Re-roll the weather at start of a new day
		_change_weather_random()
