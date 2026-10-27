# Minas (interiores)

Dos mapas de interior, independientes del mundo exterior y unidos por warps.
Se modelaron en Blender; **todavía no están exportados ni cargados en Godot**.

| Mapa | Fuente | Colección | Escena de Blender | Exportar a (propuesto) |
|---|---|---|---|---|
| Mina (cámara central + 4 túneles) | `blender/mina.blend` | `mina` | `Mina` | `assets/maps/mina/mina.glb` |
| Mina profunda (cámara grande + derrumbe + bajada) | `blender/mina2.blend` | `mina2` | `Mina2` | `assets/maps/mina/mina2.glb` |

## Coordenadas

- Cada `.blend` está en coordenadas **locales del interior**: el origen es el
  centro de la cámara principal, con el piso a altura 0. No hay que desplazar
  nada al exportar (a diferencia de los mapas del mundo, ver `docs/mapas.md`).
- Blender `(x, y, z)` ↔ Godot `(x, z, -y)`. Las posiciones de abajo están en Godot.
- Exportar igual que los mapas: solo la colección, `export_yup=True`,
  `export_apply=True`, `use_selection=True`, `use_active_scene=True`, GLB.
- **Ubicación en Godot:** `InteriorTransitionController` agrega el interior en
  el origen del mundo y solo oculta las zonas; los `StaticBody3D` ocultos siguen
  chocando. Instanciar el mapa de la mina lejos del mundo (por ejemplo el nodo
  `Map` en `y = -300`) o desactivar la colisión de las zonas mientras se está adentro.

## Nombres

Misma convención que el mundo (`docs/mapas.md`):
`*-col` visible + colisión, `*-colonly` solo colisión, `*-camcol-colonly` solo
cámara, `<Mapa>Floor-colonly` piso. Lo nuevo de las minas:

| Nombre | Qué es |
|---|---|
| `Warp*` (empty) | Dónde va el `Area3D` del warp, al fondo de cada túnel de salida. |
| `SpawnDesde*` (empty) | Dónde aparece el jugador al llegar por ese warp, 6 m antes y mirando hacia adentro. |
| `LuzFarol_*`, `LuzFarolB_*`, `LuzCristal_*` (empties) | Posición de un `OmniLight3D` (faroles: cálido; cristales: celeste). |
| `*Agua` | Agua: asignarle `features/world/water/water.tres` (no pasa por AutoDecoration). |
| `*Luz`, `*SalidaLuz` | Plano emisivo blanco al fondo de los túneles de salida. |
| `*_E0`, `*_E1`, `*_E2` | Estados de la tierra que se saca de un túnel (ver abajo). |
| `EventoTierra<Túnel>_E0/_E1` (empty) | Dónde se activa el evento de sacar tierra en ese estado (pie del montón). |

`PartyManager.place_at_spawn(scene)` busca el spawn con `scene.get_node_or_null(nombre)`,
o sea como **hijo directo** de la escena: o se crean `Node3D` spawn en el `.tscn`
copiando la posición de los empties, o se pasa la ruta (`"Map/SpawnDesdeMina"`).

## Mina (`mina.blend`)

Cámara central con un pozo de 10 m (baranda + puente), túnel largo a la playa con
vías y una gruta de cristales con lago, túnel al codo que sube 18 m, túnel a la
ribera con arroyo, y un túnel "sur" que lleva a la mina profunda.

| Warp en la mina | Posición | Conecta con | Spawn al llegar |
|---|---|---|---|
| `WarpPlaya` | (121.2, 0, -88.4) | beach: empty `WarpMina` de `playa.glb` | `SpawnDesdePlaya` |
| `WarpCodo` | (-94, 18, 31) | elbow: empty `WarpCueva` de `codo.glb` | `SpawnDesdeCodo` |
| `WarpRibera` | (-31.7, 0, 97) | riverside: empty `WarpAbertura` de `ribera.glb` | `SpawnDesdeRibera` |
| `WarpSur` | (23.1, 0, 65) | mina profunda: `WarpHaciaMina` | `SpawnDesdeSur` |

## Mina profunda (`mina2.blend`)

Cámara grande (estalagmitas, andamio, carretilla volcada), túnel de llegada desde
la mina y dos túneles cerrados con tierra que el jugador va despejando.

| Warp | Posición | Conecta con | Spawn al llegar |
|---|---|---|---|
| `WarpHaciaMina` | (2.1, 0, -65) | mina: `WarpSur` | `SpawnDesdeMina` |
| `WarpFondoDerrumbe` | (53.1, 0, -10.4) | (destino a definir), solo activo con el derrumbe en E2 | `SpawnDesdeFondoDerrumbe` |

### Estados de la tierra (evento de carretillas)

El piso, las paredes y su colisión son siempre el **túnel vacío**. La tierra son
modelos aparte, uno por estado; Godot deja activo uno solo por túnel.

| Estado | Carretillas sacadas | Contenido |
|---|---|---|
| E0 | 0–7 | Montón completo en la boca + `*Bloqueo_E0-colonly` |
| E1 | 8–15 | Montón más chico y más adentro + `*Bloqueo_E1-colonly` |
| E2 | 16+ | Solo restos contra las paredes; sin bloqueo (en el derrumbe, también `Mina2DerrumbeLuz_E2`) |

Túneles: `Derrumbe` (corto, termina en `WarpFondoDerrumbe`) y `Bajada` (baja 15 m;
al fondo hay una barricada de tablones `Mina2Barricada-col` sin salida por ahora).

Reglas para el script:
- `estado = min(carretillas / 8, 2)` por túnel; cada túnel tiene su contador
  (persistente, por ejemplo en `WorldProgressData`).
- Activar los nodos cuyo nombre contiene el túnel (`Derrumbe`/`Bajada`) y
  `_E{estado}`; desactivar los otros estados de ese túnel **también en colisión**
  (ocultar un `StaticBody3D` no lo apaga: desactivar sus `CollisionShape3D` o
  sacarlo del árbol).
- El evento se activa en `EventoTierra<Túnel>_E{estado}` (E0 y E1); en E2 ya no hay evento.
- `WarpFondoDerrumbe` solo funciona en E2.

## Pendiente en Godot

1. Exportar los dos `.glb`.
2. Escenas `mine_interior.tscn` / `mine_deep_interior.tscn` (como `lab_interior`):
   mapa lejos del mundo, ambiente oscuro, luces en los empties `Luz*`, agua,
   `WorldCollisionLayers.configure_ground_colliders` y
   `configure_camera_terrain_colliders` sobre el mapa.
3. Warps del mundo hacia la mina: `WarpMina` (beach), `WarpCueva` (elbow), `WarpAbertura` (riverside).
4. `ZoneManager` hoy no alcanza: `exit_interior()` siempre vuelve a la zona por la
   que se entró. Falta salir a **otra zona** (entrar por la playa y salir por el
   codo) y pasar de **un interior a otro** (mina ↔ mina profunda).
5. Evento de carretillas + contador persistente + cambio de estado de la tierra.
