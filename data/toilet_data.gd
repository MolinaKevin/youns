class_name ToiletData
extends Resource

@export_group("Posiciones")
## Posición global que ocupa el jugador durante la secuencia.
@export var player_start_position: Vector3 = Vector3.ZERO
## Posición global a la que llega el Youn antes de ir al baño.
@export var youn_start_position: Vector3 = Vector3.ZERO
## Posición global desde la que el Youn entra al baño.
@export var youn_entrance_position: Vector3 = Vector3.ZERO
## Posición global dentro del baño. El Youn se oculta al llegar aquí.
@export var youn_inside_position: Vector3 = Vector3.ZERO
## Punto global que encuadra la cámara durante los momentos en que se miran.
@export var camera_focus_position: Vector3 = Vector3.ZERO

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
