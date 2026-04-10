# youns — Godot 4 Roguelike Card Game

## Concepto
Juego de cartas roguelike con un compañero virtual (Youn) inspirado en Digimon World 1. El jugador arma un mazo, entra en combate y juega cartas. El Youn tiene un ciclo de vida (huevo → rookie → champion → ultimate/muerte/reencarnación) y el progreso del jugador como entrenador persiste entre reencarnaciones.

## Estructura del proyecto

```
autoload/
  game_state.gd         — Singleton. Maneja player_save y current_run. Mock data hardcodeado.
  card_database.gd      — Singleton. Carga todos los .tres de cartas y los indexa por id.
  laboratory_state.gd   — Singleton. Maneja recetas del laboratorio: activar, pausar, completar, desbloquear.
  party_manager.gd      — Singleton. Instancia la party 3D (Player, Youn, CameraRig) y la coloca en spawns.
  zone_manager.gd       — Singleton. Carga/descarga zonas exteriores y entra/sale de interiores.

data/
  card_data.gd          — Resource: id, name, description, cost, card_type, card_range, damage, image
  lab_recipe.gd         — Resource: id, recipe_name, item_name, craft_time, location, action_type, reward, ingredients
  cards/*.tres          — step, dash, strike, slash, block, meteor, arrow, snipe, grenade, bear_trap, spike_trap
  enemies/
    enemy_data.gd       — Resource: id, enemy_name, max_hp, strategy (AiStrategy), mesh, mesh_scale
    ai_strategy.gd      — Resource: Array[AiAction]. Define el conjunto de acciones de un enemigo.
    ai_action.gd        — Resource: action_type, base_score, conditions[], damage, attack_range, move_range, block_amount
    goblin.tres         — Enemigo actual en combate
    archer.tres         — Enemigo a distancia
    strategies/*.tres   — Estrategias reutilizables (aggressive, kiter)
  lab_recipes/*.tres    — Recetas del laboratorio
  save/
    player_save_data.gd — owned_card_ids, equipped_deck_ids, gold, player_level, unlocked_recipe_ids, completed_recipe_ids
    run_state_data.gd   — hp, deck/draw/discard/hand piles, relics activos

features/
  menus/
    main_menu/
      main_menu.tscn/.gd  — Menú grid 3x2. `overlay_mode=true` lo reutiliza como overlay/pause menu visual.
      menu_item.tscn/.gd  — Ítem individual del menú (icono + nombre + highlight).
      title_menu.tscn/.gd — Menú principal standalone nuevo. No está activado como `main_scene`.
    pause_menu/
      pause_menu.tscn/.gd — Menú de pausa global. Escape para abrir/cerrar.
  combat/
    scene/
      combat.tscn/.gd           — Pantalla de combate. Orquesta state, player_actions y enemy_ai.
      combat_state.gd           — Estado puro del combate: HP jugador/enemigo, block, energía, hand/draw/discard.
      combat_player_actions.gd  — Lógica de acciones del jugador (jugar cartas, mover, atacar).
      combat_enemy_ai.gd        — IA del enemigo. Evalúa AiActions por score y condiciones, ejecuta la mejor.
      combat_camera.gd          — Camera3D con zoom (scroll), pan (clic derecho), órbita (clic medio).
      map_area.gd               — Mapa isométrico 3D. Player + enemy en grid 150x150. LOS con Bresenham.
      ui/top_bar.tscn           — Barra superior del combate (HP, energía, turno, intent del enemigo).
  cards/
    presentation/
      card_view.tscn/.gd    — Carta visual. Hover anima hacia arriba.
      card_section.tscn/.gd — Agrupa CardViews por tipo.
    ui/
      CardGrid/card_grid.tscn/.gd         — Grid scrolleable (5 col) de cartas.
      Collection/collection_card.tscn/.gd — Carta de colección para deck builder.
  deck_builder/
    ui/
      deck_builder_screen.tscn/.gd — Pantalla completa del deck builder.
      preview_panel.gd             — Panel derecho: imagen + info + botón agregar al deck.
  laboratory/
    scene/
      laboratory.tscn/.gd     — UI del laboratorio. Sidebar de localizaciones + columnas por action_type + output panel.
      recipe_column.tscn/.gd  — Columna de recetas (instant/loop/upgrade/next/dungeon).
      recipe_entry.tscn/.gd   — Entrada individual de receta con barra de progreso y botón activar.
      tech_tree_view.gd       — Vista del árbol tecnológico (toggle con botón).
  world/
    game_world/
      game_world.tscn/.gd — Escena principal actual. Contenedor del mundo y overlay del menú.
    party/
      party.tscn          — Player + Youn + CameraRig instanciados por `PartyManager`.
    zones/
      zone_base.gd            — Base de triggers de zona.
      zone_hub.tscn/.gd       — Zona hub principal.
      zone_crossroads.tscn/.gd — Zona de conexión.
      zone_left.tscn/.gd      — Zona lateral izquierda.
      zone_right.tscn/.gd     — Zona lateral derecha.
    lab_interior/
      lab_interior.tscn/.gd — Interior del laboratorio.
      face_player.gd        — Helper para orientar meshes hacia el jugador.
    world_map/
      world_map.tscn/.gd      — Escena antigua de hub 3D estilo PS1; sigue en el repo.
      camera_rig.gd           — Cámara libre del world map / party.
      player_3d.gd            — Representación 3D del jugador.
      enemy_3d.gd             — Representación 3D del Youn/enemigo compañero.
      ps1_vertex.gdshader     — Shader de vértices con look PS1.
      ps1_screen.gdshader     — Post-proceso de pixelado.
```

