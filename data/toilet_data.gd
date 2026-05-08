class_name ToiletData
extends Resource

@export_group("Posiciones")
## Posición global del inodoro en el mundo.
@export var world_position: Vector3 = Vector3.ZERO
## Posición global donde el jugador y el Youn se ubican para iniciar la animación.
@export var start_point: Vector3 = Vector3.ZERO

@export_group("Distancias de animación")
## Metros delante del start_point donde el Youn espera al jugador.
@export var meeting_distance: float = 2.0
## Metros antes del inodoro desde donde el Youn entra caminando.
@export var entrance_distance: float = 3.0

@export_group("Cámara")
## Altura del pivot de cámara sobre el punto medio entre los dos personajes.
@export var cam_pivot_height: float = 1.0
## Distancia de la cámara durante la secuencia.
@export var cam_distance: float = 8.0
## Inclinación vertical de la cámara (0 = horizonte, 1.1 = casi cenital).
@export_range(-0.2, 1.1, 0.01) var cam_pitch: float = 0.6
## Lado desde donde encuadra la cámara respecto al eje jugador→baño. 1 = derecha, -1 = izquierda.
@export_range(-1.0, 1.0, 2.0) var cam_side: float = 1.0

@export_group("Tiempos")
## Segundos que el Youn permanece dentro del baño.
@export var wait_inside: float = 2.5
