extends KinematicBody
class_name Player

const CAMERA_ROTATION_SPEED = 0.001
const CAMERA_X_ROT_MIN = -80
const CAMERA_X_ROT_MAX = 80

var camera_x_rot = 0.0
var camera_y_rot = 0.0

var vel = Vector3()
var hvel = Vector2()
var prev_vel = Vector3()
var dir = Vector3()

const GRAVITY = -24.8
const MAX_SPEED = 2
const MAX_SPRINT_SPEED = 6
const JUMP_SPEED = 10
const ACCEL = 5
const SPRINT_ACCEL = 10
const DEACCEL= 5
const AIR_DEACCEL = 1
const MAX_SLOPE_ANGLE = 40

# Health
var health setget set_health

# States
var is_grounded = false
var is_sprinting = false
var is_aiming = false
var is_dead = false
var is_climbing = false
var is_dancing = false
var is_in_vehicle = false
var weapon_equipped = false

# Aiming
var camera
var target
var crosshair
var camera_target_initial : Vector3
var crosshair_color_initial : Color
var fov_initial

# Force
const GRAB_DISTANCE = 50
const THROW_FORCE = 100

# Shape
var shape
var shape_orientation

# Animations
var animation_tree : AnimationTree
var animation_state_machine : AnimationNodeStateMachinePlayback

# Sounds
var air_player
var air_sound
var force_player
var force_shoot
var footsteps_player
var footsteps_concrete
var hit_player
var body_splat
var voice_player
var pain_sound

# Gibs
var gibs_scn
var main_scn

# Rays
var ray_ground
var ray_ledge_top
var ray_ledge_front
var ray_vehicles


func _ready():
	shape = get_node("shape")
	
	camera = get_node("camera_base/rotation/target/camera")
	target = get_node("camera_base/rotation/target")
	crosshair = get_node("hud/crosshair")
	
	camera_target_initial = target.transform.origin
	crosshair_color_initial = crosshair.modulate
	#fov_initial = camera.fov
	
	# For facing direction
	shape_orientation = shape.global_transform
	
	# Animations
	animation_tree = get_node("shape/cube/animation_tree")
	animation_state_machine = animation_tree["parameters/playback"]
	
	# Sounds
	air_player = get_node("audio/air")
	air_sound = preload("res://sounds/physics/wind.wav")
	air_player.stream = air_sound
	force_player = get_node("audio/force")
	force_shoot = preload("res://sounds/force/force_shoot.wav")
	footsteps_player = get_node("audio/footsteps")
	footsteps_concrete = [
		preload("res://sounds/footsteps/concrete/concrete_1.wav"),
		preload("res://sounds/footsteps/concrete/concrete_2.wav"),
		preload("res://sounds/footsteps/concrete/concrete_3.wav"),
		preload("res://sounds/footsteps/concrete/concrete_4.wav"),
		preload("res://sounds/footsteps/concrete/concrete_5.wav"),
		preload("res://sounds/footsteps/concrete/concrete_6.wav"),
		preload("res://sounds/footsteps/concrete/concrete_7.wav")
	]
	hit_player = get_node("audio/hit")
	body_splat = preload("res://sounds/physics/body_splat.wav")
	voice_player = get_node("audio/voice")
	pain_sound = preload("res://sounds/pain/pain.wav")
	
	# Gibs
	gibs_scn = preload("res://models/characters/gibs.tscn")
	main_scn = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	# Health
	set_health(100)
	
	# Rays
	ray_ground = get_node("shape/rays/ground")
	ray_ledge_front = get_node("shape/rays/ledge_front")
	ray_ledge_top = get_node("shape/rays/ledge_top")
	ray_vehicles = get_node("shape/rays/vehicles")
	
	get_node("timer_respawn").connect("timeout", self, "_on_timer_respawn_timeout")
	
	if is_network_master():
		pass

func _init():
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pass
func _physics_process(delta):
	if is_network_master():
		process_input(delta)
		process_movement(delta)
		rpc_unreliable("process_animations", is_grounded, hvel.length(), camera_x_rot, camera_y_rot)
		
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		get_node("camera_base").rotate_y(-event.relative.x * CAMERA_ROTATION_SPEED)
		get_node("camera_base").orthonormalize()
		camera_x_rot = clamp(camera_x_rot + event.relative.y * CAMERA_ROTATION_SPEED, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX))
		camera_y_rot = clamp(camera_y_rot + event.relative.x * CAMERA_ROTATION_SPEED, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX))
		get_node("camera_base/rotation").rotation.x = camera_x_rot

