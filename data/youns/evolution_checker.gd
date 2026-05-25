class_name EvolutionChecker

const YOUNS_DIR := "res://data/youns/"
const REINCARNATE := "reincarnate"

const STAGE_MAX_DAYS := {
	"adolescente": 3.0,
	"campeon": 6.0,
}
const NEXT_STAGE := {
	"adolescente": "campeon",
}


static func try_evolve(save: PlayerSaveData, youn_data: YounData) -> String:
	if save == null or youn_data == null:
		return ""

	var target := check_conditions(save, youn_data)
	if not target.is_empty():
		return target

	var max_days: float = STAGE_MAX_DAYS.get(youn_data.stage, -1.0)
	if max_days < 0.0:
		return ""

	var days_in_stage := (GameState.get_total_hours() - save.stage_entered_total_hour) / 24.0
	if days_in_stage < max_days:
		return ""

	var next_stage: String = NEXT_STAGE.get(youn_data.stage, "")
	if next_stage.is_empty():
		return REINCARNATE

	return _find_wildcard(next_stage)


static func check_conditions(_save: PlayerSaveData, _youn_data: YounData) -> String:
	return ""


static func _find_wildcard(stage: String) -> String:
	if stage.is_empty():
		return ""
	var dir := DirAccess.open(YOUNS_DIR)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var data := load(YOUNS_DIR + file) as YounData
			if data and data.stage == stage and data.is_wildcard:
				return YOUNS_DIR + file
		file = dir.get_next()
	return ""
