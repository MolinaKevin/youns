class_name CombatMapSceneAdapter
extends CombatMapScenePort

## Adaptador de composición visual/entrada para la escena concreta del tablero.
var _input: CombatMapInput
var _actors: CombatActorPresentation

func _init(input: CombatMapInput, actors: CombatActorPresentation) -> void:
	_input = input
	_actors = actors
	self.actors = CombatMapSceneActorsAdapter.new(self)
	self.presentation = CombatMapScenePresentationAdapter.new(self)
	self.input = CombatMapSceneInputAdapter.new(self)
	_input.position_selected.connect(func(pos: Vector2): position_selected.emit(pos))

func setup_actors() -> void: _actors.setup_actors()
func setup_player(data: YounData) -> void: _actors.setup_player(data)
func setup_enemy(data: YounData) -> void: _actors.setup_enemy(data)
func set_status_texts(player_text: String, enemy_text: String) -> void: _actors.set_status_texts(player_text, enemy_text)
func lock_hover_at_last_click() -> void: _input.lock_hover_at_last_click()
func unlock_hover() -> void: _input.unlock_hover()
func is_hover_locked() -> bool: return _input.is_hover_locked()
func place_status_labels() -> void: _actors.place_status_labels()
