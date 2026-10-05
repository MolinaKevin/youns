class_name EvolutionValueCheck
extends Resource

## Una comparación: key entre min_value y max_value (los dos incluidos).
## Sin use_min / use_max ese lado no tiene límite.

@export var key := ""
@export var use_min := true
@export var min_value := 0.0
@export var use_max := false
@export var max_value := 0.0

func passes(value: float) -> bool:
	if use_min and value < min_value:
		return false
	if use_max and value > max_value:
		return false
	return true
