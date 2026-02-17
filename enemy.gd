extends StaticBody3D

@export var max_hp: float = 100.0

var current_hp: float
var is_alive: bool = true

@onready var _hp_bar: Node3D = $HPBar
@onready var _hp_fill: MeshInstance3D = $HPBar/Fill
var _hp_label: Label3D


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	_create_hp_label()
	_update_hp_bar()


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


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and _hp_bar:
		_hp_bar.global_rotation = camera.global_rotation


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
		# Only ground hit (1 result) or nothing = clear spot
		if results.size() <= 1:
			return Vector3(x, 0.0, z)
	return Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
