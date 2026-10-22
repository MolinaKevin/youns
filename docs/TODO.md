# TODO

Pendientes conocidos, agrupados por sistema. Al resolver uno, borrarlo de acá.

## Partida y guardado

- [ ] **Estaciones de guardado**: hay una sola (en el hub, modelo
      placeholder); falta decidir dónde van las demás.
- [ ] **Inicio de partida hardcodeado**: toda partida arranca con Nguruvilu
      (rookie) y stats fijas (`STARTING_YOUN_PATH` / `STARTING_STATS` en
      `game_state.gd`; el modelo del grupo también está fijo en `party.tscn`).
      Idea final: un diálogo al inicio que, según lo que responda el jugador,
      le da uno de 2 Youns iniciales rookie.

## Estados y cuidado del Youn

- [ ] **Salud, balance**: baja sola 0,5 por hora y de golpe con el
      vencimiento de *hungry* (−40), el accidente de baño (−5) y no dormir
      (−20). Sube comiendo (+5 por defecto; cada comida puede tener la suya,
      también negativa: `health_gain` en `ItemEffectMeal`, null = por defecto),
      durmiendo (+2 por hora, hasta 8 h: `StatsManager.SLEEP_HEALTH_*`) y con
      el antídoto (+60). Con poca salud las cartas rinden menos (−10 % bajo
      60, −25 % bajo 30, `CardScaling.HEALTH_PENALTIES`) y en 0 el Youn muere
      sin dejar carta. Todos los números son a balancear.
- [ ] **Vidas** (después del demo): hay 3 y se pierde una si el Youn muere
      por salud. Falta cómo se recuperan (tiene que ser fácil) y qué pasa al
      quedarse sin ninguna (hoy no pasa nada: se queda en 0).
- [ ] La caca del accidente de baño es un placeholder de primitivas
      (`features/world/items/poop.gd`): falta modelo real, animación y que se
      pueda limpiar.
- [ ] El desgaste por hora (`apply_stat_decay`) ignora los multiplicadores
      `mult_<stat>` del Youn; `add_stat` sí los usa.
- [ ] En las reglas con curva, `threshold` y `comparison` no se usan para
      activar (`comparison` solo decide hacia dónde es "mejorar").
- [ ] `vaciador_estomago.tres` setea `is_hungry`, que no existe en el save.

## Gimnasio

- [ ] El entrenamiento **bonus** es igual al normal (+10, 1 h): falta
      definirlo (`features/world/ui/training_overlay.gd`, `TRAININGS`).

## Laboratorio

- [ ] **Recetas y recursos del laboratorio**: retomar el diseño e
      implementación de recetas que consuman los recursos nuevos. Los **Ecos
      de color** ya se obtienen al jugar cartas y se guardan en el depósito
      del laboratorio; falta definir y conectar las **Resonancias de
      inteligencia** garantizadas al vencer Youns, las **Muestras de hábitat**
      raras (10 %), y recetas que combinen estos recursos con Datos.

## Mundo exterior

- [ ] **Animaciones del personaje principal**: se usan idle, run, walk (en
      la secuencia del baño) y, en el menú rápido (G), item_give (premiar),
      happy (jugar), angry (castigar) y talk (negar), con la escena de
      `youn_interaction.gd` (el jugador mira al Youn, el Youn se acerca, la
      animación y después los cambios de stats). Faltan interact (estaciones,
      puertas), pickup_floor/pickup_waist (levantar ítems) y think (¿guardar?).
      El Youn todavía no reacciona (no tiene animaciones propias de
      contento/triste). Si el artista manda una exportación nueva, correr
      `tools/import_player_model.gd`.
- [ ] `WorldBoundary` se calcula al iniciar el juego (~460 ms): precalcularlo
      y guardarlo en un archivo si molesta.
- [ ] La entrada del sendero norte (hub → crossroads) se ve poco.
- [ ] Crossroads y left son planos grises de placeholder.
- [ ] Al agregar una zona nueva (p. ej. en las puntas de la pradera: ExitUp,
      ExitDown, Hub2, Hub2Left), sumar su suelo en
      `features/world/zones/world_boundary.gd` para que se abra el paso, y
      marcarlo con su id (`_tag_rect`/`_tag_triangle`) para que cuente como
      esa zona.

## Diseño todavía sin implementar

- [ ] **Patrones modulares por línea de acción**: diseño en
      `docs/patrones_modulares.md`; las cartas ya usan módulos explícitos.
  - [ ] Aplicar `CardPattern` gradualmente a las demás acciones espaciales;
        hoy charcos, explosiones, trampas, muros, empujes y vigilancia ya
        declaran línea, círculo o cono; Arrow, Nova y Aliento validan el
        impacto con la geometría reutilizable.
  - **Para considerar, no obligatorio:** fórmula final del multiplicador
        `×0.50–×1.50`; fuentes de `+1 módulo`; formas cruz, muro y anillo;
        dimensión secundaria (ancho, apertura o grosor); migrar mazos enemigos;
        renombrar `module_count` de obstáculos para distinguirlo de estos
        módulos; tutorial/indicadores visuales de la mecánica.
- [ ] Evolución: condición de **cartas** (uso por tipo durante la etapa).
      Hoy las 5 condiciones de cada campeón/ultimate usan inteligencia, stats,
      crianza y dos bonus (zona, horario o "venir de").
