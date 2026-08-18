class_name Player
extends CharacterBody3D
# HighCraft player controller.
# Walk / sprint / jump / gravity with collision against the chunk world,
# mouse look (yaw on the body, pitch on the head), F5 perspective cycling
# (first person -> third back -> third front), and a creative fly mode
# toggled by double-tapping Space.

var current_skin_name: String = "afro_steve"

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 7.5
@export var fly_speed: float = 12.0
@export var mouse_sensitivity: float = 0.0025
@export var can_fly: bool = true


var sitting: bool = false
var sit_anchor: Vector3 = Vector3.ZERO
var world = null          # wird von game/interactor gesetzt


var interactor

var gravity: float = 24.0
var flying: bool = false
var gliding: bool = false

var inventory: Inventory
var game_mode: int = GameSettings.GameMode.SURVIVAL
var difficulty: int = GameSettings.Difficulty.NORMAL
var health: float = 20.0
var max_health: float = 20.0
var hunger: float = 20.0
var max_hunger: float = 20.0
var saturation: float = 5.0
var xp_level: int = 0
var dead: bool = false
var spawn_point: Vector3 = Vector3.ZERO

var _last_space_time: float = -1.0
var _exhaustion: float = 0.0
var _regen_t: float = 0.0
var _starve_t: float = 0.0
var _step_t: float = 0.0
var split_index: int = -1   # -1 = single player (keyboard + gamepad 0). 0-3 = split-screen device index.
var _prev_joy_jump: bool = false
var _on_ice: bool = false
var _ice_velocity: Vector3 = Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _update_model_rotation() -> void:
	var model = get_node_or_null("PlayerModel")
	if model:
		# Modell schaut in Bewegungsrichtung
		var vel_flat = Vector3(velocity.x, 0, velocity.z)
		if vel_flat.length() > 0.1:
			model.look_at(global_position + vel_flat, Vector3.UP)


func _ready() -> void:
	inventory = Inventory.new()          # ←←← DAS MUSS GANZ OBEN STEHEN
	_give_starter_items()

	if has_meta("split_index"):
		split_index = get_meta("split_index")

	# Dann erst das Modell bauen
	_build_player_model()

	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_perspective()
	_apply_fov()
	if has_node("/root/HCSettings"):
		get_node("/root/HCSettings").settings_changed.connect(_apply_fov)


func _apply_fov() -> void:
	if has_node("/root/HCSettings"):
		camera.fov = get_node("/root/HCSettings").fov


func _joy_device() -> int:
	return maxi(split_index, 0)


func _standing_on_ice() -> bool:
	if interactor == null or interactor.world == null:
		return false
	var below = global_position - Vector3(0, 0.1, 0)
	var id = interactor.world.get_block_no_gen(floori(below.x), floori(below.y), floori(below.z))
	return id == "ice"

func _build_player_model() -> void:
	var skin = AvatarLoader.load_skin(current_skin_name)
	AvatarLoader.apply_to_player(self, skin)



func _give_starter_items() -> void:
	inventory.add("stone", 64)
	inventory.add("oak_planks", 64)
	inventory.add("glass", 64)
	inventory.add("oak_log", 64)
	inventory.add("torch", 64)
	inventory.add("glowstone", 16)
	# dimension travel kit (HighCraft convenience)
	inventory.add("obsidian", 10)
	inventory.add("flint_and_steel", 1)
	inventory.add("end_portal", 4)
	inventory.add("heaven_portal", 4)
	inventory.add("firework_rocket", 16)
	inventory.add("clock", 1)
	inventory.add("compass", 1)
	inventory.add("bed", 1)
	inventory.add("elytra", 1)


func armor_points() -> int:
	var pts = 0
	for s in inventory.armor:
		if s != null:
			var it = Registry.get_item(s.item_id)
			if it != null:
				pts += int(it.get("armor_points", 0))
	return mini(20, pts)
	
	
var perspective: int = 0   # 0 = First, 1 = Third Behind, 2 = Third Front


func _unhandled_input(event: InputEvent) -> void:
	# Split: only this player's device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if split_index >= 0 and int(event.device) != _joy_device():
			return
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		if split_index > 0:
			return

	if event.is_action_pressed("shoot") and is_holding_bow():
		try_shoot_bow()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var new_pitch = head.rotation.x - event.relative.y * mouse_sensitivity
		head.rotation.x = clampf(new_pitch, -1.5, 1.5)

	# Perspective cycle: Ctrl+1 (keyboard) or R3 / Right Stick click (controller)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 and event.ctrl_pressed:
			perspective = (perspective + 1) % 3
			_apply_perspective()
		elif event.keycode == KEY_F5:
			perspective = (perspective + 1) % 3
			_apply_perspective()
		elif event.keycode == KEY_4 and event.ctrl_pressed:
			toggle_sit()
		elif event.keycode == KEY_SPACE:
			_handle_space_tap()
			if sitting:
				toggle_sit()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == HCPad.BTN_R3:
			perspective = (perspective + 1) % 3
			_apply_perspective()
				
				
