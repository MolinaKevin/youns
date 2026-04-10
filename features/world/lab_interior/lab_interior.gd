extends Node3D

@onready var lab_ui: Control     = $LabLayer/Laboratory
@onready var menu: Control = $MenuLayer/MainMenu
@onready var prompt: Label3D = $Monzaemon/Prompt
@onready var interact_area: Area3D = $Monzaemon/InteractArea
@onready var analysis_terminal: Node3D = $AnalysisTerminal
@onready var terminal_prompt: Label3D = $AnalysisTerminal/Prompt
@onready var terminal_area: Area3D = $AnalysisTerminal/InteractArea

var _near_monzaemon := false
var _near_terminal := false
var _terminal_clock_open := false

func _ready() -> void:
	GameState.set_clock_visible(GameState.has_persistent_clock_ui())
	GameState.set_clock_paused(false)
	GameState.set_youns_status_visible(GameState.has_persistent_care_ui())
	PauseMenu.enabled = false
	PartyManager.place_at_spawn(self)
	PartyManager.camera_rig.yaw = 0.0
	$ExitWarp.body_entered.connect(_on_exit_warp_entered)
	interact_area.body_entered.connect(_on_interact_entered)
	interact_area.body_exited.connect(_on_interact_exited)
	terminal_area.body_entered.connect(_on_terminal_entered)
	terminal_area.body_exited.connect(_on_terminal_exited)
	lab_ui.close_requested.connect(_toggle_lab)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	_refresh_analysis_terminal()

func _unhandled_input(event: InputEvent) -> void:
	if _is_cancel_pressed(event) and _terminal_clock_open:
		get_viewport().set_input_as_handled()
		_toggle_terminal_clock(false)
		return
	if _is_cancel_pressed(event) and lab_ui.visible:
		get_viewport().set_input_as_handled()
		_toggle_lab()
		return
	if _is_cancel_pressed(event) and menu.visible:
		get_viewport().set_input_as_handled()
		_toggle_menu()
		return
	if _is_menu_pressed(event):
		get_viewport().set_input_as_handled()
		_toggle_menu()
		return
	elif _near_monzaemon and _is_interact_pressed(event):
		_toggle_lab()
	elif _near_terminal and _is_interact_pressed(event):
		_toggle_terminal_clock(not _terminal_clock_open)

func _toggle_lab() -> void:
	var showing := not lab_ui.visible
	lab_ui.visible = showing
	GameState.set_clock_visible(false if showing else GameState.has_persistent_clock_ui())
	GameState.set_clock_paused(showing)
	GameState.set_youns_status_visible(false if showing else GameState.has_persistent_care_ui())
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

func _on_terminal_entered(body: Node3D) -> void:
	if body.name == "Player" and analysis_terminal.visible:
		_near_terminal = true
		terminal_prompt.visible = true

func _on_terminal_exited(body: Node3D) -> void:
	if body.name == "Player":
		_near_terminal = false
		terminal_prompt.visible = false
		_toggle_terminal_clock(false)

func _on_exit_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.exit_interior("SpawnFromLab")

func _on_recipe_completed(recipe: Resource) -> void:
	if recipe.id == "terminal_de_analisis":
		_refresh_analysis_terminal()

func _refresh_analysis_terminal() -> void:
	var unlocked := LaboratoryState.is_recipe_completed("terminal_de_analisis")
	analysis_terminal.visible = unlocked
	if not unlocked:
		terminal_prompt.visible = false
		_toggle_terminal_clock(false)

func _toggle_terminal_clock(showing: bool) -> void:
	_terminal_clock_open = showing
	GameState.set_clock_visible(showing or GameState.has_persistent_clock_ui())
	GameState.set_clock_paused(showing)
	GameState.set_youns_status_visible(showing or GameState.has_persistent_care_ui())
	terminal_prompt.text = "Cerrar reloj [Esc]" if showing else "Ver reloj [E]"

func _toggle_menu() -> void:
	var showing := not menu.visible
	menu.visible = showing
	GameState.set_clock_visible(false if showing else GameState.has_persistent_clock_ui())
	GameState.set_clock_paused(showing)
	GameState.set_youns_status_visible(false if showing else GameState.has_persistent_care_ui())
	PartyManager.camera_rig.enabled = not showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED

func _is_cancel_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _is_menu_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("menu_toggle"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _is_interact_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("interact"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _exit_tree() -> void:
	PauseMenu.enabled = false
