class_name WorldYounConversation
extends RefCounted

## Diálogo previo al encuentro: lo reproduce, resuelve sus choices (si tiene)
## y decide si termina en combate o no. `host._combat_handoff.engage()` es
## quien arranca la pelea en serio — esta clase no sabe nada de popups ni de
## la escena de combate. `host` es el WorldYoun dueño exclusivo de esta
## instancia.

var host: WorldYoun

func _init(p_host: WorldYoun) -> void:
	host = p_host

func play() -> void:
	host._engaging_combat = true
	host._interaction.update_prompt_visibility()
	host._ai.start_idle()
	host.velocity = Vector3.ZERO
	if host._player:
		host._player.velocity = Vector3.ZERO
		var to_enemy := (host.global_position - host._player.global_position) * Vector3(1, 0, 1)
		if to_enemy.length() > 0.01:
			host._player.rotation.y = atan2(to_enemy.x, to_enemy.z)
		var to_player := ((host._player.global_position - host.global_position) * Vector3(1, 0, 1))
		if to_player.length() > 0.01:
			host.rotation.y = atan2(to_player.x, to_player.z)
	if not Dialogue.dialogue_finished.is_connected(_on_finished):
		Dialogue.dialogue_finished.connect(_on_finished, CONNECT_ONE_SHOT)
	DialogueLines.say_many(host.youn_data, host.conversation.to_entries())

func _on_finished() -> void:
	if host.conversation.choices.is_empty():
		if host.starts_combat:
			host._combat_handoff.engage()
		else:
			_resolve_without_combat()
		return
	_open_choices()

func _open_choices() -> void:
	var labels: Array[String] = []
	for choice in host.conversation.choices:
		labels.append(choice.label())
	var index: int = await Dialogue.ask(labels)
	var choice: NpcChoice = host.conversation.choices[index] if index >= 0 else null
	if choice != null:
		_apply_choice(choice)
	if choice != null and choice.starts_combat:
		host._combat_handoff.engage()
	else:
		_resolve_without_combat()

func _apply_choice(choice: NpcChoice) -> void:
	if choice.give_item != null:
		_give_item(choice.give_item)
	if choice.restore_energy:
		var ps := GameState.player_save
		if ps:
			ps.energia = 100
			GlobalHUD.notify_youns_status_changed()

func _give_item(item: ItemData) -> void:
	var ps := GameState.player_save
	if ps == null:
		return
	var display_name := LocalizationState.item_name(item.id, item.name)
	for i in ps.inventory_items.size():
		var entry: Dictionary = ps.inventory_items[i]
		if entry.get("id") == item.id:
			entry["count"] = entry.get("count", 0) + 1
			ps.inventory_items[i] = entry
			GlobalHUD.show_toast(LocalizationState.t("world.hub.received", [display_name]))
			return
	if ps.inventory_items.size() < ps.inventory_slots:
		ps.inventory_items.append(item.to_inventory_entry())
		GlobalHUD.show_toast(LocalizationState.t("world.hub.received", [display_name]))

func _resolve_without_combat() -> void:
	host._engaging_combat = false
	host._interaction.update_prompt_visibility()
	host._ai.start_idle()
