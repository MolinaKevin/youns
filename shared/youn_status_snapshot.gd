class_name YounStatusSnapshot
extends RefCounted

var discipline := 0
var care_mistakes := 0

static func from_save(save: PlayerSaveData) -> YounStatusSnapshot:
	var snapshot := YounStatusSnapshot.new()
	if save != null:
		snapshot.discipline = save.discipline
		snapshot.care_mistakes = save.care_mistakes
	return snapshot
