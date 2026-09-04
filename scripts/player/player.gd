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
var _elytra_boost_time: float = 0.0

var inventory: Inventory
var game_mode: int = GameSettings.GameMode.SURVIVAL
var difficulty: int = GameSettings.Difficulty.NORMAL
var _knockback_t: float = 0.0
var _knockback_horizontal: Vector2 = Vector2.ZERO
var health: float = 20.0
var max_health: float = 20.0
var hunger: float = 20.0
var max_hunger: float = 20.0
var saturation: float = 5.0
var xp_level: int = 0
var dead: bool = false
var _air: float = 10.0
var _max_air: float = 10.0
var _in_water: bool = false
var spawn_point: Vector3 = Vector3.ZERO

var _last_space_time: float = -1.0
var _exhaustion: float = 0.0
var _regen_t: float = 0.0
var _starve_t: float = 0.0
var _step_t: float = 0.0
var split_index: int = -1   # -1 = single player (keyboard + gamepad 0). 0-3 = split-screen device index.
var controller_device: int = -1
var _prev_joy_jump: bool = false
var _on_ice: bool = false
var _ice_velocity: Vector3 = Vector3.ZERO
var _walk_anim_time: float = 0.0
var _arm_swing_t: float = 0.0
const ARM_SWING_DURATION := 0.30
var _first_person_arm: Node3D = null
var _stream_renderer: Node = null
var _last_stream_safe_position := Vector3.ZERO
var _has_stream_safe_position := false
var active_effects: Dictionary = {} # effect id -> {duration, amplifier}
var _effect_second_accum: float = 0.0
var _third_person_held_visual: Node3D = null
var _first_person_held_visual: Node3D = null
var _rendered_held_key: String = ""
var _remote_held_item_id: String = ""
var _remote_held_enchantments: Dictionary = {}

signal effects_changed

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _update_model_rotation() -> void:
	var model = get_node_or_null("PlayerModel")
	if model:
		# Modell schaut in Bewegungsrichtung
		var vel_flat = Vector3(velocity.x, 0, velocity.z)
		if vel_flat.length() > 0.1:
			model.look_at(global_position + vel_flat, Vector3.UP)


func play_arm_swing() -> void:
	# Do not restart a swing every process frame while mining is held.
	if _arm_swing_t <= ARM_SWING_DURATION * 0.35:
		_arm_swing_t = ARM_SWING_DURATION


func _update_player_animation(delta: float) -> void:
	var model := get_node_or_null("PlayerModel")
	if model == null:
		return
	var left_arm := model.get_node_or_null("LeftArm") as Node3D
	var right_arm := model.get_node_or_null("RightArm") as Node3D
	var left_leg := model.get_node_or_null("LeftLeg") as Node3D
	var right_leg := model.get_node_or_null("RightLeg") as Node3D
	if left_arm == null or right_arm == null or left_leg == null or right_leg == null:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horizontal_speed > 0.15 and is_on_floor() and not sitting
	if moving:
		_walk_anim_time += delta * (8.0 + minf(horizontal_speed, sprint_speed) * 0.65)
	var walk_amount := clampf(horizontal_speed / maxf(walk_speed, 0.1), 0.0, 1.25) if moving else 0.0
	var walk_swing := sin(_walk_anim_time) * 0.72 * walk_amount
	left_leg.rotation.x = lerpf(left_leg.rotation.x, walk_swing, minf(1.0, delta * 14.0))
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -walk_swing, minf(1.0, delta * 14.0))
	left_arm.rotation.x = lerpf(left_arm.rotation.x, -walk_swing * 0.8, minf(1.0, delta * 14.0))

	var right_target := walk_swing * 0.8
	if _arm_swing_t > 0.0:
		_arm_swing_t = maxf(0.0, _arm_swing_t - delta)
		var progress := 1.0 - (_arm_swing_t / ARM_SWING_DURATION)
		right_target = -sin(progress * PI) * 1.75
	right_arm.rotation.x = lerpf(right_arm.rotation.x, right_target, minf(1.0, delta * 20.0))
	if _first_person_arm != null:
		_first_person_arm.rotation.x = right_target * 0.58
		_first_person_arm.rotation.z = -0.18 + sin(_walk_anim_time) * 0.025 * walk_amount
	_update_held_item_visual()


