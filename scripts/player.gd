class_name Player
extends CharacterBody3D

signal hp_changed(current_hp: float, max_hp: float)
signal weapon_changed(weapon_name: String)
signal died

var hero_id: String = "Knight"
var max_hp: float = 150.0
var hp: float = 150.0
var move_speed: float = 5.8
var base_damage: float = 26.0
var base_attack_cd: float = 0.62
var base_attack_range: float = 2.9
var attack_speed_mult: float = 1.0
var armor: float = 3.0
var crit_chance: float = 0.10
var lifesteal_ratio: float = 0.0
var pickup_radius: float = 3.2
var projectile_count: int = 1
var dodge_cd: float = 2.0
var skill_cd: float = 5.5

var weapon_id: String = "sword_A"
var weapon_type: String = "melee"
var weapon_dmg_mult: float = 1.0
var weapon_spd_mult: float = 1.0
var weapon_range_bonus: float = 0.0

var move_input: Vector2 = Vector2.ZERO

var _arena_ref: Node = null
var _hero_root: Node3D = null
var _anim_player: AnimationPlayer = null
var _hand_r_attach: BoneAttachment3D = null
var _hand_l_attach: BoneAttachment3D = null
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D = null
var _col_shape: CollisionShape3D = null

var _attack_timer: float = 0.0
var _dodge_timer: float = 0.0
var _skill_timer: float = 0.0
var _iframe_timer: float = 0.0
var _flash_timer: float = 0.0
var _action_lock_timer: float = 0.0
var _dash_vel: Vector3 = Vector3.ZERO
var _dash_is_charge: bool = false
var _charge_hit_ids: Dictionary = {}
var _is_dead: bool = false
var _current_anim: String = ""


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	_flash_mat = Combat.get_flash_material()

	_col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.65
	_col_shape.shape = cap
	_col_shape.position = Vector3(0.0, 0.82, 0.0)
	add_child(_col_shape)


func setup_hero(arena: Node, p_hero_id: String) -> void:
	_arena_ref = arena
	hero_id = p_hero_id
	var cfg: Dictionary = GameConfig.HEROES.get(hero_id, GameConfig.HEROES["Knight"])

	max_hp = float(cfg["max_hp"])
	hp = max_hp
	move_speed = float(cfg["move_speed"])
	base_damage = float(cfg["damage"])
	base_attack_cd = float(cfg["attack_cd"])
	base_attack_range = float(cfg["attack_range"])
	attack_speed_mult = 1.0
	armor = float(cfg["armor"])
	crit_chance = float(cfg["crit_chance"])
	lifesteal_ratio = 0.0
	pickup_radius = 3.2
	projectile_count = 1
	dodge_cd = float(cfg["dodge_cd"])
	skill_cd = float(cfg["skill_cd"])

	_attack_timer = 0.2
	_dodge_timer = 0.0
	_skill_timer = 0.0
	_iframe_timer = 0.0
	_flash_timer = 0.0
	_action_lock_timer = 0.0
	_dash_vel = Vector3.ZERO
	_dash_is_charge = false
	_is_dead = false
	_current_anim = ""
	_col_shape.disabled = false

	_mount_hero_model(cfg)
	equip_weapon(String(cfg["weapon_id"]))
	hp_changed.emit(hp, max_hp)


func _mount_hero_model(cfg: Dictionary) -> void:
	if _hero_root != null:
		_hero_root.queue_free()
		_hero_root = null
	_meshes.clear()
	_hand_r_attach = null
	_hand_l_attach = null

	var packed := load(String(cfg["model_path"])) as PackedScene
	_hero_root = packed.instantiate() as Node3D
	add_child(_hero_root)

	_anim_player = AnimationPlayer.new()
	_anim_player.name = "HeroAnimPlayer"
	_hero_root.add_child(_anim_player)
	_anim_player.root_node = NodePath("..")
	var lib := load(String(cfg["anim_path"])) as AnimationLibrary
	if lib != null:
		_anim_player.add_animation_library("", lib.duplicate(true))
		_configure_loops(_anim_player)

	var skel := _find_skeleton(_hero_root)
	if skel != null:
		_hand_r_attach = BoneAttachment3D.new()
		_hand_r_attach.bone_name = "handslot.r"
		skel.add_child(_hand_r_attach)

		_hand_l_attach = BoneAttachment3D.new()
		_hand_l_attach.bone_name = "handslot.l"
		skel.add_child(_hand_l_attach)

		var offhand_path: String = String(cfg.get("offhand_path", ""))
		if offhand_path != "":
			var shield_scene := load(offhand_path) as PackedScene
			if shield_scene != null:
				_hand_l_attach.add_child(shield_scene.instantiate())

	_collect_meshes(_hero_root, _meshes)
	_play_anim("Idle_A", true)


