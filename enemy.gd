extends CharacterBody3D

@export var max_hp: float = 100.0
@export var move_speed: float = 2.5
@export var detect_range: float = 8.0
@export var stop_range: float = 1.5
@export var attack_range: float = 3.0
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 2.5
@export var gravity: float = 9.8

var current_hp: float
var is_alive: bool = true
var _target: Node3D
var _attack_timer: float = 0.0

@onready var _hp_bar: Node3D = $HPBar
@onready var _hp_fill: MeshInstance3D = $HPBar/Fill
@onready var _anim_player: AnimationPlayer = $EnemyModel/AnimationPlayer
@onready var _model: Node3D = $EnemyModel
var _hp_label: Label3D
var _sfx_poison: AudioStreamPlayer


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	_create_hp_label()
	_update_hp_bar()
	_sfx_poison = AudioStreamPlayer.new()
	_sfx_poison.stream = preload("res://sounds/poison_spit.wav")
	_sfx_poison.volume_db = -5.0
	add_child(_sfx_poison)


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

	# Find player
	_target = _find_player()
	var is_moving := false
	var is_attacking := false

	if _target and _target.has_method("take_damage"):
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		var dist := to_target.length()
		var dir := to_target.normalized()

		if dist < detect_range:
			# Always face player when detected
			if dir.length_squared() > 0.001:
				_model.look_at(global_position - dir, Vector3.UP)

			if dist <= attack_range:
				# In attack range - stop and spit poison
				velocity.x = 0.0
				velocity.z = 0.0
				is_attacking = true
				if _attack_timer <= 0.0:
					_spit_poison(_target)
					_attack_timer = attack_cooldown
			elif dist > stop_range:
				# Chase
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				is_moving = true
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# Animation control
	if _anim_player:
		if is_moving and not _anim_player.is_playing():
			var anims := _anim_player.get_animation_list()
			if anims.size() > 0:
				_anim_player.play(anims[0])
		elif not is_moving and _anim_player.is_playing():
			_anim_player.stop()

	# HP bar face camera
	var camera := get_viewport().get_camera_3d()
	if camera and _hp_bar:
		_hp_bar.global_rotation = camera.global_rotation


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


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


func _spit_poison(target: Node3D) -> void:
	_sfx_poison.play()
	var start_pos := global_position + Vector3(0, 1.2, 0)
	var end_pos := target.global_position + Vector3(0, 1.0, 0)

	# Poison ball (green glowing sphere)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	ball.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 0.0)
	mat.emission_energy_multiplier = 2.0
	ball.material_override = mat
	ball.global_position = start_pos
	get_tree().current_scene.add_child(ball)

	# Trail particles
	var particles := GPUParticles3D.new()
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 0.3
	pmat.initial_velocity_max = 0.8
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.3
	pmat.scale_max = 0.6
	pmat.color = Color(0.3, 1.0, 0.1, 0.7)
	particles.process_material = pmat
	particles.amount = 8
	particles.lifetime = 0.4
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.04
	pmesh.height = 0.08
	particles.draw_pass_1 = pmesh
	ball.add_child(particles)

	# Animate ball flying to the predicted position (dodgeable!)
	var flight_time := 0.5
	var hit_radius := 0.8  # must be within this distance to get hit
	var tween := ball.create_tween()
	# Arc trajectory toward where the player IS NOW (not tracking)
	var mid := (start_pos + end_pos) / 2.0 + Vector3(0, 1.0, 0)
	tween.tween_method(func(t: float):
		var p1 := start_pos.lerp(mid, t)
		var p2 := mid.lerp(end_pos, t)
		ball.global_position = p1.lerp(p2, t)
	, 0.0, 1.0, flight_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.tween_callback(func():
		var impact_pos := end_pos
		# Only deal damage if player is still near the impact point
		if is_instance_valid(target):
			var dist_to_impact := target.global_position.distance_to(Vector3(impact_pos.x, target.global_position.y, impact_pos.z))
			if dist_to_impact <= hit_radius and target.has_method("take_damage"):
				target.take_damage(attack_damage)
		_spawn_poison_splash(impact_pos)
		ball.queue_free()
	)


func _spawn_poison_splash(pos: Vector3) -> void:
	var splash := GPUParticles3D.new()
	splash.emitting = true
	splash.one_shot = true
	splash.amount = 16
	splash.lifetime = 0.6
	splash.global_position = pos
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 2.5
	pmat.gravity = Vector3(0, -5, 0)
	pmat.scale_min = 0.4
	pmat.scale_max = 0.8
	pmat.color = Color(0.2, 0.9, 0.0, 0.8)
	splash.process_material = pmat
	var smesh := SphereMesh.new()
	smesh.radius = 0.05
	smesh.height = 0.1
	splash.draw_pass_1 = smesh
	get_tree().current_scene.add_child(splash)
	get_tree().create_timer(1.0).timeout.connect(splash.queue_free)


func _die() -> void:
	is_alive = false
	visible = false
	$CollisionShape3D.disabled = true
	get_tree().create_timer(randf_range(1.0, 5.0)).timeout.connect(_respawn)


func _respawn() -> void:
	current_hp = max_hp
	_update_hp_bar()
	global_position = _find_clear_position()
	is_alive = true
	visible = true
	$CollisionShape3D.disabled = false


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
