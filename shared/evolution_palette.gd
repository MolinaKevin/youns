class_name EvolutionPalette
extends RefCounted

## Colores de acento que se repiten tal cual en las tres pantallas de
## evolución (evolution_screen.gd, evolution_tree_screen.gd,
## evolution_discovery_screen.gd), antes definidos por separado con nombres
## distintos (BORDER/KNOWN/LINK, CURRENT/NEW).
##
## A propósito NO están acá otros colores que coinciden de nombre entre
## pantallas (KNOWN, HIDDEN): tienen valores y roles visuales distintos en
## cada una — unificarlos cambiaría el look de alguna sin que lo pidan.

## Borde/resalte compartido: celda conocida en el árbol, línea entre
## evoluciones, borde del panel en evolution_screen/evolution_discovery.
const ACCENT := Color(0.35, 0.85, 1.0)
## Youn actual en el árbol / condición recién descubierta en el aviso.
const CURRENT := Color(1.0, 0.85, 0.35)