func toggle_sit() -> void:
	# Boot hat Vorrang
	if has_meta("in_boat") and get_meta("in_boat") != null:
		var boat = get_meta("in_boat")
		if boat.has_method("dismount"):
			boat.dismount()
		return
	sitting = not sitting
	if sitting:
		sit_anchor = global_position
		velocity = Vector3.ZERO
		# etwas absenken
		global_position.y -= 0.35
		print("[Player] sitting")
	else:
		global_position.y += 0.35
		print("[Player] stand")


func _handle_space_tap() -> void:
	if not GameSettings.can_fly(game_mode):
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_space_time < 0.3:
		flying = not flying
		velocity.y = 0.0
	_last_space_time = now


func _physics_process(delta: float) -> void:
	if dead:
		return
	var joy_dev = _joy_device()
	var deadzone = 0.18
	if has_node("/root/HCSettings"):
		deadzone = get_node("/root/HCSettings").controller_deadzone
	# SplitScreenManager.read_move_axis already combines WASD (device 0 only)
	# with that device's left stick, so this covers keyboard, gamepad, and
	# split-screen (each instance only reads its own device) in one call.
	var move_axis = SplitScreenManager.read_move_axis(joy_dev, deadzone)
	var input_dir = Vector3(move_axis.x, 0.0, move_axis.y)

	_apply_gamepad_look(delta, joy_dev, deadzone)

	var jump_pressed = (split_index <= 0 and Input.is_key_pressed(KEY_SPACE)) or HCPad.pressed(joy_dev, HCPad.BTN_ACCEPT)
	var sprint_pressed = (split_index <= 0 and Input.is_key_pressed(KEY_SHIFT)) or HCPad.pressed(joy_dev, HCPad.BTN_L3)
	var joy_jump_now = HCPad.pressed(joy_dev, HCPad.BTN_ACCEPT)
	if joy_jump_now and not _prev_joy_jump:
		_handle_space_tap()
	_prev_joy_jump = joy_jump_now

	var dir = transform.basis * input_dir
	dir.y = 0.0
	if dir.length() > 0.0:
		dir = dir.normalized()

	if flying:
		var vy = 0.0
		if jump_pressed:
			vy += 1.0
		if (split_index <= 0 and Input.is_key_pressed(KEY_SHIFT)) or HCPad.pressed(joy_dev, HCPad.BTN_CANCEL):
			vy -= 1.0
		velocity.x = dir.x * fly_speed
		velocity.z = dir.z * fly_speed
		velocity.y = vy * fly_speed
	else:
		if is_on_floor():
			gliding = false
		elif has_elytra() and jump_pressed and velocity.y < 0.0:
			gliding = true
		if gliding:
			velocity = -camera.global_transform.basis.z * 9.0
		else:
			_on_ice = is_on_floor() and _standing_on_ice()
			var speed = sprint_speed if sprint_pressed else walk_speed
			if _on_ice:
				speed *= 1.35  # faster top speed while sliding on ice
				var target = Vector3(dir.x * speed, velocity.y, dir.z * speed)
				# low acceleration = long slide before reaching/losing speed
				var accel = 2.2 if dir.length() > 0.0 else 1.4
				velocity.x = move_toward(velocity.x, target.x, accel * delta * speed)
				velocity.z = move_toward(velocity.z, target.z, accel * delta * speed)
			else:
				velocity.x = dir.x * speed
				velocity.z = dir.z * speed
			if is_on_floor():
				if jump_pressed:
					velocity.y = jump_velocity
			else:
				velocity.y -= gravity * delta

	move_and_slide()
	_footsteps(delta)
	_survival_tick(delta)
	_update_model_rotation()
	_update_model_visibility()
	if sitting:
		velocity = Vector3.ZERO
		if has_meta("in_boat") and get_meta("in_boat") != null:
			return
		move_and_slide()
		return

	# --- deine bestehende dir-Berechnung (WASD) ---
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	input_dir = (transform.basis * input_dir).normalized() if input_dir.length() > 0 else Vector3.ZERO

	var move_speed: float = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	# falls deine Vars anders heißen: move_speed / speed_walk etc. verwenden

	# --- Ice ---
	var on_ice := false
	var w = world
	if w == null and interactor != null:
		w = interactor.world
	if w != null:
		var bx = floori(global_position.x)
		var by = floori(global_position.y - 0.2)
		var bz = floori(global_position.z)
		var under = w.get_block(bx, by, bz)
		on_ice = under == "ice" or under == "packed_ice" or under == "blue_ice"

	if not flying and is_on_floor():
		if on_ice:
			var target = input_dir * move_speed * 1.35
			velocity.x = lerp(velocity.x, target.x, 0.08)
			velocity.z = lerp(velocity.z, target.z, 0.08)
			if input_dir.length() < 0.1:
				velocity.x *= 0.98
				velocity.z *= 0.98
		else:
			velocity.x = input_dir.x * move_speed
			velocity.z = input_dir.z * move_speed
	# ... gravity / jump / move_and_slide wie bisher ...
		
		
	
		
		
	


