extends Node
## Resource-based weather controller with lightning system
## This script handles weather transitions and special effects

# Nodes
@onready var daytime_cycle : Node = get_parent()
@onready var world_environment : WorldEnvironment = daytime_cycle.get_node("WorldEnvironment") if daytime_cycle else null
@onready var lightning_flash_light: DirectionalLight3D = $LightningFlashLight

# Current weather state
var current_resource: WeatherResource
var active_particles: Node3D = null
var player_node: Node3D = null

# Transition parameters
var current_params = {
	"clouds_cutoff": 0.3,
	"clouds_weight": 0.0,
	"fog_density": 0.0,
	"fog_sky_affect": 0.0,
	"sun_energy": 1.0,
	"moon_energy": 0.1,
	"sky_color": Color(0.5, 0.7, 1.0)
}

var target_params = current_params.duplicate()
var transition_speed: float = 0.5  # Will be calculated based on resource's transition duration

# Lightning system parameters
var lightning_timer: float = 0.0
var lightning_next_strike: float = 10.0
var lightning_active: bool = false
var lightning_active_time: float = 0.0
var lightning_duration: float = 0.0
var thunder_delay: float = 0.0
var thunder_pending: bool = false

# Signals
signal weather_changed(new_resource, old_resource)
signal lightning_strike(position)
signal thunder_sound(delay, distance)

func _ready():
	# Initialize
	_find_player()
	
	# Setup lightning
	if lightning_flash_light:
		lightning_flash_light.visible = false

func _process(delta: float) -> void:
	# Update particle positions
	_update_particle_position()
	
	# Update weather transitions
	_update_weather_parameters(delta)
	
	# Handle lightning system
	_process_lightning(delta)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
	else:
		push_warning("Weather_Control: No player found in 'player' group!")

func _update_particle_position() -> void:
	if active_particles and player_node:
		active_particles.global_position = player_node.global_position + Vector3(0, 5, 0)

func _update_weather_parameters(delta: float) -> void:
	# Interpolate all parameters
	for key in current_params.keys():
		if key == "sky_color":
			current_params[key] = current_params[key].lerp(target_params[key], transition_speed)
		else:
			current_params[key] = lerp(current_params[key], target_params[key], transition_speed)
	
	# Apply to Daytime_Cycle
	if daytime_cycle:
		daytime_cycle.clouds_cutoff = current_params["clouds_cutoff"]
		daytime_cycle.clouds_weight = current_params["clouds_weight"]
		daytime_cycle.sun_base_energy = current_params["sun_energy"]
		daytime_cycle.moon_base_energy = current_params["moon_energy"]
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

func _process_lightning(delta: float) -> void:
	if not current_resource or not current_resource.has_lightning:
		# Turn off lightning if weather changed
		if lightning_flash_light and lightning_flash_light.visible:
			lightning_flash_light.visible = false
		return
	
	# Count down to next lightning strike
	lightning_timer += delta
	
	# Handle active lightning flash
	if lightning_active:
		lightning_active_time += delta
		
		if lightning_active_time >= lightning_duration:
			# Turn off lightning
			lightning_active = false
			if lightning_flash_light:
				lightning_flash_light.visible = false
				
	# Handle thunder sound
	if thunder_pending and lightning_timer >= thunder_delay:
		thunder_pending = false
		emit_signal("thunder_sound", thunder_delay, _calculate_lightning_distance(thunder_delay))
	
	# Check if it's time for a new lightning strike
	if lightning_timer >= lightning_next_strike and not lightning_active:
		_trigger_lightning()

func _trigger_lightning() -> void:
	if not current_resource or not lightning_flash_light:
		return
		
	# Reset timer
	lightning_timer = 0.0
	lightning_active = true
	lightning_active_time = 0.0
	
	# Determine lightning parameters
	lightning_duration = randf_range(
		current_resource.lightning_duration_min, 
		current_resource.lightning_duration_max
	)
	
	# Set next lightning time
	lightning_next_strike = randf_range(
		current_resource.lightning_frequency_min, 
		current_resource.lightning_frequency_max
	)
	
	# Configure the lightning flash
	lightning_flash_light.visible = true
	lightning_flash_light.light_energy = current_resource.lightning_brightness
	
	# Slightly randomize light direction for variety
	lightning_flash_light.rotation.x = randf_range(-0.2, 0.2)
	lightning_flash_light.rotation.z = randf_range(-0.2, 0.2)
	
	# Set up thunder
	thunder_delay = randf_range(
		current_resource.thunder_delay_min,
		current_resource.thunder_delay_max
	)
	thunder_pending = true
	
	# Signal that lightning occurred
	emit_signal("lightning_strike", player_node.global_position if player_node else Vector3.ZERO)

func _calculate_lightning_distance(delay: float) -> float:
	# Simple calculation to estimate lightning distance based on thunder delay
	# Sound travels roughly 343 meters per second
	# This gives a rough distance in meters
	return delay * 343.0

# Public methods to control weather
func set_weather_resource(resource: WeatherResource, transition_duration: float = -1) -> void:
	if not resource:
		return
		
	var old_resource = current_resource
	current_resource = resource
	
	# Calculate transition speed
	if transition_duration > 0:
		transition_speed = 1.0 / (transition_duration * 60.0)  # Approximation for frames
	else:
		# Use resource's default transition time
		transition_speed = 1.0 / (resource.transition_duration * 60.0)
	
	# Set up target parameters
	target_params["clouds_cutoff"] = resource.clouds_cutoff
	target_params["clouds_weight"] = resource.clouds_weight
	target_params["fog_density"] = resource.fog_density
	target_params["fog_sky_affect"] = resource.fog_sky_affect
	target_params["sun_energy"] = resource.sun_energy
	target_params["moon_energy"] = resource.moon_energy
	target_params["sky_color"] = resource.sky_color
	
	# Handle fog
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.fog_enabled = resource.fog_enabled
	
	# Handle particles
	_remove_particles()
	if resource.particle_scene_path:
		var scene = load(resource.particle_scene_path)
		if scene:
			_spawn_particles(scene)
	
	# Reset lightning timers
	if resource.has_lightning:
		lightning_timer = 0.0
		lightning_next_strike = randf_range(
			resource.lightning_frequency_min,
			resource.lightning_frequency_max
		)
		
	# Emit weather changed signal
	emit_signal("weather_changed", resource, old_resource)

func _spawn_particles(particle_scene: PackedScene):
	if active_particles:
		return
		
	if particle_scene:
		active_particles = particle_scene.instantiate()
		
		# Adjust emission rate based on intensity if the particles have an "amount" property
		if current_resource and active_particles.has_method("set_amount"):
			active_particles.set_amount(current_resource.particle_intensity)
		
		add_child(active_particles)

func _remove_particles():
	if active_particles:
		active_particles.queue_free()
		active_particles = null
