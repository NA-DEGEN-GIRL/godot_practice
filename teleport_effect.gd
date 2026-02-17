extends Node3D


func _ready() -> void:
	_setup_particles()
	_setup_light()
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(queue_free)


func _setup_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 32
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.5
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.5, 0.7, 1.0, 0.9),
		Color(0.6, 0.4, 1.0, 0.6),
		Color(0.3, 0.2, 0.8, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	particles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mat.vertex_color_use_as_albedo = true
	quad.material = quad_mat
	particles.draw_pass_1 = quad

	add_child(particles)


func _setup_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.4, 1.0, 1.0)
	light.light_energy = 5.0
	light.omni_range = 4.0
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4)
