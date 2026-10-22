# Patrones modulares de acciones

Decisión de diseño para las acciones espaciales de las cartas. No implementar
como una propiedad de la carta completa: cada configuración pertenece a una
**línea de acción** (`CardActionLine`).

## Objetivo

Permitir que una acción crezca de dos maneras distintas:

- Las estadísticas amplían el efecto de forma gradual.
- Las mejoras, evoluciones, equipo o resonancias agregan módulos completos y
  cambian de forma visible el alcance del patrón.

La referencia visual puede ser Gloomhaven, pero el combate de Youns conserva
su grilla cuadrada interna; no se cambia a hexágonos.

## Unidad de módulo

La grilla de combate usa celdas de `CombatGrid.CELL` (actualmente `0.08`
unidades de mundo). Un módulo no equivale a una celda: es una unidad de diseño
formada por un grupo fijo de celdas.

Propuesta inicial para probar:

```text
1 módulo = 8 celdas internas = 0.64 unidades de mundo
```

El jugador ve módulos (`Línea 3`, `Radio 2`, `Mover 3`), nunca celdas. La
grilla interna sigue dando precisión, recorrido con obstáculos y crecimiento
fraccional por estadísticas. El valor de 8 celdas es de prueba y se puede
ajustar a 6 o 10 después de testear la escala junto a los Youns.

## Fórmula

Para una dimensión espacial:

```text
tamaño final en celdas =
(módulos base + módulos extra)
× celdas por módulo
× multiplicador de estadística
```

Ejemplo: una línea de 3 módulos, con `+1 módulo` y multiplicador `×1.12`:

```text
(3 + 1) × 8 × 1.12 = 35.84 → 36 celdas internas
```

El multiplicador de estadísticas puede penalizar o potenciar: su rango de
diseño será `×0.50` a `×1.50` (`×1.00` es neutro). Todavía falta decidir qué
estadística, estados o condiciones producen ese valor. Los módulos extra son
el crecimiento estructural importante; así un `+1 radio` de charco o un `+1
largo` de línea conserva valor propio.

## Datos de un patrón

Un patrón opcional de una línea puede definir:

| Campo | Ejemplos |
| --- | --- |
| Forma | línea, círculo, cono, cruz, muro, anillo |
| Origen | lanzador, celda elegida, enemigo, módulo del mapa |
| Dirección | cursor, enemigo, fija, ninguna |
| Dimensión principal | largo, radio o brazos, en módulos |
| Dimensión secundaria | ancho, apertura, grosor o radio interno |
| Rango de lanzamiento | distancia a la que se puede elegir el origen |
| Colisión | se detiene, atraviesa, rebota |
| Objetivos | enemigos, aliados, terreno, todos |
| Escala | fuente y multiplicador de `×0.50` a `×1.50` que modifica el patrón |
| Ejes extensibles | largo, radio, ancho, rango de lanzamiento |

El rango de lanzamiento y el tamaño del patrón son datos distintos. Por
ejemplo, un charco puede lanzarse a 4 módulos y tener radio 2; sumar radio no
debería aumentar automáticamente su alcance de lanzamiento.

## Movimiento

Mover usa módulos como presupuesto de recorrido, no como forma de impacto:

```text
Mover 3 módulos = recorrer hasta 3 módulos de camino
```

Se conserva el cálculo actual de casillas alcanzables, diagonales y obstáculos.
Una mejora `+1 módulo de movimiento` aumenta el presupuesto; la agilidad puede
aplicar el multiplicador suave antes de las penalizaciones de estados.

## Contacto con áreas

La huella circular de un Youn se configura por diámetro modular. Para charcos,
explosiones, líneas y conos no alcanza con rozar el borde: el área debe entrar
al menos un tercio del radio de la huella. En una zona circular de radio `R` y
una huella de radio `r`, el impacto ocurre hasta `R + r / 3`. Esto no cambia
las colisiones físicas, ni la intersección usada para mezclar o convertir
charcos.

## Una línea, no una mitad

Cada `CardActionLine` resuelve su propia selección, patrón, estadística y
módulos. Una mitad puede contener, por ejemplo:

```text
1. Mover 3 módulos (agilidad)
2. Atacar en línea 2 módulos (inteligencia)
```

Por defecto las líneas no comparten objetivo, dirección ni punto de impacto.
Si se necesita una combinación explícita —por ejemplo, «atacar y dejar un
charco donde impactaste»— se agrega más adelante una regla de enlace que haga
que una línea consuma el resultado espacial de la anterior.

## Migración

No todas las líneas actuales necesitan patrón: bloqueos, curas y buffs propios
pueden no tenerlo. Durante la transición, una línea sin patrón modular sigue
usando sus campos de alcance actuales. Se migran primero movimiento, ataques
en línea/conos, charcos, explosiones, trampas y otras acciones de área.

### Primer test implementado

Las líneas `move` ya usan módulos como capa de presentación y cálculo. Para
no cambiar de golpe todos los recursos existentes, una línea que no declare
`movement_base_modules` deriva el valor redondeando su `card_range` antiguo a
módulos de 8 celdas. El multiplicador editable empieza en `×1.00`; más adelante
se definirá qué estadística, estado o mejora lo modifica entre `×0.50` y
`×1.50`.

El mismo puente ya se aplica a las demás líneas espaciales: la dimensión
principal (`card_range`: alcance, radio o largo según el tipo) y la dimensión
de lanzamiento (`throw_range`) se derivan a módulos si todavía no declaran sus
campos `primary_*` o `cast_*`. Los recursos actuales siguen funcionando, pero
la interfaz y el combate usan sus equivalentes modulares. Quedan para la fase
siguiente las formas nuevas (línea, cruz, anillo, etc.) y la dimensión
secundaria (ancho, apertura o grosor).

Las reglas globales de combate también usan módulos: movimiento libre, trampa
cercana, penalizaciones por mojado/grasiento y límite por ceguera. El alcance
cuerpo a cuerpo es una excepción intencional: es un contacto fijo de 2 módulos
y no se amplifica con estadísticas.

## Próximo trabajo y consideraciones

Los recursos de cartas ya declaran `movement_base_modules`,
`primary_base_modules` y `cast_base_modules` en lugar de sus rangos antiguos.
El puente de compatibilidad queda en el código para recursos viejos o de mods.

La base de datos ya cuenta con `CardPattern`: una línea puede declarar forma,
origen, dirección, dimensión secundaria, desplazamiento inicial y colisión.
El generador reutilizable ya resuelve y previsualiza línea, círculo y cono.
`Arrow`, `Nova` y `Aliento` son las cartas de prueba conectadas de punta a
punta. Charcos, explosiones, trampas, muros, empujes, tirones, Descarga y
vigilancia ya declaran su geometría mediante `CardPattern`; se irán conectando
a reglas especiales adicionales a medida que esas acciones evolucionen.

Lo siguiente queda como **consideración de diseño, no como obligación**:

- Fórmula final y fuentes del multiplicador `×0.50–×1.50`.
- Fuentes de módulos extra (`+1 módulo`).
- Cruz, muro, anillo y otras formas.
- Dimensión secundaria: ancho, apertura o grosor.
- Migrar los mazos de enemigos a módulos.
- Renombrar `module_count` de obstáculos para no confundirlo con los módulos
  de alcance.
- Tutorial e indicadores visuales para explicar la mecánica.
