extends CharacterBody3D

@export var move_speed: float = 5.0
@export var run_speed: float = 10.0
@export var push_force: float = 3.0
@export var attack_range: float = 2.0
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 0.5
@export var skill_range: float = 6.0
@export var max_hp: float = 200.0
@export var max_sp: float = 100.0
@export var crit_chance: float = 0.2
@export var crit_multiplier: float = 2.0

var _target: Vector3
var _moving: bool = false
var _attack_target: Node3D = null
var _attack_timer: float = 0.0
var _mouse_held: bool = false
var _running: bool = false
var _anim_player: AnimationPlayer
var is_dead: bool = false
var _facing_angle: float = 0.0

# Skill system (exposed for skill_bar to read)
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var skill_max_cooldowns: Array[float] = [1.0, 5.0, 10.0, 0.0]

var current_hp: float
var current_sp: float
var _hp_bar_node: Node3D
var _hp_fill_mesh: MeshInstance3D
var _hp_label_3d: Label3D

var _lightning_scene: PackedScene
var _flamethrower_scene: PackedScene
var _flamethrower_active: bool = false
var _flamethrower_time: float = 0.0
var _flamethrower_effect: Node3D = null
const FLAMETHROWER_MAX_DURATION := 5.0
var _teleport_scene: PackedScene
const TELEPORT_DISTANCE := 5.0
var _sfx_lightning: AudioStreamPlayer
var _sfx_fire: AudioStreamPlayer
var _sfx_teleport: AudioStreamPlayer

# Inventory system
var inventory: Array[String] = ["", "", "", "", "", "", "", ""]
var equipped_right_hand: String = ""
var inventory_open: bool = false
var _pistol_scene: PackedScene
var _right_hand_attachment: BoneAttachment3D
var _equipped_model: Node3D

# Pistol shooting
var pistol_ammo: int = 0
const PISTOL_MAX_AMMO := 8
const PISTOL_DAMAGE := 35.0
const PISTOL_FIRE_RATE := 0.4
var _pistol_cooldown: float = 0.0
var _sfx_gunshot: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player")
	_target = global_position
	current_hp = max_hp
	current_sp = max_sp
	_lightning_scene = preload("res://lightning_effect.tscn")
	_flamethrower_scene = preload("res://flamethrower_effect.tscn")
	_sfx_lightning = AudioStreamPlayer.new()
	_sfx_lightning.stream = preload("res://sounds/lightening_bolt_001.wav")
	add_child(_sfx_lightning)
	_sfx_fire = AudioStreamPlayer.new()
	_sfx_fire.stream = preload("res://sounds/fire_storm_001.wav")
	_sfx_fire.finished.connect(_on_fire_sfx_finished)
	add_child(_sfx_fire)
	_sfx_teleport = AudioStreamPlayer.new()
	_sfx_teleport.stream = preload("res://sounds/fast_teleportation_001.wav")
	add_child(_sfx_teleport)
	_teleport_scene = preload("res://teleport_effect.tscn")
	_pistol_scene = preload("res://models/pistol.glb")
	_sfx_gunshot = AudioStreamPlayer.new()
	_sfx_gunshot.stream = preload("res://sounds/gunshot.wav")
	add_child(_sfx_gunshot)
	_create_hp_bar()
	var model := get_node_or_null("CharacterModel")
	if model:
		_anim_player = model.find_children("*", "AnimationPlayer").front() as AnimationPlayer


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and _hp_bar_node:
		_hp_bar_node.global_rotation = camera.global_rotation


func _create_hp_bar() -> void:
	_hp_bar_node = Node3D.new()
	_hp_bar_node.position = Vector3(0, 2.3, 0)
	add_child(_hp_bar_node)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1, 0.1, 0.02)
	var bg := MeshInstance3D.new()
	bg.mesh = bar_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.2, 0.2, 0.2, 1)
	bg.material_override = bg_mat
	_hp_bar_node.add_child(bg)
	_hp_fill_mesh = MeshInstance3D.new()
	_hp_fill_mesh.mesh = bar_mesh
	_hp_fill_mesh.position.z = 0.011
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.1, 0.8, 0.1, 1)
	_hp_fill_mesh.material_override = fill_mat
	_hp_bar_node.add_child(_hp_fill_mesh)
	_hp_label_3d = Label3D.new()
	_hp_label_3d.font_size = 16
	_hp_label_3d.pixel_size = 0.005
	_hp_label_3d.position = Vector3(0, 0.12, 0.02)
	_hp_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label_3d.no_depth_test = true
	_hp_label_3d.outline_size = 4
	_hp_label_3d.outline_modulate = Color(0, 0, 0, 0.8)
	_hp_label_3d.modulate = Color(1, 1, 1, 0.9)
	_hp_bar_node.add_child(_hp_label_3d)
	_update_player_hp_bar()


