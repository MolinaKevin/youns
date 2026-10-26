extends ItemEffect
class_name ItemEffectGive

const InventoryService := preload("res://shared/inventory_service.gd")
const MAX_STACK := InventoryService.MAX_STACK

enum GiveType { GOLD, CARD, ITEM }

@export var give_type: GiveType = GiveType.GOLD
@export var amount: int = 1
## ID de la card o del item a entregar (ignorado para GOLD)
@export var give_id: String = ""
## Ruta al ItemData del item a entregar (solo para GiveType.ITEM)
@export var item_data_path: String = ""

func apply(save: PlayerSaveData) -> void:
	match give_type:
		GiveType.GOLD:
			save.gold += amount
		GiveType.CARD:
			if not give_id.is_empty() and give_id not in save.owned_card_ids:
				save.owned_card_ids.append(give_id)
		GiveType.ITEM:
			if item_data_path.is_empty():
				return
			var data := load(item_data_path) as ItemData
			if data == null:
				return
			apply_item(save.inventory_items, data, save.inventory_slots)

func apply_item(items: Array[Dictionary], data: ItemData, capacity := 999999) -> Dictionary:
	return InventoryService.add_entry(items, {
		"id": data.id,
		"name": data.name,
		"icon": data.icon.resource_path if data.icon else "",
		"data_path": item_data_path,
		"count": amount,
	}, capacity, MAX_STACK)
