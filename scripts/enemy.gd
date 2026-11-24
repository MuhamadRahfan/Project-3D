class_name Enemy
extends CharacterBody3D

signal killed(enemy: Enemy, score_value: int, was_boss: bool)

enum State { INACTIVE, SPAWNING, ACTIVE, TELEGRAPH, RESURRECTING, DYING }

var enemy_type: String = "minion"
var is_elite: bool = false
var is_boss: bool = false
var state: State = State.INACTIVE

var max_hp: float = 34.0
var hp: float = 34.0
var move_speed: float = 3.3
var damage: float = 8.0
var attack_range: float = 1.7
var attack_cd: float = 1.25
var score_value: int = 10
var hit_radius: float = 0.72
var telegraph_duration: float = 0.0

var _has_resurrected: bool = false
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _summon_timer: float = 4.5
var _flash_timer: float = 0.0
var _knockback_vel: Vector3 = Vector3.ZERO
var _flank_sign: float = 1.0
var _current_anim: String = ""

var _arena_ref: Node = null
var _col_shape: CollisionShape3D = null
var _telegraph_ring: MeshInstance3D = null
var _telegraph_mat: StandardMaterial3D = null
var _elite_ring: MeshInstance3D = null
var _flash_mat: StandardMaterial3D = null
var _rig_slots: Dictionary = {}
var _active_slot: Dictionary = {}


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	visible = false
	set_physics_process(false)

	_col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.48
	cap.height = 1.7
	_col_shape.shape = cap
	_col_shape.position = Vector3(0.0, 0.85, 0.0)
	_col_shape.disabled = true
	add_child(_col_shape)

	_flash_mat = Combat.get_flash_material()
	_build_rings()


func _build_rings() -> void:
	_telegraph_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.03
	cyl.radial_segments = 18
	_telegraph_ring.mesh = cyl
	_telegraph_ring.position = Vector3(0.0, 0.04, 0.0)
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.albedo_color = Color(1.0, 0.18, 0.15, 0.45)
	_telegraph_mat.emission_enabled = true
	_telegraph_mat.emission = Color(1.0, 0.15, 0.10)
	_telegraph_mat.emission_energy_multiplier = 1.5
	_telegraph_ring.material_override = _telegraph_mat
	_telegraph_ring.visible = false
	add_child(_telegraph_ring)

	_elite_ring = MeshInstance3D.new()
	var ecyl := CylinderMesh.new()
	ecyl.top_radius = 0.88
	ecyl.bottom_radius = 0.88
	ecyl.height = 0.03
	ecyl.radial_segments = 16
	_elite_ring.mesh = ecyl
	_elite_ring.position = Vector3(0.0, 0.03, 0.0)
	var emat := StandardMaterial3D.new()
	emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emat.albedo_color = Color(0.85, 0.28, 1.0, 0.45)
	emat.emission_enabled = true
	emat.emission = Color(0.82, 0.25, 1.0)
	emat.emission_energy_multiplier = 1.4
	_elite_ring.material_override = emat
	_elite_ring.visible = false
	add_child(_elite_ring)


func _ensure_rig_slot(e_type: String) -> Dictionary:
	var cfg: Dictionary = GameConfig.ENEMIES[e_type]
	var model_path: String = String(cfg["model_path"])
	if _rig_slots.has(model_path):
		return _rig_slots[model_path] as Dictionary

	var anim_path: String = String(cfg["anim_path"])
	var weapon_path: String = String(cfg.get("weapon_r", ""))

	var packed := load(model_path) as PackedScene
	var root := packed.instantiate() as Node3D
	root.visible = false
	add_child(root)

	var anim_player := AnimationPlayer.new()
	anim_player.name = "EnemyAnimPlayer"
	root.add_child(anim_player)
	anim_player.root_node = NodePath("..")
	var lib := load(anim_path) as AnimationLibrary
	if lib != null:
		anim_player.add_animation_library("", lib.duplicate(true))
		_configure_loops(anim_player)

	var skel := _find_skeleton(root)
	if skel != null and weapon_path != "":
		var attach := BoneAttachment3D.new()
		attach.bone_name = "handslot.r"
		skel.add_child(attach)
		var wp := load(weapon_path) as PackedScene
		if wp != null:
			attach.add_child(wp.instantiate())

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)

	var slot := {
		"root": root,
		"anim": anim_player,
		"meshes": meshes,
	}
	_rig_slots[model_path] = slot
	return slot


func _configure_loops(ap: AnimationPlayer) -> void:
	for anim_name: StringName in ap.get_animation_list():
		var s := String(anim_name)
		var anim := ap.get_animation(anim_name)
		if anim == null:
			continue
		if s in ["Idle_A", "Skeletons_Idle", "Skeletons_Walking", "Running_A"]:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE


