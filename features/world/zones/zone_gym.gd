extends ZoneBase

const TrainingOverlay := preload("res://features/world/ui/training_overlay.gd")

## Estación del gym.glb (Station_<nombre>) → estadística que entrena.
const STATIONS := {
	"Fuerza":       "fuerza",
	"Resistencia":  "resistencia",
	"Agilidad":     "agilidad",
	"Tecnica":      "tecnica",
	"Inteligencia": "inteligencia",
	"Espiritu":     "espiritu",
	"Vitalidad":    "constitucion",
	"Energia":      "mente",
}
const INTERACT_RADIUS := 3.0

var _prompts: Array[Label3D] = []
var _near_stat := ""
var _near_prompt: Label3D = null
var _overlay: Node = null

func _ready() -> void:
	super._ready()
	for station_name in STATIONS:
		_add_station_interaction(station_name, STATIONS[station_name])
	LocalizationState.language_changed.connect(_apply_localized_text)
	_apply_localized_text()

# Área de interacción y cartel sobre el Spot (el círculo frente al equipo).
func _add_station_interaction(station_name: String, stat_key: String) -> void:
	var spot := $GymMap.find_child("Station_%s_Spot" % station_name, true, false) as Node3D
	if spot == null:
		push_warning("ZoneGym: falta Station_%s_Spot en gym.glb" % station_name)
		return
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = INTERACT_RADIUS
	col.shape = shape
	area.add_child(col)
	spot.add_child(area)

	var prompt := Label3D.new()
	prompt.position.y = 2.5
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.visible = false
	spot.add_child(prompt)
	_prompts.append(prompt)

	area.body_entered.connect(func(body: Node3D) -> void:
		if body.name == "Player":
			_near_stat = stat_key
			_near_prompt = prompt
			prompt.visible = _overlay == null)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.name == "Player" and _near_prompt == prompt:
			_near_stat = ""
			_near_prompt = null
			prompt.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if _near_stat == "" or is_instance_valid(_overlay):
		return
	if InputPresses.is_interact_pressed(event):
		get_viewport().set_input_as_handled()
		_open_training(_near_stat)

func _open_training(stat_key: String) -> void:
	_overlay = TrainingOverlay.new()
	_overlay.stat_key = stat_key
	_overlay.tree_exited.connect(func() -> void:
		_overlay = null
		if _near_prompt:
			_near_prompt.visible = true)
	if _near_prompt:
		_near_prompt.visible = false
	get_tree().root.add_child(_overlay)

func _apply_localized_text(_language: String = "") -> void:
	for prompt in _prompts:
		prompt.text = LocalizationState.t("world.prompt.train")
