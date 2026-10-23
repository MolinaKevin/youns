# youns — notas para asistentes

Juego en Godot 4 (GDScript, tests con GUT en `tests/`). Los mapas del mundo se
modelan en Blender (`blender/*.blend`) y se exportan a `assets/maps/**.glb`.

## Mapas

Antes de crear, modificar o exportar un mapa, o de tocar
`autoload/zone_manager.gd`, `features/world/zones/world_boundary*.gd`,
`auto_decoration.gd` o `shared/world_collision_layers.gd`, leer
**[docs/mapas.md](docs/mapas.md)**: convención de nombres de meshes
(`*Meadow`, `*-colonly`, `*-camcol-colonly`, `AutoForest_*`…), coordenadas,
capas de colisión y los pasos para agregar un mapa nuevo.

Lo más importante:
- Lo caminable son los meshes `*Meadow`; en cada unión tienen que solaparse,
  si no aparece una pared invisible.
- Cada mapa trae su colisión de piso (`<Mapa>Floor-colonly`) en el `.glb`;
  no agregar cajas `Floor` en los `.tscn` (excepto el hub).
- Una zona nueva se registra en `ZoneManager.ZONES` (con conexiones en los dos
  sentidos) y en `MEADOW_MAPS` de `world_boundary.gd`.

Otros documentos: `docs/patrones_modulares.md`, `docs/sistema_movimiento.md`, `docs/TODO.md`.
