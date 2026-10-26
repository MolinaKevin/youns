extends CanvasLayer

var enabled := false
var _modal := ModalScreenContext.new()

@onready var title_label = $Panel/VBox/Title
@onready var continue_button = $Panel/VBox/ContinueButton
@onready var deck_button = $Panel/VBox/DeckButton
@onready var quit_button = $Panel/VBox/QuitButton

func _ready() -> void:
	LocalizationState.language_changed.connect(_apply_localized_text)
	continue_button.pressed.connect(close)
	deck_button.pressed.connect(_on_deck)
	quit_button.pressed.connect(_on_quit)
	_apply_localized_text()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if InputPresses.is_menu_pressed(event):
		if visible:
			close()
		else:
			open()

func open() -> void:
	_modal.enter_overlay(self, true, true)
	show()

func close() -> void:
	_modal.exit_overlay(self)
	hide()

func _on_deck() -> void:
	close()
	get_tree().change_scene_to_file("res://features/deck_builder/ui/deck_builder_screen.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()

func _apply_localized_text(_language: String = "") -> void:
	title_label.text = LocalizationState.t("pause.title")
	continue_button.text = LocalizationState.t("pause.continue")
	deck_button.text = LocalizationState.t("pause.deck")
	quit_button.text = LocalizationState.t("pause.exit")
