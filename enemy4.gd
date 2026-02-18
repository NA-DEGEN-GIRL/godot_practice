extends CharacterBody3D

@export var max_hp: float = 180.0
@export var move_speed: float = 1.0
@export var run_speed: float = 5.0
@export var detect_range: float = 3.5
@export var attack_range: float = 1.2
@export var attack_damage: float = 65.0
@export var attack_cooldown: float = 3.5
@export var gravity: float = 9.8

var current_hp: float
var is_alive: bool = true
var _target: Node3D
var _attack_timer: float = 0.0

# Wandering / Sleep cycle
var _wander_target: Vector3
var _wander_timer: float = 0.0
var _wander_wait: float = 0.0
var _is_sleeping: bool = false
var _sleep_timer: float = 0.0
var _awake_timer: float = 0.0

# Animation
var _anim_player: AnimationPlayer
var _model: Node3D
var _anim_walk: String = ""
var _anim_run: String = ""
var _anim_sleep: String = ""
var _anim_attack: String = ""
var _current_anim: String = ""
var _is_attacking_anim: bool = false
var _attack_phase: int = 0  # 0=none, 1=running toward, 2=roll attack

# HP bar
@onready var _hp_bar: Node3D = $HPBar
@onready var _hp_fill: MeshInstance3D = $HPBar/Fill
var _hp_label: Label3D

# Sound
var _sfx_attack: AudioStreamPlayer

# ZZZ
var _zzz_timer: float = 0.0


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	_model = $EnemyModel
	_create_hp_label()
	_update_hp_bar()

	# Find AnimationPlayer
	var anim_players := _model.find_children("*", "AnimationPlayer")
	if anim_players.size() > 0:
		_anim_player = anim_players[0] as AnimationPlayer
		_detect_animations()
		_anim_player.animation_finished.connect(_on_animation_finished)

	# Earthquake attack SFX
	_sfx_attack = AudioStreamPlayer.new()
	_sfx_attack.stream = preload("res://sounds/earthquake_attack.wav")
	_sfx_attack.volume_db = 0.0
	add_child(_sfx_attack)

	# ZZZ (spawned dynamically while sleeping)

	# Start with a short wander before first sleep
	_pick_wander_target()
	_awake_timer = randf_range(3.0, 6.0)


func _detect_animations() -> void:
	var anims := _anim_player.get_animation_list()
	for a in anims:
		var lower := a.to_lower()
		# NOTE: animations are swapped in the GLB -
		# "dodge/roll" is actually sleep, "sleep" is actually attack
		if "roll" in lower or "dodge" in lower:
			_anim_sleep = a   # dodge anim = sleep
		elif "sleep" in lower or "rest" in lower:
			_anim_attack = a  # sleep anim = attack (roll dodge)
		elif "walk" in lower:
			_anim_walk = a
		elif "run" in lower:
			_anim_run = a
	# Fallback
	if _anim_walk == "" and anims.size() > 0:
		_anim_walk = anims[0]
	if _anim_run == "" and _anim_walk != "":
		_anim_run = _anim_walk


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if not is_alive:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_attack_timer -= delta

	# Attack phase: running toward target then roll
	if _attack_phase == 1:
		_do_charge(delta)
		move_and_slide()
		global_position.x = clampf(global_position.x, -9.5, 9.5)
		global_position.z = clampf(global_position.z, -9.5, 9.5)
		_face_camera()
		return

	# Roll attack animation playing
	if _is_attacking_anim:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_face_camera()
		return

	# Find player
	_target = _find_player()

	var player_nearby := false
	if _target and is_instance_valid(_target) and not _target.is_dead:
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		var dist := to_target.length()
		if dist < detect_range:
			player_nearby = true

	if player_nearby:
		# Wake up if sleeping
		if _is_sleeping:
			_wake_up()
		# Attack!
		if _attack_timer <= 0.0:
			_start_attack()
		else:
			# Face player while waiting for cooldown
			var to_target := _target.global_position - global_position
			to_target.y = 0.0
			if to_target.length_squared() > 0.001:
				_face_direction(to_target.normalized())
			velocity.x = 0.0
			velocity.z = 0.0
			_play_anim(_anim_walk)
	else:
		# Lazy cycle: wander <-> sleep
		if _is_sleeping:
			_do_sleep(delta)
		else:
			_awake_timer -= delta
			if _awake_timer <= 0.0:
				_fall_asleep()
			else:
				_do_wander(delta)

	move_and_slide()
	global_position.x = clampf(global_position.x, -9.5, 9.5)
	global_position.z = clampf(global_position.z, -9.5, 9.5)
	_face_camera()


