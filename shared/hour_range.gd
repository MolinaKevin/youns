class_name HourRange
extends RefCounted

## Si `from_hour` es mayor que `to_hour`, el rango cruza la medianoche (ej.
## dormir de 22 a 6): está dentro si `hour` es >= from o < to. Si no, es el
## rango normal: dentro si `hour` está entre los dos. `to_hour` es exclusivo.
static func contains(hour: float, from_hour: float, to_hour: float) -> bool:
	if from_hour > to_hour:
		return hour >= from_hour or hour < to_hour
	return hour >= from_hour and hour < to_hour
