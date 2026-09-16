extends Resource
const Choice = preload("res://Script/narration_choice.gd")
const Moment = preload("res://Script/narration_moment.gd")
## Expand Moments in the Inspector to edit each passage, prompt and accepted category.
@export var moments: Array[Resource] = []
@export_multiline var ending_text := ""
@export var listening_message := ""
@export var retry_message := ""
@export var unavailable_message := ""
@export var completed_message := ""
func validation_error() -> String:
	if moments.is_empty(): return "Story has no moments."
	for i in moments.size():
		var moment = moments[i]
		if not moment is Moment: return "Moment %s must use narration_moment.gd." % (i + 1)
		var error: String = moment.validation_error()
		if not error.is_empty(): return "Moment %s: %s" % [i + 1, error]
		if not moment.moment_id.is_empty() and index_of(moment.moment_id) != i: return "Duplicate Moment Id: " + moment.moment_id
		if moment is Choice:
			for option in moment.options:
				if not option.reconnect_point.is_empty() and index_of(option.reconnect_point) <= i:
					return "Reconnect must name an existing later Moment Id: " + option.reconnect_point
	return ""
func grammar_phrases() -> PackedStringArray:
	var result := PackedStringArray()
	var texts = preload("res://Script/narration_text.gd")
	for moment in moments:
		result.append_array(texts.phrases(moment.narration_text))
		if moment is Choice:
			for option in moment.options:
				result.append_array(option.accepted_answers)
				result.append_array(texts.phrases(option.response_text))
				result.append_array(texts.phrases(option.ending_text))
		else:
			result.append_array(moment.accepted_answers)
			result.append_array(texts.phrases(moment.response_text))
			result.append_array(texts.phrases(moment.default_response_text))
	result.append_array(texts.phrases(ending_text))
	var unique := PackedStringArray()
	for phrase in result:
		var clean: String = texts.normalized(phrase)
		if not clean.is_empty() and not unique.has(clean): unique.append(clean)
	return unique

func index_of(point: String) -> int:
	for i in moments.size():
		if moments[i] is Moment and moments[i].moment_id == point: return i
	return -1
