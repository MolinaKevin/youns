extends Control

const RecipeEntry := preload("res://scenes/laboratory/recipe_entry.tscn")
const ACTION_TYPES := ["instant", "loop", "upgrade", "next", "dungeon"]

@onready var location_list = $HBox/LocationPanel/LocationList
@onready var output_list = $HBox/OutputPanel/VBox/Scroll/OutputList
@onready var take_all_button = $HBox/OutputPanel/VBox/TakeAllButton
@onready var columns := {
	"instant": $HBox/MainArea/Columns/InstantColumn,
	"loop":    $HBox/MainArea/Columns/LoopColumn,
	"upgrade": $HBox/MainArea/Columns/UpgradeColumn,
	"next":    $HBox/MainArea/Columns/NextColumn,
	"dungeon": $HBox/MainArea/Columns/DungeonColumn,
}

var selected_location := ""

func _ready() -> void:
	take_all_button.pressed.connect(_on_take_all)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	_build_location_sidebar()
	_sync_pending_output()

# ── Sidebar ───────────────────────────────────────────────────────────────────

func _build_location_sidebar() -> void:
	for child in location_list.get_children():
		child.queue_free()
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

func _select_location(location: String) -> void:
	selected_location = location
	for btn in location_list.get_children():
		btn.button_pressed = btn.text.to_lower() == location.to_lower()
	_refresh_columns()

# ── Columnas ──────────────────────────────────────────────────────────────────

func _refresh_columns() -> void:
	for action_type in ACTION_TYPES:
		var column: Panel = columns[action_type]
		var recipe_list := column.get_node("VBox/Scroll/RecipeList")
		for child in recipe_list.get_children():
			child.queue_free()

		column.visible = LaboratoryState.is_column_unlocked(selected_location, action_type)

		var filtered := LaboratoryState.all_recipes.filter(
			func(r): return r.location == selected_location and r.action_type == action_type
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

func _sync_pending_output() -> void:
	for child in output_list.get_children():
		child.queue_free()
	for item in LaboratoryState.pending_output:
		var label := Label.new()
		label.text = item["name"]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		output_list.add_child(label)

func _on_take_all() -> void:
	var taken := LaboratoryState.take_all_output()
	for item in taken:
		# TODO: agregar item["reward"] al inventario del jugador
		pass
	for child in output_list.get_children():
		child.queue_free()
