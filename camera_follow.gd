extends Camera3D

@export var follow_speed: float = 5.0
@export var target_path: NodePath = "../Player"

var _offset: Vector3
var _target: Node3D


func _ready() -> void:
	_target = get_node(target_path)
	_offset = global_position
	if _target:
		global_position = _target.global_position + _offset


func _process(delta: float) -> void:
	if not _target:
		return
	var desired := _target.global_position + _offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