func spawn(arena: Node, pos: Vector3, p_type: String, hp_mult: float, spd_mult: float, elite: bool = false) -> void:
	_arena_ref = arena
	enemy_type = p_type
	var cfg: Dictionary = GameConfig.ENEMIES[p_type]
	is_boss = bool(cfg.get("is_boss", false))
	is_elite = elite and not is_boss
	_has_resurrected = false

	var base_scale: float = float(cfg.get("scale", 1.0))
	if is_elite:
		base_scale *= 1.18

	max_hp = float(cfg["max_hp"]) * hp_mult * (1.7 if is_elite else 1.0)
	hp = max_hp
	move_speed = float(cfg["move_speed"]) * spd_mult * (1.08 if is_elite else 1.0)
	damage = float(cfg["damage"]) * (1.0 + (hp_mult - 1.0) * 0.45) * (1.25 if is_elite else 1.0)
	attack_range = float(cfg["attack_range"]) * (1.1 if is_elite else 1.0)
	attack_cd = float(cfg["attack_cd"])
	score_value = int(cfg["score"]) * (2 if is_elite else 1)
	telegraph_duration = float(cfg.get("telegraph_time", 0.0))
	hit_radius = 0.72 * base_scale
	_flank_sign = -1.0 if randf() < 0.5 else 1.0
	_attack_timer = randf_range(0.1, 0.4)
	_summon_timer = 4.0
	_knockback_vel = Vector3.ZERO
	_flash_timer = 0.0
	_current_anim = ""

	for slot_v in _rig_slots.values():
		var r: Node3D = (slot_v as Dictionary)["root"]
		r.visible = false

	_active_slot = _ensure_rig_slot(p_type)
	var active_root: Node3D = _active_slot["root"]
	active_root.scale = Vector3.ONE * base_scale
	active_root.visible = true
	_clear_flash()

	global_position = Vector3(pos.x, 0.0, pos.z)
	if _arena_ref != null and _arena_ref.player != null:
		var p: Node3D = _arena_ref.player
		var to_p: Vector3 = p.global_position - global_position
		if to_p.length_squared() > 0.01:
			rotation.y = atan2(to_p.x, to_p.z)

	_telegraph_ring.visible = false
	_elite_ring.visible = is_elite or is_boss
	if is_boss:
		_elite_ring.scale = Vector3(1.8, 1.0, 1.8)
	elif is_elite:
		_elite_ring.scale = Vector3(1.15, 1.0, 1.15)

	state = State.SPAWNING
	_state_timer = 0.85
	_col_shape.set_deferred("disabled", true)
	visible = true
	set_physics_process(true)
	_play_anim("Skeletons_Awaken_Floor", true)


func deactivate() -> void:
	state = State.INACTIVE
	visible = false
	set_physics_process(false)
	_col_shape.set_deferred("disabled", true)
	_telegraph_ring.visible = false
	_elite_ring.visible = false


func is_targetable() -> bool:
	return state == State.ACTIVE or state == State.TELEGRAPH


func _physics_process(delta: float) -> void:
	if state == State.INACTIVE or _arena_ref == null:
		return

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_clear_flash()

	match state:
		State.SPAWNING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = State.ACTIVE
				_col_shape.disabled = false
		State.RESURRECTING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = State.ACTIVE
				_col_shape.disabled = false
		State.DYING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				deactivate()
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.ACTIVE:
			_process_active(delta)


func _process_active(delta: float) -> void:
	var player: Node3D = _arena_ref.player
	if player == null or not player.is_alive():
		_play_anim("Skeletons_Idle")
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	if is_boss:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = 7.0
			_play_anim("Ranged_Magic_Summon", true)
			_arena_ref.boss_summon_minions(global_position)
			_attack_timer = 1.0
			return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player.normalized() if dist > 0.001 else Vector3.FORWARD

	# Smooth rotation toward player
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 9.0))

	var desired_move := Vector3.ZERO
	if enemy_type == "mage" or is_boss:
		if dist > attack_range * 0.85:
			desired_move = dir * move_speed
		elif dist < 4.5:
			desired_move = -dir * (move_speed * 0.65)
	elif enemy_type == "rogue":
		if dist > attack_range * 0.9:
			var side := Vector3(-dir.z, 0.0, dir.x) * _flank_sign
			var flank_dir := (dir + side * (0.55 if dist > 3.2 else 0.1)).normalized()
			desired_move = flank_dir * move_speed
	else:
		if dist > attack_range * 0.85:
			desired_move = dir * move_speed

	if _knockback_vel.length_squared() > 0.05:
		_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 22.0 * delta)
	else:
		_knockback_vel = Vector3.ZERO

	velocity = desired_move + _knockback_vel
	move_and_slide()
	_clamp_inside_arena()

	if desired_move.length_squared() > 0.15:
		_play_anim("Running_A" if enemy_type == "rogue" else "Skeletons_Walking")
	else:
		_play_anim("Skeletons_Idle")

	if dist <= attack_range and _attack_timer <= 0.0:
		_start_attack(dir)


