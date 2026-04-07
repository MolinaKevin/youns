# Sistema de Movimiento — Youns Combat

## Resumen

El combate ocurre en un mundo 3D de **60×60 unidades** (espacio XZ). Las posiciones son `Vector2` en ese plano. No hay grilla de tiles gameplay — el movimiento es continuo.

---

## Archivos relevantes

| Archivo | Responsabilidad |
|---|---|
| `scenes/combat/map_area.gd` | Mapa 3D: visual, obstáculos, pathfinding, LOS |
| `scenes/combat/combat_player_actions.gd` | Lógica de selección de carta y confirmación de movimiento |
| `scenes/combat/combat.gd` | Orquestador: conecta señales, maneja turno |

---

## Flujo completo de movimiento

1. El jugador selecciona una carta de tipo `move` → `play_card(index)` en `combat_player_actions.gd`
2. Se llama `start_move_selection("hand", index, card.card_range, card.cost, card.name)`
3. `map_area.start_move_selection(move_range)` renderiza el disco de movimiento y guarda `selected_move_range`
4. El jugador hace click en el mapa → `map_area` emite `position_selected(pos: Vector2)`
5. `_on_position_selected(pos)` en `combat_player_actions.gd` valida el destino (ver sección Validación)
6. Si es válido: se muestra el path preview + popup de confirmación
7. El jugador confirma → `_execute_tile_action(cell)` → `map_area.try_move_player_to(pos, range)`
8. Si hay rango restante, se puede seguir moviendo. Si no, se limpia todo.

---

## Visual del disco de movimiento

### Método: `_show_reachable(outer, inner, origin, move_range)`

Para cada tile visual (CELL = **0.08** unidades), se dibuja solo si pasa **tres filtros geométricos**:

```
1. distance(tile_center, origin) <= move_range      → borde circular suave
2. NOT _tile_in_obstacle(tile_center)               → corta el cuerpo del obstáculo
3. has_line_of_sight(origin, tile_center)           → sombra detrás de obstáculos
```

Esto produce un **círculo suave** con recortes limpios donde hay obstáculos, sin artefactos de grilla.

### Dos capas de color

- **`_move_disc`** (azul, y=0.02): tiles fuera del radio `PLAYER_ZONE_RADIUS` (0.6u)
- **`_move_disc_inner`** (azul claro, y=0.022): tiles dentro del círculo del jugador
- **`_player_circle`**: círculo suave (triangle fan) en la posición del jugador, radio 0.6u

### Tiles con relleno + borde

Cada tile visual se renderiza como una `ArrayMesh` con **dos superficies**:
- Superficie 0: quad relleno (inset por BORDER = 0.010)
- Superficie 1: 4 tiras de borde (BORDER de grosor)

Los materiales se guardan en metadata del nodo (`fill_mat`, `bord_mat`).

---

## Validación del destino (antes de mostrar popup)

En `_on_position_selected`, para movimiento se verifican **4 condiciones** en orden:

```gdscript
if player.distance_to(pos) > pending_move_range:       return  # fuera del círculo
if map._tile_in_obstacle(pos):                          return  # dentro de obstáculo
if not map.has_line_of_sight(player, pos):             return  # sin LOS
var cost: float = map.compute_path(player, pos)
if cost > pending_move_range + 0.1:                    return  # path A* muy largo
```

Las primeras tres replican exactamente los filtros del visual. El cuarto es el A* para casos de borde donde hay LOS pero el path real es más largo.

---

## Pathfinding (A*)

### Método: `compute_path(from, to) -> float`

- Grilla de pathfinding: **PATH_CELL = 0.5** unidades
- 8 direcciones (cardinal: costo 1.0, diagonal: costo 1.414) × PATH_CELL
- Heurística octile distance
- Retorna el costo total en unidades mundo y guarda el path en `_last_path`

### Obstáculos bloqueados en pathfinding: `_g_blocked(cell)`

- Círculo: `distance(cell_world, obs.pos) < obs.radius + PATH_CELL*0.5`
- Caja: `abs(cell.x - obs.pos.x) < obs.box.x/2 + PATH_CELL*0.5 AND ...`

---

## Obstáculos

Array `solid_obstacles` en `map_area.gd`. Cada obstáculo es un Dictionary:

```gdscript
# Círculo
{"pos": Vector2(29.5, 29.5), "radius": 2.0}

# Caja (tiene campo "box")
{"pos": Vector2(20.0, 42.0), "radius": 3.0, "box": Vector2(6.0, 6.0)}
# radius se usa como aproximación circular para algunos checks
# box es el tamaño total (no half-size)
```

### Funciones de colisión

| Función | Uso |
|---|---|
| `_tile_in_obstacle(pos)` | Visual disc + validación destino |
| `_g_blocked(cell)` | Pathfinding A* |
| `has_line_of_sight(from, to)` | Visual disc + validación destino |
| `_segment_hits_circle(a,b,c,r)` | LOS círculos |
| `_segment_hits_box(a,b,center,half)` | LOS cajas (half = box/2) |

---

## Path preview

### Método: `show_path_preview(from, to)`

Usa `_last_path` (guardado por `compute_path`). Recorre cada segmento del path A* e interpola tiles visuales (CELL=0.08) a lo largo del camino. Renderiza con los mismos colores de relleno+borde que el disco, en verde (`Color(0.3, 0.95, 0.45, 0.70)`).

Se limpia en: confirmación, cancelación, `clear_pending_move()`.

---

## Hover

`_process` llama `_update_hover` cada frame. Si hay algún disco activo, hace raycast desde la cámara al suelo (y=0) y llama `_show_single_cell` en la posición del mouse. El hover se muestra en blanco semitransparente.

---

## Constantes clave

```gdscript
# map_area.gd
const WORLD_W := 60.0
const WORLD_H := 60.0
const PATH_CELL := 0.5        # resolución del pathfinding
const PLAYER_ZONE_RADIUS := 0.6  # radio del círculo visual bajo el jugador

# en _show_reachable / _build_tile_disc
const VCELL  := 0.08          # tamaño de tile visual
const BORDER := 0.010         # grosor del borde del tile

# combat_player_actions.gd
const MOVE_MODE_RANGE := 3    # rango al usar carta como movimiento en move_mode
```

---

## Posiciones iniciales

```gdscript
var player_pos := Vector2(5.0, 55.0)   # esquina abajo-izquierda
var enemy_pos  := Vector2(55.0, 5.0)   # esquina arriba-derecha
```

Cámara inicial: `Vector3(-10, 35, 78)` mirando a `Vector3(30, 0, 30)` — detrás del jugador apuntando al enemigo.
