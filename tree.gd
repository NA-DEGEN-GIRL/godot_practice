extends StaticBody3D

func _ready() -> void:
	# Trunk (brown cylinder)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 1.2
	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0, 0.6, 0)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.28, 0.12)
	trunk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	trunk.material_override = trunk_mat
	add_child(trunk)

	# Canopy (green sphere)
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.9
	canopy_mesh.height = 1.4
	var canopy := MeshInstance3D.new()
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0, 1.7, 0)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.2, 0.55, 0.15)
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	canopy.material_override = canopy_mat
	add_child(canopy)

	# Collision
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 2.0
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	add_child(col)
