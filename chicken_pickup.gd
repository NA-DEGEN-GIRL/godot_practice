extends Area3D

const BOB_SPEED := 2.5
const BOB_HEIGHT := 0.12
const HEAL_AMOUNT := 50.0

var _model: Node3D
var _base_y: float
var _time: float = 0.0


func _ready() -> void:
	add_to_group("chicken_pickup")
	collision_layer = 4
	collision_mask = 1

	# 3D chicken drumstick model
	_model = Node3D.new()
	add_child(_model)

	# Meat part (golden sphere)
	var meat := MeshInstance3D.new()
	var meat_mesh := SphereMesh.new()
	meat_mesh.radius = 0.25
	meat_mesh.height = 0.4
	meat.mesh = meat_mesh
	var meat_mat := StandardMaterial3D.new()
	meat_mat.albedo_color = Color(0.85, 0.6, 0.2)
	meat_mat.roughness = 0.6
	meat.material_override = meat_mat
	meat.position = Vector3(0, 0.35, 0)
	_model.add_child(meat)

	# Bone part (white cylinder)
	var bone := MeshInstance3D.new()
	var bone_mesh := CylinderMesh.new()
	bone_mesh.top_radius = 0.04
	bone_mesh.bottom_radius = 0.05
	bone_mesh.height = 0.3
	bone.mesh = bone_mesh
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.95, 0.92, 0.85)
	bone_mat.roughness = 0.4
	bone.material_override = bone_mat
	bone.position = Vector3(0, 0.1, 0)
	_model.add_child(bone)

	# Bone knob
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.06
	knob_mesh.height = 0.1
	knob.mesh = knob_mesh
	knob.material_override = bone_mat
	knob.position = Vector3(0, -0.03, 0)
	_model.add_child(knob)

	# Collision shape for overlap detection
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
	if body.is_in_group("player") and body.has_method("heal_hp"):
		body.heal_hp(HEAL_AMOUNT)
		# Gulp sound
		var sfx := AudioStreamPlayer.new()
		sfx.stream = preload("res://sounds/gulp.wav")
		sfx.bus = "Master"
		get_tree().current_scene.add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
		queue_free()