## Autoloads (orden importante)
1. `GameState` (game_state.gd) — debe ir antes de LaboratoryState
2. `CardDatabase` (card_database.gd)
3. `LaboratoryState` (laboratory_state.gd) — depende de GameState
4. `PauseMenu` (pause_menu.tscn) — UI global de pausa
5. `PartyManager` (party_manager.gd) — instancia y expone player/youn/camera_rig
6. `ZoneManager` (zone_manager.gd) — maneja streaming simple de zonas e interiores

## Tipos de carta (`card_type`)
| Tipo | Descripción |
|---|---|
| `move` | Mueve al jugador en el mapa |
| `melee_attack` | Requiere estar adyacente al enemigo |
| `range_attack` | Requiere LOS y que el enemigo esté en rango |
| `block` | Da block para absorber daño |
| `targeted_attack` | Sin chequeo de rango (por ahora) |

## Cartas existentes
| id | Nombre | Tipo | Costo | Rango | Daño |
|---|---|---|---|---|---|
| step | Step | move | 1 | 10 | — |
| dash | Dash | move | 1 | 15 | — |
| strike | Strike | melee_attack | 1 | 1 | 6 |
| slash | Slash | melee_attack | 1 | 1 | 15 |
| block | Block | block | 1 | — | — |
| meteor | Meteor | targeted_attack | 3 | — | 15 |
| arrow | Arrow | range_attack | 1 | 5 | 4 |
| snipe | Snipe | range_attack | 2 | 10 | 9 |
| grenade | Grenade | targeted_attack | ? | ? | ? |
| bear_trap | Bear Trap | ? | ? | ? | ? |
| spike_trap | Spike Trap | ? | ? | ? | ? |

## Sistema de combate

### Módulos
- `CombatState` — datos puros (HP, block, energía, mazo)
- `CombatPlayerActions` — lógica de jugar cartas y mover al jugador
- `CombatEnemyAI` — evalúa todas las AiActions, elige la de mayor score entre las elegibles
- `combat.gd` — orquestador: conecta los 3 módulos, maneja UI y turno

### Flujo de un turno
1. Jugador juega cartas (movimiento, ataque, bloqueo) gastando energía
2. "Fin de turno" → CombatEnemyAI.take_turn() → enemigo ejecuta acción → pick_intent() para preview
3. Se resetea la mano (draw 6 cartas)

### IA enemiga
- Cada enemigo tiene un `AiStrategy` con array de `AiAction`
- Cada `AiAction` tiene `conditions[]` (todas deben cumplirse) y `base_score`
- El evaluador elige la acción elegible con mayor score
- Condiciones: `always`, `player_adjacent`, `player_in_range`, `player_out_of_range`, `player_far`, `self_hp_low`, `self_hp_critical`, `has_los`
- Tipos de acción: `melee_attack`, `range_attack`, `move_toward`, `move_away`, `block`
- `score_multiplier_low_hp` modifica el score cuando el enemigo tiene ≤30% HP

