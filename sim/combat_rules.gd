extends RefCounted
## Pure combat math. No nodes, no physics: callers supply distances and states.
## M2 replaces the flat hit chance with exposure (how much of the target is visible)
## and adds material penetration and suppression.

const HEADSHOT_CHANCE := 0.1
const HEADSHOT_MULTIPLIER := 3.0
const CLOSE_RANGE := 10.0
const MOVING_SHOOTER_PENALTY := 0.55
const MOVING_TARGET_PENALTY := 0.85


## Probability (0..1) that a single shot hits.
static func hit_chance(weapon: Dictionary, distance: float, shooter_moving: bool, target_moving: bool) -> float:
	var base: float = float(weapon.get("accuracy", 0.6))
	var effective_range: float = float(weapon.get("range", 50.0))
	var chance: float
	if distance <= CLOSE_RANGE:
		chance = base + (1.0 - base) * 0.5 * (1.0 - distance / CLOSE_RANGE)
	else:
		chance = base * clampf(1.0 - (distance - CLOSE_RANGE) / effective_range, 0.15, 1.0)
	if shooter_moving:
		chance *= MOVING_SHOOTER_PENALTY
	if target_moving:
		chance *= MOVING_TARGET_PENALTY
	return clampf(chance, 0.03, 0.95)


static func roll_damage(weapon: Dictionary) -> float:
	var dmg: float = float(weapon.get("damage", 30.0)) * randf_range(0.8, 1.2)
	if randf() < HEADSHOT_CHANCE:
		dmg *= HEADSHOT_MULTIPLIER
	return dmg
