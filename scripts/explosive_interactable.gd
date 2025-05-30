extends Node3D

@export var explosion_scene: PackedScene
@export var max_health: int = 30
@export var impact_threshold: float = 1.0  # Minimum velocity to deal damage

@onready var body: RigidBody3D = $RigidBody3D
var current_health: int

func _ready() -> void:
	current_health = max_health
	body.contact_monitor = true
	body.max_contacts_reported = 10
	body.body_entered.connect(_on_body_entered)

func _on_body_entered(other: Node) -> void:
	var velocity = body.linear_velocity.length()
	
	if velocity >= impact_threshold:
		var damage = floor(velocity)
		apply_damage(damage)

func apply_damage(amount: int) -> void:
	current_health -= amount
	print("Barrel took ", amount, " damage. Health now: ", current_health)

	if current_health <= 0:
		explode()

func explode() -> void:
	if explosion_scene:
		var explosion_instance = explosion_scene.instantiate()
		explosion_instance.global_transform.origin = body.global_transform.origin
		get_tree().current_scene.add_child(explosion_instance)

	queue_free()
