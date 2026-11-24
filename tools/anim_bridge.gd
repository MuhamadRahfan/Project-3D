extends SceneTree

const RIG_DIR: String = "res://assets/rigs/"
const HERO_DIR: String = "res://assets/heroes/"
const ENEMY_DIR: String = "res://assets/enemies/"
const OUT_DIR: String = "res://assets/anim_generated/"

const RIG_FILES: Array[String] = [
	"Rig_Medium_General.glb",
	"Rig_Medium_MovementBasic.glb",
	"Rig_Medium_MovementAdvanced.glb",
	"Rig_Medium_CombatMelee.glb",
	"Rig_Medium_CombatRanged.glb",
	"Rig_Medium_Simulation.glb",
	"Rig_Medium_Special.glb",
	"Rig_Medium_Tools.glb",
]

const TARGET_CHARACTERS: Dictionary = {
	"Knight": HERO_DIR + "Knight.glb",
	"Ranger": HERO_DIR + "Ranger.glb",
	"Mage": HERO_DIR + "Mage.glb",
	"Barbarian": HERO_DIR + "Barbarian.glb",
	"Rogue": HERO_DIR + "Rogue.glb",
	"Rogue_Hooded": HERO_DIR + "Rogue_Hooded.glb",
	"Skeleton_Minion": ENEMY_DIR + "Skeleton_Minion.glb",
	"Skeleton_Warrior": ENEMY_DIR + "Skeleton_Warrior.glb",
	"Skeleton_Rogue": ENEMY_DIR + "Skeleton_Rogue.glb",
	"Skeleton_Mage": ENEMY_DIR + "Skeleton_Mage.glb",
}


