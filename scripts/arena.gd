class_name Arena
extends Node3D

signal score_changed(new_score: int)
signal boss_hp_changed(hp: float, max_hp: float, active: bool)
signal player_died(wave_reached: int, final_score: int)

const ENEMY_POOL_SIZE := 42
const PROJECTILE_POOL_SIZE := 64
const LOOT_POOL_SIZE := 24
const RING_POOL_SIZE := 16
const DMG_POOL_SIZE := 28

const TREE_PROPS := [
	"res://assets/nature/CommonTree_1.gltf",
	"res://assets/nature/CommonTree_2.gltf",
	"res://assets/nature/CommonTree_3.gltf",
	"res://assets/nature/DeadTree_1.gltf",
	"res://assets/nature/DeadTree_2.gltf",
	"res://assets/nature/Pine_1.gltf",
	"res://assets/nature/Pine_2.gltf",
	"res://assets/nature/TwistedTree_1.gltf",
]
const ACCENT_PROPS := [
	"res://assets/nature/Rock_Medium_1.gltf",
	"res://assets/nature/Rock_Medium_2.gltf",
	"res://assets/nature/Bush_Common.gltf",
	"res://assets/nature/Fern_1.gltf",
	"res://assets/nature/Mushroom_Common.gltf",
]

var player: Player = null
var wave_manager: WaveManager = null
var camera: Camera3D = null
var score: int = 0

var _enemy_pool: Array[Enemy] = []
var _proj_pool: Array[Projectile] = []
var _loot_pool: Array[LootDrop] = []
var _ring_pool: Array[Dictionary] = []
var _dmg_pool: Array[Dictionary] = []

var _cam_offset := Vector3(0.0, 14.5, 11.5)
var _cam_shake: float = 0.0
var _props_root: Node3D = null


func _ready() -> void:
	_build_environment()
	_build_ground_and_scenery()
	_init_pools()

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.died.connect(_on_player_died)

	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	wave_manager.setup(self)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.09, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.48, 0.44)
	env.ambient_light_energy = 0.78
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.14, 0.13)
	env.fog_density = 0.016
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 32.0, 0.0)
	sun.light_color = Color(0.88, 0.94, 0.90)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 44.0
	camera.position = _cam_offset
	camera.look_at(Vector3.ZERO, Vector3.UP)
	add_child(camera)


func _build_ground_and_scenery() -> void:
	# Main forest clearing floor
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = GameConfig.ARENA_RADIUS + 14.0
	disc.bottom_radius = GameConfig.ARENA_RADIUS + 14.0
	disc.height = 0.4
	disc.radial_segments = 36
	ground.mesh = disc
	ground.position = Vector3(0.0, -0.2, 0.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.15, 0.23, 0.17)
	gmat.roughness = 0.95
	ground.material_override = gmat
	add_child(ground)

	# Playable boundary ring marker
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = GameConfig.ARENA_RADIUS - 0.18
	torus.outer_radius = GameConfig.ARENA_RADIUS + 0.18
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.03, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.32, 0.48, 0.36, 0.7)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rmat
	add_child(ring)

	_props_root = Node3D.new()
	_props_root.name = "NaturePerimeter"
	add_child(_props_root)

	# Perimeter trees (32 props outside arena radius)
	var prop_scenes: Array[PackedScene] = []
	for p in TREE_PROPS:
		var sc := load(p) as PackedScene
		if sc != null:
			prop_scenes.append(sc)
	var accent_scenes: Array[PackedScene] = []
	for p in ACCENT_PROPS:
		var sc := load(p) as PackedScene
		if sc != null:
			accent_scenes.append(sc)

	if not prop_scenes.is_empty():
		for i in 30:
			var angle := (float(i) / 30.0) * TAU + randf_range(-0.08, 0.08)
			var dist := GameConfig.ARENA_RADIUS + randf_range(1.6, 7.5)
			var inst := prop_scenes[i % prop_scenes.size()].instantiate() as Node3D
			inst.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			inst.rotation.y = randf() * TAU
			var s := randf_range(0.85, 1.35)
			inst.scale = Vector3.ONE * s
			_props_root.add_child(inst)

	if not accent_scenes.is_empty():
		for i in 22:
			var angle := randf() * TAU
			var dist := GameConfig.ARENA_RADIUS + randf_range(0.6, 5.0)
			var inst := accent_scenes[i % accent_scenes.size()].instantiate() as Node3D
			inst.position = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			inst.rotation.y = randf() * TAU
			inst.scale = Vector3.ONE * randf_range(0.8, 1.3)
			_props_root.add_child(inst)

	_build_grass_multimesh()


