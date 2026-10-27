class_name PlayerSessionService
extends RefCounted

## Fachada de operaciones de partida que necesitan las pantallas. Evita que
## cada UI conozca la estructura de PlayerSaveData o los autoloads de cuidado.

const InventoryService := preload("res://shared/inventory_service.gd")

var _save_provider: Callable
var _care_action: Callable
var _status_changed: Callable


func _init(save_provider: Callable, care_action: Callable, status_changed: Callable) -> void:
	_save_provider = save_provider
	_care_action = care_action
	_status_changed = status_changed


func inventory_capacity() -> int:
	var save := _save()
	return maxi(20, save.inventory_slots) if save else 20


func inventory_items() -> Array:
	var save := _save()
	return save.inventory_items if save else []


func inventory_item_at(index: int) -> Dictionary:
	return InventoryService.item_at(_save(), index)


## "used", "combat_only", "invalid" o "missing".
func use_inventory_item(index: int) -> String:
	var save := _save()
	var item := InventoryService.item_at(save, index)
	if item.is_empty():
		return "missing"
	var data := InventoryService.resolve_item_data(item)
	if data == null:
		return "invalid"
	if data.is_combat_only():
		return "combat_only"
	data.apply_effects(save)
	_status_changed.call()
	InventoryService.consume_from_save(save, index)
	return "used"


func discard_inventory_item(index: int) -> int:
	return InventoryService.consume_from_save(_save(), index)


func deck_cards() -> Array[CardData]:
	var save := _save()
	return DeckRules.cards(save).duplicate() if save else []


func replace_deck(cards: Array[CardData]) -> void:
	var save := _save()
	if save:
		save.deck = cards.duplicate()


func owned_cards() -> Array[CardData]:
	var save := _save()
	if save == null:
		return []
	var cards: Array[CardData] = []
	cards.append_array(save.saved_cards)
	cards.append_array(CardDatabase.get_cards_from_ids(save.owned_card_ids))
	return cards


func care(action: String) -> bool:
	if action not in ["reward", "punish", "deny", "play"]:
		return false
	_care_action.call(action)
	return true


func _save() -> PlayerSaveData:
	return _save_provider.call() as PlayerSaveData
