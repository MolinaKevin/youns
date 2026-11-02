# Ports y adapters en combate

`features/combat/scene/` usa un patrón de `*_port.gd` (contrato con métodos
no-op) + `*_adapter.gd` o `*.gd` sin sufijo (implementación real que extiende
el puerto). El puerto solo se justifica si algo necesita sustituir la
implementación real por otra — en este proyecto, casi siempre un doble de
test. Si nadie sustituye nada, el puerto es ceremonia: dos archivos con las
mismas firmas, uno vacío, que hay que mantener sincronizados a mano.

## Criterio

Antes de crear un `_port.gd` nuevo, o de "completar" un par que te parezca
que le falta el puerto, verificar si alguno de estos dos casos aplica:

1. **Hay una clase que extiende el puerto directamente** en
   `tests/helpers/combat_test_case.gd` o en los `tests/helpers/mock_combat_*.gd`
   (`class Mock... extends Combat...Port`).
2. **Se instancia el puerto "en blanco" a propósito**, como no-op deliberado,
   en algún test o mock (ej. `MockPresentation._init()` en
   `combat_test_case.gd` hace `patterns = CombatMapPatternPort.new()` sin
   subclasificarlo — ahí el puerto vacío *es* el doble de test).

Si ninguno de los dos aplica: **no separar en dos archivos**. Un solo
archivo con `class_name` + `extends RefCounted`, con la implementación real
adentro, alcanza. Si en el futuro aparece una necesidad real de sustituirlo
(un mock nuevo), ahí sí se extrae el puerto — no antes.

Para verificar rápido si un puerto todavía se usa como contrato real:

```
grep -rn "extends Combat...Port" tests/
grep -rn "Combat...Port\.new(" --include="*.gd" .
```

Si ambos no devuelven nada fuera del propio archivo del puerto, es candidato
a colapsar.

## Puertos que SÍ deben seguir separados (tienen un segundo uso real)

Verificado en nov. 2026 — no colapsar estos sin revisar antes
`tests/helpers/combat_test_case.gd` y `tests/helpers/mock_combat_*.gd`:

- `CombatMapLineOfSightPort`, `CombatMapActorQueriesPort`,
  `CombatMapAreaQueriesPort` (mocks en `combat_test_case.gd`)
- `CombatMapPlacementPort` (mock en `combat_test_case.gd`)
- `CombatMapEffectsPort` (mock en `mock_combat_effects.gd`)
- `CombatMapTerrainPort`, `CombatMapTerrainGeometryPort`,
  `CombatMapTerrainCollisionPort`, `CombatMapTerrainNavigationPort`,
  `CombatMapMovementPort` (mocks en `mock_combat_navigation.gd`)
- `CombatMapPushPort` (mock en `mock_combat_push.gd`)
- `CombatMapSelectionPort`, `CombatMapSelectionTargetingPort`,
  `CombatMapSelectionActionsPort` (mocks en `mock_combat_selection.gd`)
- `CombatMapObstaclePort` (mock en `mock_combat_obstacles.gd`)
- `CombatEnemyBoardPort` (mock en `mock_enemy_board.gd`)
- `CombatMapPatternPort`, `CombatMapTargetingPresentationPort`,
  `CombatMapOverlayPort`, `CombatMapCombatPreviewPort`,
  `CombatMapOverwatchPort` (instanciados en blanco por
  `MockPresentation._init()` en `combat_test_case.gd`)
- `CombatMapTargetingHoverPort` (nunca lo sobreescribe `MockPresentation` —
  queda en blanco a propósito — y `combat_targeting.gd` llama sus métodos en
  producción; colapsarlo haría que un `_init()` sin `source` real explote)

`CombatMapPuddleVisualPort` queda separado por consistencia con sus hermanos
de la lista de arriba (misma familia "Presentation" de `CombatMapPresentation`),
aunque hoy ningún mock lo sobreescribe en blanco.

## Estado (nov. 2026)

Se revisaron y colapsaron todos los pares sin segundo uso real: Tree/Rock/
Module, la familia completa de Actor (Geometry/Targets/Configuration/State/
Presentation/Movement/el contenedor), Terrain Bounds/Spatial/Mutation,
Queries (contenedor), Presentation (contenedor) y la familia Targeting
(Overlay/Range/Path/ActorHighlights). Lo que queda como `_port.gd` en
`features/combat/scene/` es exactamente la lista de arriba — ya no hay pares
"ceremoniales" sin verificar.