func _apply_gamepad_look(delta: float, joy_dev: int, deadzone: float) -> void:
	var sens = 1.2
	if has_node("/root/HCSettings"):
		sens = get_node("/root/HCSettings").controller_aim_sensitivity
	var look = SplitScreenManager.read_look_axis(joy_dev, sens, deadzone)
	if look == Vector2.ZERO:
		return
	rotate_y(-look.x * delta * 2.5)
	var new_pitch = head.rotation.x - look.y * delta * 2.5
	head.rotation.x = clampf(new_pitch, -1.5, 1.5)


func _footsteps(delta: float) -> void:
	if flying or not is_on_floor():
		_step_t = 0.0
		return
	if Vector2(velocity.x, velocity.z).length() < 0.5:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.45
		Audio.play("step", -16.0)


func has_elytra() -> bool:
	var s = inventory.armor[1]
	return s != null and s.item_id == "elytra"
	


func elytra_boost() -> void:
	if gliding:
		velocity += -camera.global_transform.basis.z * 8.0


func _survival_tick(delta: float) -> void:
	if game_mode == GameSettings.GameMode.CREATIVE:
		health = max_health
		hunger = max_hunger
		return

	if not GameSettings.hunger_drops(difficulty):
		hunger = max_hunger
	else:
		var moving = Vector2(velocity.x, velocity.z).length() > 0.5
		_exhaustion += delta * (0.12 if moving else 0.02)
		if _exhaustion >= 4.0:
			_exhaustion -= 4.0
			if saturation > 0.0:
				saturation = maxf(0.0, saturation - 1.0)
			else:
				hunger = maxf(0.0, hunger - 1.0)

	if hunger >= max_hunger * 0.9 and health < max_health:
		_regen_t += delta
		if _regen_t >= 2.0:
			_regen_t = 0.0
			health = minf(max_health, health + 1.0)
			_exhaustion += 1.0

	if hunger <= 0.0:
		var floor_hp = GameSettings.starvation_floor(difficulty)
		_starve_t += delta
		if _starve_t >= 1.0 and health > floor_hp:
			_starve_t = 0.0
			health = maxf(floor_hp, health - 1.0)
			if health <= 0.0:
				_die()


func take_damage(raw: float) -> void:
	if not GameSettings.can_take_damage(game_mode) or dead:
		return
	var reduction = minf(0.8, armor_points() * 0.04)
	health = maxf(0.0, health - raw * (1.0 - reduction))
	_exhaustion += 0.1
	Audio.play("hurt", -4.0)
	if health <= 0.0:
		_die()


func mob_hit(base_damage: float) -> void:
	take_damage(base_damage * GameSettings.mob_damage_mult(difficulty))


func eat(item_id: String) -> bool:
	var it = Registry.get_item(item_id)
	if it == null or it.get("type", "") != "food":
		return false
	if hunger >= max_hunger:
		return false
	hunger = minf(max_hunger, hunger + int(it.get("hunger", 0)))
	saturation = minf(hunger, saturation + float(it.get("saturation", 0.0)))
	return true


func _die() -> void:
	dead = true
	if GameSettings.can_respawn(game_mode):
		respawn()


