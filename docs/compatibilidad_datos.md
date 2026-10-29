# Compatibilidad de datos

Este documento registra los campos y señales que se conservan para poder abrir
partidas o recursos creados antes de las migraciones actuales. No se deben
eliminar por estar ausentes de los recursos del repositorio: también pueden
venir de partidas guardadas, mods o herramientas externas.

| Puente | Se conserva mientras | Criterio para retirarlo |
| --- | --- | --- |
| `WorldProgressData.unlocked_bridge_ids` | Se acepten partidas con `save_version < 3`. `SaveService` lo copia a `unlocked_construction_ids`. | Subir la versión mínima soportada a 3 y mantener una migración de importación para archivos anteriores. Agregar una prueba de rechazo o conversión antes de borrar el campo. |
| `AiStrategy.actions` | Se acepten estrategias externas sin fases (`initial_phase` vacío). | El validador debe rechazar el formato plano y la documentación de mods debe exigir `phases`; luego eliminar el fallback de `CombatEnemyStrategyAI`. |
| `YounData.combat_footprint_cells` | Se acepten recursos externos que todavía expresen la huella en celdas. | Versionar la migración de recursos y confirmar que ningún `.tres` del juego ni mod soportado depende del campo; después eliminar el fallback de `combat_footprint_radius()`. |
| `LaboratoryState.recipes_loaded` | ~~Retirado~~. Los consumidores esperan `LaboratoryState.ensure_loaded()`. | Mantener `ensure_loaded()` como contrato de inicialización; no reintroducir una señal técnica equivalente. |

## Reglas de retiro

1. No borrar un campo sólo porque ya no aparece en `data/`.
2. Cada retiro debe incluir una migración o un rechazo explícito para datos
   antiguos, además de una prueba de regresión.
3. La eliminación se hace en un cambio separado de la migración que deja de
   producir el formato antiguo, para poder revertirla sin perder partidas.
