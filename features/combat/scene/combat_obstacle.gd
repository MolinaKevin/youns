class_name CombatObstacle
extends RefCounted

## Tipos de obstáculos que puede contener un tablero de combate.
## Las entradas siguen siendo Dictionary para que los biomas sean declarativos,
## pero el tipo se consulta desde este contrato único.
const SOLID := "solid"
const ROCK := "rock"
const TREE := "tree"
const BRIDGE := "bridge"
const PLATFORM := "platform"

const TYPES := [SOLID, ROCK, TREE, BRIDGE, PLATFORM]

static func circle(pos: Vector2, radius: float, obstacle_type: String = SOLID) -> Dictionary:
	return {"pos": pos, "radius": radius, "type": obstacle_type}


static func box(pos: Vector2, size: Vector2, obstacle_type: String = SOLID) -> Dictionary:
	return {"pos": pos, "box": size, "type": obstacle_type}


static func rock(pos: Vector2, radius: float, module: bool = true) -> Dictionary:
	var obstacle := circle(pos, radius, ROCK)
	obstacle["module"] = module
	return obstacle


static func platform(pos: Vector2, size: Vector2, ramps: Array[Dictionary] = []) -> Dictionary:
	var obstacle := box(pos, size, PLATFORM)
	obstacle["ramps"] = ramps.duplicate(true)
	return obstacle


static func type_of(obstacle: Dictionary) -> String:
	return str(obstacle.get("type", SOLID))


static func is_known(obstacle: Dictionary) -> bool:
	return type_of(obstacle) in TYPES


## Campos geométricos compartidos por consultas, movimiento y render. Los
## biomas siguen declarando Dictionaries, pero los consumidores no dependen de
## strings repetidos ni de casts implícitos.
static func position_of(obstacle: Dictionary) -> Vector2:
	return obstacle.get("pos", Vector2.ZERO) as Vector2


static func radius_of(obstacle: Dictionary) -> float:
	return float(obstacle.get("radius", 0.0))


static func box_of(obstacle: Dictionary) -> Vector2:
	return obstacle.get("box", Vector2.ZERO) as Vector2


static func has_box(obstacle: Dictionary) -> bool:
	return obstacle.has("box")
