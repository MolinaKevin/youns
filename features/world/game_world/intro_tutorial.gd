class_name IntroTutorial
extends CanvasLayer

## Tutorial de 5 páginas que se muestra la primera vez que se entra al mundo.
## Popup propio con fondo negro detrás (no la caja de diálogo de los NPCs).
## El jugador y el Youn no cortan `physics_process`: así la gravedad sigue
## actuando y caen al piso mientras se lee el popup (arrancan en el aire) en
## vez de quedar congelados — solo se bloquea el movimiento horizontal con
## `movement_locked`.
## `game_world.gd` llama a `start()` al final de su propio `_ready()` (no se
## auto-arranca para no competir con el resto del setup: pausar cámara/jugador
## tiene que pasar DESPUÉS de que game_world ya dejó todo habilitado, si no
## game_world lo pisa un instante después).

const INTRO_PAGES := [
	{
		"title_key": "world.intro.page_1.title",
		"body_key": "world.intro.page_1.body"
	},
	{
		"title_key": "world.intro.page_2.title",
		"body_key": "world.intro.page_2.body"
	},
	{
		"title_key": "world.intro.page_3.title",
		"body_key": "world.intro.page_3.body"
	},
	{
		"title_key": "world.intro.page_4.title",
		"body_key": "world.intro.page_4.body"
	},
	{
		"title_key": "world.intro.page_5.title",
		"body_key": "world.intro.page_5.body"
	}
]

@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _body: RichTextLabel = $Panel/Margin/VBox/Body
@onready var _hint: Label = $Panel/Margin/VBox/Hint

var _index := 0
var _active := false


func _ready() -> void:
	LocalizationState.language_changed.connect(_refresh_language)


func is_active() -> bool:
	return _active


func start() -> void:
	if GameState.world_combat.active or GameState.world_intro_seen:
		visible = false
		return
	_active = true
	_index = 0
	visible = true
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	PartyManager.camera_rig.enabled = false
	PartyManager.player.movement_locked = true
	PartyManager.youn.movement_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page()


func _show_page() -> void:
	var page: Dictionary = INTRO_PAGES[_index]
	_title.text = LocalizationState.t(page["title_key"])
	_body.text = LocalizationState.t(page["body_key"])
	_hint.text = LocalizationState.t("world.intro.hint", [_index + 1, INTRO_PAGES.size()])


## true si el evento era de esperar (se haya usado para avanzar o no) —
## game_world.gd no debe procesarlo más mientras el tutorial está activo.
func handle_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if event.is_action_pressed("ui_accept") or (
		event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
	):
		_index += 1
		if _index >= INTRO_PAGES.size():
			_close()
		else:
			_show_page()
	return true


func _close() -> void:
	_active = false
	GameState.world_intro_seen = true
	visible = false
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_clock_paused(false)
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
	PartyManager.camera_rig.enabled = true
	PartyManager.player.movement_locked = false
	PartyManager.youn.movement_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_language(_language: String = "") -> void:
	if _active:
		_show_page()
