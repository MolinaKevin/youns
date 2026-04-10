extends Node3D

@onready var lab_ui: Control     = $LabLayer/Laboratory
@onready var prompt: Label3D     = $Monzaemon/Prompt
@onready var interact_area: Area3D = $Monzaemon/InteractArea
@onready var analysis_terminal: Node3D = $AnalysisTerminal

var _near_monzaemon := false

func _ready() -> void:
	PartyManager.place_at_spawn(self)
	PartyManager.camera_rig.yaw = 0.0
	$ExitWarp.body_entered.connect(_on_exit_warp_entered)
	interact_area.body_entered.connect(_on_interact_entered)
	interact_area.body_exited.connect(_on_interact_exited)
	lab_ui.close_requested.connect(_toggle_lab)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	_refresh_analysis_terminal()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and lab_ui.visible:
		_toggle_lab()
	elif _near_monzaemon and event.is_action_pressed("ui_accept"):
		_toggle_lab()

func _toggle_lab() -> void:
	var showing := not lab_ui.visible
	lab_ui.visible = showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED

func _on_interact_entered(body: Node3D) -> void:
	if body.name == "Player":
		_near_monzaemon = true
		prompt.visible = true

func _on_interact_exited(body: Node3D) -> void:
	if body.name == "Player":
		_near_monzaemon = false
		prompt.visible = false
		if lab_ui.visible:
			_toggle_lab()

func _on_exit_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.exit_interior("SpawnFromLab")

func _on_recipe_completed(recipe: Resource) -> void:
	if recipe.id == "terminal_de_analisis":
		_refresh_analysis_terminal()

func _refresh_analysis_terminal() -> void:
	analysis_terminal.visible = LaboratoryState.is_recipe_completed("terminal_de_analisis")