func _configure_loops(ap: AnimationPlayer) -> void:
	for anim_name: StringName in ap.get_animation_list():
		var s := String(anim_name)
		var anim := ap.get_animation(anim_name)
		if anim == null:
			continue
		if s in ["Idle_A", "Idle_B", "Running_A", "Running_B", "Running_HoldingBow"]:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE


func equip_weapon(new_weapon_id: String) -> void:
	if not GameConfig.WEAPONS.has(new_weapon_id):
		return
	weapon_id = new_weapon_id
	var w: Dictionary = GameConfig.WEAPONS[new_weapon_id]
	weapon_type = String(w["weapon_type"])
	weapon_dmg_mult = float(w["damage_mult"])
	weapon_spd_mult = float(w["speed_mult"])
	weapon_range_bonus = float(w["range_bonus"])

	# Keep shield in left hand unless equipping a 2H bow in handslot.l
	var hand: String = String(w.get("hand", "r"))
	if hand == "l":
		_clear_children(_hand_l_attach)
		_clear_children(_hand_r_attach)
	else:
		_clear_children(_hand_r_attach)
		var hero_cfg: Dictionary = GameConfig.HEROES.get(hero_id, {})
		var offhand_path: String = String(hero_cfg.get("offhand_path", ""))
		if offhand_path != "" and _hand_l_attach != null and _hand_l_attach.get_child_count() == 0:
			var shield_scene := load(offhand_path) as PackedScene
			if shield_scene != null:
				_hand_l_attach.add_child(shield_scene.instantiate())

	var w_scene := load(String(w["model_path"])) as PackedScene
	if w_scene != null:
		var target_attach := _hand_l_attach if hand == "l" else _hand_r_attach
		if target_attach != null:
			target_attach.add_child(w_scene.instantiate())

	weapon_changed.emit(String(w["name"]))


func is_alive() -> bool:
	return not _is_dead and hp > 0.0


func get_dodge_cooldown_ratio() -> float:
	return clampf(_dodge_timer / maxf(dodge_cd, 0.01), 0.0, 1.0)


func get_skill_cooldown_ratio() -> float:
	return clampf(_skill_timer / maxf(skill_cd, 0.01), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _is_dead or _arena_ref == null:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_skill_timer = maxf(0.0, _skill_timer - delta)
	_iframe_timer = maxf(0.0, _iframe_timer - delta)
	_action_lock_timer = maxf(0.0, _action_lock_timer - delta)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_clear_flash()

	# Keyboard quick triggers for testing
	if Input.is_action_just_pressed("ui_accept"):
		trigger_dodge()

	if _dash_vel.length_squared() > 0.2:
		velocity = _dash_vel
		move_and_slide()
		_clamp_inside_arena()
		if _dash_is_charge:
			_check_shield_charge_hits()
		_dash_vel = _dash_vel.move_toward(Vector3.ZERO, 36.0 * delta)
		if _dash_vel.length_squared() <= 0.2:
			_dash_is_charge = false
		return

	var move_dir := Vector3(move_input.x, 0.0, move_input.y)
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	velocity = move_dir * move_speed
	move_and_slide()
	_clamp_inside_arena()

	var target: Enemy = _find_nearest_enemy()
	var effective_range := _get_effective_range()

	if target != null and target.global_position.distance_to(global_position) <= effective_range:
		var aim_dir := (target.global_position - global_position)
		aim_dir.y = 0.0
		if aim_dir.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(aim_dir.x, aim_dir.z), minf(1.0, delta * 14.0))
		if _attack_timer <= 0.0 and _action_lock_timer <= 0.0:
			_perform_auto_attack(aim_dir.normalized())
	elif move_dir.length_squared() > 0.02:
		rotation.y = lerp_angle(rotation.y, atan2(move_dir.x, move_dir.z), minf(1.0, delta * 12.0))

	if _action_lock_timer <= 0.0:
		if move_dir.length_squared() > 0.04:
			_play_anim("Running_HoldingBow" if weapon_type == "bow" else "Running_A")
		else:
			_play_anim("Idle_A")


func _get_effective_range() -> float:
	if weapon_type == "melee":
		return maxf(2.7, base_attack_range if hero_id == "Knight" else 3.2) + weapon_range_bonus
	return maxf(11.5, base_attack_range) + weapon_range_bonus


