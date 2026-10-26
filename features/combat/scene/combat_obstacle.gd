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


static func type_of(obstacle: Dictionary) -> String:
	return str(obstacle.get("type", SOLID))


static func is_known(obstacle: Dictionary) -> bool:
	return type_of(obstacle) in TYPES
