class_name Combat
extends RefCounted


class DamageData:
	var amount: float = 0.0
	var is_crit: bool = false
	var source: Node3D = null
	var knockback: Vector3 = Vector3.ZERO
	var lifesteal_ratio: float = 0.0

	func _init(dmg: float, crit: bool = false, src: Node3D = null, kb: Vector3 = Vector3.ZERO, ls: float = 0.0) -> void:
		amount = dmg
		is_crit = crit
		source = src
		knockback = kb
		lifesteal_ratio = ls


static func compute_damage(base_dmg: float, crit_chance: float, armor: float = 0.0) -> Dictionary:
	var is_crit := randf() < crit_chance
	var raw := base_dmg * (1.8 if is_crit else 1.0)
	var final_dmg := maxf(1.0, raw - armor)
	return {"amount": final_dmg, "is_crit": is_crit}


static func get_flash_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.92, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.75)
	mat.emission_energy_multiplier = 2.0
	return mat
