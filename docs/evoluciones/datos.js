// Datos del árbol de evoluciones de Youns.
// Editá este archivo para actualizar la página (index.html no hace falta tocarlo).
//
// Cada Youn:
//   id            identificador único (sin espacios)
//   nombre        nombre visible
//   etapa         "bebe" | "nino" | "rookie" | "campeon" | "ultimate"
//   inteligencias lista de ids de INTELIGENCIAS (rookie: una sola)
//   desde         de quién evoluciona: [{ id, tipo }]
//                 tipo: "fijo" (bebé→niño), "bonus" (evento aparte), "normal",
//                       "especial", "comodin" (si no cumple nada), "condiciones"
//   comodin       true si es el Youn al que se cae sin condiciones cumplidas
//   provisorio    true mientras el nombre/datos sean de relleno
//   condiciones   (campeones y ultimates) las 5: inteligencia, stats, crianza, cartas, bonus
//   stats         estadísticas base (opcional)
//
// Los Youns que ya existen en el juego se completan desde data/youns/*.tres
// (nombre, etapa, comodín y stats): acá solo va lo que el juego no tiene.
// Para actualizarlos: godot --headless --path . --script res://tools/export_evoluciones.gd
//   notas         texto libre (opcional)

window.EVOLUCIONES = {
  etapas: [
    { id: "bebe", nombre: "Bebé" },
    { id: "nino", nombre: "Niño" },
    { id: "rookie", nombre: "Rookie" },
    { id: "campeon", nombre: "Campeón" },
    { id: "ultimate", nombre: "Ultimate" },
  ],

  inteligencias: [
    { id: "linguistica", nombre: "Lingüística", color: "#e8a33d" },
    { id: "logica", nombre: "Lógico-matemática", color: "#4f8fe8" },
    { id: "espacial", nombre: "Espacial", color: "#35b7a8" },
    { id: "musical", nombre: "Musical", color: "#c56ae0" },
    { id: "corporal", nombre: "Corporal-kinestésica", color: "#e0584f" },
    { id: "interpersonal", nombre: "Interpersonal", color: "#e07fb0" },
    { id: "intrapersonal", nombre: "Intrapersonal", color: "#8f87e8" },
    { id: "naturalista", nombre: "Naturalista", color: "#5cb85c" },
  ],

  reglas: [
    "Bebé → Niño: fijo, cada bebé tiene su niño. El niño bonus sale de un evento aparte (p. ej. llevarlo a un lugar).",
    "Rookie → Campeón y Campeón → Ultimate: cada uno tiene 5 condiciones; con 3 cumplidas se accede.",
    "Las 5 condiciones: inteligencia, stats, crianza, cartas (lo usado en combate) y bonus.",
    "Si califica para varios: gana el de más condiciones; si empatan, el que cumple la inteligencia; si ambos, al azar.",
    "Si no cumple ninguno, evoluciona al Campeón comodín. No hay Ultimate comodín: si no llega a ninguno, reencarna.",
  ],

  youns: [
    // ── Bebés ───────────────────────────────────────────────────────────────
    { id: "bebe_1", nombre: "Bebé 1", etapa: "bebe", provisorio: true },
    { id: "bebe_2", nombre: "Bebé 2", etapa: "bebe", provisorio: true },
    { id: "bebe_3", nombre: "Bebé 3", etapa: "bebe", provisorio: true },
    { id: "bebe_4", nombre: "Bebé 4", etapa: "bebe", provisorio: true },

    // ── Niños ───────────────────────────────────────────────────────────────
    { id: "nino_1", nombre: "Niño 1", etapa: "nino", provisorio: true, desde: [{ id: "bebe_1", tipo: "fijo" }] },
    { id: "nino_2", nombre: "Niño 2", etapa: "nino", provisorio: true, desde: [{ id: "bebe_2", tipo: "fijo" }] },
    { id: "nino_3", nombre: "Niño 3", etapa: "nino", provisorio: true, desde: [{ id: "bebe_3", tipo: "fijo" }] },
    { id: "nino_4", nombre: "Niño 4", etapa: "nino", provisorio: true, desde: [{ id: "bebe_4", tipo: "fijo" }] },
    {
      id: "nino_bonus", nombre: "Niño bonus", etapa: "nino", provisorio: true,
      desde: [
        { id: "bebe_1", tipo: "bonus" }, { id: "bebe_2", tipo: "bonus" },
        { id: "bebe_3", tipo: "bonus" }, { id: "bebe_4", tipo: "bonus" },
      ],
      notas: "Sale de un evento aparte (p. ej. llevar al bebé a cierto lugar). Si no se da, cada bebé va a su niño fijo.",
    },

    // ── Rookies (en el código: etapa "adolescente") ──────────────────────────
    { id: "pombero", nombre: "Pombero", etapa: "rookie", inteligencias: ["corporal"], desde: [{ id: "nino_1", tipo: "normal" }],
      notas: "Inteligencia provisoria." },
    { id: "rookie_1b", nombre: "Rookie 1B", etapa: "rookie", provisorio: true, inteligencias: ["logica"], desde: [{ id: "nino_2", tipo: "normal" }] },
    { id: "nguruvilu", nombre: "Nguruvilu", etapa: "rookie", inteligencias: ["naturalista"], desde: [{ id: "nino_1", tipo: "normal" }],
      notas: "Inteligencia provisoria." },
    { id: "rookie_2b", nombre: "Rookie 2B", etapa: "rookie", provisorio: true, inteligencias: ["musical"], desde: [{ id: "nino_2", tipo: "normal" }] },
    { id: "rookie_3a", nombre: "Rookie 3A", etapa: "rookie", provisorio: true, inteligencias: ["espacial"], desde: [{ id: "nino_3", tipo: "normal" }] },
    { id: "rookie_3b", nombre: "Rookie 3B", etapa: "rookie", provisorio: true, inteligencias: ["interpersonal"], desde: [{ id: "nino_3", tipo: "normal" }] },
    { id: "rookie_4a", nombre: "Rookie 4A", etapa: "rookie", provisorio: true, inteligencias: ["linguistica"], desde: [{ id: "nino_4", tipo: "normal" }] },
    { id: "rookie_4b", nombre: "Rookie 4B", etapa: "rookie", provisorio: true, inteligencias: ["intrapersonal"], desde: [{ id: "nino_4", tipo: "normal" }] },
    { id: "rookie_esp_1", nombre: "Rookie especial 1", etapa: "rookie", provisorio: true, inteligencias: ["corporal"], desde: [{ id: "nino_bonus", tipo: "especial" }],
      notas: "Supuesto: los 2 especiales salen del niño bonus (pendiente de confirmar)." },
    { id: "rookie_esp_2", nombre: "Rookie especial 2", etapa: "rookie", provisorio: true, inteligencias: ["intrapersonal"], desde: [{ id: "nino_bonus", tipo: "especial" }],
      notas: "Supuesto: los 2 especiales salen del niño bonus (pendiente de confirmar)." },

    // ── Campeones (desde cualquier rookie, con 3 de 5 condiciones) ───────────
    { id: "campeon_1", nombre: "Campeón 1", etapa: "campeon", provisorio: true, inteligencias: ["corporal"],
      condiciones: { inteligencia: "Corporal-kinestésica", stats: "Fuerza > 150 y Agilidad > 120", crianza: "Errores de cuidado ≤ 2", cartas: "Usar 40 líneas de movimiento", bonus: "Ganar 10 combates" } },
    { id: "campeon_2", nombre: "Campeón 2", etapa: "campeon", provisorio: true, inteligencias: ["logica", "espacial"],
      condiciones: { inteligencia: "Lógico-matemática o Espacial", stats: "Técnica > 150", crianza: "Disciplina ≥ 70", cartas: "Usar 25 ataques a distancia", bonus: "Evolucionar en la zona lógica" } },
    { id: "campeon_3", nombre: "Campeón 3", etapa: "campeon", provisorio: true, inteligencias: ["naturalista"],
      condiciones: { inteligencia: "Naturalista", stats: "Espíritu > 150 y Vitalidad entre 500 y 700", crianza: "Estrés ≤ 30", cartas: "Jugar 20 mitades de charco", bonus: "Venir de Nguruvilu" } },
    { id: "campeon_4", nombre: "Campeón 4", etapa: "campeon", provisorio: true, inteligencias: ["musical", "interpersonal"],
      condiciones: { inteligencia: "Musical o Interpersonal", stats: "Inteligencia > 140", crianza: "Felicidad ≥ 80", cartas: "Usar 30 líneas de bloqueo", bonus: "—" } },
    { id: "campeon_5", nombre: "Campeón 5", etapa: "campeon", provisorio: true, inteligencias: ["linguistica", "intrapersonal"],
      condiciones: { inteligencia: "Lingüística o Intrapersonal", stats: "Resistencia > 160", crianza: "Peso entre 15 y 25", cartas: "Usar el comodín mantener 10 veces", bonus: "—" } },
    { id: "nguruvilu_campeon", nombre: "Nguruvilu (comodín)", etapa: "campeon", comodin: true,
      desde: [{ id: "*rookies", tipo: "comodin" }],
      notas: "Campeón comodín: al que se cae si no se cumplen 3 condiciones de ningún campeón. Más débil, pero es el único que llega al Ultimate secreto." },

    // ── Ultimates (con 3 de 5 condiciones; sin comodín) ─────────────────────
    { id: "ultimate_1", nombre: "Ultimate 1", etapa: "ultimate", provisorio: true, inteligencias: ["corporal"],
      desde: [{ id: "campeon_1", tipo: "condiciones" }],
      condiciones: { inteligencia: "Corporal-kinestésica", stats: "Fuerza > 300", crianza: "—", cartas: "—", bonus: "—" } },
    { id: "ultimate_2", nombre: "Ultimate 2", etapa: "ultimate", provisorio: true, inteligencias: ["logica"],
      desde: [{ id: "campeon_2", tipo: "condiciones" }],
      condiciones: { inteligencia: "Lógico-matemática", stats: "Técnica > 300", crianza: "—", cartas: "—", bonus: "—" } },
    { id: "ultimate_secreto", nombre: "Ultimate secreto", etapa: "ultimate", provisorio: true,
      desde: [{ id: "nguruvilu_campeon", tipo: "especial" }],
      notas: "Solo desde el Campeón comodín (como el traje de Monzaemon en DW1)." },
  ],
};
