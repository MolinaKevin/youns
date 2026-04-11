extends Control

signal close_requested

const RecipeEntry := preload("res://features/laboratory/scene/recipe_entry.tscn")
const ACTION_TYPES := ["instant", "loop", "upgrade", "next", "dungeon"]

@export var standalone_mode := true
@export var interaction_enabled := true

@onready var location_list = $RootVBox/ContentHBox/LocationPanel/LocationList
@onready var output_list = $RootVBox/ContentHBox/OutputPanel/VBox/Scroll/OutputList
@onready var take_all_button = $RootVBox/ContentHBox/OutputPanel/VBox/TakeAllButton
@onready var recipes_button = $RootVBox/TopBar/RecipesButton
@onready var tech_tree_button = $RootVBox/TopBar/TechTreeButton
@onready var close_button = $RootVBox/TopBar/CloseButton
@onready var columns_container = $RootVBox/ContentHBox/MainArea/Columns
@onready var tech_tree_view = $RootVBox/ContentHBox/MainArea/TechTreeView
@onready var columns := {
	"instant": $RootVBox/ContentHBox/MainArea/Columns/InstantColumn,
	"loop":    $RootVBox/ContentHBox/MainArea/Columns/LoopColumn,
	"upgrade": $RootVBox/ContentHBox/MainArea/Columns/UpgradeColumn,
	"next":    $RootVBox/ContentHBox/MainArea/Columns/NextColumn,
	"dungeon": $RootVBox/ContentHBox/MainArea/Columns/DungeonColumn,
}

var selected_location := ""
var location_buttons: Dictionary = {}  # location -> Button
var notified_locations: Array = []

