extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/wildred_mc/AnimationPlayer
@onready var visuals: Node3D = $visuals
@onready var dust_particles: GPUParticles3D = $SlideDust

var speed = 3.0
var anim_state: String = ""
var direction: Vector3 = Vector3.ZERO

# Movement settings
@export var walking_speed = 6.0
@export var running_speed = 10.0
@export var jump_velocity = 5.0
@export var can_double_jump = true
@export var slide_force = 2.0
@export var slide_duration = 0.8
@export var frictionFromSpeedCoefficient = 0.8
@export var frictionBase = 2
@export var turn_speed = 5.0

# Camera sensitivity
var sens_horizontal = 0.5
var sens_vertical = 0.5

# States
var running = false
var crouching = false
var sliding = false
var climbing = false
var wallrunning = false
var readyToSlide = true
var slide_triggered = false

# Slide timer
var slide_timer: Timer

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Slide timer setup
	slide_timer = Timer.new()
	slide_timer.wait_time = slide_duration
	slide_timer.one_shot = true
	add_child(slide_timer)
	slide_timer.connect("timeout", Callable(self, "_on_slide_timer_timeout"))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y) * sens_vertical)

func _physics_process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("player_position", global_position)
	RenderingServer.global_shader_parameter_set("player_velocity", velocity)
	
	var on_floor = is_on_floor()
	var input_dir := Input.get_vector("left", "right", "forward", "backward").normalized()
	var turnToDirection := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if turnToDirection.length() > 0:  # Only interpolate if there's meaningful input
		direction = direction.lerp(turnToDirection, turn_speed * delta).normalized()
	else:
		direction = direction.lerp(Vector3.ZERO, turn_speed * delta)  # Reset if no input
	

	# Gravity
	if not on_floor:
		velocity += get_gravity() * delta
	else:
		can_double_jump = true

	# Crouch state tracking
	crouching = Input.is_action_pressed("crouch")

	# Jumping logic + jump animations
	if Input.is_action_just_pressed("ui_accept") and not $RayCastRight.is_colliding() and not $RayCastLeft.is_colliding():
		if on_floor:
			velocity.y = jump_velocity
			if velocity.length() < 2:
				play_anim("jumping")
			else:
				play_anim("running_jump")
		elif can_double_jump:
			can_double_jump = false
			velocity.y = jump_velocity * 0.8
			if velocity.length() < 2:
				play_anim("jumping")
			else:
				play_anim("running_jump")

	# Sliding logic
	if crouching and direction.length() > 0 and readyToSlide and not sliding and not slide_triggered and on_floor:
		sliding = true
		slide_triggered = true
		readyToSlide = false
		slide_timer.start()

		var flat_velocity = velocity
		flat_velocity.y = 0
		var preserved_momentum = flat_velocity.normalized() * clamp(flat_velocity.length(), 3.0, 10.0)
		velocity = preserved_momentum * (slide_force * 0.6)

		if dust_particles:
			dust_particles.restart()

	if not Input.is_action_pressed("crouch"):
		slide_triggered = false

	# Face movement direction (not while sliding)
	if direction.length() > 0 and not sliding:
		visuals.look_at(position + direction)

	# Speed setting
	running = Input.is_action_pressed("sprint") and not crouching and not sliding
	speed = running_speed if running else walking_speed

	if not sliding:
		velocity.x += direction.x * speed * delta
		velocity.z += direction.z * speed * delta
	visuals.scale = Vector3(1, 1, 1)
	# Wallrunning logic
	wallrunning = false
	if $RayCastRight.is_colliding() and direction.length() > 0 and velocity.distance_to(Vector3(0, velocity.y, 0)) > 4 and not on_floor:
		wallrunning = true
		can_double_jump = true
		velocity += transform.basis.x * 3 * delta
		velocity.y += 6 * delta
		visuals.scale = Vector3(-1, 1, 1)  # Flip horizontally (left wall)
		if Input.is_action_just_pressed("ui_accept"):
			velocity += transform.basis.x * -8
			velocity.y = 2
	elif $RayCastLeft.is_colliding() and direction.length() > 0 and velocity.distance_to(Vector3(0, velocity.y, 0)) > 4 and not on_floor:
		wallrunning = true
		can_double_jump = true
		velocity += transform.basis.x * -3 * delta
		velocity.y += 6 * delta
		if Input.is_action_just_pressed("ui_accept"):
			velocity += transform.basis.x * 8
			velocity.y = 2
	
	# Climbing logic
	climbing = $RayCastClimb.is_colliding() and not $RayCastClimb2.is_colliding()
	if climbing:
		velocity.y = 6
	var frictionFactorK
	if (velocity.distance_to(Vector3(0, velocity.y, 0))) == 0:
		frictionFactorK = 2
	else:
		frictionFactorK = frictionBase / (velocity.distance_to(Vector3(0, velocity.y, 0)))
	# Friction
	if not sliding:
		velocity.x = move_toward(velocity.x, 0, (abs(velocity.x * frictionFromSpeedCoefficient) + abs((frictionFactorK * velocity).x)) * delta)
		velocity.z = move_toward(velocity.z, 0, (abs(velocity.z * frictionFromSpeedCoefficient) + abs((frictionFactorK * velocity).z)) * delta)

	# Animation update
	update_animation(direction, on_floor)

	move_and_slide()

func update_animation(direction: Vector3, on_floor: bool):
	if sliding:
		play_anim("slide")
	elif climbing:
		play_anim("climbing")
	elif wallrunning:
		play_anim("wall_run_001")
	elif not on_floor and velocity.y < 0:
		play_anim("falling_idle")
	elif crouching:
		if direction.length() > 0:
			play_anim("crouch_walk")
		else:
			play_anim("crouch_idle_001")
	elif velocity.length() > 0:
		play_anim("running") if running else play_anim("walking")
	else:
		play_anim("idle")

func play_anim(new_anim: String):
	if anim_state == new_anim:
		return
	anim_state = new_anim
	animation_player.play(new_anim)

func _on_slide_timer_timeout() -> void:
	sliding = false
	readyToSlide = true
	if dust_particles:
		dust_particles.emitting = false
