extends Node3D

@export var explosion_scene: PackedScene
@export var impact_scene: PackedScene

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

var impact_cooldown := 0.0

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

func _physics_process(delta: float) -> void:
	impact_cooldown -= delta

	# Don't do anything if cooldown is active
	if impact_cooldown > 0.0:
		return

	var velocity = body.linear_velocity
	var speed = velocity.length()
	
	if speed >= 0.1:
		# Cast a ray in the direction of motion to simulate contact point
		var ray_origin = body.global_transform.origin
		var ray_target = ray_origin + velocity.normalized() * 0.5

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
		query.exclude = [body]
		query.collision_mask = collision_mask
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var impact_point = result.position
			var impact_normal = result.normal

			spawn_impact(impact_point, impact_normal)
			impact_cooldown = 0.3  # Prevents spamming every frame

func apply_damage(amount: int) -> void:
	current_health -= amount
	flash_red()
	
	if current_health <= 0:
		explode()

func explode() -> void:
	# Apply knockback before spawning explosion effect
	# if enable_explosion:
		# apply_knockback()
	
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

func spawn_impact(position: Vector3, normal: Vector3) -> void:
	if impact_scene:
		var impact_instance = impact_scene.instantiate()

		# Add to scene *first*
		get_tree().current_scene.add_child(impact_instance)

		# Set position
		# impact_instance.global_transform = Transform3D().looking_at(normal.normalized(), Vector3.UP)
		impact_instance.global_transform.origin = position

# Optional: Add a method to manually trigger explosion (useful for testing)
func trigger_explosion() -> void:
	current_health = 0
	explode()

# Optional: Add a method to deal damage externally
func take_damage(amount: int) -> void:
	apply_damage(amount)
