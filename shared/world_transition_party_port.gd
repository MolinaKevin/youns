class_name WorldTransitionPartyPort
extends Node

## Contrato mínimo del grupo que necesita una transición. El puerto conserva
## el detalle de Player/Youn/CameraRig dentro de PartyManager.

func snapshot_transition_state() -> Dictionary: return {}
func restore_transition_state(_snapshot: Dictionary, _restore_actors: bool, _restore_camera: bool) -> void: pass
func freeze_actors() -> void: pass
func freeze_camera() -> void: pass
