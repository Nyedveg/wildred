extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/mixamo_base/AnimationPlayer
@onready var visuals: Node3D = $visuals
@onready var gpu_particles_3d: GPUParticles3D = $visuals/dust_particle/GPUParticles3D
@onready var distortion_emitter: Node3D = $visuals/Distortion_emitter
@onready var trail_timer: Timer = $trail_timer
@export var trail_scene: PackedScene
var trail_nodes := []

var speed = 3.0

# player movement
@export var walking_speed = 3.0
@export var running_speed = 5.0
@export var jump_velocity = 5.0

# 3d person camera controller
var sens_horizontal = 0.5
var sens_vertical = 0.5

var running: bool = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	trail_timer.wait_time = 0.1
	trail_timer.one_shot = false
	trail_timer.start()
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y) * sens_vertical)

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("sprint"):
		speed = running_speed
		running = true
	else:
		speed = walking_speed
		running = false 
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if running:
			if animation_player.current_animation != "running":
				animation_player.play("running")
				if is_on_floor():
					gpu_particles_3d.emitting = true
				else:
					gpu_particles_3d.emitting = false
		else:
			if animation_player.current_animation != "walking":
				animation_player.play("walking")
				if is_on_floor():
					gpu_particles_3d.emitting = true
				else:
					gpu_particles_3d.emitting = false
			
		visuals.look_at(position + direction)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		if animation_player.current_animation != "idle":
			animation_player.play("idle")
			gpu_particles_3d.emitting = false
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()


func _on_trail_timer_timeout() -> void:
	if running:
		var trail_instance = trail_scene.instantiate()
		trail_instance.global_transform = distortion_emitter.global_transform
		get_tree().current_scene.add_child(trail_instance)
		trail_nodes.append(trail_instance)
