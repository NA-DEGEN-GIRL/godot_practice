extends Node3D

const BOLT_HEIGHT := 10.0
const BOLT_SEGMENTS := 12
const BOLT_SPREAD := 0.5


func _ready() -> void:
	# Glow bolt (wider, transparent)
	add_child(_create_bolt(BOLT_SEGMENTS, BOLT_HEIGHT, BOLT_SPREAD, 0.15,
		Color(0.4, 0.6, 1.0, 0.3), 2.0))

	# Main bolt (thin, bright)
	add_child(_create_bolt(BOLT_SEGMENTS, BOLT_HEIGHT, BOLT_SPREAD, 0.05,
		Color(0.85, 0.95, 1.0, 0.95), 4.0))

	# Branch bolt
	var branch := _create_bolt(5, 3.0, 0.3, 0.03,
		Color(0.6, 0.8, 1.0, 0.5), 2.0)
	branch.position = Vector3(randf_range(-0.2, 0.2), randf_range(3.0, 6.0), randf_range(-0.2, 0.2))
	var side := 1.0 if randf() > 0.5 else -1.0
	branch.rotation.z = randf_range(0.3, 0.7) * side
	add_child(branch)

	# Animate
	var tween := create_tween()
	tween.tween_property($Flash, "light_energy", 2.0, 0.04)
	tween.tween_property($Flash, "light_energy", 6.0, 0.04)
	for child in get_children():
		if child is MeshInstance3D:
			tween.parallel().tween_property(child, "transparency", 1.0, 0.25)
	tween.parallel().tween_property($Flash, "light_energy", 0.0, 0.25)
	tween.tween_callback(queue_free)


func _create_bolt(segments: int, height: float, spread: float, width: float,
		color: Color, emission_energy: float) -> MeshInstance3D:
	var points := _zigzag_points(segments, height, spread)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _build_cross_ribbon(points, width)
	mesh_inst.material_override = _bolt_material(color, emission_energy)
	return mesh_inst


func _zigzag_points(segments: int, height: float, spread: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var offset := Vector2.ZERO
	for i in segments + 1:
		var t := float(i) / segments
		var y := height * (1.0 - t)
		if i == 0 or i == segments:
			offset = Vector2.ZERO
		else:
			offset += Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
			offset *= 0.8
		points.append(Vector3(offset.x, y, offset.y))
	return points


func _build_cross_ribbon(points: PackedVector3Array, width: float) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	# X-axis ribbon
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in points:
		im.surface_add_vertex(Vector3(p.x - width, p.y, p.z))
		im.surface_add_vertex(Vector3(p.x + width, p.y, p.z))
	im.surface_end()
	# Z-axis ribbon (perpendicular, so bolt looks good from any angle)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in points:
		im.surface_add_vertex(Vector3(p.x, p.y, p.z - width))
		im.surface_add_vertex(Vector3(p.x, p.y, p.z + width))
	im.surface_end()
	return im


func _bolt_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = emission_energy
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	return mat
