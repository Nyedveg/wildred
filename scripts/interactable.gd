extends RigidBody3D

class_name PickableObject

@export var hold_force_strength := 20.0
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

enum HighlightState { NONE, HOVER, PICKED_UP }

var pickup_cooldown: float = 0.0
var current_highlight_state: HighlightState = HighlightState.NONE

func _ready() -> void:
	# Ensure each surface has a unique material
	for surface_index in mesh_instance.get_surface_override_material_count():
		var base_material: Material = mesh_instance.get_active_material(surface_index)

		if base_material:
			# Duplicate the base material
			var new_material := base_material.duplicate()
			
			# If there's a next_pass (e.g., for outline), duplicate it as well
			if new_material.has_method("get_next_pass") and new_material.next_pass:
				var next_pass_material: Material = new_material.next_pass.duplicate()
				new_material.next_pass = next_pass_material

			# Apply the unique material to this surface
			mesh_instance.set_surface_override_material(surface_index, new_material)

func _physics_process(delta: float) -> void:
	if pickup_cooldown > 0.0:
		pickup_cooldown -= delta

func start_pickup_cooldown(time: float) -> void:
	pickup_cooldown = time

func can_be_picked_up() -> bool:
	return pickup_cooldown <= 0.0

func set_highlight_state(state: HighlightState) -> void:
	if state == current_highlight_state:
		return  # Avoid reapplying same state
	
	current_highlight_state = state
	
	match state:
		HighlightState.NONE:
			set_outline_color(Color(0, 0, 0, 0))  # Transparent = hidden
		HighlightState.HOVER:
			set_outline_color(Color.WHITE)
		HighlightState.PICKED_UP:
			set_outline_color(Color.YELLOW)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not custom_integrator:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	var hold_point = player.hold_point.global_transform.origin
	var dir = hold_point - global_transform.origin
	var force = dir * hold_force_strength
	state.apply_central_force(force)

func set_outline_color(color: Color) -> void:
	for surface_index in mesh_instance.get_surface_override_material_count():
		var mat: Material = mesh_instance.get_active_material(surface_index)
		if mat and mat.has_method("get_next_pass") and mat.next_pass:
			mat.next_pass.set_shader_parameter("outline_color", color)
			mat.next_pass.set_shader_parameter("enable", color.a > 0.0)
