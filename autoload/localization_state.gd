extends Node

signal language_changed(language: String)

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "general"
const SETTINGS_KEY_LANGUAGE := "language"

const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["es", "en"]

const STRINGS := {
	"es": {
		"title.prototype": "PROTOTYPE",
		"title.subtitle": "Roguelike de cartas, crianza y exploracion",
		"title.selected": "Seleccionado: %s",
		"title.world_status": "ESTADO DEL MUNDO",
		"title.world_name": "Sector Lab / Ciudad Baja",
		"title.description": "Demo",
		"title.features": "Construi tu mazo.\nCria a tu Youn.\nExplora la ciudad y el laboratorio.",
		"title.nav_hint": "Flechas para navegar. Enter para confirmar.",
		"title.menu.new_game": "Nueva partida",
		"title.menu.quick_battle": "Combate rapido",
		"title.menu.lab": "Laboratorio",
		"title.menu.deck_builder": "Constructor de mazo",
		"title.menu.language": "Idioma",
		"title.menu.exit": "Salir",
		"language.title": "Elegi idioma",
		"language.subtitle": "Podes cambiarlo mas tarde desde este menu.",
		"language.es": "Espanol",
		"language.en": "English",
		"language.current": "Idioma actual: %s",
		"main_menu.lab": "Laboratorio",
		"main_menu.combat": "Combate",
		"main_menu.deck": "Mazo",
		"main_menu.map": "Mapa",
		"main_menu.inventory": "Inventario",
		"main_menu.save": "Guardar",
		"main_menu.gold": "Oro: %d",
		"main_menu.year": "%d Año",
		"main_menu.day": "%d Día",
		"pause.title": "Pausa",
		"pause.continue": "Continuar",
		"pause.deck": "Mazo",
		"pause.exit": "Salir",
		"inventory.title": "Inventario",
		"inventory.count": "%d / %d",
		"inventory.close": "Cerrar",
		"inventory.use": "Usar",
		"inventory.drop": "Tirar",
		"inventory.cancel": "Cancelar",
		"inventory.item_default": "Item",
		"inventory.count_short": "x%d",
		"deck.title": "Constructor de mazo",
		"deck.save": "Guardar",
		"deck.select_card": "Seleccioná una carta",
		"deck.add": "Agregar al deck",
		"deck.my_deck": "Mi Deck",
		"deck.count": "%d cartas",
		"deck.remove": "X",
		"deck.preview": "%s\nCosto: %d | Tipo: %s\n\n%s",
		"card_type.move": "Movimiento",
		"card_type.range_attack": "Ataque a distancia",
		"card_type.melee_attack": "Ataque cuerpo a cuerpo",
		"card_type.targeted_attack": "Ataque dirigido",
		"card_type.block": "Bloqueo",
		"card_type.trap_place": "Trampa cercana",
		"card_type.trap_throw": "Trampa arrojadiza",
		"card_type.grenade": "Granada",
		"lab.recipes": "Recetas",
		"lab.tech_tree": "Árbol de Tecnologías",
		"lab.close": "✕ Cerrar",
		"lab.generated": "Generado",
		"lab.take_all": "Sacar todo",
		"lab.take_all_disabled": "Solo disponible el laboratorio",
		"lab.need_prefix": "Necesita: ",
		"lab.gold_cost": "%d oro",
		"lab.output_count": "%s x%d",
		"lab.location.produccion": "Producción",
		"lab.location.analisis": "Análisis",
		"lab.location.bio": "Bio",
		"lab.location.infraestructura": "Infraestructura",
		"lab.location.sistemas": "Sistemas",
		"lab.location.lab": "Lab",
		"lab.location.city": "Ciudad",
		"lab.action.instant": "Instantánea",
		"lab.action.loop": "Bucle",
		"lab.action.upgrade": "Mejora",
		"lab.action.next": "Siguiente",
		"lab.action.dungeon": "Mazmorra",
		"day_clock.day": "Día %d",
		"status.title": "ESTADO YOUN",
		"status.discipline": "Disciplina",
		"status.care_mistakes": "Errores de cuidado",
		"world.prompt.talk": "Hablar [E]",
		"world.prompt.view_clock": "Ver reloj [E]",
		"world.prompt.close_clock": "Cerrar reloj [Esc]",
		"world.demo.monzaemon": "Monzaemon: Eso es todo lo que tiene el demo por ahora. Gracias por jugar.",
		"world.enemy.intercepted": "%s te interceptó",
		"world.intro.hint": "Enter o Espacio para continuar (%d/%d)",
		"world.intro.page_1.title": "Bienvenido",
		"world.intro.page_1.body": "[center]Esto es un demo corto de Youns.[/center]",
		"world.intro.page_2.title": "Moverse",
		"world.intro.page_2.body": "Usa [b]WASD[/b] para moverte.\nMueve la cámara con el mouse.\nCon Tab abrís menú.",
		"world.intro.page_3.title": "Enemigos",
		"world.intro.page_3.body": "Si un enemigo te toca, te intercepta y entrás en combate.\nEl sistema de combate es una suerte de deck builder táctico.",
		"world.intro.page_4.title": "LAB",
		"world.intro.page_4.body": "Otra mecánica importante del juego es el laboratorio incremental.\nPodés acceder hablando con el NPC dentro del lab.",
		"combat.hand": "Mano",
		"combat.draw_pile": "Mazo (%d)",
		"combat.discard_pile": "Descarte (%d)",
		"combat.end_move": "Fin movimiento",
		"combat.confirm_action": "Confirmar acción",
		"combat.yes": "Sí",
		"combat.no": "No",
		"combat.finish": "Terminar",
		"combat.move": "Mover",
		"combat.end_turn": "Fin de turno",
		"combat.player_stats": "HP: %d | Bloqueo: %d | Energía: %d | HP enemigo: %d",
		"combat.intent.attack": "Intención: Atacar %d",
		"combat.intent.range_attack": "Intención: Disparar %d",
		"combat.intent.move": "Intención: Moverse",
		"combat.intent.retreat": "Intención: Retirarse",
		"combat.intent.block": "Intención: Bloquear %d",
		"combat.intent.wait": "Intención: Esperar",
		"combat.started": "Combate iniciado contra %s.",
		"combat.reshuffle": "Mazo vacío. Se mezcló el descarte.",
		"combat.win": "Ganaste.",
		"combat.lose": "Perdiste.",
		"card.name.step": "Paso",
		"card.name.dash": "Sprint",
		"card.name.strike": "Golpe",
		"card.name.slash": "Corte",
		"card.name.block": "Bloqueo",
		"card.name.meteor": "Meteorito",
		"card.name.arrow": "Flecha",
		"card.name.snipe": "Disparo preciso",
		"card.name.grenade": "Granada",
		"card.name.bear_trap": "Trampa de oso",
		"card.name.spike_trap": "Trampa de púas",
		"card.desc.step": "Movete una distancia corta.",
		"card.desc.dash": "Hacé un dash largo rápidamente.",
		"card.desc.strike": "Golpeá a un enemigo cercano por 6 de daño.",
		"card.desc.slash": "Atacá con un arco amplio por 15 de daño.",
		"card.desc.block": "Ganá bloqueo para absorber daño entrante.",
		"card.desc.meteor": "Invocá un meteorito sobre un objetivo por 15 de daño.",
		"card.desc.arrow": "Dispará una flecha a distancia por 4 de daño.",
		"card.desc.snipe": "Disparo preciso de largo alcance por 9 de daño.",
		"card.desc.grenade": "Lanzá una granada que rebota hacia adelante. Coeficiente de rebote: 0.4.",
		"card.desc.bear_trap": "Colocá una trampa cercana. El enemigo recibe daño al pararse sobre ella.",
		"card.desc.spike_trap": "Lanzá una trampa a cualquier parte del mapa. El enemigo recibe daño al pararse sobre ella.",
		"recipe.name.producir_datos": "Producir Datos",
		"recipe.name.terminal_de_analisis": "Terminal de Análisis",
		"recipe.name.reloj_de_sistema": "Reloj de Sistema",
		"recipe.name.contador_de_crianza": "Contador de Crianza",
		"recipe.name.biolectura_inicial": "Biolectura Inicial",
		"recipe.name.estimulacion_suave": "Estimulación Suave",
		"recipe.name.kit_de_topografia": "Kit de Topografía",
		"recipe.name.estudio_de_puente_ligero": "Estudio de Puente Ligero",
		"recipe.name.construccion_de_puente": "Construcción de Puente",
		"recipe.name.archivo_de_campo": "Archivo de Campo",
		"recipe.name.investigar_suero_loco": "Investigar Suero Loco",
		"recipe.name.investigar_suero_muy_loco": "Investigar Suero Muy Loco",
		"recipe.name.suero_potenciado": "Suero Potenciado",
		"recipe.name.suero_produccion": "Suero de Producción",
		"recipe.desc.producir_datos": "Recolecta y ordena datos básicos para habilitar nuevas investigaciones.",
		"recipe.desc.terminal_de_analisis": "Instala una terminal base en la ciudad para expandir la investigación del laboratorio.",
		"recipe.desc.reloj_de_sistema": "Integra un reloj visible permanente en la UI para seguir el paso del tiempo mientras explorás.",
		"recipe.desc.contador_de_crianza": "Agrega barras visibles permanentes para seguir la disciplina y los errores de cuidado del Youn.",
		"recipe.desc.biolectura_inicial": "Instala un monitoreo simple para observar mejor el estado general del Youn.",
		"recipe.desc.estimulacion_suave": "Aplica una mejora basal para favorecer el desarrollo temprano del Youn.",
		"recipe.desc.kit_de_topografia": "Prepara instrumental base para estudiar un cruce seguro sobre el río. Idealmente debería costar 100 de oro.",
		"recipe.desc.estudio_de_puente_ligero": "Analiza materiales y trazado para construir un puente por encima del río.",
		"recipe.desc.construccion_de_puente": "Levanta una estructura básica para cruzar el río y abrir una nueva ruta.",
		"recipe.desc.archivo_de_campo": "Compila observaciones útiles para futuras investigaciones.",
		"recipe.desc.investigar_suero_loco": "Estudia la fórmula del Suero Loco para poder fabricarlo.",
		"recipe.desc.investigar_suero_muy_loco": "Estudia la fórmula del Suero Muy Loco.",
		"recipe.desc.suero_potenciado": "Combina vitalidad y defensas en un suero de alto impacto.",
		"recipe.desc.suero_produccion": "Aumenta la producción de materiales de la ciudad.",
		"item.name.datos": "Datos",
		"item.name.archivo_campo": "Archivo de Campo",
		"item.name.kit_topografia": "Kit de Topografía",
		"item.name.agumon_fang": "Colmillo de Agumon",
		"item.name.bear_plush": "Peluche de oso",
		"item.name.broken_arrow": "Flecha rota",
		"item.name.suero_vitalidad": "Suero Vitalidad",
		"item.name.field_data": "Datos de campo",
		"enemy.name.goblin": "Goblin",
		"enemy.name.agumon": "Agumon",
		"enemy.name.archer": "Arquero",
		"enemy.name.monzaemon": "Monzaemon"
	},
	"en": {
		"title.prototype": "PROTOTYPE",
		"title.subtitle": "Card roguelike, creature raising and exploration",
		"title.selected": "Selected: %s",
		"title.world_status": "WORLD STATUS",
		"title.world_name": "Lab Sector / Lower City",
		"title.description": "Demo",
		"title.features": "Build your deck.\nRaise your Youn.\nExplore the city and the laboratory.",
		"title.nav_hint": "Use arrows to navigate. Press Enter to confirm.",
		"title.menu.new_game": "New Game",
		"title.menu.quick_battle": "Quick Battle",
		"title.menu.lab": "Laboratory",
		"title.menu.deck_builder": "Deck Builder",
		"title.menu.language": "Language",
		"title.menu.exit": "Exit",
		"language.title": "Choose language",
		"language.subtitle": "You can change it later from this menu.",
		"language.es": "Spanish",
		"language.en": "English",
		"language.current": "Current language: %s",
		"main_menu.lab": "Laboratory",
		"main_menu.combat": "Combat",
		"main_menu.deck": "Deck",
		"main_menu.map": "Map",
		"main_menu.inventory": "Inventory",
		"main_menu.save": "Save",
		"main_menu.gold": "Gold: %d",
		"main_menu.year": "Year %d",
		"main_menu.day": "Day %d",
		"pause.title": "Pause",
		"pause.continue": "Continue",
		"pause.deck": "Deck",
		"pause.exit": "Exit",
		"inventory.title": "Inventory",
		"inventory.count": "%d / %d",
		"inventory.close": "Close",
		"inventory.use": "Use",
		"inventory.drop": "Drop",
		"inventory.cancel": "Cancel",
		"inventory.item_default": "Item",
		"inventory.count_short": "x%d",
		"deck.title": "Deck Builder",
		"deck.save": "Save",
		"deck.select_card": "Select a card",
		"deck.add": "Add to deck",
		"deck.my_deck": "My Deck",
		"deck.count": "%d cards",
		"deck.remove": "X",
		"deck.preview": "%s\nCost: %d | Type: %s\n\n%s",
		"card_type.move": "Move",
		"card_type.range_attack": "Ranged Attack",
		"card_type.melee_attack": "Melee Attack",
		"card_type.targeted_attack": "Targeted Attack",
		"card_type.block": "Block",
		"card_type.trap_place": "Nearby Trap",
		"card_type.trap_throw": "Thrown Trap",
		"card_type.grenade": "Grenade",
		"lab.recipes": "Recipes",
		"lab.tech_tree": "Tech Tree",
		"lab.close": "✕ Close",
		"lab.generated": "Generated",
		"lab.take_all": "Take all",
		"lab.take_all_disabled": "Only available in the laboratory",
		"lab.need_prefix": "Needs: ",
		"lab.gold_cost": "%d gold",
		"lab.output_count": "%s x%d",
		"lab.location.produccion": "Production",
		"lab.location.analisis": "Analysis",
		"lab.location.bio": "Bio",
		"lab.location.infraestructura": "Infrastructure",
		"lab.location.sistemas": "Systems",
		"lab.location.lab": "Lab",
		"lab.location.city": "City",
		"lab.action.instant": "Instant",
		"lab.action.loop": "Loop",
		"lab.action.upgrade": "Upgrade",
		"lab.action.next": "Next",
		"lab.action.dungeon": "Dungeon",
		"day_clock.day": "Day %d",
		"status.title": "YOUN STATUS",
		"status.discipline": "Discipline",
		"status.care_mistakes": "Care Mistakes",
		"world.prompt.talk": "Talk [E]",
		"world.prompt.view_clock": "View clock [E]",
		"world.prompt.close_clock": "Close clock [Esc]",
		"world.demo.monzaemon": "Monzaemon: That's everything the demo has for now. Thanks for playing.",
		"world.enemy.intercepted": "%s intercepted you",
		"world.intro.hint": "Enter or Space to continue (%d/%d)",
		"world.intro.page_1.title": "Welcome",
		"world.intro.page_1.body": "[center]This is a short Youns demo.[/center]",
		"world.intro.page_2.title": "Movement",
		"world.intro.page_2.body": "Use [b]WASD[/b] to move.\nMove the camera with the mouse.\nPress Tab to open the menu.",
		"world.intro.page_3.title": "Enemies",
		"world.intro.page_3.body": "If an enemy touches you, it intercepts you and combat starts.\nThe combat system is a kind of tactical deck builder.",
		"world.intro.page_4.title": "LAB",
		"world.intro.page_4.body": "Another key mechanic is the incremental lab.\nYou can access it by talking to the NPC inside the lab.",
		"combat.hand": "Hand",
		"combat.draw_pile": "Draw (%d)",
		"combat.discard_pile": "Discard (%d)",
		"combat.end_move": "End move",
		"combat.confirm_action": "Confirm action",
		"combat.yes": "Yes",
		"combat.no": "No",
		"combat.finish": "Finish",
		"combat.move": "Move",
		"combat.end_turn": "End Turn",
		"combat.player_stats": "HP: %d | Block: %d | Energy: %d | Enemy HP: %d",
		"combat.intent.attack": "Intent: Attack %d",
		"combat.intent.range_attack": "Intent: Shoot %d",
		"combat.intent.move": "Intent: Move",
		"combat.intent.retreat": "Intent: Retreat",
		"combat.intent.block": "Intent: Block %d",
		"combat.intent.wait": "Intent: Wait",
		"combat.started": "Combat started against %s.",
		"combat.reshuffle": "Draw pile empty. Discard pile was shuffled back in.",
		"combat.win": "You win.",
		"combat.lose": "You lose.",
		"card.name.step": "Step",
		"card.name.dash": "Dash",
		"card.name.strike": "Strike",
		"card.name.slash": "Slash",
		"card.name.block": "Block",
		"card.name.meteor": "Meteor",
		"card.name.arrow": "Arrow",
		"card.name.snipe": "Snipe",
		"card.name.grenade": "Grenade",
		"card.name.bear_trap": "Bear Trap",
		"card.name.spike_trap": "Spike Trap",
		"card.desc.step": "Move a short distance.",
		"card.desc.dash": "Dash a long distance quickly.",
		"card.desc.strike": "Strike a nearby enemy for 6 damage.",
		"card.desc.slash": "Slash with a wide swing for 15 damage.",
		"card.desc.block": "Gain block to absorb incoming damage.",
		"card.desc.meteor": "Call down a meteor on a target for 15 damage.",
		"card.desc.arrow": "Shoot an arrow at range for 4 damage.",
		"card.desc.snipe": "Long-range precise shot for 9 damage.",
		"card.desc.grenade": "Throw a grenade that bounces forward. Bounce coefficient: 0.4.",
		"card.desc.bear_trap": "Place a trap nearby. Enemy takes damage when standing on it.",
		"card.desc.spike_trap": "Throw a trap anywhere on the map. Enemy takes damage when standing on it.",
		"recipe.name.producir_datos": "Produce Data",
		"recipe.name.terminal_de_analisis": "Analysis Terminal",
		"recipe.name.reloj_de_sistema": "System Clock",
		"recipe.name.contador_de_crianza": "Care Counter",
		"recipe.name.biolectura_inicial": "Initial Bio Reading",
		"recipe.name.estimulacion_suave": "Gentle Stimulation",
		"recipe.name.kit_de_topografia": "Survey Kit",
		"recipe.name.estudio_de_puente_ligero": "Light Bridge Study",
		"recipe.name.construccion_de_puente": "Bridge Construction",
		"recipe.name.archivo_de_campo": "Field Archive",
		"recipe.name.investigar_suero_loco": "Research Crazy Serum",
		"recipe.name.investigar_suero_muy_loco": "Research Very Crazy Serum",
		"recipe.name.suero_potenciado": "Enhanced Serum",
		"recipe.name.suero_produccion": "Production Serum",
		"recipe.desc.producir_datos": "Collect and organize basic data to unlock new research.",
		"recipe.desc.terminal_de_analisis": "Install a basic city terminal to expand laboratory research.",
		"recipe.desc.reloj_de_sistema": "Integrate a permanent visible clock into the UI to track time while exploring.",
		"recipe.desc.contador_de_crianza": "Adds permanent visible bars to track discipline and care mistakes for the Youn.",
		"recipe.desc.biolectura_inicial": "Install simple monitoring to better observe the Youn's overall condition.",
		"recipe.desc.estimulacion_suave": "Apply a baseline improvement to support early Youn development.",
		"recipe.desc.kit_de_topografia": "Prepare the base tools needed to study a safe river crossing. Ideally this should cost 100 gold.",
		"recipe.desc.estudio_de_puente_ligero": "Analyze materials and layout to build a bridge over the river.",
		"recipe.desc.construccion_de_puente": "Raise a basic structure to cross the river and open a new route.",
		"recipe.desc.archivo_de_campo": "Compile useful observations for future investigations.",
		"recipe.desc.investigar_suero_loco": "Study the Crazy Serum formula so it can be crafted.",
		"recipe.desc.investigar_suero_muy_loco": "Study the Very Crazy Serum formula.",
		"recipe.desc.suero_potenciado": "Combine vitality and defenses into a high-impact serum.",
		"recipe.desc.suero_produccion": "Increase city material production.",
		"item.name.datos": "Data",
		"item.name.archivo_campo": "Field Archive",
		"item.name.kit_topografia": "Survey Kit",
		"item.name.agumon_fang": "Agumon Fang",
		"item.name.bear_plush": "Bear Plush",
		"item.name.broken_arrow": "Broken Arrow",
		"item.name.suero_vitalidad": "Vitality Serum",
		"item.name.field_data": "Field Data",
		"enemy.name.goblin": "Goblin",
		"enemy.name.agumon": "Agumon",
		"enemy.name.archer": "Archer",
		"enemy.name.monzaemon": "Monzaemon"
	}
}