func _update_player_hp_bar() -> void:
	var ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	_hp_fill_mesh.scale.x = ratio
	_hp_fill_mesh.position.x = (ratio - 1.0) * 0.5
	if _hp_label_3d:
		_hp_label_3d.text = "%d / %d" % [ceili(maxf(current_hp, 0.0)), int(max_hp)]


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	_update_player_hp_bar()
	_spawn_damage_number(amount)
	if current_hp <= 0.0:
		_die()


func _spawn_damage_number(amount: float) -> void:
	var node := Node3D.new()
	node.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.5, randf_range(-0.3, 0.3))
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.text = str(int(amount))
	label.font_size = 28
	label.modulate = Color(0.3, 1.0, 0.1, 1.0)  # green poison color
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", node.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(node.queue_free)


func _die() -> void:
	is_dead = true
	_moving = false
	_mouse_held = false
	velocity = Vector3.ZERO
	_stop_flamethrower()
	_play_anim("")
	get_tree().call_group("game_ui", "show_game_over")


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or inventory_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_held = event.pressed
		_running = Input.is_key_pressed(KEY_CTRL)
		if event.pressed:
			_handle_click(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_shoot_pistol(event.position)
	elif event is InputEventMouseMotion and _mouse_held:
		_running = Input.is_key_pressed(KEY_CTRL)
		_handle_drag(event.position)
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_1: _use_skill(0)
				KEY_2: _start_flamethrower()
				KEY_3: _cast_teleport()
				KEY_4: _use_skill(3)
		elif not event.pressed:
			match event.keycode:
				KEY_2: _stop_flamethrower()


func _handle_click(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)

	if result:
		if result.collider.is_in_group("enemy"):
			_attack_target = result.collider
			_target = _attack_target.global_position
			_moving = true
			return
		elif result.collider.is_in_group("pickup_body"):
			var pickup = result.collider.get_meta("pickup_owner", null)
			if pickup and is_instance_valid(pickup) and global_position.distance_to(pickup.global_position) < 2.5:
				_try_pickup(pickup)
				return

	_attack_target = null
	_move_to_ground(from, dir)


func _handle_drag(screen_pos: Vector2) -> void:
	_attack_target = null
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	_move_to_ground(from, dir)


func _move_to_ground(from: Vector3, dir: Vector3) -> void:
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		if t > 0.0:
			var hit := from + dir * t
			_target = Vector3(hit.x, 0.0, hit.z)
			_moving = true


func _use_skill(index: int) -> void:
	if skill_cooldowns[index] > 0.0 or skill_max_cooldowns[index] <= 0.0:
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)

	if not result or not result.collider.is_in_group("enemy"):
		return
	var enemy: Node3D = result.collider
	if not enemy.visible:
		return
	if global_position.distance_to(enemy.global_position) > skill_range:
		return

	skill_cooldowns[index] = skill_max_cooldowns[index]

	match index:
		0: _cast_lightning(enemy)


func _cast_lightning(enemy: Node3D) -> void:
	var is_crit := randf() < crit_chance
	var dmg := 40.0 * (crit_multiplier if is_crit else 1.0)
	enemy.take_damage(dmg, is_crit)
	_sfx_lightning.play()
	var effect := _lightning_scene.instantiate()
	effect.global_position = enemy.global_position
	get_tree().current_scene.add_child(effect)


func _start_flamethrower() -> void:
	if skill_cooldowns[1] > 0.0 or _flamethrower_active:
		return
	_flamethrower_active = true
	_flamethrower_time = 0.0
	_sfx_fire.play()
	_flamethrower_effect = _flamethrower_scene.instantiate()
	_flamethrower_effect.position = Vector3(0, 1, 0)
	_flamethrower_effect.rotation.y = _facing_angle + PI
	add_child(_flamethrower_effect)


func _on_fire_sfx_finished() -> void:
	if _flamethrower_active:
		_sfx_fire.play()


