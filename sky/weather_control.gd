extends Node3D

enum WeatherType {
	CLEAR,
	RAIN,
	STORM,
	SNOW,
	FOG
}

# Weather parameters configuration (move these to a resource later for better organization)
const WEATHER_CONFIGS = {
	WeatherType.CLEAR: {
		"clouds_cutoff": 0.3,
		"clouds_weight": 0.0,
		"fog_density": 0.0,
		"fog_sky_affect": 0.0,
		"sun_energy": 1.0,
		"moon_energy": 0.1,
		"sky_color": Color(0.48, 0.6, 0.7), # Light blue
		"fog_enabled": false,
		"particle_scene": null
	},
	WeatherType.RAIN: {
		"clouds_cutoff": 0.1,
		"clouds_weight": 0.7,
		"fog_density": 0.02,
		"fog_sky_affect": 0.3,
		"sun_energy": 0.5,
		"moon_energy": 0.05,
		"sky_color": Color(0.4, 0.5, 0.6), # Grayish
		"fog_enabled": true,
		"particle_scene_key": "rain" # Reference to the scene name
	},
	WeatherType.STORM: {
		"clouds_cutoff": 0.0,
		"clouds_weight": 0.85,
		"fog_density": 0.05,
		"fog_sky_affect": 0.6,
		"sun_energy": 0.3,
		"moon_energy": 0.0,
		"sky_color": Color(0.2, 0.2, 0.3), # Dark stormy
		"fog_enabled": true,
		"particle_scene_key": "storm"
	},
	WeatherType.SNOW: {
		"clouds_cutoff": 0.2,
		"clouds_weight": 0.5,
		"fog_density": 0.015,
		"fog_sky_affect": 0.8,
		"sun_energy": 0.5,
		"moon_energy": 0.05,
		"sky_color": Color(0.8, 0.85, 0.9), # Pale icy
		"fog_enabled": true,
		"particle_scene_key": "snow" # You would need to add a snow particle scene
	},
	WeatherType.FOG: {
		"clouds_cutoff": 0.25,
		"clouds_weight": 0.3,
		"fog_density": 0.07,
		"fog_sky_affect": 1.0,
		"sun_energy": 0.3,
		"moon_energy": 0.05,
		"sky_color": Color(0.7, 0.75, 0.8), # Washed out
		"fog_enabled": true,
		"particle_scene_key": null
	}
}

# Current weather parameter values
var current_params = {
	"clouds_cutoff": 0.3,
	"clouds_weight": 0.0,
	"fog_density": 0.0,
	"fog_sky_affect": 0.0,
	"sun_energy": 1.0,
	"moon_energy": 0.1,
	"sky_color": Color(0.5, 0.7, 1.0)
}

# Target values for transitions
var target_params = current_params.duplicate()

# Available particle scenes
@export var rain_particle_scene : PackedScene
@export var storm_particle_scene : PackedScene
@export var snow_particle_scene : PackedScene  # Add this for snow effects

# Scenes dictionary for easy reference
var particle_scenes = {}

@export_range(0.001, 0.1, 0.001) var transition_speed : float = 0.005 # Configurable from editor
@export var debug_controls : bool = true  # Set to false in production

@onready var daytime_cycle : Node = get_parent()
@onready var world_environment : WorldEnvironment = daytime_cycle.get_node("WorldEnvironment")

var current_weather : WeatherType = WeatherType.CLEAR
var active_particles : Node3D = null
var player_node : Node3D = null

# Signal to notify other game systems about weather changes
signal weather_changed(new_type, old_type)

func _ready():
	# Initialize particle scenes dictionary
	particle_scenes = {
		"rain": rain_particle_scene,
		"storm": storm_particle_scene,
		"snow": snow_particle_scene
	}
	
	_find_player()
	_set_weather(WeatherType.CLEAR)

func _process(delta: float) -> void:
	# Debug controls, can be disabled in production
	if debug_controls and Input.is_action_just_pressed("Rain"):
		_cycle_weather()
	
	_update_particle_position()
	_update_weather_parameters()

func _cycle_weather() -> void:
	match current_weather:
		WeatherType.CLEAR:
			_set_weather(WeatherType.RAIN)
		WeatherType.RAIN:
			_set_weather(WeatherType.STORM)
		WeatherType.STORM:
			_set_weather(WeatherType.SNOW)
		WeatherType.SNOW:
			_set_weather(WeatherType.FOG)
		WeatherType.FOG:
			_set_weather(WeatherType.CLEAR)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
	else:
		push_warning("Weather_Control: No player found in 'player' group!")

func _update_particle_position() -> void:
	if active_particles and player_node:
		active_particles.global_position = player_node.global_position + Vector3(0, 10, 0)
		
func _update_weather_parameters() -> void:
	# Interpolate all parameters at once
	for key in current_params.keys():
		if key == "sky_color":
			current_params[key] = current_params[key].lerp(target_params[key], transition_speed)
		else:
			current_params[key] = lerp(current_params[key], target_params[key], transition_speed)
	
	# Apply to Daytime_Cycle (parent)
	if daytime_cycle:
		daytime_cycle.clouds_cutoff = current_params["clouds_cutoff"]
		daytime_cycle.clouds_weight = current_params["clouds_weight"]
		
		daytime_cycle.sun_base_enegry = current_params["sun_energy"]
		daytime_cycle.moon_base_enegry = current_params["moon_energy"]
		
		daytime_cycle.sky_color = current_params["sky_color"]

	# Apply fog parameters
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.fog_density = current_params["fog_density"]
		env.fog_sky_affect = current_params["fog_sky_affect"]

		# Enable/disable fog based on density
		env.fog_enabled = current_params["fog_density"] > 0.001 or current_params["fog_sky_affect"] > 0.001
	
	# Scale particles for smooth transition
	if active_particles:
		active_particles.scale = active_particles.scale.lerp(Vector3.ONE, transition_speed)

# Public methods to control weather
func set_weather(weather_type: WeatherType, transition_duration: float = -1) -> void:
	# Optional override for transition duration
	var original_speed = transition_speed
	if transition_duration > 0:
		transition_speed = 1.0 / (transition_duration * 60.0)  # frames to seconds approximation
	
	_set_weather(weather_type)
	
	# Restore original transition speed
	if transition_duration > 0:
		transition_speed = original_speed

# Internal weather setup
func _set_weather(new_weather: WeatherType) -> void:
	if new_weather == current_weather:
		return
		
	var old_weather = current_weather
	current_weather = new_weather
	
	# Remove current particle effects
	_remove_particles()
	
	# Set new target values from the configuration
	var config = WEATHER_CONFIGS[new_weather]
	for key in config.keys():
		if key in target_params:
			target_params[key] = config[key]
	
	# Handle fog enabling/disabling
	if world_environment and world_environment.environment:
		world_environment.environment.fog_enabled = config["fog_enabled"]
	
	# Handle particles
	var particle_key = config.get("particle_scene_key")
	if particle_key and particle_key in particle_scenes and particle_scenes[particle_key]:
		_spawn_particles(particle_scenes[particle_key])
	
	# Emit signal for other systems
	emit_signal("weather_changed", new_weather, old_weather)

func _spawn_particles(particle_scene: PackedScene):
	if active_particles:
		return
		
	if particle_scene:
		active_particles = particle_scene.instantiate()
		active_particles.scale = Vector3.ZERO  # Start small for fade-in
		add_child(active_particles)

func _remove_particles():
	if active_particles:
		active_particles.queue_free()
		active_particles = null