var current_language := DEFAULT_LANGUAGE
var _has_saved_language := false

func _ready() -> void:
	_load_language()

func has_saved_language() -> bool:
	return _has_saved_language

func get_language_name(language: String = current_language) -> String:
	return t("language.%s" % language)

func location_name(location_id: String) -> String:
	return t("lab.location.%s" % location_id)

func action_type_name(action_type: String) -> String:
	return t("lab.action.%s" % action_type)

func card_name(card_id: String, fallback: String = "") -> String:
	return t("card.name.%s" % card_id) if has_key("card.name.%s" % card_id) else fallback

func card_description(card_id: String, fallback: String = "") -> String:
	return t("card.desc.%s" % card_id) if has_key("card.desc.%s" % card_id) else fallback

func card_type_name(card_type: String) -> String:
	return t("card_type.%s" % card_type) if has_key("card_type.%s" % card_type) else card_type

func recipe_name(recipe_id: String, fallback: String = "") -> String:
	return t("recipe.name.%s" % recipe_id) if has_key("recipe.name.%s" % recipe_id) else fallback

func recipe_description(recipe_id: String, fallback: String = "") -> String:
	return t("recipe.desc.%s" % recipe_id) if has_key("recipe.desc.%s" % recipe_id) else fallback

func item_name(item_id: String, fallback: String = "") -> String:
	return t("item.name.%s" % item_id) if has_key("item.name.%s" % item_id) else fallback

