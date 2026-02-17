extends Node3D

const DAMAGE_PER_SECOND := 15.0
const FLAME_LENGTH := 4.0
const DAMAGE_TICK := 0.5

var _area: Area3D
var _damage_timer: float = 0.0


func _ready() -> void:
	_setup_particles()
	_setup_damage_area()
	_setup_light()


func _setup_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 64
	particles.lifetime = 0.5
	particles.visibility_aabb = AABB(Vector3(-3, -2, -6), Vector3(6, 4, 6))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 20.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, 1.5, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.4, 0.9),
		Color(1.0, 0.55, 0.1, 0.8),
		Color(0.9, 0.2, 0.0, 0.4),
		Color(0.3, 0.1, 0.0, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	particles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mat.vertex_color_use_as_albedo = true
	quad.material = quad_mat
	particles.draw_pass_1 = quad

	add_child(particles)


func _setup_damage_area() -> void:
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, FLAME_LENGTH)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0, -FLAME_LENGTH / 2.0)
	_area.add_child(col)
	add_child(_area)


func _setup_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.1, 1.0)
	light.light_energy = 3.0
	light.omni_range = 4.0
	light.position = Vector3(0, 0, -1.5)
	add_child(light)


func _physics_process(delta: float) -> void:
	_damage_timer += delta
	if _damage_timer >= DAMAGE_TICK:
		_damage_timer -= DAMAGE_TICK
		for body in _area.get_overlapping_bodies():
			if body.is_in_group("enemy") and body.has_method("take_damage"):
				body.take_damage(DAMAGE_PER_SECOND * DAMAGE_TICK)


func stop() -> void:
	_area.monitoring = false
	set_physics_process(false)
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = false
		elif child is OmniLight3D:
			child.light_energy = 0.0
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(queue_free)
