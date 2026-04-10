class_name LabRecipe
extends Resource

@export var id: String = ""
@export var recipe_name: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var craft_time: float = 10.0
@export var location: String = "lab"        # qué localización lo desbloquea en el sidebar
@export var action_type: String = "upgrade" # "instant", "loop", "upgrade", "next", "dungeon"
@export var reward: Dictionary = {}
@export var extra_rewards: Array[Dictionary] = []
@export var ingredients: Array[Dictionary] = []
@export var gold_cost: int = 0
@export var starts_unlocked: bool = false
@export var needs_research: bool = false
