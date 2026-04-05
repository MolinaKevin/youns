class_name LabRecipe
extends Resource

@export var id: String = ""
@export var recipe_name: String = ""
@export var description: String = ""
@export var craft_time: float = 10.0
@export var location: String = "lab"        # qué localización lo desbloquea en el sidebar
@export var action_type: String = "upgrade" # "instant", "loop", "upgrade", "next", "dungeon"
@export var reward: Dictionary = {}
@export var ingredients: Array[Dictionary] = []
