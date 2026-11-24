extends Node3D

@onready var knight_mount: Node3D = $KnightMount
@onready var skeleton_mount: Node3D = $SkeletonMount
@onready var status_label: Label = $CanvasLayer/StatusLabel


func _ready() -> void:
	var knight_status := _spawn_with_anim(
		"res://assets/heroes/Knight.glb",
		"res://assets/anim_generated/Knight.res",
		knight_mount,
		"Idle_A",
		0.4
	)
	var skel_status := _spawn_with_anim(
		"res://assets/enemies/Skeleton_Warrior.glb",
		"res://assets/anim_generated/Skeleton_Warrior.res",
		skeleton_mount,
		"Skeletons_Idle",
		-0.4
	)
	status_label.text = "%s v%s (Phase 0 Smoke Test)\nKnight: %s\nSkeleton: %s" % [
		GameConfig.GAME_TITLE,
		GameConfig.GAME_VERSION,
		knight_status,
		skel_status,
	]


func _spawn_with_anim(
	model_path: String,
	anim_lib_path: String,
	mount: Node3D,
	preferred_anim: String,
	yaw_rad: float
) -> String:
	var packed := load(model_path) as PackedScene
	if packed == null:
		return "MODEL LOAD ERROR"
	var inst := packed.instantiate()
	inst.rotation.y = yaw_rad
	mount.add_child(inst)

	var lib := load(anim_lib_path) as AnimationLibrary
	if lib == null:
		return "ANIM LIB MISSING"

	var player := AnimationPlayer.new()
	player.name = "BridgeAnimPlayer"
	inst.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", lib)

	var anim_to_play := preferred_anim
	if not player.has_animation(anim_to_play):
		var anims := player.get_animation_list()
		if anims.is_empty():
			return "NO ANIMS"
		anim_to_play = anims[0]

	var anim_res := player.get_animation(anim_to_play)
	if anim_res != null:
		anim_res.loop_mode = Animation.LOOP_LINEAR
	player.play(anim_to_play)
	return "OK (%d clips, playing %s)" % [player.get_animation_list().size(), anim_to_play]
