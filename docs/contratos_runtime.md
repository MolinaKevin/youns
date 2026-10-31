# Contratos de runtime

Pequeños contratos que cruzan escenas y autoloads. Mantenerlos explícitos evita
que una pantalla visual dependa de la forma interna de un servicio.

## Partida activa

Las pantallas, zonas y secuencias leen la partida mediante
`PlayerSessionAccess.save()` o `has_active_save()`. Sólo `GameState`, el
adaptador y los servicios que componen el runtime deben conocer
`SaveService.player_save` directamente.

## Transiciones de vida del Youn

`EmotionService` es dueño de `active_states`. Las marcas excluyentes se crean
con `begin_evolution(path)` y `begin_reincarnation(cause)`, se consultan con
`transition_active()`/`transition_entry()` y se cierran con
`finish_transition()`. Ningún consumidor externo debe escribir las entradas
`evolving` o `dying` directamente.

## Secuencias cancelables

Toda secuencia que use `AsyncFlowToken` debe comprobarlo después de cada
`await`, y su `_exit_tree()` debe restaurar cualquier estado que cambió antes
del siguiente `await`: visibilidad de la party, cámara, input y leases. Si la
secuencia pausa o congela el mundo, usa `WorldTransitionLease` y lo libera en
la ruta normal y en `_exit_tree()`.

## Comodines de combate

La mitad de carta reservada por los comodines `KEEP` e `ITEM` se representa con
`CombatHalfSelection` (`card_index`, `is_top`). No usar diccionarios con claves
`card`/`is_top` para este estado temporal.

## Movimiento enemigo

`CombatMovePlan` concentra `destination` y `path`. Los puertos del mapa aún
serializan el resultado como diccionario por compatibilidad, pero los sistemas
de navegación y movimiento lo crean/leen mediante este contrato.
