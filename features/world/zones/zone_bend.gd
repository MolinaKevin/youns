extends ZoneBase

## Recodo (bend): codo en L al sur de la pradera derecha. Se entra por la
## salida de abajo de la pradera (ExitDown). Del lado de afuera (sur y este)
## sigue el cañón con el río que viene de la ribera; dobla al norte y en la
## punta sube hasta el nivel del suelo. La punta oeste del pasto la cierran
## árboles (del otro lado está el claro de la ribera).
##
## La Bajada: del borde este del pasto sale un rellano y un camino en zigzag
## (con colisión -col) pegado a la pared de adentro del brazo este del cañón:
## RecodoBajadaRampa baja hacia el norte, gira en RecodoBajadaDescanso y
## RecodoBajadaRampa2 vuelve hacia el sur hasta la playa (dos tramos de 4 m de
## ancho, unos 13° cada uno). Abajo el brazo se ensancha
## hacia afuera: la rampa llega a una playa de arena (RecodoPlayaMeadow, y -24)
## y el río corre del otro lado, pegado a la pared de afuera. El cañón ya no sube en punta: sigue
## hasta z 60 del mundo, donde sale a la playa (zona beach).
## En la grilla de WorldBoundary la huella de la rampa (RecodoBajadaMeadow) y
## la playa son caminables, pero sus paredes quedan a la altura del suelo de
## arriba: abajo frenan las barandas y la pared de la playa del propio .glb
## (*-colonly).
##
## Sin caja de piso: el pasto de arriba tiene su colisión
## (RecodoMeadowFloor-colonly). Una caja entera taparía la bajada.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Recodo")
	$CoastalGuard.coastal_descent_opened.connect(_refresh_coastal_descent)
	$CoastalDescentWarning.body_entered.connect(_on_coastal_descent_warning_body_entered)
	_refresh_coastal_descent()


func _on_coastal_descent_warning_body_entered(body: Node3D) -> void:
	if body == PartyManager.player and not _coastal_descent_open():
		$CoastalGuard.warn_descent_blocked()


func _refresh_coastal_descent() -> void:
	var open := _coastal_descent_open()
	$CoastalDescentBarrier/Col.disabled = open
	$CoastalDescentWarning.monitoring = not open
	$CoastalGuard.visible = not open
	$CoastalGuard.set_active(not open)


func _coastal_descent_open() -> bool:
	var save := PlayerSessionAccess.save()
	return save != null and save.world_progress != null and save.world_progress.coastal_descent_open
