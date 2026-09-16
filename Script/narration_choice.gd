extends "res://Script/narration_moment.gd"
const Option = preload("res://Script/narration_option.gd")
## Choice moments use Options instead of the inherited single-answer fields.
@export var options: Array[Resource] = []
## One-based option number used by the Use default button.
@export_range(1, 4) var default_option := 1
func selected_option(transcript: String) -> Resource:
	var heard := normalized(transcript)
	for option in options:
		for answer in option.accepted_answers:
			var phrase := normalized(answer)
			if heard == phrase or heard == normalized(narration_text) + " " + phrase: return option
	return null
func matches(transcript: String) -> bool:
	return selected_option(transcript) != null
func outcome(transcript: String, used_default: bool) -> Dictionary:
	var option = options[default_option - 1] if used_default else selected_option(transcript)
	return {"category": option.category, "response": option.response_text, "reconnect": option.reconnect_point, "ends": option.ends_story, "ending": option.ending_text}
func grammar_phrases() -> PackedStringArray:
	var phrases := PackedStringArray()
	var line := normalized(narration_text)
	if not line.is_empty(): phrases.append(line)
	for option in options:
		for answer in option.accepted_answers:
			var phrase := normalized(answer)
			phrases.append(phrase)
			if not line.is_empty(): phrases.append(line + " " + phrase)
	return phrases
func validation_error() -> String:
	if narration_text.strip_edges().is_empty() or prompt_text.strip_edges().is_empty(): return "Needs narration and prompt text."
	if options.size() < 2 or options.size() > 4: return "Needs 2 to 4 options."
	if default_option > options.size(): return "Default Option is outside the options list."
	var seen := []
	for option in options:
		if not option is Option: return "Options must use narration_option.gd."
		if option.category.strip_edges().is_empty() or option.accepted_answers.is_empty(): return "Each option needs a category and accepted answers."
		for answer in option.accepted_answers:
			var phrase := normalized(answer)
			if phrase.is_empty() or seen.has(phrase): return "Answer phrases must be nonempty and unique within a choice."
			seen.append(phrase)
		if option.ends_story and not option.reconnect_point.is_empty(): return "An ending cannot also reconnect."
	return ""