func _perform_auto_attack(aim_dir: Vector3) -> void:
	var cd := base_attack_cd / (attack_speed_mult * weapon_spd_mult)
	_attack_timer = maxf(0.18, cd)
	_action_lock_timer = 0.22

	var calc := Combat.compute_damage(base_damage * weapon_dmg_mult, crit_chance, 0.0)
	var dmg: float = float(calc["amount"])
	var is_crit: bool = bool(calc["is_crit"])

	if weapon_type == "melee":
		_play_anim("Melee_1H_Attack_Slice_Horizontal", true)
		AudioManager.play_sfx("swing", -5.0, 0.1)
		var cleave_r := _get_effective_range() + 0.55
		_arena_ref.spawn_burst_ring(global_position + aim_dir * 1.1, cleave_r * 0.65, Color(0.85, 0.92, 1.0, 0.5))
		var enemies: Array = _arena_ref.get_active_enemies()
		for e in enemies:
			if not e.is_targetable():
				continue
			var to_e: Vector3 = e.global_position - global_position
			to_e.y = 0.0
			var d := to_e.length()
			if d <= cleave_r + e.hit_radius:
				var dot := aim_dir.dot(to_e.normalized()) if d > 0.1 else 1.0
				if dot > 0.15 or d < 1.65:
					var dd := Combat.DamageData.new(dmg, is_crit, self, to_e.normalized() * 5.2, lifesteal_ratio)
					e.take_damage(dd)
		# Multishot/Echo bonus for melee: fires arcane slash waves!
		if projectile_count > 1:
			for i in range(projectile_count - 1):
				var spread := (i - (projectile_count - 2) * 0.5) * 0.22
				var sdir := aim_dir.rotated(Vector3.UP, spread)
				_arena_ref.spawn_projectile(
					global_position + sdir * 0.8, sdir, Projectile.Kind.MAGIC_BOLT, true, 14.0, dmg * 0.65, is_crit, lifesteal_ratio
				)
	elif weapon_type == "bow":
		_play_anim("Ranged_Bow_Release", true)
		AudioManager.play_sfx("bow", -5.0, 0.1)
		_fire_spread(aim_dir, Projectile.Kind.ARROW, 20.0, dmg, is_crit, 0)
	else:
		_play_anim("Ranged_Magic_Shoot", true)
		AudioManager.play_sfx("magic", -5.0, 0.1)
		_fire_spread(aim_dir, Projectile.Kind.MAGIC_BOLT, 15.5, dmg, is_crit, 0)


func _fire_spread(dir: Vector3, kind: Projectile.Kind, speed: float, dmg: float, is_crit: bool, pierce: int) -> void:
	var count := maxi(1, projectile_count)
	var step := 0.16
	for i in count:
		var offset := (float(i) - float(count - 1) * 0.5) * step
		var sdir := dir.rotated(Vector3.UP, offset)
		_arena_ref.spawn_projectile(
			global_position + sdir * 0.8,
			sdir,
			kind,
			true,
			speed,
			dmg,
			is_crit,
			lifesteal_ratio,
			pierce
		)


func trigger_dodge() -> void:
	if _is_dead or get_tree().paused or _dodge_timer > 0.0:
		return
	_dodge_timer = dodge_cd
	_iframe_timer = 0.44
	_action_lock_timer = 0.30
	_dash_is_charge = false

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length_squared() < 0.04:
		dir = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	else:
		dir = dir.normalized()
		rotation.y = atan2(dir.x, dir.z)

	_dash_vel = dir * 16.5
	_play_anim("Dodge_Forward", true)
	AudioManager.play_sfx("dodge", -4.0, 0.08)


func trigger_skill() -> void:
	if _is_dead or get_tree().paused or _skill_timer > 0.0 or _arena_ref == null:
		return
	_skill_timer = skill_cd
	_action_lock_timer = 0.38

	var target := _find_nearest_enemy()
	var dir := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	if target != null:
		var to_t := target.global_position - global_position
		to_t.y = 0.0
		if to_t.length_squared() > 0.01:
			dir = to_t.normalized()
			rotation.y = atan2(dir.x, dir.z)

	match hero_id:
		"Knight":
			_iframe_timer = 0.48
			_dash_is_charge = true
			_charge_hit_ids.clear()
			_dash_vel = dir * 19.5
			_play_anim("Melee_Block_Attack", true)
			AudioManager.play_sfx("shield", -3.0, 0.06)
			_arena_ref.spawn_burst_ring(global_position, 2.4, Color(0.4, 0.8, 1.0, 0.7))
		"Ranger":
			_play_anim("Ranged_Bow_Release_Up", true)
			AudioManager.play_sfx("bow", -3.0, 0.08)
			var volley_count := 7 + (projectile_count - 1) * 2
			var dmg := base_damage * weapon_dmg_mult * 1.35
			for i in volley_count:
				var angle := (float(i) - float(volley_count - 1) * 0.5) * 0.13
				var sdir := dir.rotated(Vector3.UP, angle)
				_arena_ref.spawn_projectile(
					global_position + sdir * 0.8,
					sdir,
					Projectile.Kind.ARROW,
					true,
					22.0,
					dmg,
					true,
					lifesteal_ratio,
					2
				)
		"Mage":
			_play_anim("Ranged_Magic_Spellcasting", true)
			AudioManager.play_sfx("magic", -2.0, 0.06)
			var fb_dmg := base_damage * weapon_dmg_mult * 2.7
			_arena_ref.spawn_projectile(
				global_position + dir * 0.9,
				dir,
				Projectile.Kind.FIREBALL,
				true,
				14.0,
				fb_dmg,
				true,
				lifesteal_ratio,
				0,
				4.4
			)