func _stop_flamethrower() -> void:
	if not _flamethrower_active:
		return
	_flamethrower_active = false
	_sfx_fire.stop()
	if _flamethrower_effect and is_instance_valid(_flamethrower_effect):
		_flamethrower_effect.stop()
		_flamethrower_effect = null
	skill_cooldowns[1] = skill_max_cooldowns[1]


func _update_flamethrower(delta: float) -> void:
	if not _flamethrower_active or not _flamethrower_effect:
		return
	_flamethrower_time += delta
	if _flamethrower_time >= FLAMETHROWER_MAX_DURATION:
		_stop_flamethrower()
		return
	# Fire in the direction the character is facing
	_flamethrower_effect.rotation.y = _facing_angle + PI


func _get_mouse_ground_pos() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return global_position
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		if t > 0.0:
			return from + dir * t
	return global_position


func _cast_teleport() -> void:
	if skill_cooldowns[2] > 0.0:
		return
	var ground_pos := _get_mouse_ground_pos()
	var dir := ground_pos - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()

	var dest := global_position + dir * TELEPORT_DISTANCE
	dest.y = 0.0

	# Clamp to map bounds
	dest.x = clampf(dest.x, -9.5, 9.5)
	dest.z = clampf(dest.z, -9.5, 9.5)

	# Check if destination is clear of other objects
	dest = _find_clear_teleport_pos(dest)

	# Start cooldown
	skill_cooldowns[2] = skill_max_cooldowns[2]

	# Sound + departure effect
	_sfx_teleport.play()
	var depart_fx := _teleport_scene.instantiate()
	depart_fx.global_position = global_position + Vector3(0, 0.5, 0)
	get_tree().current_scene.add_child(depart_fx)

	# Teleport
	global_position = dest
	_target = dest
	_moving = false
	_attack_target = null
	velocity = Vector3.ZERO

	# Spawn arrival effect
	var arrive_fx := _teleport_scene.instantiate()
	arrive_fx.global_position = dest + Vector3(0, 0.5, 0)
	get_tree().current_scene.add_child(arrive_fx)

	# Camera shake
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.15)


func _find_clear_teleport_pos(target: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, target + Vector3(0, 1, 0))
	params.exclude = [get_rid()]
	params.collide_with_areas = false
	# Exclude ground by checking results manually
	var hits := space.intersect_shape(params, 8)
	hits = hits.filter(func(h): return h.collider != null and not (h.collider is StaticBody3D and h.collider.name == "Ground"))
	if hits.is_empty():
		return target
	# Try slightly shorter distances
	var dir := (target - global_position).normalized()
	for step in range(4, 0, -1):
		var test_pos := global_position + dir * (TELEPORT_DISTANCE * step / 5.0)
		test_pos.y = 0.0
		test_pos.x = clampf(test_pos.x, -9.5, 9.5)
		test_pos.z = clampf(test_pos.z, -9.5, 9.5)
		params.transform = Transform3D(Basis.IDENTITY, test_pos + Vector3(0, 1, 0))
		hits = space.intersect_shape(params, 8)
		hits = hits.filter(func(h): return h.collider != null and not (h.collider is StaticBody3D and h.collider.name == "Ground"))
		if hits.is_empty():
			return test_pos
	# All positions blocked, return original position (skill is consumed)
	return global_position


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_timer -= delta
	_update_flamethrower(delta)

	for i in skill_cooldowns.size():
		if skill_cooldowns[i] > 0.0:
			skill_cooldowns[i] = maxf(skill_cooldowns[i] - delta, 0.0)
	if _pistol_cooldown > 0.0:
		_pistol_cooldown = maxf(_pistol_cooldown - delta, 0.0)

	# Handle attack target
	if _attack_target:
		if not is_instance_valid(_attack_target) or not _attack_target.visible:
			_attack_target = null
		else:
			var dist := global_position.distance_to(_attack_target.global_position)
			if dist <= attack_range:
				_moving = false
				velocity = Vector3.ZERO
				if _attack_timer <= 0.0:
					var is_crit := randf() < crit_chance
					var dmg := attack_damage * (crit_multiplier if is_crit else 1.0)
					_attack_target.take_damage(dmg, is_crit)
					_attack_timer = attack_cooldown
					_attack_target = null
				return
			else:
				_target = _attack_target.global_position

	if not _moving:
		velocity = Vector3.ZERO
		_play_anim("")
		return

	var diff := _target - global_position
	diff.y = 0.0
	if diff.length() < 0.1:
		_moving = false
		velocity = Vector3.ZERO
		_play_anim("")
		return

	var speed := run_speed if _running else move_speed
	velocity = diff.normalized() * speed
	_play_anim("run" if _running else "walk")

	# Rotate model to face movement direction
	var model := get_node_or_null("CharacterModel")
	if model:
		_facing_angle = atan2(velocity.x, velocity.z)
		model.rotation.y = _facing_angle

	move_and_slide()
	global_position.x = clampf(global_position.x, -9.5, 9.5)
	global_position.z = clampf(global_position.z, -9.5, 9.5)

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			var push_dir := -collision.get_normal()
			push_dir.y = 0.0
			collider.apply_central_impulse(push_dir * push_force)


