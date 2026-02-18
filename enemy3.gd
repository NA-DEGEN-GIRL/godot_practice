extends CharacterBody3D

@export var max_hp: float = 100.0
@export var move_speed: float = 1.2
@export var run_speed: float = 3.5
@export var detect_range: float = 7.0
@export var attack_range: float = 1.8
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 2.5
@export var gravity: float = 9.8

var current_hp: float
var is_alive: bool = true
var _target: Node3D
var _attack_timer: float = 0.0

# Wandering
var _wander_target: Vector3
var _wander_timer: float = 0.0
var _wander_wait: float = 0.0

# Animation
var _anim_player: AnimationPlayer
var _model: Node3D
var _anim_walk: String = ""
var _anim_run: String = ""
var _anim_attack: String = ""
var _anim_electrocution: String = ""
var _current_anim: String = ""
var _is_attacking_anim: bool = false

# Stun (electrocution)
var _is_stunned: bool = false
var _stun_timer: float = 0.0
const STUN_DURATION := 3.0

# HP bar
@onready var _hp_bar: Node3D = $HPBar
@onready var _hp_fill: MeshInstance3D = $HPBar/Fill
var _hp_label: Label3D

# Sound
var _sfx_attack: AudioStreamPlayer
var _sfx_electrocution: AudioStreamPlayer


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

	# Attack SFX
	_sfx_attack = AudioStreamPlayer.new()
	_sfx_attack.stream = preload("res://sounds/enemy3_attack.wav")
	_sfx_attack.volume_db = -3.0
	add_child(_sfx_attack)

	# Electrocution SFX
	_sfx_electrocution = AudioStreamPlayer.new()
	_sfx_electrocution.stream = preload("res://sounds/electrocution.wav")
	_sfx_electrocution.volume_db = -2.0
	add_child(_sfx_electrocution)

	# Start wandering
	_pick_wander_target()


func _detect_animations() -> void:
	var anims := _anim_player.get_animation_list()
	for a in anims:
		var lower := a.to_lower()
		if "electrocution" in lower or "electro" in lower or "shock" in lower:
			_anim_electrocution = a
		elif "walk" in lower:
			_anim_walk = a
		elif "run" in lower:
			_anim_run = a
		elif "jab" in lower or "attack" in lower or "punch" in lower:
			_anim_attack = a
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

	# Handle stun
	if _is_stunned:
		_stun_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_face_camera()
		if _stun_timer <= 0.0:
			_is_stunned = false
			_is_attacking_anim = false
			_current_anim = ""
		return

	_attack_timer -= delta

	# Don't move during attack animation
	if _is_attacking_anim:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_face_camera()
		return

	# Find player
	_target = _find_player()

	var state := "wander"

	if _target and is_instance_valid(_target) and not _target.is_dead:
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		var dist := to_target.length()

		if dist < detect_range:
			if dist <= attack_range:
				state = "attack"
			else:
				state = "chase"

	match state:
		"chase":
			_do_chase(delta)
		"attack":
			_do_attack(delta)
		"wander":
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
			_play_anim(_anim_walk)
			if _anim_player and _anim_player.is_playing():
				_anim_player.stop()
			return
		_pick_wander_target()

	var diff := _wander_target - global_position
	diff.y = 0.0
	if diff.length() < 0.5:
		_wander_wait = randf_range(1.0, 3.0)
		_wander_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dir := diff.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_direction(dir)
	_play_anim(_anim_walk)


func _do_chase(_delta: float) -> void:
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dir := to_target.normalized()
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed
	_face_direction(dir)
	_play_anim(_anim_run)


func _do_attack(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.001:
		_face_direction(to_target.normalized())

	if _attack_timer <= 0.0 and _anim_attack != "":
		_attack_timer = attack_cooldown
		_is_attacking_anim = true
		_sfx_attack.pitch_scale = randf_range(0.85, 1.15)
		_sfx_attack.play()
		if _anim_player:
			_anim_player.stop()
			_anim_player.play(_anim_attack)
			_current_anim = _anim_attack


func _on_animation_finished(anim_name: String) -> void:
	if _is_stunned:
		# Keep playing electrocution anim while stunned
		if _anim_electrocution != "" and _stun_timer > 0.0:
			_anim_player.play(_anim_electrocution)
		return
	if _is_attacking_anim:
		_is_attacking_anim = false
		if _target and is_instance_valid(_target) and not _target.is_dead:
			var dist := global_position.distance_to(_target.global_position)
			if dist <= attack_range + 0.3 and _target.has_method("take_damage"):
				_target.take_damage(attack_damage)


func apply_electrocution() -> void:
	if not is_alive:
		return
	_is_stunned = true
	_stun_timer = STUN_DURATION
	_is_attacking_anim = false
	velocity = Vector3.ZERO
	_sfx_electrocution.play()
	# Play electrocution animation
	if _anim_player and _anim_electrocution != "":
		_anim_player.stop()
		_anim_player.play(_anim_electrocution)
		_current_anim = _anim_electrocution
	# Spawn stun text
	_spawn_stun_text()


func _spawn_stun_text() -> void:
	var node := Node3D.new()
	node.global_position = global_position + Vector3(0, 2.8, 0)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.text = "STUNNED!"
	label.font_size = 24
	label.modulate = Color(0.3, 0.7, 1.0, 1.0)
	node.add_child(label)
	get_tree().current_scene.add_child(node)
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", node.position.y + 1.0, STUN_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, STUN_DURATION).set_delay(1.0)
	tween.tween_callback(node.queue_free)


func _face_direction(dir: Vector3) -> void:
	if _model and dir.length_squared() > 0.001:
		_model.look_at(global_position - dir, Vector3.UP)


func _play_anim(anim_name: String) -> void:
	if not _anim_player or anim_name == "" or _is_attacking_anim or _is_stunned:
		return
	if _current_anim != anim_name or not _anim_player.is_playing():
		_anim_player.play(anim_name)
		_current_anim = anim_name
		if anim_name == _anim_run:
			_anim_player.speed_scale = 1.5
		else:
			_anim_player.speed_scale = 1.0


func _pick_wander_target() -> void:
	_wander_target = Vector3(randf_range(-8.0, 8.0), 0, randf_range(-8.0, 8.0))
	_wander_timer = randf_range(3.0, 6.0)
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
	_is_stunned = false
	get_tree().create_timer(randf_range(3.0, 8.0)).timeout.connect(_respawn)


func _respawn() -> void:
	current_hp = max_hp
	_update_hp_bar()
	global_position = _find_clear_position()
	is_alive = true
	visible = true
	$CollisionShape3D.disabled = false
	_is_attacking_anim = false
	_is_stunned = false
	_stun_timer = 0.0
	_current_anim = ""
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
