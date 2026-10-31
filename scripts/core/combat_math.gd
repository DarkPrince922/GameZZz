class_name CombatMath
extends Node
## Combat and economy maths shared by gameplay, UI and tests.
## Pure static functions only: no scene access, so GUT can test them directly.

const DIFFICULTIES := {
	"easy": {"damage_taken": 0.6, "enemy_hp": 0.85, "shard_mult": 1.15},
	"normal": {"damage_taken": 1.0, "enemy_hp": 1.0, "shard_mult": 1.0},
	"nightmare": {"damage_taken": 1.55, "enemy_hp": 1.3, "shard_mult": 1.4},
}


static func clamp_crit(chance: float) -> float:
	return clampf(chance, 0.0, 1.0)


static func hit_damage(base: float, damage_mult: float, crit: bool,
		crit_multiplier: float = 1.75) -> float:
	var value := maxf(0.0, base) * maxf(0.0, damage_mult)
	if crit:
		value *= crit_multiplier
	return roundf(value * 10.0) / 10.0


static func roll_crit(rng: RandomNumberGenerator, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return rng.randf() < chance


static func combo_step(combo_index: int, steps: Array) -> float:
	if steps.is_empty():
		return 1.0
	var index: int = clampi(combo_index, 0, steps.size() - 1)
	return float(steps[index])


static func upgrade_price(base: int, growth: float, current_level: int) -> int:
	if current_level < 0:
		return base
	return int(round(float(base) * pow(growth, float(current_level))))


static func upgrade_value(base: float, per_level: float, level: int) -> float:
	return base + per_level * float(maxi(0, level))


static func difficulty(name: String) -> Dictionary:
	return DIFFICULTIES.get(name, DIFFICULTIES["normal"])


static func damage_taken(raw: float, difficulty_name: String) -> float:
	return maxf(0.0, raw) * float(difficulty(difficulty_name)["damage_taken"])


static func enemy_health(raw: float, difficulty_name: String) -> float:
	return maxf(1.0, raw * float(difficulty(difficulty_name)["enemy_hp"]))


static func shard_amount(raw: int, difficulty_name: String) -> int:
	return maxi(1, int(round(float(raw) * float(difficulty(difficulty_name)["shard_mult"]))))


static func stars_awarded(cleared: bool, collected_all: bool, no_deaths: bool) -> int:
	if not cleared:
		return 0
	var stars := 1
	if collected_all:
		stars += 1
	if no_deaths:
		stars += 1
	return stars


static func shard_chain_pitch(chain: int) -> float:
	## rising tone for chained pickups, capped so it never becomes a squeal
	return clampf(1.0 + 0.055 * float(maxi(0, mini(chain, 8))), 1.0, 1.45)
