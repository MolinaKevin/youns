class_name CombatMapQueriesPort
extends RefCounted

var line_of_sight: CombatMapLineOfSightPort = CombatMapLineOfSightPort.new()
var actors: CombatMapActorQueriesPort = CombatMapActorQueriesPort.new()
var areas: CombatMapAreaQueriesPort = CombatMapAreaQueriesPort.new()

## Seam geométrico mantenido para el adaptador de colisión del terreno.
func clip_path_at_obstacle(_from: Vector2, to: Vector2) -> Vector2: return to

## Contrato de las consultas espaciales que consumen las reglas de combate.
## Las implementaciones reales pueden exponer utilidades extra, pero los
## resolvers sólo deben depender de estas operaciones de lectura.
