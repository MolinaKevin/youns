extends Control

signal close_requested

const RecipeEntry := preload("res://features/laboratory/scene/recipe_entry.tscn")
const ACTION_TYPES := ["instant", "loop", "upgrade", "next", "dungeon"]

@export var standalone_mode := true

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
	if standalone_mode:
		ZoneManager.set_world_visible(false)
		PartyManager.set_party_visible(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	take_all_button.pressed.connect(_on_take_all)
	recipes_button.pressed.connect(func(): _set_view("recipes"))
	tech_tree_button.pressed.connect(func(): _set_view("tech_tree"))
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	LaboratoryState.recipe_unlocked.connect(_on_recipe_unlocked)
	LaboratoryState.pending_output_changed.connect(_sync_pending_output)
	LaboratoryState.recipes_loaded.connect(_on_recipes_loaded)
	close_button.pressed.connect(func(): close_requested.emit())
	if LaboratoryState.all_recipes.size() > 0:
		_on_recipes_loaded()

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
		if recipe.location not in seen:
			seen.append(recipe.location)
			_add_location_button(recipe.location)
	if seen.size() > 0:
		_select_location(seen[0])

func _add_location_button(location: String) -> void:
	var btn := Button.new()
	btn.text = location.capitalize()
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
		location_buttons[location].text = location.capitalize() + "  !"

func _clear_notification(location: String) -> void:
	if not notified_locations.has(location):
		return
	notified_locations.erase(location)
	if location_buttons.has(location):
		location_buttons[location].text = location.capitalize()

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
			entry.setup(recipe)
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
	_set_notification(recipe.location)
	if recipe.location == selected_location:
		_refresh_columns()

func _sync_pending_output() -> void:
	for child in output_list.get_children():
		child.queue_free()
	for item_id in LaboratoryState.pending_output:
		var entry: Dictionary = LaboratoryState.pending_output[item_id]
		var label := Label.new()
		label.text = "%s x%d" % [entry["name"], entry["count"]]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		output_list.add_child(label)

func _on_take_all() -> void:
	var taken := LaboratoryState.take_all_output()
	for item_id in taken:
		# TODO: agregar item al inventario del jugador (id: item_id, count: taken[item_id]["count"])
		pass
	for child in output_list.get_children():
		child.queue_free()
