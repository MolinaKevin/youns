class_name CombatRoundEvent
extends RefCounted

## Evento de fin de ronda que arma CombatRoundResolver.build_events() y que
## Combat aplica en _resolve_round_event(). Antes era un Dictionary con 5
## formas distintas sin esquema (kind: tree_drop/delayed_zone/
## tick_map_effects/status_damage/status_duration); cada "kind" sólo llena
## los campos que le corresponden, el resto queda en su valor por defecto.

var kind: String = ""

## tree_drop: si el jugador cae encima del enemigo y cuánto daño le hace.
var hit: bool = false
var damage: int = 0

## delayed_zone: a quién le llegó el charco demorado ("enemy"/"player"/"none")
## y el registro de impacto que ya construye PuddleSystem/CombatMapInteractions
## (sigue siendo Dictionary declarativo, fuera del alcance de este tipado).
var target: String = ""
var zone_hit: Dictionary = {}

## status_damage / status_duration: a qué efecto corresponde (CombatEffect.*)
## y las claves de localización del mensaje de daño / de expirado.
var effect: String = ""
var damage_type: String = ""
var damage_log_key: String = ""
var expired_log_key: String = ""