func _play_anim(anim_name: String) -> void:
	if not _anim_player:
		return
	if anim_name == "":
		if _anim_player.is_playing():
			_anim_player.stop()
		return
	# Map simple names to actual animation names in the GLB
	var anims := _anim_player.get_animation_list()
	var target := ""
	for a in anims:
		if anim_name == "walk" and "walk" in a.to_lower():
			target = a
			break
		elif anim_name == "run" and ("run" in a.to_lower() or "walk" in a.to_lower()):
			target = a
			break
	if target == "" and anims.size() > 0:
		target = anims[0]
	if target != "" and _anim_player.current_animation != target:
		_anim_player.play(target)
		if anim_name == "run":
			_anim_player.speed_scale = 2.0
		else:
			_anim_player.speed_scale = 1.0


func _try_pickup(pickup: Node) -> void:
	for i in inventory.size():
		if inventory[i] == "":
			inventory[i] = pickup.item_id
			if pickup.item_id == "pistol":
				pistol_ammo = mini(pistol_ammo + 8, PISTOL_MAX_AMMO)
			pickup.collect()
			return


func has_pistol() -> bool:
	if equipped_right_hand == "pistol":
		return true
	for item in inventory:
		if item == "pistol":
			return true
	return false


func add_ammo(amount: int) -> void:
	if not has_pistol():
		return
	var old_ammo := pistol_ammo
	pistol_ammo = mini(pistol_ammo + amount, PISTOL_MAX_AMMO)
	var added := pistol_ammo - old_ammo
	if added > 0:
		_spawn_heal_number_custom("+%d AMMO" % added, Color(1.0, 0.85, 0.2, 1.0))


func equip_to_right_hand(item_id: String) -> void:
	_clear_right_hand_model()
	equipped_right_hand = item_id
	if item_id == "pistol":
		_attach_pistol_to_hand()


func unequip_right_hand() -> String:
	var item := equipped_right_hand
	equipped_right_hand = ""
	_clear_right_hand_model()
	return item


func _attach_pistol_to_hand() -> void:
	var model := get_node_or_null("CharacterModel")
	if not model:
		return
	# Attach pistol to the character model so it rotates with the character
	_equipped_model = _pistol_scene.instantiate()
	_equipped_model.scale = Vector3(0.5, 0.5, 0.5)
	# Right hand area: right side offset, hand height, slightly forward
	_equipped_model.position = Vector3(-0.5, 0.4, 0.15)
	_equipped_model.rotation_degrees = Vector3(0, 90, 0)
	model.add_child(_equipped_model)
	PistolMaterial.apply(_equipped_model)


func _clear_right_hand_model() -> void:
	if _equipped_model and is_instance_valid(_equipped_model):
		_equipped_model.queue_free()
		_equipped_model = null
	if _right_hand_attachment and is_instance_valid(_right_hand_attachment):
		_right_hand_attachment.queue_free()
		_right_hand_attachment = null


func heal_hp(amount: float) -> void:
	if is_dead:
		return
	var old_hp := current_hp
	current_hp = minf(current_hp + amount, max_hp)
	var healed := current_hp - old_hp
	if healed > 0.0:
		_update_player_hp_bar()
		_spawn_heal_number(healed)


func _spawn_heal_number(amount: float) -> void:
	var node := Node3D.new()
	node.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.5, randf_range(-0.3, 0.3))
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.text = "+%d" % int(amount)
	label.font_size = 28
	label.modulate = Color(0.2, 1.0, 0.3, 1.0)
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", node.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(node.queue_free)


func _spawn_heal_number_custom(text: String, color: Color) -> void:
	var node := Node3D.new()
	node.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.5, randf_range(-0.3, 0.3))
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.text = text
	label.font_size = 24
	label.modulate = color
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", node.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(node.queue_free)


