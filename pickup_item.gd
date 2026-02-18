extends Area3D

const PICKUP_RANGE := 2.5
const BOB_SPEED := 2.0
const BOB_HEIGHT := 0.15

var item_id: String = "pistol"
var _model: Node3D
var _label: Label3D
var _base_y: float
var _time: float = 0.0


func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 0
	collision_mask = 0

	# Load pistol model
	var pistol_scene: PackedScene = preload("res://models/pistol.glb")
	_model = pistol_scene.instantiate()
	_model.scale = Vector3(0.5, 0.5, 0.5)
	add_child(_model)
	PistolMaterial.apply(_model)

	# Floating label (hidden until player is near)
	_label = Label3D.new()
	_label.text = "Click to pick up"
	_label.font_size = 20
	_label.pixel_size = 0.005
	_label.position = Vector3(0, 1.2, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 4
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.modulate = Color(1, 1, 0.5, 0.9)
	_label.visible = false
	add_child(_label)

	# StaticBody3D for raycast click detection
	var click_body := StaticBody3D.new()
	click_body.add_to_group("pickup_body")
	click_body.set_meta("pickup_owner", self)
	var click_col := CollisionShape3D.new()
	var click_shape := BoxShape3D.new()
	click_shape.size = Vector3(0.6, 0.6, 0.6)
	click_col.shape = click_shape
	click_col.position = Vector3(0, 0.3, 0)
	click_body.add_child(click_col)
	add_child(click_body)

	_base_y = position.y


func _process(delta: float) -> void:
	_time += delta
	# Bobbing + slow spin
	position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
	_model.rotation.y += delta * 1.5

	# Show label when player is near
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var dist := global_position.distance_to(players[0].global_position)
		_label.visible = dist < PICKUP_RANGE


func collect() -> void:
	queue_free()
