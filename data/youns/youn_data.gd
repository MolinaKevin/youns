class_name YounData
extends Resource

@export var id: String = ""
@export var youn_name: String = ""

@export var texture: Texture2D
@export var mesh: Mesh
@export var mesh_scale: float = 1.0
@export var mesh_y_offset: float = 0.0

@export_group("Animations")
@export var scene_idle: PackedScene
@export var scene_walk: PackedScene
@export var scene_run: PackedScene
@export var scene_attack: PackedScene
@export var scene_range: PackedScene
@export var scene_damage: PackedScene
@export var scene_die: PackedScene
@export var scene_evolve: PackedScene

@export_range(0.1, 20.0, 0.1) var wander_speed: float = 2.2
@export_range(0.1, 20.0, 0.1) var chase_speed: float = 5.8
@export_range(0.1, 20.0, 0.1) var rotate_speed: float = 8.0
@export_range(0.0, 50.0, 0.1) var detect_range: float = 12.0
@export_range(0.0, 50.0, 0.1) var lose_range: float = 18.0
@export_range(0.0, 50.0, 0.1) var wander_radius: float = 8.0
@export_range(0.0, 100.0, 0.1) var leash_range: float = 14.0

@export_range(0.0, 10.0, 0.1) var body_height: float = 1.0
@export_range(0.1, 5.0, 0.05) var combat_shadow_radius: float = 0.65
@export_range(0.1, 5.0, 0.05) var collision_radius: float = 0.35
@export_range(0.1, 5.0, 0.05) var collision_height: float = 1.6

@export_range(0.0, 10.0, 0.1) var idle_time_min: float = 0.8
@export_range(0.0, 10.0, 0.1) var idle_time_max: float = 2.5
@export_range(0.0, 10.0, 0.1) var notice_delay_min: float = 0.4
@export_range(0.0, 10.0, 0.1) var notice_delay_max: float = 1.3

@export_group("Wild (combat)")
@export var max_hp: int = 30
@export var strategy: AiStrategy
@export var loot_item_name: String = "Data"
@export var loot_gold: int = 0

@export_range(0, 23, 1) var sleep_hour: int = 22
@export_range(0, 23, 1) var wake_hour: int = 7

@export_range(0.0, 999.0, 0.1) var base_weight: float = 10.0

@export_range(0, 100, 1) var base_discipline: int = 55
@export_range(0, 100, 1) var base_felicidad: int = 70
@export_range(0, 10, 1) var base_care_mistakes: int = 0
@export_range(0, 100, 1) var base_confianza: int = 50
@export_range(0, 100, 1) var base_estres: int = 10
@export_range(0, 100, 1) var base_aburrimiento: int = 20
@export_range(0, 100, 1) var base_autocontrol: int = 50

