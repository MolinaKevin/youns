class_name WorldProgressData
extends Resource

## Progreso persistente del mundo exterior. Los nuevos puentes, warps y rutas
## desbloqueadas se agregan acá, sin inflar PlayerSaveData con flags sueltos.

@export var north_trail_open := false
