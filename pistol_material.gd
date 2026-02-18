class_name PistolMaterial

static func apply(node: Node3D) -> void:
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.12, 0.12, 0.14)
	barrel_mat.metallic = 0.9
	barrel_mat.roughness = 0.25
	barrel_mat.metallic_specular = 0.9
	barrel_mat.emission_enabled = true
	barrel_mat.emission = Color(0.05, 0.05, 0.08)
	barrel_mat.emission_energy_multiplier = 0.3

	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.35, 0.2, 0.1)
	grip_mat.metallic = 0.0
	grip_mat.roughness = 0.75

	var mesh_list: Array[MeshInstance3D] = []
	_collect_meshes(node, mesh_list)

	# Assign materials: first mesh gets barrel, rest get grip (or alternate)
	for i in mesh_list.size():
		if i == 0:
			mesh_list[i].material_override = barrel_mat
		else:
			mesh_list[i].material_override = grip_mat


static func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		if child.get_child_count() > 0:
			_collect_meshes(child, result)
