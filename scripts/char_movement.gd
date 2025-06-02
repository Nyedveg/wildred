extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/wildred_mc/AnimationPlayer
@onready var visuals: Node3D = $visuals
@onready var interact_raycast: RayCast3D = $camera_mount/Camera/InteractRaycast
@onready var hold_point: Node3D = $camera_mount/Camera/HoldPoint


var speed = 3.0
var push_force = 80.0

var hovered_object: Node = null
var held_object: RigidBody3D = null
var held_object_velocity: Vector3 = Vector3.ZERO

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
@export var frictionBase = 4
@export var turn_speed = 5.0

# Object interaction settings
@export var pickup_cooldown = 0.2  # Cooldown after throwing object
@export var throw_force = 20.0     # Force applied when throwing
@export var hold_force = 10.0      # Force applied to keep object at hold point

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
var ladder_array = []
# Slide timer
var slide_timer: Timer


enum State{
	NORMAL,
	LADDER
}
var current_state = State.NORMAL

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
		
	if event.is_action_pressed("attack") and held_object:
		throw_held_object()

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
	if not on_floor and current_state == State.NORMAL:
		velocity += get_gravity() * delta
	else:
		can_double_jump = true

	# Crouch state tracking
	crouching = Input.is_action_pressed("crouch")
	print(current_state)
	if current_state == State.LADDER:
		direction = Vector3(input_dir.x,input_dir.y*-1,0).rotated(Vector3.UP, global_transform.basis.get_euler().y).normalized()

	# Jumping logic + jump animations
	if Input.is_action_just_pressed("ui_accept") and not $RayCastRight.is_colliding() and not $RayCastLeft.is_colliding():
		current_state = State.NORMAL
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

	if not Input.is_action_pressed("crouch"):
		slide_triggered = false

	# Face movement direction (not while sliding)
	if direction.length() > 0 and not sliding and not velocity == Vector3(0, 0, 0):
		visuals.look_at(Vector3(position.x + velocity.x, position.y + Vector3.ZERO.y, position.z + velocity.z))

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
		
	# Friction calculation
	var frictionFactorK
	if (velocity.distance_to(Vector3(0, velocity.y, 0))) == 0:
		frictionFactorK = 2
	else:
		frictionFactorK = frictionBase / (velocity.distance_to(Vector3(0, velocity.y, 0)))
		
	# Apply friction
	if not sliding:
		velocity.x = move_toward(velocity.x, 0, (abs(velocity.x * frictionFromSpeedCoefficient) + abs((frictionFactorK * velocity).x)) * delta)
		velocity.z = move_toward(velocity.z, 0, (abs(velocity.z * frictionFromSpeedCoefficient) + abs((frictionFactorK * velocity).z)) * delta)
	
	# Handle object interaction
	update_object_interaction()
	
	# Animation update
	update_animation(direction, on_floor)

	move_and_slide()
	
	# Handle collisions with physics objects
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var normal = c.get_normal()
			# Only push if not colliding from below (standing on top)
			if abs(normal.y) < 0.5:
				c.get_collider().apply_central_impulse(-normal * push_force)

# Separate function for all object interaction logic
func update_object_interaction() -> void:
	# 1. Update highlighting for objects
	update_hovered_object()
	
	# 2. Handle held object physics
	update_held_object_physics()
	
	# 3. Check for pickup/drop input
	if Input.is_action_pressed("hold"):
		if not held_object and interact_raycast.is_colliding():
			var col = interact_raycast.get_collider()
			if col is RigidBody3D and col.has_method("can_be_picked_up") and col.call("can_be_picked_up"):
				pick_up_object(col)
	else:
		if held_object:
			drop_object()

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

