class_name PlanSlotPayload
extends RefCounted

const SOURCE := "source"
const INDEX := "index"
const HAND := "hand"
const SLOT := "slot"

var source := ""
var index := -1

static func make(payload_source: String, payload_index: int) -> Dictionary:
	return {SOURCE: payload_source, INDEX: payload_index}

static func parse(data: Variant) -> PlanSlotPayload:
	if not data is Dictionary:
		return null
	var payload := PlanSlotPayload.new()
	payload.source = str(data.get(SOURCE, ""))
	payload.index = int(data.get(INDEX, -1))
	return payload if payload.source in [HAND, SLOT] and payload.index >= 0 else null
