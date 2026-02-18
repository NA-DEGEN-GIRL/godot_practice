extends Area3D

const BOB_SPEED := 2.5
const BOB_HEIGHT := 0.12
const AMMO_AMOUNT := 4

var _model: Node3D
var _base_y: float
var _time: float = 0.0


func _ready() -> void:
	add_to_group("ammo_pickup")
	collision_layer = 4
	collision_mask = 1

	_model = Node3D.new()
	add_child(_model)

	# Bullet casing (brass cylinder)
	var casing := MeshInstance3D.new()
	var casing_mesh := CylinderMesh.new()
	casing_mesh.top_radius = 0.06
	casing_mesh.bottom_radius = 0.06
	casing_mesh.height = 0.25
	casing.mesh = casing_mesh
	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.85, 0.7, 0.2)
	brass_mat.metallic = 0.8
	brass_mat.roughness = 0.3
	casing.material_override = brass_mat
	casing.position = Vector3(0, 0.2, 0)
	_model.add_child(casing)

	# Bullet tip (dark cone)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.055
	tip_mesh.height = 0.12
	tip.mesh = tip_mesh
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.55, 0.35, 0.15)
	tip_mat.metallic = 0.6
	tip_mat.roughness = 0.4
	tip.material_override = tip_mat
	tip.position = Vector3(0, 0.385, 0)
	_model.add_child(tip)

	# Second bullet (offset)
	var casing2 := MeshInstance3D.new()
	casing2.mesh = casing_mesh
	casing2.material_override = brass_mat
	casing2.position = Vector3(0.14, 0.2, 0)
	_model.add_child(casing2)
	var tip2 := MeshInstance3D.new()
	tip2.mesh = tip_mesh
	tip2.material_override = tip_mat
	tip2.position = Vector3(0.14, 0.385, 0)
	_model.add_child(tip2)

	# "x4" label
	var label := Label3D.new()
	label.text = "x4"
	label.font_size = 18
	label.pixel_size = 0.005
	label.position = Vector3(0.07, 0.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.modulate = Color(1.0, 0.9, 0.4, 0.9)
	_model.add_child(label)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	col.position = Vector3(0, 0.3, 0)
	add_child(col)

	body_entered.connect(_on_body_entered)
	_base_y = position.y


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
	_model.rotation.y += delta * 1.5


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("add_ammo"):
		if body.has_method("has_pistol") and not body.has_pistol():
			return
		if body.pistol_ammo >= body.PISTOL_MAX_AMMO:
			return
		body.add_ammo(AMMO_AMOUNT)
		# Click/reload sound
		var sfx := AudioStreamPlayer.new()
		sfx.stream = preload("res://sounds/gulp.wav")
		sfx.pitch_scale = 1.8
		sfx.bus = "Master"
		get_tree().current_scene.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
		queue_free()