func _ready() -> void:
	GameState.set_clock_visible(false if standalone_mode else true)
	GameState.set_clock_paused(true)
	GameState.set_youns_status_visible(false)
	if standalone_mode:
		ZoneManager.set_world_visible(false)
		PartyManager.set_party_visible(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		interaction_enabled = false
	take_all_button.pressed.connect(_on_take_all)
	recipes_button.pressed.connect(func(): _set_view("recipes"))
	tech_tree_button.pressed.connect(func(): _set_view("tech_tree"))
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	LaboratoryState.recipe_unlocked.connect(_on_recipe_unlocked)
	LaboratoryState.pending_output_changed.connect(_sync_pending_output)
	LaboratoryState.recipes_loaded.connect(_on_recipes_loaded)
	LocalizationState.language_changed.connect(_apply_localized_text)
	close_button.pressed.connect(_close_or_return)
	_apply_mode_state()
	_apply_localized_text()
	if LaboratoryState.all_recipes.size() > 0:
		_on_recipes_loaded()

func _unhandled_input(event: InputEvent) -> void:
	if standalone_mode and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_or_return()

func _apply_mode_state() -> void:
	take_all_button.disabled = not interaction_enabled
	take_all_button.text = LocalizationState.t("lab.take_all_disabled") if not interaction_enabled else LocalizationState.t("lab.take_all")

func _set_view(view: String) -> void:
	var is_recipes := view == "recipes"
	columns_container.visible = is_recipes
	tech_tree_view.visible = not is_recipes
	recipes_button.button_pressed = is_recipes
	tech_tree_button.button_pressed = not is_recipes
	$RootVBox/ContentHBox/OutputPanel.visible = is_recipes
	$RootVBox/ContentHBox/LocationPanel.visible = is_recipes

func _on_recipes_loaded() -> void:
	_build_location_sidebar()
	_sync_pending_output()

# ── Sidebar ───────────────────────────────────────────────────────────────────

func _build_location_sidebar() -> void:
	for child in location_list.get_children():
		child.queue_free()
	location_buttons.clear()
	var seen: Array = []
	for recipe in LaboratoryState.all_recipes:
		if not LaboratoryState.is_recipe_unlocked(recipe.id) and not LaboratoryState.is_recipe_completed(recipe.id):
			continue
		if recipe.location not in seen:
			seen.append(recipe.location)
			_add_location_button(recipe.location)
	if seen.size() > 0:
		_select_location(seen[0])
	else:
		selected_location = ""

func _add_location_button(location: String) -> void:
	var btn := Button.new()
	btn.text = LocalizationState.location_name(location)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.toggle_mode = true
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.pressed.connect(func(): _select_location(location))
	location_list.add_child(btn)
	location_buttons[location] = btn

func _select_location(location: String) -> void:
	selected_location = location
	for loc in location_buttons:
		location_buttons[loc].button_pressed = (loc == location)
	_clear_notification(location)
	_refresh_columns()

func _set_notification(location: String) -> void:
	if location == selected_location or notified_locations.has(location):
		return
	notified_locations.append(location)
	if location_buttons.has(location):
		location_buttons[location].text = LocalizationState.location_name(location) + "  !"

func _clear_notification(location: String) -> void:
	if not notified_locations.has(location):
		return
	notified_locations.erase(location)
	if location_buttons.has(location):
		location_buttons[location].text = LocalizationState.location_name(location)

# ── Columnas ──────────────────────────────────────────────────────────────────

func _refresh_columns() -> void:
	for action_type in ACTION_TYPES:
		var column: Panel = columns[action_type]
		var recipe_list: VBoxContainer = column.recipe_list
		for child in recipe_list.get_children():
			child.queue_free()

		column.visible = LaboratoryState.is_column_unlocked(selected_location, action_type)

		var filtered := LaboratoryState.all_recipes.filter(
			func(r): return r.location == selected_location and r.action_type == action_type \
				and LaboratoryState.is_recipe_unlocked(r.id) \
				and not LaboratoryState.is_recipe_completed(r.id)
		)

		for recipe in filtered:
			var entry := RecipeEntry.instantiate()
			recipe_list.add_child(entry)
			entry.setup(recipe, interaction_enabled)
			if interaction_enabled:
				entry.activate_requested.connect(_on_activate_requested)

			if recipe.id == LaboratoryState.active_recipe_id:
				entry.set_active()
			elif LaboratoryState.recipe_progress.has(recipe.id):
				entry.set_paused(LaboratoryState.recipe_progress[recipe.id])

# ── Eventos ───────────────────────────────────────────────────────────────────

func _on_activate_requested(recipe: Resource) -> void:
	LaboratoryState.activate_recipe(recipe)
	_refresh_columns()

func _on_recipe_completed(_recipe: Resource) -> void:
	_refresh_columns()
	_sync_pending_output()

func _on_recipe_unlocked(recipe: Resource) -> void:
	if not location_buttons.has(recipe.location):
		_add_location_button(recipe.location)
		if selected_location == "":
			_select_location(recipe.location)
	_set_notification(recipe.location)
	if recipe.location == selected_location:
		_refresh_columns()

func _sync_pending_output() -> void:
	for child in output_list.get_children():
		child.queue_free()
	for item_id in LaboratoryState.pending_output:
		var entry: Dictionary = LaboratoryState.pending_output[item_id]
		var label := Label.new()
		var localized_item_id := str(entry.get("id", item_id))
		label.text = LocalizationState.t(
			"lab.output_count",
			[LocalizationState.item_name(localized_item_id, str(entry["name"])), entry["count"]]
		)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		output_list.add_child(label)

func _on_take_all() -> void:
	if not interaction_enabled:
		return
	var taken := LaboratoryState.take_all_output()
	for item_id in taken:
		# TODO: agregar item al inventario del jugador (id: item_id, count: taken[item_id]["count"])
		pass
	for child in output_list.get_children():
		child.queue_free()

func _close_or_return() -> void:
	if standalone_mode and GameState.ui_return_scene_path != "":
		var return_scene := GameState.ui_return_scene_path
		GameState.ui_return_scene_path = ""
		get_tree().change_scene_to_file(return_scene)
		return
	close_requested.emit()

func _apply_localized_text(_language: String = "") -> void:
	recipes_button.text = LocalizationState.t("lab.recipes")
	tech_tree_button.text = LocalizationState.t("lab.tech_tree")
	close_button.text = LocalizationState.t("lab.close")
	$RootVBox/ContentHBox/OutputPanel/VBox/Header.text = LocalizationState.t("lab.generated")
	_apply_mode_state()
	columns["instant"].title = LocalizationState.action_type_name("instant")
	columns["loop"].title = LocalizationState.action_type_name("loop")
	columns["upgrade"].title = LocalizationState.action_type_name("upgrade")
	columns["next"].title = LocalizationState.action_type_name("next")
	columns["dungeon"].title = LocalizationState.action_type_name("dungeon")
	for location in location_buttons:
		location_buttons[location].text = LocalizationState.location_name(location)
	_sync_pending_output()
	_refresh_columns()