func _check_shield_charge_hits() -> void:
	var dmg := base_damage * weapon_dmg_mult * 2.3
	var enemies: Array = _arena_ref.get_active_enemies()
	for e_v in enemies:
		var e := e_v as Enemy
		if e == null or not e.is_targetable():
			continue
		var eid: int = e.get_instance_id()
		if _charge_hit_ids.has(eid):
			continue
		var diff: Vector3 = e.global_position - global_position
		diff.y = 0.0
		if diff.length() <= 1.85 + e.hit_radius:
			_charge_hit_ids[eid] = true
			var dd := Combat.DamageData.new(dmg, true, self, diff.normalized() * 11.0, lifesteal_ratio)
			e.take_damage(dd)
			AudioManager.play_sfx("hit", -3.0, 0.08)


func take_damage(raw_amount: float, _knockback: Vector3 = Vector3.ZERO) -> void:
	if _is_dead or _iframe_timer > 0.0:
		return

	_iframe_timer = 0.35
	var dmg := maxf(1.0, raw_amount - armor)
	hp = maxf(0.0, hp - dmg)
	_flash_timer = 0.12
	_apply_flash()
	AudioManager.play_sfx("hurt", -3.0, 0.08)
	if _arena_ref != null:
		_arena_ref.spawn_damage_number(global_position, dmg, Color(1.0, 0.28, 0.28), false, "-")
	hp_changed.emit(hp, max_hp)

	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	var prev_hp := hp
	hp = minf(max_hp, hp + amount)
	var gained := hp - prev_hp
	if gained >= 1.0 and _arena_ref != null:
		_arena_ref.spawn_damage_number(global_position, gained, Color(0.32, 0.96, 0.45), false, "+")
	hp_changed.emit(hp, max_hp)


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			base_damage *= 1.20
		"attack_speed":
			attack_speed_mult *= 1.15
		"move_speed":
			move_speed *= 1.12
		"max_hp":
			max_hp += 30.0
			hp = minf(max_hp, hp + 30.0)
			hp_changed.emit(hp, max_hp)
		"pickup_radius":
			pickup_radius *= 1.45
		"dodge_cd":
			dodge_cd = maxf(0.7, dodge_cd * 0.80)
		"projectile_count":
			projectile_count += 1
		"crit_chance":
			crit_chance = minf(0.85, crit_chance + 0.12)
		"lifesteal":
			lifesteal_ratio = minf(0.35, lifesteal_ratio + 0.05)
		"armor":
			armor += 4.0


func _die() -> void:
	_is_dead = true
	_col_shape.set_deferred("disabled", true)
	_play_anim("Death_A", true)
	AudioManager.play_sfx("game_over", -2.0, 0.0)
	var t := get_tree().create_timer(0.95)
	t.timeout.connect(func(): died.emit())


func _find_nearest_enemy() -> Enemy:
	if _arena_ref == null:
		return null
	var best: Enemy = null
	var best_d2 := INF
	var enemies: Array = _arena_ref.get_active_enemies()
	for e_v in enemies:
		var e := e_v as Enemy
		if e == null or not e.is_targetable():
			continue
		var dx := e.global_position.x - global_position.x
		var dz := e.global_position.z - global_position.z
		var d2 := dx * dx + dz * dz
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


func _clamp_inside_arena() -> void:
	var pos2 := Vector2(global_position.x, global_position.z)
	var limit: float = GameConfig.ARENA_RADIUS - 0.8
	if pos2.length() > limit:
		pos2 = pos2.normalized() * limit
		global_position.x = pos2.x
		global_position.z = pos2.y


func _play_anim(anim_name: String, force: bool = false) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	if not force and _current_anim == anim_name and _anim_player.is_playing():
		return
	_current_anim = anim_name
	_anim_player.play(anim_name, 0.12)


func _apply_flash() -> void:
	for m in _meshes:
		m.material_override = _flash_mat


func _clear_flash() -> void:
	for m in _meshes:
		m.material_override = null


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for ch in node.get_children():
		ch.queue_free()


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