func update_hovered_object() -> void:
	if held_object:
		# If we're holding something, don't hover other objects
		if hovered_object and hovered_object != held_object and hovered_object.has_method("set_highlight_state"):
			hovered_object.call("set_highlight_state", 0)  # HighlightState.NONE
			hovered_object = null
		return
		
	if interact_raycast.is_colliding():
		var collider = interact_raycast.get_collider()
		
		# Skip if it's the same object we're already hovering
		if collider == hovered_object:
			return
			
		# Remove highlight from previous object
		if hovered_object:
			if hovered_object.has_method("set_highlight_state"):
				hovered_object.call("set_highlight_state", 0)  # HighlightState.NONE
			elif hovered_object.has_method("set_highlighted"):
				hovered_object.set_highlighted(false)

		# Set highlight on new object
		hovered_object = collider
		if hovered_object:
			if hovered_object.has_method("set_highlight_state"):
				hovered_object.call("set_highlight_state", 1)  # HighlightState.HOVER
			elif hovered_object.has_method("set_highlighted"):
				hovered_object.set_highlighted(true)
	else:
		# Clear highlight if not pointing at anything
		if hovered_object:
			if hovered_object.has_method("set_highlight_state"):
				hovered_object.call("set_highlight_state", 0)  # HighlightState.NONE
			elif hovered_object.has_method("set_highlighted"):
				hovered_object.set_highlighted(false)
		hovered_object = null

func update_held_object_physics() -> void:
	if held_object:
		var target_pos = hold_point.global_transform.origin
		var current_pos = held_object.global_transform.origin
		var direction = target_pos - current_pos

		# Track velocity for natural throwing
		held_object_velocity = direction / get_physics_process_delta_time()

		# Apply force toward the hold point
		held_object.linear_velocity = direction * hold_force

func play_anim(new_anim: String):
	if anim_state == new_anim:
		return
	anim_state = new_anim
	animation_player.play(new_anim)

func _on_slide_timer_timeout() -> void:
	sliding = false
	readyToSlide = true

func pick_up_object(obj: RigidBody3D) -> void:
	held_object = obj
	
	# Physics configuration
	held_object.custom_integrator = true
	held_object.freeze = false
	held_object.linear_damp = 10.0
	held_object.angular_damp = 10.0
	
	# Visual highlight update
	if held_object.has_method("set_highlight_state"):
		held_object.call("set_highlight_state", 2)  # HighlightState.PICKED_UP
	elif held_object.has_method("set_highlighted"):
		held_object.set_highlighted(true)

func drop_object() -> void:
	if not held_object:
		return
		
	# Fully restore physics state
	held_object.custom_integrator = false
	held_object.freeze = false
	held_object.linear_damp = 0.05
	held_object.angular_damp = 0.1

	# Apply the captured throw velocity (scaled down for more natural feel)
	held_object.linear_velocity = held_object_velocity * 0.5

	# Add a slight angular momentum for realism
	held_object.angular_velocity = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	) * 2.0
	
	# Reset highlight state
	if held_object.has_method("set_highlight_state"):
		held_object.call("set_highlight_state", 0)  # HighlightState.NONE
	elif held_object.has_method("set_highlighted"):
		held_object.set_highlighted(false)

	held_object = null
	held_object_velocity = Vector3.ZERO

func throw_held_object() -> void:
	if not held_object:
		return

	# Restore physics
	held_object.custom_integrator = false
	held_object.freeze = false
	held_object.linear_damp = 0.05
	held_object.angular_damp = 0.1

	# Calculate throw direction from camera
	var throw_dir = -camera_mount.get_node("Camera").global_transform.basis.z.normalized()

	# Apply impulse for throw
	held_object.linear_velocity = throw_dir * throw_force

	# Add spin for realism
	held_object.angular_velocity = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	) * 4.0

	# Set cooldown on the object
	if held_object.has_method("start_pickup_cooldown"):
		held_object.call("start_pickup_cooldown", pickup_cooldown)
	
	# Reset highlight state
	if held_object.has_method("set_highlight_state"):
		held_object.call("set_highlight_state", 0)  # HighlightState.NONE
	elif held_object.has_method("set_highlighted"):
		held_object.set_highlighted(false)

	held_object = null
	held_object_velocity = Vector3.ZERO
