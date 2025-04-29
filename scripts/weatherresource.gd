@tool
class_name WeatherResource
extends Resource

## Base resource for defining weather parameters
## Save this script as WeatherResource.gd

@export_group("Visual Parameters")
@export var clouds_cutoff: float = 0.3
@export var clouds_weight: float = 0.0
@export var sky_color: Color = Color(0.5, 0.7, 1.0)
@export var sun_energy: float = 1.0
@export var moon_energy: float = 0.1

@export_group("Fog Parameters")
@export var fog_enabled: bool = false
@export var fog_density: float = 0.0
@export var fog_sky_affect: float = 0.0
@export var fog_color: Color = Color(0.8, 0.8, 0.8, 1.0)

@export_group("Precipitation")
@export var particle_scene_path: String = ""
@export var particle_intensity: float = 1.0  # Controls emission rate, can be adjusted in code

@export_group("Special Effects")
@export var has_lightning: bool = false
@export var lightning_frequency_min: float = 5.0  # Minimum seconds between lightning strikes
@export var lightning_frequency_max: float = 15.0  # Maximum seconds between lightning strikes
@export var lightning_duration_min: float = 0.05  # Minimum duration of lightning flash
@export var lightning_duration_max: float = 0.2  # Maximum duration of lightning flash
@export var lightning_brightness: float = 5.0  # Intensity of lightning light
@export var thunder_delay_min: float = 0.5  # Minimum delay for thunder sound after flash
@export var thunder_delay_max: float = 3.0  # Maximum delay for thunder sound after flash

@export_group("Transition")
@export var transition_duration: float = 120.0  # Time in seconds for complete weather transition

@export_group("Audio")
@export var ambient_audio_path: String = ""  # Path to ambient audio stream for this weather
@export var ambient_volume_db: float = -10.0

func _get_property_list() -> Array:
	# This allows the resource to show its name in the editor
	return [
		{
			"name": "resource_name",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		}
	]
