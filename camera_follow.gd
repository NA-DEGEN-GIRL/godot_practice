extends Camera3D

@export var follow_speed: float = 5.0
@export var target_path: NodePath = "../Player"

var _offset: Vector3
var _target: Node3D
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0


func _ready() -> void:
	_target = get_node(target_path)
	_offset = global_position
	if _target:
		global_position = _target.global_position + _offset


func shake(duration: float, intensity: float) -> void:
	_shake_duration = duration
	_shake_intensity = intensity
	_shake_time = 0.0


func _process(delta: float) -> void:
	if not _target:
		return
	var desired := _target.global_position + _offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

	if _shake_time < _shake_duration:
		_shake_time += delta
		var decay := 1.0 - (_shake_time / _shake_duration)
		global_position += Vector3(
			randf_range(-1.0, 1.0) * _shake_intensity * decay,
			randf_range(-1.0, 1.0) * _shake_intensity * decay * 0.5,
			randf_range(-1.0, 1.0) * _shake_intensity * decay
		)