func _initialize() -> void:
	print("=== Bonefall Grove: Animation Bridge & Bone Validator ===")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var rig_animations: Dictionary = {}
	var rig_bones_ref := PackedStringArray()
	var total_clips_found := 0

	for rig_file: String in RIG_FILES:
		var rig_path: String = RIG_DIR + rig_file
		var packed := ResourceLoader.load(rig_path) as PackedScene
		if packed == null:
			push_error("Failed to load rig: " + rig_path)
			continue
		var rig_root: Node = packed.instantiate()
		var skel: Skeleton3D = _find_first_skeleton(rig_root)
		var anim_player: AnimationPlayer = _find_first_anim_player(rig_root)

		if skel == null or anim_player == null:
			push_error("Missing Skeleton3D or AnimationPlayer in: " + rig_file)
			rig_root.free()
			continue

		if rig_bones_ref.is_empty():
			rig_bones_ref = _get_bone_names(skel)
			print("\n[REF RIG] %s Skeleton3D path='%s' bones(%d): %s" % [
				rig_file,
				String(rig_root.get_path_to(skel)),
				rig_bones_ref.size(),
				", ".join(rig_bones_ref)
			])

		var lib_list: Array[StringName] = anim_player.get_animation_library_list()
		var rig_anim_count := 0
		var sample_tracks_printed := false
		for lib_name: StringName in lib_list:
			var lib: AnimationLibrary = anim_player.get_animation_library(lib_name)
			for anim_name: StringName in lib.get_animation_list():
				var anim: Animation = lib.get_animation(anim_name)
				var anim_key: String = String(anim_name)
				if not sample_tracks_printed and anim.get_track_count() > 0:
					var samples: Array[String] = []
					for t in mini(3, anim.get_track_count()):
						samples.append(String(anim.track_get_path(t)))
					print("[RIG] %-34s sample tracks (from '%s'): %s" % [
						rig_file, anim_key, ", ".join(samples)
					])
					sample_tracks_printed = true
				if rig_animations.has(anim_key):
					print("[WARN] Duplicate anim '%s' in %s (keeping earlier)" % [anim_key, rig_file])
				else:
					rig_animations[anim_key] = anim.duplicate(true)
					rig_anim_count += 1
					total_clips_found += 1

		print("[RIG] %-34s loaded %d unique clips" % [rig_file, rig_anim_count])
		rig_root.free()

	print("\n[SUMMARY] Total unique animation clips collected: %d" % total_clips_found)

	var all_ok := true
	for char_name_v in TARGET_CHARACTERS.keys():
		var char_name: String = String(char_name_v)
		var char_path: String = String(TARGET_CHARACTERS[char_name])
		var packed := ResourceLoader.load(char_path) as PackedScene
		if packed == null:
			push_error("Failed to load character: " + char_path)
			all_ok = false
			continue

		var char_root: Node = packed.instantiate()
		var skel: Skeleton3D = _find_first_skeleton(char_root)
		if skel == null:
			push_error("No Skeleton3D found in character: " + char_name)
			char_root.free()
			all_ok = false
			continue

		var rel_skel_path: String = String(char_root.get_path_to(skel))
		var target_bones: PackedStringArray = _get_bone_names(skel)
		var missing_from_target: PackedStringArray = _diff_bones(rig_bones_ref, target_bones)
		print("\n[TARGET] %-18s Skeleton3D='%s' bones(%d) missing_vs_rig=%s" % [
			char_name,
			rel_skel_path,
			target_bones.size(),
			"NONE" if missing_from_target.is_empty() else ", ".join(missing_from_target)
		])
		if char_name == "Knight" or char_name == "Skeleton_Warrior":
			print("  -> %s bone order: %s" % [char_name, ", ".join(target_bones)])

		var out_lib := AnimationLibrary.new()
		var unmatched_bones: Dictionary = {}
		var remapped_tracks := 0
		var skipped_tracks := 0

		for anim_key_v in rig_animations.keys():
			var anim_key: String = String(anim_key_v)
			var src_anim := rig_animations[anim_key] as Animation
			var dst_anim := src_anim.duplicate(true) as Animation
			for i in range(dst_anim.get_track_count() - 1, -1, -1):
				var t_path: NodePath = dst_anim.track_get_path(i)
				var bone_sub: String = t_path.get_concatenated_subnames()
				if bone_sub == "":
					skipped_tracks += 1
					dst_anim.remove_track(i)
					continue
				if skel.find_bone(bone_sub) == -1:
					unmatched_bones[bone_sub] = true
					dst_anim.remove_track(i)
					continue
				dst_anim.track_set_path(i, NodePath(rel_skel_path + ":" + bone_sub))
				remapped_tracks += 1
			out_lib.add_animation(anim_key, dst_anim)

		var out_path: String = OUT_DIR + char_name + ".res"
		var err: Error = ResourceSaver.save(out_lib, out_path)
		if err != OK:
			push_error("Failed to save %s (err=%d)" % [out_path, err])
			all_ok = false
		else:
			var verify_lib := ResourceLoader.load(out_path) as AnimationLibrary
			var v_count: int = verify_lib.get_animation_list().size() if verify_lib != null else -1
			print("  -> Saved %s (%d anims, %d remapped tracks, %d non-bone tracks stripped, unmatched_bones=%d)" % [
				out_path, v_count, remapped_tracks, skipped_tracks, unmatched_bones.size()
			])
			if not unmatched_bones.is_empty():
				print("  -> UNMATCHED BONES: %s" % ", ".join(unmatched_bones.keys()))
				all_ok = false

		char_root.free()

	print("\n=== Animation Bridge Complete (all_ok=%s) ===" % str(all_ok))
	quit(0 if all_ok else 1)


func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found != null:
			return found
	return null


func _find_first_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_first_anim_player(child)
		if found != null:
			return found
	return null


func _get_bone_names(skel: Skeleton3D) -> PackedStringArray:
	var names := PackedStringArray()
	for i in skel.get_bone_count():
		names.append(skel.get_bone_name(i))
	return names


func _diff_bones(a: PackedStringArray, b: PackedStringArray) -> PackedStringArray:
	var missing := PackedStringArray()
	for item in a:
		if not b.has(item):
			missing.append(item)
	return missing
