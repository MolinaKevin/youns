extends Control

signal card_pressed(card_data: CardData)
signal hover_entered
signal hover_exited

@onready var background_rect = $BackgroundRect
@onready var art_rect = $ArtRect
@onready var name_label = $NameLabel
@onready var desc_label = $DescLabel
@onready var stat1_label = $Stat1Label
@onready var stat2_label = $Stat2Label
@onready var stat3_label = $Stat3Label
@onready var cost_label = $CostLabel
@onready var card_button = $CardButton

var card_data: CardData
var pending_setup_card: CardData
var hover_enabled := true

var _hover_tween: Tween

const FALLBACK_IMAGE = preload("res://assets/cards/test.png")

const BACKGROUNDS := {
	"melee_attack":    "res://assets/cards/scratch.png",
	"range_attack":    "res://assets/cards/gun.png",
	"move":            "res://assets/cards/step.png",
	"block":           "res://assets/cards/fist.png",
	"trap_place":      "res://assets/cards/trap.png",
	"trap_throw":      "res://assets/cards/trap.png",
	"grenade":         "res://assets/cards/gun.png",
	"targeted_attack": "res://assets/cards/sword.png",
}

func _ready() -> void:
	card_button.pressed.connect(_on_card_button_pressed)
	card_button.mouse_entered.connect(_on_hover_enter)
	card_button.mouse_exited.connect(_on_hover_exit)

	if pending_setup_card != null:
		_apply_card_data(pending_setup_card)
		pending_setup_card = null

func _on_hover_enter() -> void:
	if hover_enabled:
		hover_entered.emit()
		_animate_to(-12.0)

func _on_hover_exit() -> void:
	if hover_enabled:
		hover_exited.emit()
		_animate_to(0.0)

func _animate_to(target_y: float) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "position:y", target_y, 0.12)

func setup(card: CardData) -> void:
	set_card(card)

func set_card(card: CardData) -> void:
	card_data = card

	if not is_node_ready():
		pending_setup_card = card
		return

	_apply_card_data(card)

func _apply_card_data(card: CardData) -> void:
	var bg_path: String = BACKGROUNDS.get(card.card_type, "")
	background_rect.texture = load(bg_path) if bg_path != "" else null
	art_rect.texture = card.image if card.image != null else null
	name_label.text = LocalizationState.card_name(card.id, card.name)
	desc_label.text = LocalizationState.card_description(card.id, card.description)
	if card.damage > 0:
		stat1_label.text = str(card.damage)
	elif card.block_amount > 0:
		stat1_label.text = str(card.block_amount)
	else:
		stat1_label.text = ""
	stat2_label.text = str(card.card_range) if card.card_range > 0 else ""
	stat3_label.text = "%.1f" % card.bounce if card.bounce > 0.0 else ""
	cost_label.text = str(card.cost)

func set_disabled(value: bool) -> void:
	card_button.disabled = value

func _on_card_button_pressed() -> void:
	card_pressed.emit(card_data)