func _ready() -> void:
	add_to_group("players")
	inventory = Inventory.new()          # ←←← DAS MUSS GANZ OBEN STEHEN
	if not bool(get_meta("remote_proxy", false)) and has_node("/root/HCSettings"):
		var skin_slot := int(get_meta("split_index", 0)) if has_meta("split_index") else 0
		var settings = get_node("/root/HCSettings")
		current_skin_name = settings.get_local_player_skin(skin_slot) if settings.has_method("get_local_player_skin") else str(settings.selected_skin_name)
	if bool(get_meta("remote_proxy", false)):
		_build_player_model()
		if _first_person_arm != null:
			_first_person_arm.visible = false
		camera.current = false
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)
		return

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
	return controller_device if controller_device >= 0 else maxi(split_index, 0)


func _standing_on_ice() -> bool:
	if interactor == null or interactor.world == null:
		return false
	var below = global_position - Vector3(0, 0.1, 0)
	var id = interactor.world.get_block_no_gen(floori(below.x), floori(below.y), floori(below.z))
	return id == "ice"

func _build_player_model() -> void:
	var skin = AvatarLoader.load_skin(current_skin_name)
	_apply_skin_data(skin)


func set_skin(skin_name: String, skin_data: Dictionary = {}) -> void:
	current_skin_name = skin_name
	var skin := skin_data if not skin_data.is_empty() else AvatarLoader.load_skin(skin_name)
	_apply_skin_data(skin)


func _apply_skin_data(skin: Dictionary) -> void:
	AvatarLoader.apply_to_player(self, skin)
	_build_first_person_arm(skin)
	call_deferred("_apply_model_render_layers")
	call_deferred("_apply_own_camera_cull")


