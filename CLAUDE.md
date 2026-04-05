# youns — Godot 4 Roguelike Card Game

## Concepto
Juego de cartas roguelike con combate en mapa isométrico. El jugador arma un mazo, entra en combate y juega cartas que se dividen por tipo (movimiento, ataque, bloqueo, ultimate).

## Estructura del proyecto

```
autoload/
  game_state.gd       — Singleton. Maneja player_save y current_run. Actualmente usa mock data hardcodeado.
  card_database.gd    — Singleton. Carga todos los .tres de cartas y los indexa por id.

data/
  card_data.gd        — Resource class: id, name, description, cost, card_type, card_range, damage, image
  cards/*.tres        — Recursos de cartas: step, dash, strike, slash, block, meteor, arrow, snipe
  save/
    player_save_data.gd  — owned_card_ids, equipped_deck_ids, gold, relics, level
    run_state_data.gd    — hp, deck/draw/discard/hand piles, relics activos

scenes/
  combat/
    combat.tscn/.gd   — Pantalla de combate. Maneja energía, turnos, jugar cartas, estado del combate.
    map_area.gd       — Mapa isométrico. Player + enemy en grid 150x150. Movimiento, rango de ataque, LOS, obstáculo.
    ui/top_bar.tscn   — Barra superior del combate (HP, energía, turno)
  cards/
    card_view.tscn/.gd    — Carta visual para combate. Imagen + nombre. Hover anima la carta hacia arriba.
    card_section.tscn/.gd — Sección de cartas en combate (ej: "Attack", "Movement"). Agrupa CardViews.

UI/
  Cards/
    CardGrid/
      card_grid.tscn/.gd       — Grid scrolleable (5 columnas) de CollectionCards.
    Collection/
      collection_card.tscn/.gd — Carta para el deck builder: imagen + nombre + descripción.
  DeckBuilder/
    deck_builder_screen.tscn/.gd — Pantalla completa del deck builder.
    preview_panel.gd             — Panel derecho: muestra imagen + info + descripción de la carta seleccionada.
```

## Tipos de carta (`card_type`)
| Tipo | Sección en combate | Descripción |
|---|---|---|
| `move` | Movement | Mueve al jugador en el mapa |
| `melee_attack` | Attack | Requiere estar adyacente al enemigo |
| `range_attack` | Attack | Requiere LOS y que el enemigo esté en rango |
| `block` | Block | Da block para absorber daño |
| `targeted_attack` | Ultimate | Sin chequeo de rango (por ahora) |

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

## Flujo de combate
1. `setup_hands()` lee `GameState.player_save.equipped_deck_ids`, resuelve cartas via `CardDatabase`, y distribuye por `card_type` a las 4 secciones.
2. Jugar una carta de **movimiento**: seleccionar → se muestra rango azul → click en tile → jugador se mueve.
3. Jugar una carta de **range_attack**: seleccionar → se muestra rango naranja con LOS → click confirma → si enemigo en rango y LOS, daño.
4. Jugar una carta de **melee_attack**: si enemigo adyacente, daño directo.
5. "Fin de turno" → enemigo ataca → se resetea la mano.

## Deck Builder
- Pantalla: `UI/DeckBuilder/deck_builder_screen.tscn`
- Izquierda: grid de toda la colección del jugador (CardGrid)
- Derecha: preview de carta seleccionada + lista del deck actual con botón X para quitar
- Botón "Agregar al deck" en el preview
- Botón "Guardar" persiste en `GameState.player_save.equipped_deck_ids`

## Mapa isométrico
- Grid 150×150, tiles isométricos pequeños (8×4px)
- Jugador en (132,135), enemigo en (6,8)
- Obstáculo 21×21 en (65,65), infranqueable y bloquea LOS
- LOS usa algoritmo de Bresenham

## Estado actual (mock)
`game_state.gd` usa datos hardcodeados para testing:
- `owned_card_ids`: las 8 cartas
- `equipped_deck_ids`: las 8 cartas
- El guardado real usa `user://player_save.tres` pero no se usa todavía

## Convenciones
- Las imágenes de cartas van en `assets/cards/`. Actualmente todas usan `test.png`.
- Si una carta no tiene imagen asignada, los scripts usan `test.png` como fallback.
- Los `.tres` NO deben abrirse en el inspector de Godot (el editor los sobreescribe y rompe las referencias a texturas).
- Agregar una carta nueva: crear `.tres` en `data/cards/`, agregarlo al array en `card_database.gd`, y al mock en `game_state.gd`.