func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		if _wander_wait > 0.0:
			_wander_wait -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _anim_player and _anim_player.is_playing():
				_anim_player.stop()
			return
		_pick_wander_target()

	var diff := _wander_target - global_position
	diff.y = 0.0
	if diff.length() < 0.5:
		_wander_wait = randf_range(1.0, 2.0)
		_wander_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dir := diff.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_direction(dir)
	_play_anim(_anim_walk)


func _fall_asleep() -> void:
	_is_sleeping = true
	_sleep_timer = randf_range(8.0, 15.0)
	_zzz_timer = 0.0
	velocity = Vector3.ZERO
	if _anim_sleep != "":
		_play_anim_force(_anim_sleep)
	else:
		if _anim_player and _anim_player.is_playing():
			_anim_player.stop()


func _do_sleep(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_sleep_timer -= delta
	# Spawn floating zzz every 1.5 seconds
	_zzz_timer -= delta
	if _zzz_timer <= 0.0:
		_zzz_timer = 1.5
		_spawn_zzz()
	# Keep replaying sleep animation
	if _anim_player and _anim_sleep != "" and not _anim_player.is_playing():
		_anim_player.play(_anim_sleep)
	if _sleep_timer <= 0.0:
		_wake_up()


func _spawn_zzz() -> void:
	var label := Label3D.new()
	label.text = "z"
	label.font_size = 32
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.7, 0.7, 1.0, 0.9)
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0.3, 0.7)
	var node := Node3D.new()
	node.global_position = global_position + Vector3(randf_range(0.2, 0.5), 2.2, randf_range(-0.2, 0.2))
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", node.position.y + 1.5, 2.0).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.5)
	tween.parallel().tween_property(node, "position:x", node.position.x + randf_range(-0.3, 0.3), 2.0)
	tween.tween_callback(node.queue_free)


func _wake_up() -> void:
	_is_sleeping = false
	_awake_timer = randf_range(3.0, 5.0)
	_current_anim = ""
	_pick_wander_target()


func _start_attack() -> void:
	_attack_phase = 1  # charge toward player
	_attack_timer = attack_cooldown


func _do_charge(_delta: float) -> void:
	if not _target or not is_instance_valid(_target) or _target.is_dead:
		_attack_phase = 0
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	if dist <= attack_range:
		# Close enough, start roll attack
		_attack_phase = 2
		_is_attacking_anim = true
		velocity = Vector3.ZERO
		_face_direction(to_target.normalized())
		_sfx_attack.pitch_scale = randf_range(0.85, 1.15)
		_sfx_attack.play()
		_spawn_ground_shake()
		if _anim_player and _anim_attack != "":
			_anim_player.stop()
			_anim_player.play(_anim_attack)
			_current_anim = _anim_attack
		return

	var dir := to_target.normalized()
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed
	_face_direction(dir)
	_play_anim(_anim_run)


func _on_animation_finished(anim_name: String) -> void:
	if _is_attacking_anim and _attack_phase == 2:
		_is_attacking_anim = false
		_attack_phase = 0
		# Apply heavy damage if target still in range
		if _target and is_instance_valid(_target) and not _target.is_dead:
			var dist := global_position.distance_to(_target.global_position)
			if dist <= attack_range + 0.5 and _target.has_method("take_damage"):
				_target.take_damage(attack_damage)
		# Go back to lazy cycle
		_awake_timer = randf_range(3.0, 5.0)
		_current_anim = ""


func _spawn_ground_shake() -> void:
	# Visual dust ring on ground
	var dust := GPUParticles3D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 30
	dust.lifetime = 0.8
	dust.explosiveness = 0.9
	dust.global_position = global_position + Vector3(0, 0.1, 0)
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0.3, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 4.0
	pmat.gravity = Vector3(0, -2, 0)
	pmat.scale_min = 0.5
	pmat.scale_max = 1.5
	pmat.color = Color(0.6, 0.5, 0.3, 0.6)
	dust.process_material = pmat
	var dmesh := SphereMesh.new()
	dmesh.radius = 0.06
	dmesh.height = 0.12
	dust.draw_pass_1 = dmesh
	get_tree().current_scene.add_child(dust)
	get_tree().create_timer(1.5).timeout.connect(dust.queue_free)


