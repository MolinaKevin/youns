class_name EnemyData
extends Resource

@export var id: String = ""
@export var enemy_name: String = ""
@export var max_hp: int = 30
@export var strategy: AiStrategy
## Mazo de cartas de habilidad cuando pelea como enemigo. Sin mazo usa `strategy`.
@export var monster_deck: MonsterDeck
## Iniciativa fija mientras los enemigos no tengan mazo. Menor actúa primero.
@export var initiative: int = 50

@export var mesh: Mesh
@export var mesh_scale: float = 0.3
@export var mesh_y_offset: float = 0.0

@export_range(0.1, 10.0, 0.1) var collision_radius: float = 0.35
@export_range(0.1, 10.0, 0.1) var collision_height: float = 1.6
## Radio de la huella en combate, en casillas de la grilla (CombatGrid.CELL):
## es la sombra que se ve bajo el personaje y las casillas que ocupa. Más grande
## = ocupa más lugar (no puede pasar por huecos chicos, está "más cerca" al atacar).
@export_range(1, 60, 1) var combat_footprint_cells: int = 5

@export_range(0.1, 20.0, 0.1) var wander_speed: float = 2.2
@export_range(0.1, 20.0, 0.1) var chase_speed: float = 5.8
@export_range(0.1, 20.0, 0.1) var rotate_speed: float = 8.0
@export_range(0.0, 50.0, 0.1) var detect_range: float = 12.0
@export_range(0.0, 50.0, 0.1) var lose_range: float = 18.0
@export_range(0.0, 50.0, 0.1) var wander_radius: float = 8.0
@export_range(0.0, 100.0, 0.1) var leash_range: float = 14.0

@export_range(0.0, 10.0, 0.1) var idle_time_min: float = 0.8
@export_range(0.0, 10.0, 0.1) var idle_time_max: float = 2.5
@export_range(0.0, 10.0, 0.1) var notice_delay_min: float = 0.4
@export_range(0.0, 10.0, 0.1) var notice_delay_max: float = 1.3

@export var loot_item_name: String = "Data"
@export var loot_gold: int = 5

## Radio de la huella en unidades de mundo.
func combat_footprint_radius() -> float:
	return float(combat_footprint_cells) * CombatGrid.CELL
