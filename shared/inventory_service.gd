class_name InventoryService
extends RefCounted

## Operaciones consistentes sobre el inventario persistido del jugador.
const MAX_STACK := 20

## Agrega una entrada sin crear pilas duplicadas. Devuelve cuánto entró y
## cuánto queda fuera por capacidad o por llegar al límite de la pila.
static func add_entry(items: Array[Dictionary], entry: Dictionary, capacity: int, max_stack := MAX_STACK) -> Dictionary:
	var requested := maxi(0, int(entry.get("count", 1)))
	var item_id := str(entry.get("id", ""))
	if requested == 0 or item_id.is_empty():
		return {"added": 0, "remaining": requested}
	for index in items.size():
		var existing: Dictionary = items[index]
		if str(existing.get("id", "")) != item_id:
			continue
		var current := maxi(0, int(existing.get("count", 0)))
		var added := mini(requested, maxi(0, max_stack - current))
		if added > 0:
			existing["count"] = current + added
			items[index] = existing
		return {"added": added, "remaining": requested - added}
	if items.size() >= maxi(0, capacity):
		return {"added": 0, "remaining": requested}
	var added := mini(requested, max_stack)
	var stored := entry.duplicate()
	stored["count"] = added
	items.append(stored)
	return {"added": added, "remaining": requested - added}

## Consume hasta `amount` unidades de una entrada y devuelve las que quitó.
static func consume_at(items: Array[Dictionary], index: int, amount := 1) -> int:
	if index < 0 or index >= items.size() or amount <= 0:
		return 0
	var entry: Dictionary = items[index]
	var count := maxi(0, int(entry.get("count", 1)))
	var consumed := mini(count, amount)
	if count <= amount:
		items.remove_at(index)
	else:
		entry["count"] = count - amount
		items[index] = entry
	return consumed

## Entrada en `index` del inventario de la partida, o {} si está fuera de
## rango. Así las pantallas no repiten el chequeo de límites a mano.
static func item_at(save: PlayerSaveData, index: int) -> Dictionary:
	if save == null or index < 0 or index >= save.inventory_items.size():
		return {}
	return save.inventory_items[index]

## El ItemData de una entrada guardada, o null si la ruta no es válida (ítem
## de una versión vieja del juego, asset borrado, etc.).
static func resolve_item_data(entry: Dictionary) -> ItemData:
	var data_path := str(entry.get("data_path", ""))
	if data_path.is_empty() or not ResourceLoader.exists(data_path):
		return null
	return load(data_path) as ItemData

## Consume hasta `amount` unidades de la entrada en `index` del inventario de
## la partida. Devuelve cuántas se sacaron.
static func consume_from_save(save: PlayerSaveData, index: int, amount := 1) -> int:
	if save == null:
		return 0
	return consume_at(save.inventory_items, index, amount)