func _shoot_pistol(screen_pos: Vector2) -> void:
	if equipped_right_hand != "pistol" or pistol_ammo <= 0 or _pistol_cooldown > 0.0:
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var space := get_world_3d().direct_space_state

	# Determine aim target: first raycast from camera to see if we clicked on an enemy
	var cam_from := camera.project_ray_origin(screen_pos)
	var cam_dir := camera.project_ray_normal(screen_pos)
	var cam_query := PhysicsRayQueryParameters3D.create(cam_from, cam_from + cam_dir * 100.0)
	cam_query.exclude = [get_rid()]
	var cam_result := space.intersect_ray(cam_query)

	var aim_point: Vector3
	if cam_result and cam_result.collider.is_in_group("enemy"):
		# Clicked on enemy -> aim directly at their ground position
		aim_point = Vector3(cam_result.collider.global_position.x, 0, cam_result.collider.global_position.z)
	else:
		# No enemy clicked -> project to ground plane
		if abs(cam_dir.y) > 0.001:
			var t := -cam_from.y / cam_dir.y
			if t > 0.0:
				aim_point = cam_from + cam_dir * t
			else:
				aim_point = global_position
		else:
			aim_point = global_position

	# Face aim direction
	var aim_dir := aim_point - global_position
	aim_dir.y = 0.0
	if aim_dir.length_squared() > 0.001:
		_facing_angle = atan2(aim_dir.x, aim_dir.z)
		var char_model := get_node_or_null("CharacterModel")
		if char_model:
			char_model.rotation.y = _facing_angle

	# Consume ammo and set cooldown
	pistol_ammo -= 1
	_pistol_cooldown = PISTOL_FIRE_RATE
	_sfx_gunshot.play()

	# Muzzle position (in front of character at chest height)
	var muzzle_pos := global_position + Vector3(0, 0.8, 0)
	var forward := Vector3(sin(_facing_angle), 0, cos(_facing_angle))
	muzzle_pos += forward * 0.5

	# Raycast from muzzle in aim direction
	var shoot_dir := Vector3(forward.x, 0, forward.z).normalized()
	var bullet_end := muzzle_pos + shoot_dir * 30.0
	var query := PhysicsRayQueryParameters3D.create(muzzle_pos, bullet_end)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)

	# Determine hit point
	var hit_point: Vector3
	if result:
		hit_point = result.position
	else:
		hit_point = bullet_end

	# Spawn bullet tracer
	_spawn_bullet_tracer(muzzle_pos, hit_point)
	_spawn_muzzle_flash(muzzle_pos)

	# Apply damage if enemy hit
	if result and result.collider.is_in_group("enemy"):
		var enemy: Node3D = result.collider
		if enemy.has_method("take_damage"):
			var is_crit := randf() < crit_chance
			var dmg := PISTOL_DAMAGE * (crit_multiplier if is_crit else 1.0)
			enemy.take_damage(dmg, is_crit)


func _spawn_bullet_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	# Glowing bullet head
	var bullet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	bullet.mesh = sphere
	var bullet_mat := StandardMaterial3D.new()
	bullet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bullet_mat.albedo_color = Color(1.0, 1.0, 0.7, 1.0)
	bullet_mat.emission_enabled = true
	bullet_mat.emission = Color(1.0, 0.9, 0.5)
	bullet_mat.emission_energy_multiplier = 6.0
	bullet.material_override = bullet_mat
	bullet.global_position = from_pos
	get_tree().current_scene.add_child(bullet)

	# Trailing particles that follow the bullet
	var trail := GPUParticles3D.new()
	trail.amount = 20
	trail.lifetime = 0.15
	trail.emitting = true
	var tmat := ParticleProcessMaterial.new()
	tmat.direction = Vector3(0, 0, 0)
	tmat.spread = 5.0
	tmat.initial_velocity_min = 0.3
	tmat.initial_velocity_max = 0.8
	tmat.gravity = Vector3.ZERO
	tmat.scale_min = 0.3
	tmat.scale_max = 0.8
	tmat.color = Color(1.0, 0.6, 0.1, 0.8)
	trail.process_material = tmat
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.03
	tmesh.height = 0.06
	trail.draw_pass_1 = tmesh
	bullet.add_child(trail)

	# Animate bullet to target
	var dist := from_pos.distance_to(to_pos)
	var flight_time := clampf(dist / 20.0, 0.15, 0.5)
	var tween := bullet.create_tween()
	tween.tween_property(bullet, "global_position", to_pos, flight_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		_spawn_impact_sparks(to_pos)
		# Let trail particles finish before removing
		trail.emitting = false
		bullet.visible = false
		get_tree().create_timer(0.3).timeout.connect(bullet.queue_free)
	)

	# Streak line (fading laser trail)
	var streak := MeshInstance3D.new()
	var dir := (to_pos - from_pos).normalized()
	var streak_len := minf(dist, 2.0)
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.02, streak_len)
	streak.mesh = box
	var streak_mat := StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.8)
	streak_mat.emission_enabled = true
	streak_mat.emission = Color(1.0, 0.7, 0.2)
	streak_mat.emission_energy_multiplier = 4.0
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material_override = streak_mat
	var mid := (from_pos + to_pos) / 2.0
	streak.global_position = mid
	streak.look_at(to_pos, Vector3.UP)
	get_tree().current_scene.add_child(streak)
	var streak_tween := streak.create_tween()
	streak_tween.tween_property(streak_mat, "albedo_color:a", 0.0, 0.35)
	streak_tween.tween_callback(streak.queue_free)