func _build_first_person_arm(skin: Dictionary) -> void:
	if _first_person_arm != null and is_instance_valid(_first_person_arm):
		_first_person_arm.queue_free()
	_first_person_arm = Node3D.new()
	_first_person_arm.name = "FirstPersonArm"
	_first_person_arm.position = Vector3(0.48, -0.42, -0.72)
	_first_person_arm.rotation.z = -0.18
	camera.add_child(_first_person_arm)
	var mesh_instance := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.18, 0.62, 0.18)
	mesh_instance.mesh = arm_mesh
	mesh_instance.position = Vector3(0, -0.22, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = skin.get("skin_color", Color(0.55, 0.35, 0.2))
	mesh_instance.material_override = material
	# Split-screen rain layers are already isolated per camera and are ideal for
	# this camera-only view model as well.
	mesh_instance.layers = 1 << (14 + clampi(split_index, 0, 3)) if split_index >= 0 else 1
	_first_person_arm.add_child(mesh_instance)
	_first_person_arm.visible = perspective == 0
	_rendered_held_key = ""
	_update_held_item_visual()


func current_held_item_id() -> String:
	if bool(get_meta("remote_proxy", false)):
		return _remote_held_item_id
	if inventory == null:
		return ""
	var stack = inventory.held()
	return "" if stack == null else str(stack.item_id)


func current_held_enchantments() -> Dictionary:
	if bool(get_meta("remote_proxy", false)):
		return _remote_held_enchantments.duplicate(true)
	if inventory == null:
		return {}
	var stack = inventory.held()
	return {} if stack == null else stack.enchantments.duplicate(true)


func set_remote_held_item(item_id: String, enchantments: Dictionary = {}) -> void:
	_remote_held_item_id = item_id
	_remote_held_enchantments = enchantments.duplicate(true)
	_rendered_held_key = ""
	_update_held_item_visual()


func _free_held_visuals() -> void:
	for visual in [_third_person_held_visual, _first_person_held_visual]:
		if visual != null and is_instance_valid(visual):
			visual.queue_free()
	_third_person_held_visual = null
	_first_person_held_visual = null


func _make_held_visual(item_id: String, enchanted: bool, first_person: bool) -> Node3D:
	var holder := Node3D.new()
	holder.name = "HeldItemView" if first_person else "HeldItemWorld"
	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_texture = Textures.get_texture(item_id)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	if enchanted:
		material.emission_enabled = true
		material.emission = Color(0.34, 0.12, 0.62)
		material.emission_energy_multiplier = 0.55
	if Registry.blocks.has(item_id):
		var block_mesh := BoxMesh.new()
		block_mesh.size = Vector3.ONE * (0.28 if first_person else 0.22)
		mesh_instance.mesh = block_mesh
	else:
		var item_mesh := QuadMesh.new()
		item_mesh.size = Vector2(0.42, 0.42) if first_person else Vector2(0.32, 0.32)
		mesh_instance.mesh = item_mesh
	mesh_instance.material_override = material
	holder.add_child(mesh_instance)
	if first_person:
		holder.position = Vector3(0.03, -0.55, -0.18)
		holder.rotation_degrees = Vector3(-20, 18, -18)
		mesh_instance.layers = 1 << (14 + clampi(split_index, 0, 3)) if split_index >= 0 else 1
	else:
		holder.position = Vector3(0.0, -0.38, -0.14)
		holder.rotation_degrees = Vector3(-72, 0, 8)
		mesh_instance.layers = _body_layer_bit() if _is_locally_controlled() else 1
	return holder


func _update_held_item_visual() -> void:
	var item_id := current_held_item_id()
	var enchantments := current_held_enchantments()
	var key := item_id + "|" + JSON.stringify(enchantments)
	if key == _rendered_held_key:
		return
	_rendered_held_key = key
	_free_held_visuals()
	if item_id.is_empty():
		return
	var model := get_node_or_null("PlayerModel")
	var right_arm := model.get_node_or_null("RightArm") if model != null else null
	if right_arm == null and model != null:
		right_arm = model.find_child("RightArm", true, false)
	if right_arm != null:
		_third_person_held_visual = _make_held_visual(item_id, not enchantments.is_empty(), false)
		right_arm.add_child(_third_person_held_visual)
	if _first_person_arm != null and not bool(get_meta("remote_proxy", false)):
		_first_person_held_visual = _make_held_visual(item_id, not enchantments.is_empty(), true)
		_first_person_arm.add_child(_first_person_held_visual)



func armor_points() -> int:
	var pts = 0
	for s in inventory.armor:
		if s != null:
			var it = Registry.get_item(s.item_id)
			if it != null:
				pts += int(it.get("armor_points", 0))
	return mini(20, pts)


func has_effect(effect_id: String) -> bool:
	return active_effects.has(effect_id) and float(active_effects[effect_id].get("duration", 0.0)) > 0.0


func effect_level(effect_id: String) -> int:
	return int(active_effects[effect_id].get("amplifier", 0)) + 1 if has_effect(effect_id) else 0


func movement_effect_multiplier() -> float:
	return maxf(0.1, (1.0 + 0.2 * effect_level("speed")) * (1.0 - 0.15 * effect_level("slowness")))


func mining_effect_multiplier() -> float:
	return maxf(0.1, (1.0 + 0.2 * effect_level("haste")) * (1.0 - 0.2 * effect_level("mining_fatigue")))


func attack_effect_bonus() -> float:
	return float(effect_level("strength")) * 3.0 - float(effect_level("weakness")) * 2.0


func apply_status_effect(effect_id: String, duration: float, amplifier: int = 0) -> void:
	var level := maxi(1, amplifier + 1)
	if effect_id in ["instant_health", "healing"]:
		health = minf(max_health, health + 4.0 * pow(2.0, level - 1))
		return
	if effect_id in ["instant_damage", "harming"]:
		take_damage(6.0 * pow(2.0, level - 1), Vector3.INF, "magic")
		return
	if duration <= 0.0:
		return
	var previous: Dictionary = active_effects.get(effect_id, {})
	if not previous.is_empty() and int(previous.get("amplifier", 0)) > amplifier:
		return
	active_effects[effect_id] = {"duration": maxf(duration, float(previous.get("duration", 0.0))), "amplifier": amplifier}
	_refresh_effect_visuals()
	effects_changed.emit()


func drink_potion(item_id: String) -> bool:
	if not Registry.potions.has(item_id):
		return false
	var potion: Dictionary = Registry.potions[item_id]
	for effect in potion.get("effects", []):
		apply_status_effect(str(effect.get("type", "")), float(effect.get("duration", 0.0)), int(effect.get("amplifier", 0)))
	Audio.play("player_eat", -8.0)
	return true


func clear_status_effects() -> void:
	active_effects.clear()
	_refresh_effect_visuals()
	effects_changed.emit()


func _refresh_effect_visuals() -> void:
	var model := get_node_or_null("PlayerModel")
	if model != null:
		model.visible = not has_effect("invisibility")
	if _first_person_arm != null:
		_first_person_arm.visible = perspective == 0 and not has_effect("invisibility")


func _tick_status_effects(delta: float) -> void:
	if active_effects.is_empty() or dead:
		return
	var expired := false
	for effect_id in active_effects.keys():
		active_effects[effect_id]["duration"] = float(active_effects[effect_id].get("duration", 0.0)) - delta
		if float(active_effects[effect_id]["duration"]) <= 0.0:
			active_effects.erase(effect_id)
			expired = true
	_effect_second_accum += delta
	if _effect_second_accum >= 1.0:
		_effect_second_accum -= 1.0
		if has_effect("regeneration"):
			health = minf(max_health, health + float(effect_level("regeneration")))
		if has_effect("poison") and GameSettings.can_take_damage(game_mode):
			health = maxf(1.0, health - float(effect_level("poison")))
		if has_effect("wither"):
			take_damage(float(effect_level("wither")), Vector3.INF, "magic")
	if expired:
		_refresh_effect_visuals()
		effects_changed.emit()
	
	
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
	_tick_speed_boost(delta)
	_tick_status_effects(delta)
	_update_held_item_visual()
	if has_meta("spawn_frozen") and bool(get_meta("spawn_frozen")):
		velocity = Vector3.ZERO
		return

	if dead:
		return
	var ui_input_locked := bool(get_meta("ui_input_locked", false))
	# Boat / minecart: Shift sneaks out (Minecraft style)
	if has_meta("in_boat") and get_meta("in_boat") != null:
		if Input.is_key_pressed(KEY_SHIFT) or HCPad.pressed(_joy_device(), HCPad.BTN_CANCEL):
			var boat = get_meta("in_boat")
			if boat != null and boat.has_method("dismount"):
				boat.dismount()
			return
		# Rider physics handled by boat
		return
	if has_meta("in_minecart") and get_meta("in_minecart") != null:
		if Input.is_key_pressed(KEY_SHIFT) or HCPad.pressed(_joy_device(), HCPad.BTN_CANCEL):
			var cart = get_meta("in_minecart")
			if cart != null and cart.has_method("dismount"):
				cart.dismount()
			return
		return
	if has_meta("riding_mob") and get_meta("riding_mob") != null:
		var rm = get_meta("riding_mob")
		if not is_instance_valid(rm) or Input.is_key_pressed(KEY_SHIFT):
			set_meta("riding_mob", null)
			if is_instance_valid(rm):
				rm.set_meta("rider", null)
			return
		global_position = rm.global_position + Vector3(0, 1.4, 0)
		velocity = Vector3.ZERO
		# Steer mount
		var md = Vector3.ZERO
		if Input.is_key_pressed(KEY_W):
			md -= global_transform.basis.z
		if Input.is_key_pressed(KEY_S):
			md += global_transform.basis.z
		if Input.is_key_pressed(KEY_A):
			rm.rotate_y(1.5 * delta)
		if Input.is_key_pressed(KEY_D):
			rm.rotate_y(-1.5 * delta)
		md.y = 0
		if md.length() > 0.01 and "velocity" in rm:
			rm.velocity = md.normalized() * 5.0
		return
	var joy_dev = _joy_device()
	var deadzone = 0.18
	if has_node("/root/HCSettings"):
		deadzone = get_node("/root/HCSettings").controller_deadzone
	# SplitScreenManager.read_move_axis already combines WASD (device 0 only)
	# with that device's left stick, so this covers keyboard, gamepad, and
	# split-screen (each instance only reads its own device) in one call.
	var move_axis = Vector2.ZERO if ui_input_locked else SplitScreenManager.read_move_axis(joy_dev, deadzone)
	var input_dir = Vector3(move_axis.x, 0.0, move_axis.y)

	var jump_pressed = not ui_input_locked and ((split_index <= 0 and Input.is_key_pressed(KEY_SPACE)) or HCPad.pressed(joy_dev, HCPad.BTN_ACCEPT))
	var sprint_pressed = not ui_input_locked and ((split_index <= 0 and Input.is_key_pressed(KEY_SHIFT)) or HCPad.pressed(joy_dev, HCPad.BTN_L3))
	var joy_jump_now = not ui_input_locked and HCPad.pressed(joy_dev, HCPad.BTN_ACCEPT)
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
			_elytra_boost_time = maxf(0.0, _elytra_boost_time - delta)
			var glide_speed := 18.0 if _elytra_boost_time > 0.0 else 9.0
			velocity = -camera.global_transform.basis.z * glide_speed
		else:
			_on_ice = is_on_floor() and _standing_on_ice()
			var speed = sprint_speed if sprint_pressed else walk_speed
			speed *= movement_effect_multiplier()
			if has_meta("speed_boost_t"):
				speed *= float(get_meta("speed_boost_multiplier", 1.55))
			if has_meta("water_breath_t"):
				var wt = float(get_meta("water_breath_t"))
				if wt > 0.0:
					_air = _max_air
					set_meta("water_breath_t", wt - delta)

			if has_meta("gaze_slow_t"):
				var gt = float(get_meta("gaze_slow_t"))
				if gt > 0.0:
					speed *= 0.35  # Slowness V-ish
					set_meta("gaze_slow_t", gt - delta)

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
					velocity.y = jump_velocity + (1.2 * float(effect_level("jump_boost")))
					Audio.play("player_jump", -10.0)
			else:
				velocity.y -= gravity * delta

	if _knockback_t > 0.0:
		_knockback_t = maxf(0.0, _knockback_t - delta)
		var fade := _knockback_t / 0.20
		velocity.x = _knockback_horizontal.x * fade
		velocity.z = _knockback_horizontal.y * fade
	if not _guard_unloaded_chunks(delta):
		_update_model_rotation()
		_update_player_animation(delta)
		return
	move_and_slide()
	_update_water(delta)
	_footsteps(delta)
	_survival_tick(delta)
	_update_model_rotation()
	_update_player_animation(delta)
	# Render layers/cull masks only change when the model or perspective changes.
	# Recursively traversing the avatar every physics frame multiplied badly in split-screen.
	if sitting:
		velocity = Vector3.ZERO
		if has_meta("in_boat") and get_meta("in_boat") != null:
			return
		move_and_slide()
		return


func _guard_unloaded_chunks(delta: float) -> bool:
	var renderer := _get_stream_renderer()
	if renderer == null or not renderer.has_method("collision_ready_at"):
		return true
	var current_ready := bool(renderer.collision_ready_at(global_position))
	if not current_ready:
		if renderer.has_method("prioritize_collision_at"):
			renderer.prioritize_collision_at(global_position)
		# A teleport or an unload race can place us in a chunk without collision.
		# Restore the last known safe position instead of allowing a void fall.
		if _has_stream_safe_position:
			global_position = _last_stream_safe_position
		velocity = Vector3.ZERO
		return false
	_last_stream_safe_position = global_position
	_has_stream_safe_position = true
	var predicted := global_position + velocity * delta
	if renderer.collision_ready_at(predicted):
		return true
	if renderer.has_method("prioritize_collision_at"):
		renderer.prioritize_collision_at(predicted)
	# Keep gravity/jumping functional over the current loaded collision, but do
	# not allow horizontal movement into a chunk whose collision is still absent.
	velocity.x = 0.0
	velocity.z = 0.0
	return true


func _get_stream_renderer() -> Node:
	if _stream_renderer != null and is_instance_valid(_stream_renderer):
		return _stream_renderer
	var game_node := _find_game_node()
	if game_node == null:
		return null
	var candidate = game_node.get("renderer")
	if candidate is Node and is_instance_valid(candidate):
		_stream_renderer = candidate
		return _stream_renderer
	return null
	
	

func _tick_speed_boost(delta: float) -> void:
	if not has_meta("speed_boost_t"):
		return
	var remaining := float(get_meta("speed_boost_t")) - delta
	if remaining > 0.0:
		set_meta("speed_boost_t", remaining)
		return
	remove_meta("speed_boost_t")
	remove_meta("speed_boost_multiplier")


func _process(delta: float) -> void:
	# Controller camera motion must follow rendered frames. Updating it in the
	# fixed physics loop produces visible judder on 90/120/144 Hz displays.
	if dead or bool(get_meta("remote_proxy", false)) or bool(get_meta("ui_input_locked", false)):
		return
	var deadzone := 0.18
	if has_node("/root/HCSettings"):
		deadzone = float(get_node("/root/HCSettings").controller_deadzone)
	_apply_gamepad_look(delta, _joy_device(), deadzone)


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
		var under := "grass_block"
		if interactor != null and interactor.get("world") != null:
			var p := global_position
			under = str(interactor.world.get_block_no_gen(floori(p.x), floori(p.y - 0.1), floori(p.z)))
		Audio.play_step(under)


func has_elytra() -> bool:
	var s = inventory.armor[1]
	return s != null and s.item_id == "elytra"
	


func elytra_boost() -> void:
	if gliding:
		# Keep the boost active across physics frames; the glide controller assigns
		# its velocity every frame and used to erase a one-frame impulse instantly.
		_elytra_boost_time = 1.0
		velocity = -camera.global_transform.basis.z * 18.0
		Audio.play("place")


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


func take_damage(raw: float, source_position: Vector3 = Vector3.INF, damage_type: String = "generic") -> void:
	if not GameSettings.can_take_damage(game_mode) or dead:
		return
	if damage_type in ["fire", "lava"] and has_effect("fire_resistance"):
		return
	var reduction = minf(0.8, armor_points() * 0.04)
	var protection := 0
	for stack in inventory.armor:
		if stack != null:
			protection += stack.get_enchantment_level("protection")
			if damage_type in ["fire", "lava"]:
				protection += stack.get_enchantment_level("fire_protection") * 2
	var enchant_reduction := minf(0.8, float(protection) * 0.04)
	var resistance := minf(0.8, float(effect_level("resistance")) * 0.2)
	health = maxf(0.0, health - raw * (1.0 - reduction) * (1.0 - enchant_reduction) * (1.0 - resistance))
	_exhaustion += 0.1
	Audio.play("player_hurt", -4.0)
	if source_position != Vector3.INF:
		var away := global_position - source_position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = Vector3(0, 0, 1)
		away = away.normalized()
		_knockback_horizontal = Vector2(away.x, away.z) * 4.5
		_knockback_t = 0.20
		velocity.y = maxf(velocity.y, 3.0)
	if health <= 0.0:
		_die()


func mob_hit(base_damage: float, source_position: Vector3 = Vector3.INF) -> void:
	take_damage(base_damage * GameSettings.mob_damage_mult(difficulty), source_position)


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
	Audio.play("player_death", -2.0)
	if GameSettings.can_respawn(game_mode):
		respawn()


func respawn() -> void:
	dead = false
	active_effects.clear()
	_refresh_effect_visuals()
	effects_changed.emit()
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


func _body_layer_bit() -> int:
	# Unique render layer per local split player (layers 11–14).
	# Other cameras still see this layer; only THIS player's FP camera culls it.
	var idx := split_index
	if idx < 0:
		idx = int(get_meta("split_index")) if has_meta("split_index") else 0
	idx = clampi(idx, 0, 3)
	return 1 << (10 + idx)  # layer 11 + idx  (bit 10 = layer 11)


func _is_locally_controlled() -> bool:
	if split_index >= 0 or has_meta("split_index"):
		return true
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		return is_multiplayer_authority()
	return true


func _set_visual_layers(n: Node, bits: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = bits
	for c in n.get_children():
		_set_visual_layers(c, bits)


func _apply_model_render_layers() -> void:
	var model = get_node_or_null("PlayerModel")
	if model == null:
		return
	# NEVER hide the node — other viewports / peers must still see the skin
	model.visible = not has_effect("invisibility")
	if _is_locally_controlled():
		_set_visual_layers(model, _body_layer_bit())
	else:
		_set_visual_layers(model, 1)  # world layer — always visible


func _apply_own_camera_cull() -> void:
	if camera == null:
		return
	# All layers except own body layer in first person
	var all_layers := 0xFFFFF
	var mask := all_layers
	if split_index >= 0:
		# Terrain layers 2-5 are private to the matching local player. The chunk
		# renderer assigns a chunk only to players whose stream radius contains it.
		var all_split_chunk_layers := (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
		mask = (mask & ~all_split_chunk_layers) | (1 << (1 + clampi(split_index, 0, 3)))
		# Rain layers 15–18 are private per split camera. Without this, each
		# SubViewport renders every player's particle sheet when players are near.
		var all_split_rain_layers := (1 << 14) | (1 << 15) | (1 << 16) | (1 << 17)
		mask = (mask & ~all_split_rain_layers) | (1 << (14 + clampi(split_index, 0, 3)))
	if perspective == 0 and _is_locally_controlled():
		camera.cull_mask = mask & ~_body_layer_bit()
	else:
		camera.cull_mask = mask


func _apply_perspective() -> void:
	_apply_model_render_layers()
	_apply_own_camera_cull()
	if _first_person_arm != null:
		_first_person_arm.visible = perspective == 0
	match perspective:
		0:  # First Person — body hidden ONLY in this camera
			camera.position = Vector3(0, 0.1, 0)
			camera.rotation = Vector3.ZERO
		1:  # Third Person von hinten
			camera.position = Vector3(0, 0.6, 4.0)
			camera.rotation = Vector3.ZERO
		2:  # Third Person von vorne
			camera.position = Vector3(0, 0.6, -4.0)
			camera.rotation = Vector3(0, PI, 0)


func _update_model_visibility() -> void:
	# Keep skin in the world. First-person only culls it from THIS camera.
	_apply_model_render_layers()
	_apply_own_camera_cull()

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
	Audio.play("player_arrow_shoot", -6.0)

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


func _update_water(delta: float) -> void:
	_in_water = false
	var w = world
	if w == null and interactor != null:
		w = interactor.world
	var n = get_parent()
	var hops = 0
	while w == null and n != null and hops < 8:
		if n.get("world") != null:
			w = n.world
			break
		n = n.get_parent()
		hops += 1
	if w == null:
		return
	var hx = int(floor(global_position.x))
	var hz = int(floor(global_position.z))
	# Feet and body (player is ~2 blocks tall)
	var feet_y = int(floor(global_position.y))
	var body_y = int(floor(global_position.y + 1.0))
	var eye_y = int(floor(global_position.y + 1.6))
	var feet = str(w.get_block_no_gen(hx, feet_y, hz))
	var body = str(w.get_block_no_gen(hx, body_y, hz))
	var eyes = str(w.get_block_no_gen(hx, eye_y, hz))
	# Swimming if any lower water
	_in_water = feet == "water" or body == "water"
	if _in_water:
		if velocity.y < -1.0:
			velocity.y = -1.0
		if Input.is_key_pressed(KEY_SPACE) or HCPad.pressed(_joy_device(), HCPad.BTN_ACCEPT):
			velocity.y = 3.5
		velocity.x *= 0.92
		velocity.z *= 0.92
		# Drown ONLY when fully covered: at least 2 water blocks (body + eyes)
		# i.e. water must cover the head/eyes — swimming at surface is safe
		if body == "water" and eyes == "water" and not has_effect("water_breathing"):
			_air -= delta
			if _air <= 0.0:
				_air = 0.0
				if has_method("take_damage"):
					take_damage(2.0 * delta)
		else:
			# Head above water while swimming — recover air
			_air = minf(_max_air, _air + delta * 2.5)
	else:
		_air = minf(_max_air, _air + delta * 4.0)
