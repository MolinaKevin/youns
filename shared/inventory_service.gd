class_name InventoryService
extends RefCounted

const ItemCatalogScript := preload("res://shared/item_catalog.gd")
const Entry := preload("res://shared/inventory_entry.gd")

## Operaciones consistentes sobre el inventario persistido del jugador.
const MAX_STACK := 20

## Agrega una entrada sin crear pilas duplicadas. Devuelve cuánto entró y
## cuánto queda fuera por capacidad o por llegar al límite de la pila.
static func add_entry(items: Array[Dictionary], entry: Dictionary, capacity: int, max_stack := MAX_STACK) -> Dictionary:
	var requested := maxi(0, int(entry.get(Entry.COUNT, 1)))
	var item_id := Entry.item_id(entry)
	if requested == 0 or item_id.is_empty():
		return {"added": 0, "remaining": requested}
	for index in items.size():
		var existing: Dictionary = items[index]
		if Entry.item_id(existing) != item_id:
			continue
		var current := Entry.count_of(existing)
		var merged_count := mini(requested, maxi(0, max_stack - current))
		if merged_count > 0:
			existing[Entry.COUNT] = current + merged_count
			items[index] = existing
		return {"added": merged_count, "remaining": requested - merged_count}
	if items.size() >= maxi(0, capacity):
		return {"added": 0, "remaining": requested}
	var added := mini(requested, max_stack)
	var stored := entry.duplicate()
	stored[Entry.COUNT] = added
	items.append(stored)
	return {"added": added, "remaining": requested - added}

## Consume hasta `amount` unidades de una entrada y devuelve las que quitó.
static func consume_at(items: Array[Dictionary], index: int, amount := 1) -> int:
	if index < 0 or index >= items.size() or amount <= 0:
		return 0
	var entry: Dictionary = items[index]
	var count := maxi(0, int(entry.get(Entry.COUNT, 1)))
	var consumed := mini(count, amount)
	if count <= amount:
		items.remove_at(index)
	else:
		entry[Entry.COUNT] = count - amount
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
	var data_path := Entry.data_path(entry)
	if data_path.is_empty():
		return null
	return ItemCatalogScript.by_path(data_path)


## Reconstruye entradas persistidas con los datos actuales del catálogo. Descarta
## referencias inválidas, limita cada pila y une las que representan al mismo
## ítem sin superar la capacidad disponible.
static func sanitize_entries(entries: Array[Dictionary], capacity: int, max_stack := MAX_STACK) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	var slot_limit := maxi(0, capacity)
	var stack_limit := maxi(1, max_stack)
	for entry in entries:
		var count := Entry.count_of(entry)
		var data := resolve_item_data(entry)
		if count == 0 or data == null or data.id.is_empty():
			continue
		while count > 0:
			var merged := false
			for index in sanitized.size():
				var stored: Dictionary = sanitized[index]
				if Entry.item_id(stored) != data.id:
					continue
				var room := stack_limit - Entry.count_of(stored)
				if room <= 0:
					continue
				var merged_amount := mini(count, room)
				stored[Entry.COUNT] = Entry.count_of(stored) + merged_amount
				sanitized[index] = stored
				count -= merged_amount
				merged = true
				break
			if merged:
				continue
			if sanitized.size() >= slot_limit:
				break
			var added := mini(count, stack_limit)
			sanitized.append(Entry.make(data, added))
			count -= added
	return sanitized

## Consume hasta `amount` unidades de la entrada en `index` del inventario de
## la partida. Devuelve cuántas se sacaron.
static func consume_from_save(save: PlayerSaveData, index: int, amount := 1) -> int:
	if save == null:
		return 0
	return consume_at(save.inventory_items, index, amount)
