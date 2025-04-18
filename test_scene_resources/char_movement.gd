extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/mixamo_base/AnimationPlayer
@onready var visuals: Node3D = $visuals

var speed = 3.0

# player movement
@export var walking_speed = 6.0
@export var running_speed = 10.0
@export var jump_velocity = 5.0
@export var can_double_jump = true
@export var slide_force = 2
@export var frictionFromSpeedCoefficient = 0.8
@export var frictionBase = 2
var readyToSlide = true

# 3d person camera controller
var sens_horizontal = 0.5
var sens_vertical = 0.5

var running: bool = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
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
	else:
		can_double_jump = true

	# Handle jump.
	if Input.is_action_pressed("ui_accept") and not $RayCastRight.is_colliding() and not $RayCastLeft.is_colliding():
		if Input.is_action_just_pressed("ui_accept"):
			if is_on_floor():
				velocity.y = jump_velocity
			else:
				if can_double_jump:
					can_double_jump = false
					velocity.y = jump_velocity * 0.8
		velocity.y+= (jump_velocity - 2) * delta
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if running:
		if animation_player.current_animation != "running":
			animation_player.play("running")
	else:
		if animation_player.current_animation != "walking":
			animation_player.play("walking")
			
	visuals.look_at(position + direction)
	velocity.x += direction.x * speed * delta
	velocity.z += direction.z * speed * delta
	if animation_player.current_animation != "idle" and not velocity.length() > 0:
		animation_player.play("idle")
	velocity.x = move_toward(velocity.x, 0, (abs(velocity.x*frictionFromSpeedCoefficient )+frictionBase)*delta)
	velocity.z = move_toward(velocity.z, 0, (abs(velocity.z*frictionFromSpeedCoefficient )+frictionBase)*delta)
		
		#Crouching and Sliding  LACKS ANIMATIONS
	if Input.is_action_just_pressed("crouch"):
		scale = Vector3(1.0, 0.5, 1.0)
		position.y -= 0.1
		if velocity.length() > 0:
			if  readyToSlide:
				readyToSlide = false
				var slide_direction = velocity
				slide_direction.y = 0  # Ensure we don't add force in the y direction
				velocity = slide_direction * slide_force
				$readyToSlide.start()
	if Input.is_action_just_released("crouch"):
		scale = Vector3(1.0, 1.0, 1.0)
		position.y += 0.1
		
	#Climbing, LACKS ANIMATIONS AND REALISTIC CLIMBING
	if $RayCastClimb.is_colliding() and not $RayCastClimb2.is_colliding():
		velocity.y = 6
		
	#Wall Running, LACKS ANIMATION
	if $RayCastRight.is_colliding():
		can_double_jump = true
		velocity += transform.basis.x * 3 * delta
		velocity.y += 6 *delta
		if Input.is_action_just_pressed("ui_accept"):
			velocity += transform.basis.x * -8
			velocity.y = 2
	if $RayCastLeft.is_colliding():
		can_double_jump = true
		velocity += transform.basis.x * -3 * delta
		velocity.y += 6 *delta
		if Input.is_action_just_pressed("ui_accept"):
			velocity += transform.basis.x * 8
			velocity.y = 2
	
	
	move_and_slide()


func _on_ready_to_slide_timeout() -> void:
	readyToSlide = true
