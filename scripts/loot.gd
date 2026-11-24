class_name LootDrop
extends Node3D

enum LootType { WEAPON, HEAL_ORB }

var active: bool = false
var loot_type: LootType = LootType.HEAL_ORB
var weapon_id: String = ""
var heal_amount: float = 20.0
var life_left: float = 22.0

var _visual_mount: Node3D = null
var _ring_mesh: MeshInstance3D = null
var _ring_mat: StandardMaterial3D = null
var _orb_mesh: MeshInstance3D = null
var _arena_ref: Node = null
var _bob_time: float = 0.0
var _weapon_cache: Dictionary = {}


func _ready() -> void:
	visible = false
	set_process(false)
	_build_base_visuals()


func _build_base_visuals() -> void:
	_visual_mount = Node3D.new()
	_visual_mount.position = Vector3(0.0, 0.75, 0.0)
	add_child(_visual_mount)

	_orb_mesh = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.25
	sph.height = 0.50
	sph.radial_segments = 10
	sph.rings = 6
	_orb_mesh.mesh = sph
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.28, 0.95, 0.45)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.20, 0.90, 0.40)
	orb_mat.emission_energy_multiplier = 1.6
	_orb_mesh.material_override = orb_mat
	_visual_mount.add_child(_orb_mesh)

	_ring_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.72
	cyl.bottom_radius = 0.72
	cyl.height = 0.04
	cyl.radial_segments = 16
	_ring_mesh.mesh = cyl
	_ring_mesh.position = Vector3(0.0, 0.03, 0.0)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(0.3, 0.95, 0.5, 0.45)
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Color(0.3, 0.95, 0.5)
	_ring_mat.emission_energy_multiplier = 1.2
	_ring_mesh.material_override = _ring_mat
	add_child(_ring_mesh)


func spawn_drop(arena: Node, pos: Vector3, p_type: LootType, p_weapon_id: String = "") -> void:
	_arena_ref = arena
	active = true
	loot_type = p_type
	weapon_id = p_weapon_id
	life_left = 22.0
	_bob_time = randf() * TAU

	global_position = Vector3(pos.x, 0.0, pos.z)

	for ch in _visual_mount.get_children():
		if ch != _orb_mesh:
			ch.visible = false

	if loot_type == LootType.HEAL_ORB:
		_orb_mesh.visible = true
		_ring_mat.albedo_color = Color(0.28, 0.95, 0.45, 0.45)
		_ring_mat.emission = Color(0.25, 0.95, 0.45)
	else:
		_orb_mesh.visible = false
		var wdata: Dictionary = GameConfig.WEAPONS.get(weapon_id, {})
		var wcolor: Color = wdata.get("color", Color(1.0, 0.8, 0.3))
		_ring_mat.albedo_color = Color(wcolor.r, wcolor.g, wcolor.b, 0.55)
		_ring_mat.emission = wcolor
		var w_node: Node3D = _get_or_create_weapon_preview(weapon_id, String(wdata.get("model_path", "")))
		if w_node != null:
			w_node.visible = true

	visible = true
	set_process(true)


func _get_or_create_weapon_preview(id: String, path: String) -> Node3D:
	if _weapon_cache.has(id):
		return _weapon_cache[id] as Node3D
	if path == "":
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	inst.scale = Vector3(0.85, 0.85, 0.85)
	inst.rotation = Vector3(0.35, 0.0, 0.25)
	_visual_mount.add_child(inst)
	_weapon_cache[id] = inst
	return inst


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active or _arena_ref == null:
		return

	_bob_time += delta * 3.0
	_visual_mount.rotation.y += delta * 2.2
	_visual_mount.position.y = 0.72 + sin(_bob_time) * 0.14

	life_left -= delta
	if life_left <= 0.0:
		deactivate()
		return

	var player: Node3D = _arena_ref.player
	if player == null or not player.is_alive():
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var magnet_r: float = player.pickup_radius

	if dist < 1.15:
		if loot_type == LootType.HEAL_ORB:
			player.heal(heal_amount)
			AudioManager.play_sfx("pickup", -5.0, 0.1)
		else:
			player.equip_weapon(weapon_id)
			AudioManager.play_sfx("upgrade", -4.0, 0.05)
		deactivate()
		return
	elif dist < magnet_r:
		global_position += to_player.normalized() * 11.5 * delta
