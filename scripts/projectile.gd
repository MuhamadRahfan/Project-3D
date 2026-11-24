class_name Projectile
extends Node3D

enum Kind { ARROW, MAGIC_BOLT, FIREBALL, ENEMY_BOLT }

var active: bool = false
var kind: Kind = Kind.ARROW
var from_player: bool = true
var velocity: Vector3 = Vector3.ZERO
var damage: float = 15.0
var is_crit: bool = false
var lifesteal_ratio: float = 0.0
var pierce_left: int = 0
var aoe_radius: float = 0.0
var life_left: float = 0.0
var hit_radius: float = 0.85

var _hit_ids: Dictionary = {}
var _arrow_visual: Node3D = null
var _orb_mesh: MeshInstance3D = null
var _orb_mat: StandardMaterial3D = null
var _arena_ref: Node = null


func _ready() -> void:
	visible = false
	set_process(false)
	_build_visuals()


func _build_visuals() -> void:
	var arrow_scene := load("res://assets/weapons/arrow_A.gltf") as PackedScene
	if arrow_scene != null:
		_arrow_visual = arrow_scene.instantiate() as Node3D
		_arrow_visual.scale = Vector3(1.25, 1.25, 1.25)
		add_child(_arrow_visual)

	_orb_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	sphere.radial_segments = 10
	sphere.rings = 6
	_orb_mesh.mesh = sphere
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.emission_enabled = true
	_orb_mat.emission_energy_multiplier = 2.0
	_orb_mesh.material_override = _orb_mat
	add_child(_orb_mesh)


func launch(
	arena: Node,
	start_pos: Vector3,
	dir: Vector3,
	p_kind: Kind,
	p_from_player: bool,
	p_speed: float,
	p_damage: float,
	p_is_crit: bool = false,
	p_lifesteal: float = 0.0,
	p_pierce: int = 0,
	p_aoe: float = 0.0
) -> void:
	_arena_ref = arena
	active = true
	kind = p_kind
	from_player = p_from_player
	var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
	if flat_dir.length_squared() < 0.001:
		flat_dir = Vector3.FORWARD
	velocity = flat_dir * p_speed
	damage = p_damage
	is_crit = p_is_crit
	lifesteal_ratio = p_lifesteal
	pierce_left = p_pierce
	aoe_radius = p_aoe
	life_left = 1.65
	_hit_ids.clear()

	global_position = Vector3(start_pos.x, 1.05, start_pos.z)
	look_at(global_position + flat_dir, Vector3.UP)

	if _arrow_visual != null:
		_arrow_visual.visible = (kind == Kind.ARROW)
	if _orb_mesh != null:
		_orb_mesh.visible = (kind != Kind.ARROW)
		match kind:
			Kind.MAGIC_BOLT:
				_orb_mesh.scale = Vector3.ONE
				_orb_mat.albedo_color = Color(0.75, 0.45, 1.0)
				_orb_mat.emission = Color(0.70, 0.35, 1.0)
				hit_radius = 0.85
			Kind.FIREBALL:
				_orb_mesh.scale = Vector3(2.1, 2.1, 2.1)
				_orb_mat.albedo_color = Color(1.0, 0.48, 0.12)
				_orb_mat.emission = Color(1.0, 0.35, 0.05)
				hit_radius = 1.05
			Kind.ENEMY_BOLT:
				_orb_mesh.scale = Vector3(0.95, 0.95, 0.95)
				_orb_mat.albedo_color = Color(0.55, 1.0, 0.42)
				_orb_mat.emission = Color(0.45, 0.95, 0.30)
				hit_radius = 0.72
			_:
				hit_radius = 0.80

	visible = true
	set_process(true)


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active or _arena_ref == null:
		return

	global_position += velocity * delta
	life_left -= delta
	if life_left <= 0.0 or Vector2(global_position.x, global_position.z).length() > GameConfig.ARENA_RADIUS + 2.5:
		if kind == Kind.FIREBALL and aoe_radius > 0.0:
			_explode_fireball()
		deactivate()
		return

	if from_player:
		var enemies: Array = _arena_ref.get_active_enemies()
		for e in enemies:
			if not e.is_targetable():
				continue
			var eid: int = e.get_instance_id()
			if _hit_ids.has(eid):
				continue
			var dx: float = e.global_position.x - global_position.x
			var dz: float = e.global_position.z - global_position.z
			var r: float = hit_radius + e.hit_radius
			if dx * dx + dz * dz <= r * r:
				_hit_ids[eid] = true
				if kind == Kind.FIREBALL and aoe_radius > 0.0:
					_explode_fireball()
					deactivate()
					return
				var kb := velocity.normalized() * 3.8
				var dd := Combat.DamageData.new(damage, is_crit, _arena_ref.player, kb, lifesteal_ratio)
				e.take_damage(dd)
				if pierce_left > 0:
					pierce_left -= 1
				else:
					deactivate()
					return
	else:
		var p: Node3D = _arena_ref.player
		if p != null and p.is_alive():
			var dx: float = p.global_position.x - global_position.x
			var dz: float = p.global_position.z - global_position.z
			var r: float = hit_radius + 0.65
			if dx * dx + dz * dz <= r * r:
				p.take_damage(damage, velocity.normalized() * 3.0)
				deactivate()


func _explode_fireball() -> void:
	AudioManager.play_sfx("explosion", -3.0, 0.1)
	_arena_ref.spawn_burst_ring(global_position, aoe_radius, Color(1.0, 0.45, 0.12, 0.85))
	var enemies: Array = _arena_ref.get_active_enemies()
	var r2: float = aoe_radius * aoe_radius
	for e in enemies:
		if not e.is_targetable():
			continue
		var dx: float = e.global_position.x - global_position.x
		var dz: float = e.global_position.z - global_position.z
		if dx * dx + dz * dz <= r2:
			var push_dir := Vector3(dx, 0.0, dz).normalized()
			var dd := Combat.DamageData.new(damage, is_crit, _arena_ref.player, push_dir * 6.5, lifesteal_ratio)
			e.take_damage(dd)
