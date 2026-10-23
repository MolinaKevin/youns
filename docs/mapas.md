# Mapas del mundo: cómo agregar o modificar uno

Los mapas se modelan en **Blender** y se registran en **Godot**. Todo funciona
por **convención de nombres**: Godot no sabe qué es piso, pared o bosque;
lo deduce del nombre de cada mesh del `.glb`.

## Archivos

| Qué | Dónde |
|---|---|
| Fuente de cada mapa | `blender/<mapa>.blend` (una colección con el nombre del mapa, en coordenadas locales) |
| Mapa exportado | `assets/maps/<zona>/<mapa>.glb` |
| Escena de la zona | `features/world/zones/zone_<id>.tscn` + `zone_<id>.gd` |
| Registro de zonas | `autoload/zone_manager.gd` (`ZONES`) |
| Grilla caminable, paredes invisibles, detección de zona | `features/world/zones/world_boundary.gd`, `world_boundary_grid.gd` |
| Decoración procedural (suelo, árboles, agua) | `features/world/zones/auto_decoration.gd` |
| Capas de colisión | `shared/world_collision_layers.gd` |
| Biblioteca de árboles | `blender/arboles.blend` → `assets/maps/world/arboles.glb` |
| Guías que cubren huecos entre mapas | `blender/world_guides.blend` → `assets/maps/world/auto_fill.glb` |
| Agua | `features/world/water/water.gdshader`, `water.tres` |

## Coordenadas

- Godot global `(x, y, z)` ↔ Blender `(x, -z, y)`.
- En la escena de trabajo de Blender (todos los mapas juntos, para alinear
  uniones) se usa el marco `G(x, z, y) = (x + 130, 20 - z, y)`.
- Cada `.glb` se exporta en coordenadas **locales de la zona**: el origen es el
  `offset` de la zona en `ZoneManager.ZONES`. Desde el marco G se desplaza
  `dx = -(ox + 130)`, `dy = -(20 - oz)`.
- Exportar: solo la selección, +Y arriba, modificadores aplicados
  (`export_yup=True, export_apply=True, use_selection=True`, formato GLB).

## Nombres de los meshes (Blender)

| Nombre | Qué hace en el juego |
|---|---|
| `*Meadow` | Suelo **caminable** de la grilla (navegación, paredes invisibles, detección de zona). Es visual: no tiene colisión propia. |
| `*Path` | Camino **solo visual**. Siempre arriba de un `*Meadow`; si no, ahí hay pared. |
| `*Canyon`, `*ForestFloor` | No caminable (CLEAR). |
| `*Rock` | No caminable aunque esté sobre un `*Meadow` (lo pisa). |
| `<Mapa>Floor-colonly` / `<Mapa>MeadowFloor-colonly` | **Colisión del piso.** Cubre todos los `*Meadow` del mapa, caras hacia arriba. Sin esto el jugador se cae. |
| `*-col` | Mesh visible + colisión trimesh (rampas, rellanos, puentes). |
| `*-colonly` | Solo colisión, invisible. |
| `*Wall-colonly`, `*Rail-colonly` | Paredes invisibles a mano. Necesarias en zonas bajas (playas, fondos de cañón): las paredes automáticas de la grilla solo van de y 0 a 6. |
| `*-camcol-colonly` | Colisión **solo para la cámara** (montañas, acantilados): capa 3, no afecta al jugador. |
| `AutoForest_*` | Guía: genera suelo de bosque + árboles sobre sus triángulos reales (con altura). |
| `AutoGround_*` | Guía: solo suelo de relleno, sin árboles. |
| `NoAutoFill_*` | Guía: ni suelo ni árboles. |
| `NoAutoTrees_*` | Guía: suelo sí, árboles no. |
| `AutoWater_*` | Guía: superficie de agua con `water.tres`. |
| `Warp*` | Marcador (empty) donde la zona pone un warp. |

Las guías `Auto*`/`NoAuto*` se borran de la zona al cargarla (`AutoDecoration.remove_guides`)
y solo afectan la decoración: no cambian la grilla.

### Capas de colisión

`WorldCollisionLayers.configure_ground_colliders` pasa a la capa **GROUND (2)**
todo StaticBody3D cuyo nombre (o el de un padre) contiene `floor`, `ground`,
`meadow`, `path`, `ramp`, `rellano`, `descanso` o `bridge`, y les activa
`backface_collision`. El resto queda en **OBSTACLES (1)**. El jugador usa
`ACTOR_WORLD_MASK` (1 | 2). `camcol` → **CAMERA_TERRAIN (3, valor 4)**.

## Reglas que ya causaron bugs

1. **Las praderas tienen que solaparse en las uniones**, también entre mapas
   distintos. Una franja de 1–3 m sin `*Meadow` es una pared invisible en el
   medio del paso. Si hace falta, agregar un `<Mapa>EnlaceMeadow` que tape el
   hueco (y sumar ese polígono al `Floor-colonly`).
2. **El `Floor-colonly` tiene que cubrir todo lo caminable** y tener las caras
   hacia arriba. Revisar normales antes de exportar.
   **En las uniones los pisos tienen que estar a la misma altura** (diferencia
   menor a ~10 cm). Los pisos chocan de los dos lados (`backface_collision`),
   así que un borde 30 cm más alto que el piso vecino es una pared invisible
   (pasó con `Hub2LeftMeadow` contra la pradera norte y `Hub2Meadow`).
3. **No usar cajas `Floor` en los `.tscn`**: se salen del mapa y tapan cañones.
   Única excepción: `zone_hub.tscn`, porque `city_map.glb` no trae piso completo.
4. Las zonas bajas (playa, fondo de cañón) necesitan sus propias
   `*Wall-colonly` / `*Rail-colonly`.
5. Las rampas: tramos cortos (≈13°) en zigzag con descansos, con `-col`, y
   barandas `*Rail-colonly`.
6. Nada de piezas flotando: suelos y guías no deben quedar sobre el vacío de
   un precipicio.

## Pasos para un mapa nuevo

### Blender
1. Crear la colección `<mapa>` y modelarla al lado de los mapas vecinos (marco G).
2. Nombrar los meshes según la tabla. Mínimo: `*Meadow`, `<Mapa>Floor-colonly`,
   bordes (`*Canyon`/`*Rock`/paredes), guías `AutoForest_*` alrededor.
3. Verificar que los `*Meadow` pisan los del vecino en cada unión.
4. Desplazar a coordenadas locales, exportar a `assets/maps/<zona>/<mapa>.glb`
   y guardar `blender/<mapa>.blend` (en coordenadas locales).

### Godot
5. Crear `features/world/zones/zone_<id>.tscn` + `.gd`: instanciar el `.glb`
   y poner un `SpawnPoint` sobre un `*Meadow`. Sin caja `Floor`.
6. `autoload/zone_manager.gd`: agregar la zona a `ZONES` con `scene`, `offset`
   y `connections`; agregar el id también en las `connections` de los vecinos.
7. `world_boundary.gd`: agregar el mapa a `MEADOW_MAPS` y al bucle de
   `tag_triangle` (lista de zonas).
8. Tests: `tests/unit/test_zone_floors.gd` revisa todas las zonas solo; agregar
   un caso en `tests/unit/test_zone_detection.gd` con un punto del mapa.
9. Probar en el juego: uniones con los vecinos, bordes de precipicio, rampas y
   la cámara contra paredes.
