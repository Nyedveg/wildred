extends Node3D

enum WeatherType {
	CLEAR,
	RAIN,
	STORM,
	SNOW,
	FOG
}

@export var rain_particle_scene : PackedScene
@export var storm_particle_scene : PackedScene

@onready var daytime_cycle : Node = get_parent()
@onready var world_environment : WorldEnvironment = daytime_cycle.get_node("WorldEnvironment")

var current_weather : WeatherType = WeatherType.CLEAR
var rain_instance : Node3D = null
var player_node : Node3D = null

# Transition values
var clouds_cutoff_target : float = 0.3
var clouds_weight_target : float = 0.0
var transition_speed : float = 0.5 # How fast clouds change

func _ready():
	_find_player()
	_set_weather(WeatherType.CLEAR)

func _process(delta: float) -> void:
	_update_weather_transition(delta)
	_update_rain_position()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
	else:
		push_warning("Weather_Control: No player found in 'player' group!")

func _update_weather_transition(delta: float) -> void:
	daytime_cycle.clouds_cutoff = lerp(daytime_cycle.clouds_cutoff, clouds_cutoff_target, delta * transition_speed)
	daytime_cycle.clouds_weight = lerp(daytime_cycle.clouds_weight, clouds_weight_target, delta * transition_speed)

func _update_rain_position() -> void:
	if rain_instance and player_node:
		rain_instance.global_position = player_node.global_position + Vector3(0, 10, 0)

func _set_weather(new_weather: WeatherType) -> void:
	if new_weather == current_weather:
		return

	_remove_weather_effects()
	current_weather = new_weather

	match new_weather:
		WeatherType.CLEAR:
			clouds_cutoff_target = 0.3
			clouds_weight_target = 0.0
			_set_fog_enabled(false)
		WeatherType.RAIN:
			clouds_cutoff_target = 0.1
			clouds_weight_target = 0.7
			_spawn_rain(rain_particle_scene)
			_set_fog_enabled(true)
		WeatherType.STORM:
			clouds_cutoff_target = 0.0
			clouds_weight_target = 0.85
			_spawn_rain(storm_particle_scene if storm_particle_scene else rain_particle_scene)
			_set_fog_enabled(true)
		WeatherType.SNOW:
			clouds_cutoff_target = 0.2
			clouds_weight_target = 0.5
			_set_fog_enabled(true) # Maybe foggy during snow too
		WeatherType.FOG:
			clouds_cutoff_target = 0.25
			clouds_weight_target = 0.3
			_set_fog_enabled(true)

func _remove_weather_effects():
	_remove_rain()
	_set_fog_enabled(false)

func _spawn_rain(particle_scene: PackedScene):
	if rain_instance:
		return
	if particle_scene:
		rain_instance = particle_scene.instantiate()
		add_child(rain_instance)

func _remove_rain():
	if rain_instance:
		rain_instance.queue_free()
		rain_instance = null

func _set_fog_enabled(enabled: bool):
	if world_environment and world_environment.environment:
		world_environment.environment.fog_enabled = enabled

# Public method to set weather directly
func set_weather(weather: WeatherType):
	_set_weather(weather)

# Public method to randomly choose the next weather
func randomize_weather():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var roll = rng.randf()

	match current_weather:
		WeatherType.CLEAR:
			if roll < 0.6:
				set_weather(WeatherType.CLEAR)
			elif roll < 0.8:
				set_weather(WeatherType.RAIN)
			else:
				set_weather(WeatherType.FOG)
		WeatherType.RAIN:
			if roll < 0.7:
				set_weather(WeatherType.RAIN)
			else:
				set_weather(WeatherType.STORM)
		WeatherType.STORM:
			if roll < 0.5:
				set_weather(WeatherType.RAIN)
			else:
				set_weather(WeatherType.CLEAR)
		WeatherType.FOG:
			if roll < 0.5:
				set_weather(WeatherType.CLEAR)
			else:
				set_weather(WeatherType.RAIN)
		WeatherType.SNOW:
			if roll < 0.5:
				set_weather(WeatherType.SNOW)
			else:
				set_weather(WeatherType.CLEAR)
