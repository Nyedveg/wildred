extends Node3D

@export var explosion_scene: PackedScene
@export var enable_explosion: bool = true
@export var knockback_force: float = 40.0
@export var knockback_radius: float = 5.0
@export var max_health: int = 30
@export var impact_threshold: float = 1.0 
@export var collision_mask: int = 0xFFFFFFFF

@onready var body: RigidBody3D = $RigidBody3D
@onready var mesh_instance: MeshInstance3D = $RigidBody3D/MeshInstance3D

var current_health: int
var knockback_area: Area3D = null
var original_emissions := {}
var flash_tweens := {}

func _ready() -> void:
	current_health = max_health
	
	# Set up collision monitoring
	body.contact_monitor = true
	body.max_contacts_reported = 10
	body.body_entered.connect(_on_body_entered)
	
	# Set up knockback area if it exists
	setup_knockback_area()

func setup_knockback_area() -> void:
	if has_node("KnockbackArea"):
		knockback_area = $KnockbackArea
		
		# Configure the collision shape radius
		if knockback_radius > 0.0 and knockback_area.has_node("CollisionShape3D"):
			var collision_shape = knockback_area.get_node("CollisionShape3D")
			var shape = collision_shape.shape
			if shape is SphereShape3D:
				shape.radius = knockback_radius

func _on_body_entered(other_body: Node) -> void:
	# Ignore self-collision
	if other_body == body:
		return
		
	var velocity = body.linear_velocity.length()
	
	if velocity >= impact_threshold:
		var damage = floor(velocity)
		apply_damage(damage)

func apply_damage(amount: int) -> void:
	current_health -= amount
	flash_red()
	
	if current_health <= 0:
		explode()

func explode() -> void:
	
	# Apply knockback before spawning explosion effect
	if enable_explosion:
		apply_knockback()
	
	# Spawn explosion effect
	if explosion_scene:
		var explosion_instance = explosion_scene.instantiate()
		explosion_instance.global_transform.origin = body.global_transform.origin
		get_tree().current_scene.add_child(explosion_instance)
	
	# Clean up and destroy
	queue_free()

func flash_red() -> void:
	if not mesh_instance:
		return
		
	# Get the mesh's surface count
	var surface_count = mesh_instance.get_surface_override_material_count()
	if surface_count == 0 and mesh_instance.mesh:
		surface_count = mesh_instance.mesh.get_surface_count()
	
	for surface_index in surface_count:
		var mat = mesh_instance.get_active_material(surface_index)
		
		if mat is StandardMaterial3D:
			# Create a duplicate material to avoid affecting other objects
			var flash_mat = mat.duplicate()
			mesh_instance.set_surface_override_material(surface_index, flash_mat)
			
			# Save original emission if not already saved
			if not original_emissions.has(surface_index):
				original_emissions[surface_index] = flash_mat.emission
			
			# Set red emission
			flash_mat.emission_enabled = true
			flash_mat.emission = Color(1, 0, 0)
			
			# Kill existing tween if running
			if flash_tweens.has(surface_index) and flash_tweens[surface_index].is_valid():
				flash_tweens[surface_index].kill()
			
			# Tween back to original emission
			var tween = create_tween()
			tween.tween_property(flash_mat, "emission", original_emissions[surface_index], 0.2)
			flash_tweens[surface_index] = tween

func apply_knockback() -> void:
	var space_state = get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = knockback_radius
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_transform.origin)
	query.collision_mask = collision_mask  # Use configurable collision mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var obj = result.get("collider")
		
		# Skip self
		if obj == body:
			continue
			
		var knockback_direction = (obj.global_transform.origin - global_transform.origin)
		
		# Handle case where objects are at exact same position
		if knockback_direction.length() < 0.01:
			knockback_direction = Vector3.UP
		else:
			knockback_direction = knockback_direction.normalized()
		
		var impulse = knockback_direction * knockback_force
		
		# Handle different physics body types
		if obj is RigidBody3D:
			obj.apply_impulse(impulse)
			
		elif obj is CharacterBody3D:
			# For CharacterBody3D, we need to apply knockback differently
			# Check if the object has a knockback method or property
			if obj.has_method("apply_knockback"):
				obj.apply_knockback(impulse)
			elif obj.has_method("take_knockback"):
				obj.take_knockback(impulse)
			else:
				# Fallback: try to set velocity directly
				if "velocity" in obj:
					obj.velocity += impulse
			
		# Handle custom knockback interface
		elif obj.has_method("receive_explosion_knockback"):
			obj.receive_explosion_knockback(impulse, global_transform.origin)

# Optional: Add a method to manually trigger explosion (useful for testing)
func trigger_explosion() -> void:
	current_health = 0
	explode()

# Optional: Add a method to deal damage externally
func take_damage(amount: int) -> void:
	apply_damage(amount)