func _start_attack(dir: Vector3) -> void:
	if telegraph_duration > 0.0:
		state = State.TELEGRAPH
		_state_timer = telegraph_duration
		_telegraph_ring.visible = true
		var r: float = attack_range * (1.2 if is_boss else 0.95)
		_telegraph_ring.scale = Vector3(r, 1.0, r)
		_play_anim("Skeletons_Taunt" if enemy_type == "warrior" else "Ranged_Magic_Raise", true)
	else:
		_perform_attack(dir)


func _process_telegraph(delta: float) -> void:
	_state_timer -= delta
	var progress: float = 1.0 - clampf(_state_timer / maxf(telegraph_duration, 0.01), 0.0, 1.0)
	_telegraph_mat.albedo_color.a = 0.25 + progress * 0.55
	if _state_timer <= 0.0:
		_telegraph_ring.visible = false
		state = State.ACTIVE
		var player: Node3D = _arena_ref.player
		if player != null and player.is_alive():
			var to_p := (player.global_position - global_position)
			to_p.y = 0.0
			_perform_attack(to_p.normalized())


func _perform_attack(dir: Vector3) -> void:
	_attack_timer = attack_cd
	var player: Node3D = _arena_ref.player
	if player == null or not player.is_alive():
		return

	if is_boss:
		_play_anim("Ranged_Magic_Spellcasting", true)
		for angle_deg in [-18.0, 0.0, 18.0]:
			var shot_dir := dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
			_arena_ref.spawn_projectile(
				global_position + shot_dir * 0.9,
				shot_dir,
				Projectile.Kind.ENEMY_BOLT,
				false,
				11.0,
				damage
			)
	elif enemy_type == "mage":
		_play_anim("Ranged_Magic_Shoot", true)
		_arena_ref.spawn_projectile(
			global_position + dir * 0.8,
			dir,
			Projectile.Kind.ENEMY_BOLT,
			false,
			10.0,
			damage
		)
	else:
		if enemy_type == "rogue":
			_play_anim("Melee_Dualwield_Attack_Slice", true)
		else:
			_play_anim("Melee_1H_Attack_Chop", true)
		var to_p := player.global_position - global_position
		to_p.y = 0.0
		if to_p.length() <= attack_range + 0.65:
			player.take_damage(damage, to_p.normalized() * 4.5)
		if enemy_type == "rogue":
			_knockback_vel = -dir * 6.5
			_play_anim("Dodge_Backward", true)


func take_damage(data: Combat.DamageData) -> void:
	if not is_targetable():
		return

	hp -= data.amount
	_flash_timer = 0.09
	_apply_flash()
	_knockback_vel += data.knockback * (0.35 if is_boss else 1.0)
	AudioManager.play_sfx("hit", -6.0, 0.12)

	var dmg_col := Color(1.0, 0.84, 0.18) if data.is_crit else Color(1.0, 0.96, 0.92)
	_arena_ref.spawn_damage_number(global_position, data.amount, dmg_col, data.is_crit)

	if data.source != null and data.lifesteal_ratio > 0.0 and data.source.has_method("heal"):
		data.source.heal(data.amount * data.lifesteal_ratio)

	if is_boss:
		_arena_ref.notify_boss_hp(maxf(0.0, hp), max_hp, true)

	if hp <= 0.0:
		if is_elite and not _has_resurrected:
			_has_resurrected = true
			state = State.RESURRECTING
			_state_timer = 1.05
			hp = max_hp * 0.65
			_telegraph_ring.visible = false
			_col_shape.set_deferred("disabled", true)
			_play_anim("Skeletons_Death_Resurrect", true)
			AudioManager.play_sfx("spawn", -4.0, 0.08)
		else:
			_die()


func _die() -> void:
	state = State.DYING
	_state_timer = 0.90
	_telegraph_ring.visible = false
	_elite_ring.visible = false
	_col_shape.set_deferred("disabled", true)
	_play_anim("Skeletons_Death", true)
	AudioManager.play_sfx("enemy_die", -5.0, 0.1)
	if is_boss:
		_arena_ref.notify_boss_hp(0.0, max_hp, false)
	killed.emit(self, score_value, is_boss)


func _clamp_inside_arena() -> void:
	var r := Vector2(global_position.x, global_position.z).length()
	var limit: float = GameConfig.ARENA_RADIUS - 0.6
	if r > limit:
		var n := Vector2(global_position.x, global_position.z).normalized() * limit
		global_position.x = n.x
		global_position.z = n.y


func _play_anim(anim_name: String, force: bool = false) -> void:
	if _active_slot.is_empty():
		return
	var ap: AnimationPlayer = _active_slot["anim"]
	if not ap.has_animation(anim_name):
		return
	if not force and _current_anim == anim_name and ap.is_playing():
		return
	_current_anim = anim_name
	ap.play(anim_name, 0.12)


func _apply_flash() -> void:
	if _active_slot.is_empty():
		return
	for m: MeshInstance3D in _active_slot["meshes"]:
		m.material_override = _flash_mat


func _clear_flash() -> void:
	if _active_slot.is_empty():
		return
	for m: MeshInstance3D in _active_slot["meshes"]:
		m.material_override = null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find_skeleton(c)
		if f != null:
			return f
	return null


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)