func _build_grass_multimesh() -> void:
	var grass_scene := load("res://assets/nature/Grass_Common_Tall.gltf") as PackedScene
	if grass_scene == null:
		return
	var temp := grass_scene.instantiate()
	var mi := _find_first_mesh_instance(temp)
	if mi == null or mi.mesh == null:
		temp.free()
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mi.mesh
	var count := 120
	mm.instance_count = count
	for i in count:
		var angle := randf() * TAU
		var dist := sqrt(randf()) * (GameConfig.ARENA_RADIUS + 2.0)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var basis := Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(0.65, 1.1))
		mm.set_instance_transform(i, Transform3D(basis, pos))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	temp.free()


func _init_pools() -> void:
	for i in ENEMY_POOL_SIZE:
		var e := Enemy.new()
		add_child(e)
		e.killed.connect(_on_enemy_killed)
		_enemy_pool.append(e)

	for i in PROJECTILE_POOL_SIZE:
		var p := Projectile.new()
		add_child(p)
		_proj_pool.append(p)

	for i in LOOT_POOL_SIZE:
		var l := LootDrop.new()
		add_child(l)
		_loot_pool.append(l)

	for i in RING_POOL_SIZE:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.height = 0.04
		cyl.radial_segments = 18
		mi.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 1.8
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_ring_pool.append({"mesh": mi, "mat": mat, "timer": 0.0, "max_r": 1.0, "active": false})

	for i in DMG_POOL_SIZE:
		var lbl := Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.render_priority = 12
		lbl.font_size = 48
		lbl.outline_size = 12
		lbl.pixel_size = 0.012
		lbl.visible = false
		add_child(lbl)
		_dmg_pool.append({"label": lbl, "timer": 0.0, "vel_y": 1.9, "base_scale": 1.0, "color": Color.WHITE, "active": false})


func start_run(hero_id: String) -> void:
	reset_run()
	player.global_position = Vector3.ZERO
	player.setup_hero(self, hero_id)
	camera.position = _cam_offset
	camera.look_at(Vector3.ZERO, Vector3.UP)
	score = 0
	score_changed.emit(score)
	boss_hp_changed.emit(0.0, 1.0, false)
	wave_manager.start_wave(1)


func reset_run() -> void:
	wave_manager.stop()
	for e in _enemy_pool:
		e.deactivate()
	for p in _proj_pool:
		p.deactivate()
	for l in _loot_pool:
		l.deactivate()
	for r in _ring_pool:
		r["active"] = false
		(r["mesh"] as MeshInstance3D).visible = false
	for d in _dmg_pool:
		d["active"] = false
		(d["label"] as Label3D).visible = false


func _process(delta: float) -> void:
	if player != null and camera != null:
		var target_pos := player.global_position + _cam_offset
		if _cam_shake > 0.0:
			_cam_shake = maxf(0.0, _cam_shake - delta * 3.5)
			target_pos += Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * _cam_shake * 0.35
		camera.position = camera.position.lerp(target_pos, minf(1.0, delta * 8.0))
		camera.look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

	for r in _ring_pool:
		if not bool(r["active"]):
			continue
		var t: float = float(r["timer"]) + delta * 3.6
		r["timer"] = t
		var mi: MeshInstance3D = r["mesh"]
		var mat: StandardMaterial3D = r["mat"]
		if t >= 1.0:
			r["active"] = false
			mi.visible = false
		else:
			var sc: float = lerpf(0.35, float(r["max_r"]), t)
			mi.scale = Vector3(sc, 1.0, sc)
			mat.albedo_color.a = (1.0 - t) * 0.65

	for d in _dmg_pool:
		if not bool(d["active"]):
			continue
		var t: float = float(d["timer"]) + delta * 1.55
		d["timer"] = t
		var lbl: Label3D = d["label"]
		if t >= 1.0:
			d["active"] = false
			lbl.visible = false
		else:
			lbl.position.y += float(d["vel_y"]) * delta * (1.0 - t * 0.5)
			var alpha: float = clampf(1.0 - maxf(0.0, t - 0.35) / 0.65, 0.0, 1.0)
			var col: Color = d["color"]
			lbl.modulate = Color(col.r, col.g, col.b, alpha)
			lbl.outline_modulate = Color(0.05, 0.05, 0.06, alpha)
			var pop: float = float(d["base_scale"]) * (1.18 - t * 0.25)
			lbl.scale = Vector3.ONE * pop


func spawn_enemy_at_edge(e_type: String, hp_mult: float, spd_mult: float, elite: bool) -> void:
	var angle := randf() * TAU
	var dist := randf_range(13.0, GameConfig.ARENA_RADIUS - 1.5)
	var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	if player != null and pos.distance_to(player.global_position) < 7.5:
		pos = -pos.normalized() * dist
	spawn_enemy_at(pos, e_type, hp_mult, spd_mult, elite)


