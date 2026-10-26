# Sistema de movimiento — combate

## Resumen

El tablero de combate ocupa **30 × 30 unidades** en el plano XZ. Las
posiciones lógicas de jugador y enemigo son `Vector2(x, z)`; las vistas 3D se
ubican a partir de ellas.

El movimiento se resuelve sobre una grilla interna de `0.08` unidades
(`CombatGrid.CELL`). Es una implementación de navegación, no una restricción
de diseño: el jugador apunta a posiciones continuas y el destino se ajusta al
centro de la casilla correspondiente.

## Responsabilidades

| Archivo | Responsabilidad |
| --- | --- |
| `features/combat/scene/map_area.gd` | Fachada pública y coordinador del tablero. Conserva posiciones, elevaciones y componentes. |
| `combat_map_movement.gd` | Coordina rutas con estado lógico y waypoints visuales. |
| `combat_navigation.gd` | Calcula alcance, caminos y avance enemigo; no conoce `MapArea` ni vistas 3D. |
| `combat_grid.gd` | Conversión mundo/casilla y Dijkstra en ocho direcciones. |
| `combat_terrain.gd` | Obstáculos, plataformas, rampas, alturas y cachés de ocupación. |
| `combat_map_terrain.gd` | API espacial que usan los demás sistemas. |
| `combat_range_overlay.gd` | Construye las mallas de alcance y camino sobre las alturas del terreno. |
| `combat_map_presentation.gd` | Muestra selección, hover y previsualizaciones en `CombatMapOverlay`. |
| `pending_actions/combat_move_action.gd` | Controla la carta de movimiento, confirmación, rango restante y efectos de zonas. |

## Flujo del jugador

1. `CombatMoveAction.configure()` pide a `CombatMapInteractions` iniciar la
   selección de movimiento.
2. `CombatTargeting` llama a `terrain.reachable_cells(...)`; `CombatNavigation`
   calcula las casillas alcanzables y `presentation` dibuja el alcance.
3. Al hacer clic, `CombatMoveAction.on_tile_selected()` llama
   `CombatMapMovement.plan_player_move(pos)`.
4. La navegación devuelve `""` si hay ruta o uno de estos motivos:

   - `"range"`: el destino está fuera del alcance circular;
   - `"blocked"`: el destino no admite la huella del actor o invade al otro;
   - `"no_path"`: está dentro del círculo pero no existe una ruta válida.

5. Si la ruta es válida se muestra su preview y el usuario confirma.
6. `CombatMapMovement.try_move_player_to()` actualiza la posición y elevación
   lógicas, convierte las esquinas de la ruta en waypoints y sincroniza la
   vista del actor.
7. La acción aplica charcos y trampas cruzados, descuenta el coste recorrido y
   permite seguir moviéndose mientras quede rango.

## Navegación

`CombatNavigation` usa Dijkstra con cola por baldes. Cada paso ortogonal cuesta
`1` y uno diagonal `1.41`; las diagonales no pueden cortar la esquina de un
obstáculo. El alcance se suaviza con `PATH_SLACK` y después se filtra por el
círculo de rango para que el resultado sea visualmente natural.

Para decidir si una celda es transitable se consideran:

- los límites del tablero;
- la elevación actual del actor y plataformas/rampas;
- la huella circular del actor;
- la separación respecto del otro combatiente;
- obstáculos sólidos, rocas, puentes y módulos según sus reglas de terreno.

El resultado de una selección se guarda temporalmente en `CombatNavigation`:
la ruta se usa para el preview y su coste se consume al confirmar. Después de
ejecutar un movimiento se limpia esa ruta planeada.

## Terreno, elevación y obstáculos

`CombatTerrain` es dueño de la geometría lógica. Los biomas declaran
obstáculos mediante la API de `MapArea` (`add_solid`, `add_rock`, `add_tree`,
`add_platform`, etc.). Durante el combate, árboles y módulos los modifican a
través de `map.terrain` para invalidar los cachés correspondientes.

- Una plataforma cambia la elevación a `1` y su altura es `1.5` unidades.
- Las rampas permiten entrar y salir de plataformas.
- Un puente deja pasar por debajo, pero puede bloquear línea de visión.
- Las rocas pueden bloquear desplazamiento sin bloquear necesariamente línea
  de visión, según la acción que consulta el terreno.

La línea de visión es una consulta distinta del camino. Los previews de
trampas y charcos que requieren visión usan `CombatRangeOverlay` junto con
`CombatMapQueries`; el movimiento se decide siempre por navegación.

## Visualización y hover

Las mallas de alcance, camino y patrones se elevan con la altura real del
terreno. `CombatMapPresentation` es el único dueño de los meshes de
`CombatMapOverlay`; los sistemas piden intenciones visuales, no manipulan los
nodes del overlay.

`CombatMapInput` proyecta el mouse contra suelo, plataformas y rampas.
`CombatTargeting` coordina el hover, mientras `CombatMapInteractions` actualiza
los previews de trampas, charcos y overwatch cuando hay una colocación activa.

## Constantes relevantes

```gdscript
# map_area.gd
const WORLD_W := 30.0
const WORLD_H := 30.0

# combat_grid.gd
const CELL := 0.08

# combat_terrain.gd
const PATH_CELL := 0.5  # margen por defecto para consultas de ocupación
const PLATFORM_HEIGHT := 1.5
```

No duplicar estas reglas en cartas o UI. Las acciones deben usar la fachada de
`MapArea` o sus servicios (`terrain`, `movement`, `actors` y `presentation`)
según corresponda.