func respawn() -> void:
	dead = false
	health = max_health
	hunger = max_hunger
	saturation = 5.0
	_exhaustion = 0.0
	velocity = Vector3.ZERO
	flying = false
	gliding = false

	var pos: Vector3 = spawn_point
	var game_node = _find_game_node()
	if game_node != null:
		var w = game_node.get("world")
		var r = game_node.get("renderer")
		# Snap to current surface so we never spawn inside void / unloaded terrain
		if w != null and w.has_method("surface_height"):
			var sx := floori(pos.x)
			var sz := floori(pos.z)
			var sy: int = int(w.surface_height(sx, sz))
			if sy < 1:
				sy = 64
			pos = Vector3(float(sx) + 0.5, float(sy) + 2.0, float(sz) + 0.5)
		# Force-load collision under the spawn point BEFORE the physics step
		if r != null:
			var cs := 16
			if w != null and "CHUNK_SIZE" in w:
				cs = int(w.CHUNK_SIZE)
			elif ClassDB.class_exists("VoxelWorld"):
				cs = 16
			var cx := floori(pos.x / float(cs))
			var cz := floori(pos.z / float(cs))
			if r.has_method("build_chunk"):
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						r.build_chunk(cx + dx, cz + dz)
			if r.has_method("update_around"):
				r.update_around(pos, 3)

	spawn_point = pos
	global_position = pos
	# Second snap next frame after colliders are in the physics server
	call_deferred("_respawn_snap", pos)


func _respawn_snap(pos: Vector3) -> void:
	if not is_instance_valid(self):
		return
	global_position = pos
	velocity = Vector3.ZERO


func _find_game_node() -> Node:
	# Solo: parent is Game. Split: climb out of SubViewport.
	var n: Node = get_parent()
	var hops := 0
	while n != null and hops < 8:
		if n.get("world") != null and n.get("renderer") != null:
			return n
		n = n.get_parent()
		hops += 1
	# Fallback: scene root search
	var tree = get_tree()
	if tree != null:
		for c in tree.get_nodes_in_group("game"):
			return c
		var root = tree.current_scene
		if root != null and root.get("world") != null:
			return root
	return null


func configure(mode: int, diff: int) -> void:
	game_mode = mode
	difficulty = diff
	if not GameSettings.can_fly(mode):
		flying = false
	if not GameSettings.can_take_damage(mode):
		health = max_health
		hunger = max_hunger


func _apply_perspective() -> void:
	var model = get_node_or_null("PlayerModel")
	match perspective:
		0:  # First Person
			camera.position = Vector3(0, 0.1, 0)
			camera.rotation = Vector3.ZERO
			if model:
				model.visible = false
		1:  # Third Person von hinten
			camera.position = Vector3(0, 0.6, 4.0)
			camera.rotation = Vector3.ZERO
			if model:
				model.visible = true
		2:  # Third Person von vorne
			camera.position = Vector3(0, 0.6, -4.0)
			camera.rotation = Vector3(0, PI, 0)
			if model:
				model.visible = true


func _update_model_visibility() -> void:
	var model = get_node_or_null("PlayerModel")
	if model == null:
		return

	# perspective 0 = First Person → Modell unsichtbar
	model.visible = (perspective != 0)

func _toggle_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func perspective_name() -> String:
	return ["First person", "Third (back)", "Third (front)"][perspective]
	

# Add this logic to your player.gd or create a separate component

func try_shoot_bow() -> void:
	if not is_holding_bow():
		return

	# Spawn arrow
	var arrow_scene = preload("res://scenes/arrow.tscn")  # Create this scene
	var arrow = arrow_scene.instantiate()

	# Get camera direction
	var camera = get_viewport().get_camera_3d()
	var direction = -camera.global_transform.basis.z

	arrow.global_position = camera.global_position + direction * 1.5
	get_tree().current_scene.add_child(arrow)

	if arrow.has_method("setup"):
		arrow.setup(direction, self)

	# Consume arrow from inventory (optional)
	# inventory.remove("arrow", 1)

func is_holding_bow() -> bool:
	var held = inventory.held()
	return held != null and held.item_id == "bow"
	
	
	
func try_apply_name_tag_to_mob(mob) -> bool:
	var held = inventory.held()
	if held == null or held.item_id != "name_tag":
		return false

	var new_name = held.custom_name.strip_edges() if held.custom_name.strip_edges() != "" else "Named Mob"

	for c in mob.get_children():
		if c is Label3D and c.position.y > 1.5:
			c.queue_free()

	var label = Label3D.new()
	label.name = "NameTagLabel"
	label.text = new_name
	label.font_size = 48
	label.modulate = Color(1.0, 1.0, 0.85)
	label.outline_modulate = Color(0, 0, 0)
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.3, 0)
	mob.add_child(label)

	if mob.has_method("set_custom_name"):
		mob.set_custom_name(new_name)
	elif "custom_name" in mob:
		mob.custom_name = new_name

	inventory.consume_held(1)
	return true