func process_input(delta):
	# Walking
	dir = Vector3()
	var cam_xform = get_node("camera_base/rotation/target/camera").global_transform

	var input_movement_vector = Vector2()
	
	if !is_climbing and !is_dead:
		if Input.is_action_pressed("movement_forward"):
			input_movement_vector.y += 1
		if Input.is_action_pressed("movement_backward"):
			input_movement_vector.y -= 1
		if Input.is_action_pressed("movement_left"):
			input_movement_vector.x -= 1
		if Input.is_action_pressed("movement_right"):
			input_movement_vector.x += 1

		input_movement_vector = input_movement_vector.normalized()

		# Basis vectors are already normalized.
#		dir += -cam_xform.basis.z * input_movement_vector.y
#		dir += cam_xform.basis.x * input_movement_vector.x
	
		# Sprinting
		if Input.is_action_pressed("sprint"):
			is_sprinting = true
		else:
			is_sprinting = false
	
		# Jumping
		if is_grounded:
			if Input.is_action_just_pressed("jump"):
				vel.y = JUMP_SPEED

	# Slow Mo
	if Input.is_action_pressed("slowmo"):
		Engine.time_scale = 0.25
		AudioServer.set_bus_effect_enabled(0, 0, true)
		AudioServer.get_bus_effect(0, 0).pitch_scale = 0.25
	else:	
		Engine.time_scale = 1
#		AudioServer.get_bus_effect(0, 0).pitch_scale = 1
#		AudioServer.set_bus_effect_enabled(0, 0, false)
		
	
	# Cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func process_movement(delta):
	# Ground detection
	if ray_ground.is_colliding() == true:
		is_grounded = true
	else:
		is_grounded = false
	
	# Movement
	dir.y = 0
	dir = dir.normalized()

	vel.y += delta * GRAVITY

	hvel = vel
	hvel.y = 0

	var target = dir
	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED

	var accel
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		if is_grounded:
			accel = DEACCEL
		else:
			accel = AIR_DEACCEL

	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	
	vel = move_and_slide(vel, Vector3.UP, 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

	# Face moving direction
	if(dir.dot(hvel) > 0):
		var quat_from = Quat(shape_orientation.basis)
		var quat_to = Quat(Transform().looking_at(-dir, Vector3.UP).basis)
		shape_orientation.basis = Basis(quat_from.slerp(quat_to, delta * 10))
		shape.rotation.y = shape_orientation.basis.get_euler().y

	# Ledge detection
	if ray_ledge_front.is_colliding():
		ray_ledge_top.enabled = true
		if ray_ledge_top.is_colliding():
			var ledge_point = ray_ledge_top.get_collision_point() + Vector3(0, 0.5, 0)
			if Input.is_action_just_pressed("jump"):
				is_grounded = true
				is_climbing = true
				vel.y = 0
				hvel = Vector2.ZERO
				global_transform.origin = ledge_point
	else:
		ray_ledge_top.enabled = false
	
	# Sounds
	air_player.unit_size = vel.length() / 30
	if !air_player.playing:
		air_player.play()
	
	if (vel.length() - prev_vel.length()) < -20:
		#hurt(50)
		rpc("hurt", 50)
	if (vel.length() - prev_vel.length()) < -40:
		#die()
		rpc("die")
	
	prev_vel = vel

	# Network
	rpc_unreliable("update_trans_rot", translation, rotation, shape.rotation)


# Animations
remotesync func process_animations(is_grounded, hvel_length, camera_x_rot, camera_y_rot):
		animation_tree["parameters/blend_tree/locomotion/idle_walk_run/blend_position"] = hvel_length
		if !is_grounded and !is_on_floor():
			animation_state_machine.travel("fall")

# Sync position and rotation in the network
puppet func update_trans_rot(pos, rot, shape_rot):
	translation = pos
	rotation = rot
	shape.rotation = shape_rot

func play_random_footstep():
	footsteps_player.unit_size = vel.length()
	footsteps_player.stream = footsteps_concrete[randi() % footsteps_concrete.size()]
	footsteps_player.play()

remotesync func hurt(damage):
	set_health(health - damage)
	voice_player.stream = pain_sound
	voice_player.play()

remotesync func die():
	if !is_dead:
		hit_player.stream = body_splat
		hit_player.play()
		
		# Gibs
		visible = false
		var gibs = gibs_scn.instance()
		main_scn.add_child(gibs)
		gibs.global_transform.origin = global_transform.origin
		for c in gibs.get_children():
			c.apply_impulse(global_transform.origin, c.global_transform.origin - global_transform.origin * 1.1)
		
		is_dead = true
		get_node("timer_respawn").start()

func set_health(value):
	health = value
	if health <= 0:
		#die()
		rpc("die")

# Respawn
func _on_timer_respawn_timeout():
	rpc("respawn")

remotesync func respawn():
	is_dead = false
	set_health(100)
	vel = Vector3()
	global_transform.origin = main_scn.get_node("spawn_points").get_child(randi() % main_scn.get_node("spawn_points").get_child_count()).global_transform.origin
	visible = true