func spawn_enemy_at(pos: Vector3, e_type: String, hp_mult: float, spd_mult: float, elite: bool) -> void:
	for e in _enemy_pool:
		if e.state == Enemy.State.INACTIVE:
			e.spawn(self, pos, e_type, hp_mult, spd_mult, elite)
			if e.is_boss:
				notify_boss_hp(e.hp, e.max_hp, true)
			return


func boss_summon_minions(boss_pos: Vector3) -> void:
	AudioManager.play_sfx("spawn", -4.0, 0.08)
	spawn_burst_ring(boss_pos, 3.2, Color(0.55, 1.0, 0.45, 0.7))
	for i in 2:
		if get_active_enemy_count() >= GameConfig.MAX_ACTIVE_ENEMIES:
			return
		var ang := randf() * TAU
		var offset := Vector3(cos(ang), 0.0, sin(ang)) * 2.6
		var pos := boss_pos + offset
		var p2 := Vector2(pos.x, pos.z)
		if p2.length() > GameConfig.ARENA_RADIUS - 1.2:
			p2 = p2.normalized() * (GameConfig.ARENA_RADIUS - 1.2)
			pos = Vector3(p2.x, 0.0, p2.y)
		spawn_enemy_at(pos, "minion", 1.0 + float(wave_manager.current_wave) * 0.12, 1.1, false)
		wave_manager.on_summoned_minion_added()


func spawn_projectile(
	pos: Vector3,
	dir: Vector3,
	kind: Projectile.Kind,
	from_player: bool,
	speed: float,
	dmg: float,
	is_crit: bool = false,
	lifesteal: float = 0.0,
	pierce: int = 0,
	aoe: float = 0.0
) -> void:
	for p in _proj_pool:
		if not p.active:
			p.launch(self, pos, dir, kind, from_player, speed, dmg, is_crit, lifesteal, pierce, aoe)
			return


func spawn_loot_drop(pos: Vector3, l_type: LootDrop.LootType) -> void:
	for l in _loot_pool:
		if not l.active:
			var w_id := ""
			if l_type == LootDrop.LootType.WEAPON:
				w_id = String(GameConfig.LOOT_WEAPON_IDS[randi() % GameConfig.LOOT_WEAPON_IDS.size()])
			l.spawn_drop(self, pos, l_type, w_id)
			return


func spawn_burst_ring(pos: Vector3, radius: float, color: Color) -> void:
	for r in _ring_pool:
		if not bool(r["active"]):
			r["active"] = true
			r["timer"] = 0.0
			r["max_r"] = radius
			var mi: MeshInstance3D = r["mesh"]
			var mat: StandardMaterial3D = r["mat"]
			mi.position = Vector3(pos.x, 0.06, pos.z)
			mi.scale = Vector3(0.35, 1.0, 0.35)
			mat.albedo_color = color
			mat.emission = Color(color.r, color.g, color.b)
			mi.visible = true
			return


func spawn_damage_number(world_pos: Vector3, amount: float, color: Color, is_crit: bool = false, prefix: String = "") -> void:
	var slot: Dictionary = {}
	for d in _dmg_pool:
		if not bool(d["active"]):
			slot = d
			break
	if slot.is_empty():
		slot = _dmg_pool[0]

	slot["active"] = true
	slot["timer"] = 0.0
	slot["color"] = color
	slot["base_scale"] = 1.38 if is_crit else 1.0
	slot["vel_y"] = 2.4 if is_crit else 1.85

	var lbl: Label3D = slot["label"]
	var val_str := str(maxi(1, roundi(amount)))
	lbl.text = prefix + val_str + ("!" if is_crit else "")
	lbl.position = Vector3(
		world_pos.x + randf_range(-0.35, 0.35),
		world_pos.y + 1.85,
		world_pos.z + randf_range(-0.2, 0.2)
	)
	lbl.modulate = color
	lbl.outline_modulate = Color(0.05, 0.05, 0.06, 1.0)
	lbl.scale = Vector3.ONE * float(slot["base_scale"])
	lbl.visible = true


func get_active_enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for e in _enemy_pool:
		if e.state != Enemy.State.INACTIVE:
			list.append(e)
	return list


func get_active_enemy_count() -> int:
	var c := 0
	for e in _enemy_pool:
		if e.state != Enemy.State.INACTIVE:
			c += 1
	return c


func notify_boss_hp(hp_val: float, max_hp_val: float, active: bool) -> void:
	boss_hp_changed.emit(hp_val, max_hp_val, active)


func _on_enemy_killed(enemy: Enemy, pts: int, was_boss: bool) -> void:
	score += pts
	score_changed.emit(score)
	if was_boss:
		_cam_shake = 0.9
	wave_manager.on_enemy_killed(was_boss, enemy.global_position)


func _on_player_died() -> void:
	wave_manager.stop()
	player_died.emit(wave_manager.current_wave, score)


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for ch in node.get_children():
		var f := _find_first_mesh_instance(ch)
		if f != null:
			return f
	return null