### Mapa isométrico
- Grid 150×150, tiles isométricos pequeños (8×4px)
- Jugador en (132,135), enemigo en (6,8) (posiciones iniciales)
- Obstáculo 21×21 en (65,65), infranqueable y bloquea LOS
- LOS usa Bresenham

## Laboratorio (`LaboratoryState`)

### Tipos de receta (`action_type`)
| Tipo | Comportamiento |
|---|---|
| `instant` | Se ejecuta inmediatamente al activar, consume ingredientes |
| `loop` | Se repite indefinidamente mientras haya ingredientes |
| `upgrade` | Se completa una sola vez (one-shot permanente) |
| `next` | (por definir) |
| `dungeon` | (por definir) |

### Flujo
1. Al cargar, `LaboratoryState` lee todos los `.tres` de `data/lab_recipes/`
2. Las recetas con `starts_unlocked=true` se desbloquean automáticamente
3. Las recetas sin `needs_research` se desbloquean cuando se tienen todos sus ingredientes en `pending_output`
4. Activar una receta pausa la activa y empieza un Timer por `craft_time` segundos
5. Al completar: genera `reward` y `extra_rewards` en `pending_output`, "Take All" los pasa al inventario
6. La UI se organiza por `location` (sidebar) y `action_type` (columnas)

### Notificaciones
- Si se completa una receta de una localización no seleccionada, el botón del sidebar muestra "!"

## Mundo / Exploración 3D
- La `main_scene` actual es `features/world/game_world/game_world.tscn`
- `game_world.gd` crea environment/fog y monta `main_menu.tscn` como overlay
- `PartyManager` instancia la party (`Player`, `Youn`, `CameraRig`) desde `features/world/party/party.tscn`
- `ZoneManager` hace streaming simple de zonas exteriores y entra/sale de interiores
- Existe también `features/world/world_map/world_map.tscn` como escena/hub 3D con estética PS1
- Look PS1: shader `ps1_vertex.gdshader` en meshes y post-process `ps1_screen.gdshader` (pixel_size=2)
- Fog azulado, luz ambiente fría
- En `world_map`: edificios codificados por color Laboratorio (violeta), Ciudad (azul), Dungeon (rojo)

## Menú principal
- `features/menus/main_menu/main_menu.tscn` es el menú grid 3×2 usado como overlay dentro del mundo
- Ítems actuales: Laboratorio, Combate, Mazo, Mapa, Inventario, Guardar
- Solo Laboratorio, Combate y Mazo tienen escena asignada
- Navegación con flechas + Enter. `overlay_mode=true` oculta fondo y stats bar para usarlo como overlay
- `features/menus/main_menu/title_menu.tscn` existe como menú principal standalone nuevo, pero no está activado todavía

## Deck Builder
- `features/deck_builder/ui/deck_builder_screen.tscn`
- Izquierda: grid de la colección completa del jugador
- Derecha: preview + lista del deck actual con botón X
- "Guardar" persiste en `GameState.player_save.equipped_deck_ids`

## Estado actual (mock)
`game_state.gd` usa datos hardcodeados:
- `owned_card_ids`: incluye `step`, `dash`, `strike`, `slash`, `block`, `meteor`, `arrow`, `snipe`, `grenade`
- `equipped_deck_ids`: deck mock más grande con repeticiones e incluye `grenade`, `bear_trap`, `spike_trap`
- Guardado real usa `user://player_save.tres` pero no se activa todavía
- `PlayerSaveData` ya incluye `unlocked_recipe_ids` y `completed_recipe_ids`

## Convenciones
- Imágenes de cartas: `assets/cards/`. Todas usan `test.png` por ahora.
- Los `.tres` NO abrir en el inspector de Godot (sobreescribe referencias a texturas).
- Agregar carta: crear `.tres` en `data/cards/`, agregar a `card_database.gd` y al mock en `game_state.gd`.
- Agregar enemigo: crear `.tres` en `data/enemies/` con `EnemyData` + `AiStrategy` + `AiAction[]`.
- Agregar receta: crear `.tres` en `data/lab_recipes/` con `LabRecipe`.
- Organización actual: features jugables/visuales viven bajo `features/`; estado global compartido en `autoload/`; contenido y resources en `data/`.
