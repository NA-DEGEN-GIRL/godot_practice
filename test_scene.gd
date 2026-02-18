extends Node3D

var _pickup_script: GDScript = preload("res://pickup_item.gd")
var _chicken_script: GDScript = preload("res://chicken_pickup.gd")
var _ammo_script: GDScript = preload("res://ammo_pickup.gd")
var _enemy2_scene: PackedScene = preload("res://enemy2.tscn")

const CHICKEN_RESPAWN_TIME := 15.0
const AMMO_RESPAWN_TIME := 12.0
const PISTOL_RESPAWN_TIME := 30.0
const MAX_CHICKENS := 3
const MAX_AMMO_PICKUPS := 2
const INITIAL_ENEMY2_COUNT := 2

var _chicken_timer: float = 0.0
var _ammo_timer: float = 0.0
var _pistol_timer: float = 0.0
var _player: Node = null


func _ready() -> void:
	_player = get_node_or_null("Player")
	_spawn_pistol()
	for i in 2:
		_spawn_chicken()
	for i in INITIAL_ENEMY2_COUNT:
		_spawn_enemy2()


func _process(delta: float) -> void:
	# Chicken respawn
	_chicken_timer += delta
	if _chicken_timer >= CHICKEN_RESPAWN_TIME:
		_chicken_timer = 0.0
		var count := get_tree().get_nodes_in_group("chicken_pickup").size()
		if count < MAX_CHICKENS:
			_spawn_chicken()

	# Pistol / Ammo respawn logic
	if _player and is_instance_valid(_player) and _player.has_method("has_pistol"):
		if _player.has_pistol():
			# Player has pistol -> only spawn ammo pickups
			_ammo_timer += delta
			_pistol_timer = 0.0
			if _ammo_timer >= AMMO_RESPAWN_TIME:
				_ammo_timer = 0.0
				var ammo_count := get_tree().get_nodes_in_group("ammo_pickup").size()
				if ammo_count < MAX_AMMO_PICKUPS:
					_spawn_ammo()
		else:
			# Player trashed pistol -> spawn pistol only (no ammo)
			_pistol_timer += delta
			_ammo_timer = 0.0
			if _pistol_timer >= PISTOL_RESPAWN_TIME:
				_pistol_timer = 0.0
				var pistol_count := get_tree().get_nodes_in_group("pickup").size()
				if pistol_count < 1:
					_spawn_pistol()


func _spawn_pistol() -> void:
	var pickup := Area3D.new()
	pickup.set_script(_pickup_script)
	var x := randf_range(-7.0, 7.0)
	var z := randf_range(-7.0, 7.0)
	pickup.position = Vector3(x, 0.3, z)
	add_child(pickup)


func _spawn_chicken() -> void:
	var chicken := Area3D.new()
	chicken.set_script(_chicken_script)
	var x := randf_range(-7.0, 7.0)
	var z := randf_range(-7.0, 7.0)
	chicken.position = Vector3(x, 0.3, z)
	add_child(chicken)


func _spawn_ammo() -> void:
	var ammo := Area3D.new()
	ammo.set_script(_ammo_script)
	var x := randf_range(-7.0, 7.0)
	var z := randf_range(-7.0, 7.0)
	ammo.position = Vector3(x, 0.3, z)
	add_child(ammo)


func _spawn_enemy2() -> void:
	var enemy := _enemy2_scene.instantiate()
	var x := randf_range(-7.0, 7.0)
	var z := randf_range(-7.0, 7.0)
	enemy.position = Vector3(x, 0, z)
	add_child(enemy)
