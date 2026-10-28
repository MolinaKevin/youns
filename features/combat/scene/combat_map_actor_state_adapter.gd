class_name CombatMapActorStateAdapter
extends CombatMapActorStatePort

var source: CombatMapActors
func _init(value: CombatMapActors) -> void:
	source = value
	geometry = CombatMapActorGeometryAdapter.new(self)
	targets = CombatMapActorTargetsAdapter.new(self)
	configuration = CombatMapActorConfigurationAdapter.new(self)
func player_radius() -> float: return source.player_radius()
func enemy_radius() -> float: return source.enemy_radius()
func set_player_radius(radius: float) -> void: source.set_player_radius(radius)
func set_enemy_radius(radius: float) -> void: source.set_enemy_radius(radius)
func sync_targets() -> void: source.sync_targets()
func player_target() -> Vector3: return source.player_target()
func enemy_target() -> Vector3: return source.enemy_target()
func player_rotate_speed() -> float: return source.player_rotate_speed()
func enemy_rotate_speed() -> float: return source.enemy_rotate_speed()
func configure_player(data: YounData) -> void: source.configure_player(data)
func configure_enemy(data: YounData) -> void: source.configure_enemy(data)