func _face_direction(dir: Vector3) -> void:
	if _model and dir.length_squared() > 0.001:
		_model.look_at(global_position - dir, Vector3.UP)


func _play_anim(anim_name: String) -> void:
	if not _anim_player or anim_name == "" or _is_attacking_anim:
		return
	if _current_anim != anim_name or not _anim_player.is_playing():
		_anim_player.play(anim_name)
		_current_anim = anim_name
		if anim_name == _anim_run:
			_anim_player.speed_scale = 1.5
		else:
			_anim_player.speed_scale = 1.0


func _play_anim_force(anim_name: String) -> void:
	if not _anim_player or anim_name == "":
		return
	_anim_player.play(anim_name)
	_current_anim = anim_name
	_anim_player.speed_scale = 1.0


func _pick_wander_target() -> void:
	_wander_target = Vector3(randf_range(-8.0, 8.0), 0, randf_range(-8.0, 8.0))
	_wander_timer = randf_range(3.0, 5.0)
	_wander_wait = 0.0


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and _hp_bar:
		_hp_bar.global_rotation = camera.global_rotation


func _create_hp_label() -> void:
	_hp_label = Label3D.new()
	_hp_label.font_size = 16
	_hp_label.pixel_size = 0.005
	_hp_label.position = Vector3(0, 0.12, 0.02)
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.outline_size = 4
	_hp_label.outline_modulate = Color(0, 0, 0, 0.8)
	_hp_label.modulate = Color(1, 1, 1, 0.9)
	_hp_bar.add_child(_hp_label)


func take_damage(amount: float, is_crit: bool = false) -> void:
	if not is_alive:
		return
	current_hp -= amount
	_update_hp_bar()
	_spawn_damage_number(amount, is_crit)
	# Wake up if sleeping
	if _is_sleeping:
		_wake_up()
	if current_hp <= 0.0:
		_die()


func _update_hp_bar() -> void:
	var ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	_hp_fill.scale.x = ratio
	_hp_fill.position.x = (ratio - 1.0) * 0.5
	if _hp_label:
		_hp_label.text = "%d / %d" % [ceili(maxf(current_hp, 0.0)), int(max_hp)]


func _spawn_damage_number(amount: float, is_crit: bool) -> void:
	var node := Node3D.new()
	node.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.5, randf_range(-0.3, 0.3))
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	if is_crit:
		label.text = str(int(amount)) + "!"
		label.font_size = 48
		label.modulate = Color(1.0, 0.2, 0.1, 1.0)
		node.scale = Vector3(1.5, 1.5, 1.5)
	else:
		label.text = str(int(amount))
		label.font_size = 28
		label.modulate = Color(1.0, 0.9, 0.2, 1.0)
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", node.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	if is_crit:
		tween.parallel().tween_property(node, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_callback(node.queue_free)


func _die() -> void:
	is_alive = false
	visible = false
	$CollisionShape3D.disabled = true
	_is_sleeping = false
	_attack_phase = 0
	get_tree().create_timer(randf_range(5.0, 10.0)).timeout.connect(_respawn)


func _respawn() -> void:
	current_hp = max_hp
	_update_hp_bar()
	global_position = _find_clear_position()
	is_alive = true
	visible = true
	$CollisionShape3D.disabled = false
	_is_attacking_anim = false
	_attack_phase = 0
	_is_sleeping = false
	_current_anim = ""
	_awake_timer = randf_range(3.0, 6.0)
	_pick_wander_target()


func _find_clear_position() -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.8
	shape.height = 2.0
	for i in 30:
		var x := randf_range(-8.0, 8.0)
		var z := randf_range(-8.0, 8.0)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 1.0, z))
		query.exclude = [get_rid()]
		query.collision_mask = 0xFFFFFFFF
		var results := space.intersect_shape(query)
		if results.size() <= 1:
			return Vector3(x, 0.0, z)
	return Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