func _spawn_muzzle_flash(pos: Vector3) -> void:
	# Particle burst muzzle flash
	var flash := GPUParticles3D.new()
	flash.emitting = true
	flash.one_shot = true
	flash.amount = 15
	flash.lifetime = 0.15
	flash.explosiveness = 1.0
	flash.global_position = pos
	var fmat := ParticleProcessMaterial.new()
	fmat.direction = Vector3(sin(_facing_angle), 0.3, cos(_facing_angle))
	fmat.spread = 25.0
	fmat.initial_velocity_min = 3.0
	fmat.initial_velocity_max = 6.0
	fmat.gravity = Vector3.ZERO
	fmat.damping_min = 10.0
	fmat.damping_max = 15.0
	fmat.scale_min = 0.4
	fmat.scale_max = 1.0
	fmat.color = Color(1.0, 0.8, 0.2, 1.0)
	flash.process_material = fmat
	var fmesh := SphereMesh.new()
	fmesh.radius = 0.04
	fmesh.height = 0.08
	flash.draw_pass_1 = fmesh
	get_tree().current_scene.add_child(flash)

	# Bright core flash sphere
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.12
	core_mesh.height = 0.24
	core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.95, 0.7, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.8, 0.3)
	core_mat.emission_energy_multiplier = 8.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.material_override = core_mat
	core.global_position = pos
	get_tree().current_scene.add_child(core)

	var tween := core.create_tween()
	tween.tween_property(core, "scale", Vector3(2.0, 2.0, 2.0), 0.06)
	tween.parallel().tween_property(core_mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(core.queue_free)

	get_tree().create_timer(0.5).timeout.connect(flash.queue_free)


func _spawn_impact_sparks(pos: Vector3) -> void:
	# Spark shower
	var sparks := GPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 20
	sparks.lifetime = 0.4
	sparks.explosiveness = 0.9
	sparks.global_position = pos
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 3.0
	pmat.initial_velocity_max = 7.0
	pmat.gravity = Vector3(0, -12, 0)
	pmat.scale_min = 0.15
	pmat.scale_max = 0.5
	pmat.color = Color(1.0, 0.7, 0.1, 1.0)
	sparks.process_material = pmat
	var smesh := SphereMesh.new()
	smesh.radius = 0.025
	smesh.height = 0.05
	sparks.draw_pass_1 = smesh
	get_tree().current_scene.add_child(sparks)

	# Smoke puff
	var smoke := GPUParticles3D.new()
	smoke.emitting = true
	smoke.one_shot = true
	smoke.amount = 8
	smoke.lifetime = 0.5
	smoke.explosiveness = 0.8
	smoke.global_position = pos
	var smat := ParticleProcessMaterial.new()
	smat.direction = Vector3(0, 1, 0)
	smat.spread = 40.0
	smat.initial_velocity_min = 0.5
	smat.initial_velocity_max = 1.5
	smat.gravity = Vector3(0, 0.5, 0)
	smat.scale_min = 0.5
	smat.scale_max = 1.5
	smat.color = Color(0.5, 0.5, 0.5, 0.4)
	smoke.process_material = smat
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.06
	smoke_mesh.height = 0.12
	smoke.draw_pass_1 = smoke_mesh
	get_tree().current_scene.add_child(smoke)

	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)
	get_tree().create_timer(1.5).timeout.connect(smoke.queue_free)