func enemy_name(enemy_id: String, fallback: String = "") -> String:
	return t("enemy.name.%s" % enemy_id) if has_key("enemy.name.%s" % enemy_id) else fallback

func t(key: String, args: Array = []) -> String:
	var table: Dictionary = STRINGS.get(current_language, STRINGS[DEFAULT_LANGUAGE])
	var fallback: Dictionary = STRINGS[DEFAULT_LANGUAGE]
	var text: String = table.get(key, fallback.get(key, key))
	return text % args if not args.is_empty() else text

func has_key(key: String) -> bool:
	var table: Dictionary = STRINGS.get(current_language, STRINGS[DEFAULT_LANGUAGE])
	var fallback: Dictionary = STRINGS[DEFAULT_LANGUAGE]
	return table.has(key) or fallback.has(key)

func set_language(language: String) -> void:
	if language not in SUPPORTED_LANGUAGES:
		return
	current_language = language
	_has_saved_language = true
	_save_language()
	language_changed.emit(language)

func _load_language() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_language := str(config.get_value(SETTINGS_SECTION, SETTINGS_KEY_LANGUAGE, DEFAULT_LANGUAGE))
		if saved_language in SUPPORTED_LANGUAGES:
			current_language = saved_language
			_has_saved_language = true

func _save_language() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY_LANGUAGE, current_language)
	config.save(SETTINGS_PATH)
