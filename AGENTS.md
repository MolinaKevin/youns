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
- Una zona nueva se registra con un `ZoneDefinition` en
  `data/zones/definitions/<id>.tres` (con conexiones en los dos sentidos) y en
  `meadow_maps` de `data/world/world_layout.tres`.

## Minas (interiores)

Los interiores de la mina (`blender/mina.blend`, `blender/mina2.blend`) tienen su
propia guía: **[docs/minas.md](docs/minas.md)** — warps, spawns, luces, estados
de la tierra (`*_E0/_E1/_E2`) y lo que falta en Godot.

## Ports y adapters de combate

Antes de agregar un `*_port.gd` nuevo en `features/combat/scene/`, o de
"completarle" el puerto a un adapter que no lo tiene, leer
**[docs/combate_ports.md](docs/combate_ports.md)**: el puerto solo se
justifica si un mock de test lo sustituye de verdad; si no, un solo archivo
alcanza. Incluye la lista de los que sí deben seguir separados.

## Separar lógica de una escena en una clase nueva

Antes de partir un script de escena (`Control`/`CanvasLayer` con `@onready`)
en varias clases "porque tiene muchas líneas", o de copiarle el patrón
port/adapter de combate a otra feature:

- El port/adapter (contrato vacío + implementación en archivos separados)
  **solo** se justifica si un mock de test necesita sustituir la
  implementación real — ver [docs/combate_ports.md](docs/combate_ports.md).
  En el resto del proyecto no se usa, y no hace falta empezar a usarlo.
- Para separar lógica de dominio de la presentación alcanza con una clase
  `RefCounted` propia que la escena construye en `_ready()` y a la que
  delega (ej. `EvolutionDraft`, `DialogueChoiceMenu`, `DialogueToast`,
  `DialogueLayout`) — sin contrato ni mock de por medio.
- Que un script de escena orqueste varios widgets de una sola pantalla
  (sidebar, columnas, notificaciones) no es "mezclar responsabilidades": es
  su trabajo. No partirlo solo por el tamaño del archivo — partirlo cuando
  dos de esas partes tengan lógica de dominio real que valga la pena probar
  sin construir toda la UI.

Otros documentos: `docs/patrones_modulares.md`, `docs/sistema_movimiento.md`, `docs/TODO.md`.