- [ ] **Reencarnación, lo que falta** (la secuencia ya está implementada):
      los 3 huevos bloqueados todavía no tienen bebé
      (`ReincarnationRules.EGGS`); el bebé no tiene modelo (se ve una bolita
      de repuesto) y su mazo inicial es de prueba; las animaciones son
      placeholders (acercarse, "!", "?", destello al morir y al nacer). Las
      cartas reencarnadas (listado en el menú, se desbloquea con la primera
      reencarnación) aparecen primero en la colección del armado de mazo y se
      pueden sumar sin límite de copias. Un campeón vive 6 días de juego
      (~72 min reales) antes de reencarnar.
- [ ] **Campeones y ultimates de prueba**: 4 campeones (Pillán,
      Yaguareté-Abá, Caá-Porá, Kalku) + el comodín Mbói Tu'i, y 2 ultimates
      (Arasy desde los 4 normales; Luisón exclusivo del comodín). Nombres,
      stats, condiciones, cartas características y acciones son de prueba, y
      usan modelos provisorios de primitivas (`PlaceholderModel`,
      `YounData.placeholder_*`). Un ultimate vive 8 días de juego.
- [ ] **Árbol de evoluciones**: funciona (menú → Evoluciones) pero es
      básico: botones con nombre, sin imágenes de los Youns.
- [ ] **Acomodar las recompensas por combate**: hoy ganar da +1 a cada stat
      (8 en total, contra +10 por una hora de gym) y 300 de oro, igual para
      cualquier enemigo (`VICTORY_STAT_GAINS` y `VICTORY_GOLD` en `combat.gd`).
- [ ] **Balancear lo que agrega cada evolución** (pantalla de evolución ya
      implementada): las cartas características, los colores (`color_changes`)
      y sobre todo las acciones (`granted_lines`) de nino_1, Pombero, Nguruvilu
      y Nguruvilu campeón son de relleno; las características son cartas que ya
      existían. Los colores de las inteligencias también son de ejemplo
      (`data/youns/intelligences.gd`).
- [ ] **Mazos por evolución, lo que falta**: mazo inicial por bebé (4). Al
      llegar al máximo de 5 líneas por mitad, la evolución debería mejorar una
      línea en vez de agregar (hoy no deja agregar más). El tope por etapa en
      combate ya está (`DeckRules.LINE_CAP_BY_STAGE`).
- [ ] **Comodines por inteligencia**: cada inteligencia cambia los comodines ▲
      y ▼ por variantes de la misma fuerza (daño 2 / mover 2 quedan como los
      neutros de bebé y niño; "Mantener carta" igual para todos). Hoy son
      constantes en `combat.gd` (`WILD_ATTACK`, `WILD_MOVE`).
- [ ] **Ítems de combate** (comodín ▲▼ "Ítem"): los 3 de prueba (Hierba
      Curativa, Agua de Manantial, Ungüento) tienen valores e íconos
      provisorios y se regalan 2 de cada uno en la partida de prueba
      (`game_state.gd`). Falta definir de dónde se consiguen.
- [ ] Colores de las mitades con efecto: ritmo/armonías y condiciones bonus.
- [ ] Probar si el mazo que solo crece necesita límite de cartas por combate.
- [ ] Mazos iniciales de los 2 rookies del juego final, "como si hubieran
      heredado" cambios de bebé y niño (después del demo).
- [ ] **Inteligencia de los enemigos**: cada ronda el enemigo mira 3 cartas
      de su mazo (siempre 3: si quedan menos por usar, se vuelve a mezclar) y
      elige una (`CombatEnemyAI.choose_card`), hoy al azar. Las otras dos se
      muestran dadas vuelta en la revelación.
- [ ] Nivel Tamer, desbloqueo de zonas con el Youn como llave, 8 zonas por
      inteligencia.
- [ ] Menú principal: la opción "Mapa" no abre nada.

## Para el demo

- [ ] **Sonido**: el proyecto no tiene ningún audio.
- [ ] **Tutorial / guía**: hay páginas de intro, pero nada explica el cuidado,
      el baño, el gym, el laboratorio, las cartas dobles ni la evolución.
- [ ] **Modelos de Digimon** (Agumon, Monzaemon): reemplazarlos por Youns
      propios antes de mostrar el demo en público (copyright).
- [ ] Youn bebé propio (diseño, modelo y mazo inicial) para arrancar el demo
      en bebé.

## Limpieza

- [ ] Código sin uso: `features/world/world_map/world_map.gd`, `enemy_3d.gd`
      y `world_map.tscn` (de ahí solo se usan `player_3d.gd`, `camera_rig.gd`
      y los shaders), y `RunStateData` / `current_run` en `GameState`.
- [ ] **Log de combate sin traducir**: `combat.gd` pasa casi todos sus
      `log_message(...)` por `LocalizationState.t(...)`, pero
      `combat_player_actions.gd` y los resolvers de
      `features/combat/scene/pending_actions/` tienen ~148 mensajes en
      español hardcodeado (ninguno usa el helper). Falta decidir si se migran
      a claves de `es.json`/`en.json` o si el log de combate queda fuera del
      alcance de traducción a propósito.
- [ ] **Inteligencias placeholder en cartas base**: al sacar el campo `color`
      de `CardAction` (ahora se deriva de `intelligence`), las 106 mitades de
      los 53 `.tres` de `data/cards/` más `wild_attack.tres`/`wild_move.tres`
      no tenían ninguna asignada, así que quedaron todas en `"linguistica"`
      como placeholder. Falta curarlas una por una con la inteligencia real
      de cada mitad (y, en el caso de los wildcards de combate, probablemente
      convenga que cada uno tenga una distinta para que se distingan a simple
      vista como antes).
