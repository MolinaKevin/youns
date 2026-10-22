class_name CombatMapQueries
extends RefCounted

## Consultas geométricas puras del tablero. Lee el estado espacial de MapArea,
## pero no lo modifica: LOS, intersecciones y distancias a obstáculos.
var map: Node

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return line_of_sight_clear(from, to, false, true, map._elevation_at(from), map._elevation_at(to))

func line_of_sight_clear(from: Vector2, to: Vector2, block_rocks: bool, block_bridges: bool, from_elevation: int, to_elevation: int) -> bool:
	for obstacle: Dictionary in map.solid_obstacles:
		var obstacle_type: String = obstacle.get("type", "solid")
		if obstacle_type == "rock" and not block_rocks:
			continue
		if obstacle_type == "bridge" and not block_bridges:
			continue
		if obstacle_type == "platform":
			if from_elevation > 0 or to_elevation > 0:
				continue
			if segment_hits_box(from, to, obstacle["pos"], obstacle["box"] * 0.5):
				return false
			continue
		if obstacle.has("box"):
			if segment_hits_box(from, to, obstacle["pos"], obstacle["box"] * 0.5):
				return false
		elif segment_hits_circle(from, to, obstacle["pos"], obstacle["radius"]):
			return false
	return true

func clip_path_at_obstacle(from: Vector2, to: Vector2) -> Vector2:
	var closest_time := 1.0
	for obstacle: Dictionary in map.solid_obstacles:
		if obstacle.get("type", "solid") == "rock":
			continue
		var hit_time := segment_hit_time_box(from, to, obstacle["pos"], obstacle["box"] * 0.5) if obstacle.has("box") else segment_hit_time_circle(from, to, obstacle["pos"], obstacle["radius"])
		if hit_time >= 0.0 and hit_time < closest_time:
			closest_time = hit_time
	return from + (to - from) * maxf(0.0, closest_time - 0.05) if closest_time < 1.0 else to

# ── Consultas de actores y áreas ──────────────────────────────────────────────
static func is_pos_in_zones(pos: Vector2, zones: Array) -> bool:
	for zone in zones:
		if pos.distance_to(zone["pos"]) <= float(zone["radius"]):
			return true
	return false

func actors_gap() -> float:
	return map.player_pos.distance_to(map.enemy_pos) - map._player_shadow_radius - map._enemy_shadow_radius

func is_enemy_in_attack_range(attack_range: float) -> bool:
	return actors_gap() <= attack_range + CombatGrid.CELL * 0.5 and has_line_of_sight(map.player_pos, map.enemy_pos)

func is_enemy_in_melee_range() -> bool:
	return map.player_pos.distance_to(map.enemy_pos) <= 1.5

func is_player_in_melee_range() -> bool:
	return map.enemy_pos.distance_to(map.player_pos) <= 1.5

func player_area_contact_radius() -> float:
	return map._player_shadow_radius * map.AREA_CONTACT_FRACTION

func enemy_area_contact_radius() -> float:
	return map._enemy_shadow_radius * map.AREA_CONTACT_FRACTION

func is_enemy_in_zones(zones: Array) -> bool:
	for zone in zones:
		if map.enemy_pos.distance_to(zone["pos"]) <= float(zone["radius"]) + enemy_area_contact_radius():
			return true
	return false

func is_player_in_zones(zones: Array) -> bool:
	for zone in zones:
		if map.player_pos.distance_to(zone["pos"]) <= float(zone["radius"]) + player_area_contact_radius():
			return true
	return false

func segment_hits_enemy(from: Vector2, to: Vector2) -> bool:
	return segment_point_distance(from, to, map.enemy_pos) <= enemy_area_contact_radius()

func is_enemy_in_cone(origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	var to_enemy: Vector2 = map.enemy_pos - origin
	var distance: float = to_enemy.length()
	var contact_margin: float = enemy_area_contact_radius()
	if distance > cone_range + contact_margin:
		return false
	if distance <= contact_margin:
		return true
	var slack := asin(clampf(contact_margin / distance, 0.0, 1.0))
	return absf(direction.normalized().angle_to(to_enemy)) <= deg_to_rad(half_angle_deg) + slack

func is_enemy_in_area_circle(center: Vector2, radius: float) -> bool:
	return center.distance_to(map.enemy_pos) <= radius + enemy_area_contact_radius()

func is_player_in_area_circle(center: Vector2, radius: float) -> bool:
	return center.distance_to(map.player_pos) <= radius + player_area_contact_radius()

func is_enemy_in_circle(center: Vector2, radius: float) -> bool:
	return center.distance_to(map.enemy_pos) <= radius + map._enemy_shadow_radius

func is_player_in_circle(center: Vector2, radius: float) -> bool:
	return center.distance_to(map.player_pos) <= radius + map._player_shadow_radius

static func obstacle_edge_distance(obstacle: Dictionary, pos: Vector2) -> float:
	var center: Vector2 = obstacle["pos"]
	if obstacle.has("box"):
		var half_size: Vector2 = obstacle["box"] * 0.5
		return Vector2(maxf(absf(pos.x - center.x) - half_size.x, 0.0), maxf(absf(pos.y - center.y) - half_size.y, 0.0)).length()
	return maxf(0.0, pos.distance_to(center) - float(obstacle["radius"]))

static func segment_hits_box(a: Vector2, b: Vector2, center: Vector2, half: Vector2) -> bool:
	return segment_hit_time_box(a, b, center, half) >= 0.0

static func segment_hits_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	return segment_hit_time_circle(a, b, center, radius) >= 0.0

static func segment_hit_time_box(a: Vector2, b: Vector2, center: Vector2, half: Vector2) -> float:
	var delta := b - a
	var minimum := 0.0
	var maximum := 1.0
	for axis in range(2):
		var axis_delta: float = delta[axis]
		var low: float = center[axis] - half[axis] - a[axis]
		var high: float = center[axis] + half[axis] - a[axis]
		if abs(axis_delta) < 0.0001:
			if low > 0.0 or high < 0.0:
				return -1.0
		else:
			var first := low / axis_delta
			var second := high / axis_delta
			if first > second:
				var swap := first
				first = second
				second = swap
			minimum = maxf(minimum, first)
			maximum = minf(maximum, second)
			if minimum > maximum:
				return -1.0
	return minimum

static func segment_hit_time_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> float:
	var delta := b - a
	var offset := a - center
	var quadratic_a := delta.dot(delta)
	if quadratic_a < 0.000001:
		return -1.0
	var quadratic_b := 2.0 * offset.dot(delta)
	var quadratic_c := offset.dot(offset) - radius * radius
	var discriminant := quadratic_b * quadratic_b - 4.0 * quadratic_a * quadratic_c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var first := (-quadratic_b - root) / (2.0 * quadratic_a)
	var second := (-quadratic_b + root) / (2.0 * quadratic_a)
	if first >= 0.0 and first <= 1.0:
		return first
	return second if second >= 0.0 and second <= 1.0 else -1.0

static func segment_point_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	var delta := b - a
	var length_squared := delta.length_squared()
	if length_squared < 0.000001:
		return point.distance_to(a)
	var time := clampf((point - a).dot(delta) / length_squared, 0.0, 1.0)
	return point.distance_to(a + delta * time)

static func first_contact_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> float:
	var delta := b - a
	if a.distance_to(center) < radius:
		return 0.0 if delta.dot(center - a) > 0.0 else -1.0
	return segment_hit_time_circle(a, b, center, radius)
