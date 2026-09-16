extends Resource
## A reusable narration gap. Moment Id optionally names a reconnect destination.
@export var moment_id := ""
@export_multiline var narration_text := ""
@export_multiline var prompt_text := ""
@export var answer_category := ""
@export var accepted_answers: PackedStringArray = PackedStringArray()
@export_multiline var response_text := ""
## Empty uses Response Text. The fallback button never pretends voice was recognized.
@export_multiline var default_response_text := ""
func normalized(value: String) -> String:
	return preload("res://Script/narration_text.gd").normalized(value)
func matches(transcript: String) -> bool:
	var heard := normalized(transcript)
	for answer in accepted_answers:
		var phrase := normalized(answer)
		if phrase.is_empty(): continue
		# Accept a response alone or attached to this narration, without grading the narration.
		if heard == phrase or heard == normalized(narration_text) + " " + phrase: return true
	return false
func grammar_phrases() -> PackedStringArray:
	var phrases := PackedStringArray()
	var line := normalized(narration_text)
	if not line.is_empty(): phrases.append(line)
	for answer in accepted_answers:
		var phrase := normalized(answer)
		if phrase.is_empty(): continue
		phrases.append(phrase)
		if not line.is_empty(): phrases.append(line + " " + phrase)
	return phrases

func outcome(_transcript: String, used_default: bool) -> Dictionary:
	return {"category": answer_category, "response": default_response_text if used_default and not default_response_text.is_empty() else response_text, "reconnect": "", "ends": false, "ending": ""}
func validation_error() -> String:
	if narration_text.strip_edges().is_empty() or prompt_text.strip_edges().is_empty(): return "Needs narration and prompt text."
	if answer_category.strip_edges().is_empty(): return "Needs an answer category."
	if accepted_answers.is_empty(): return "Needs accepted answers."
	for answer in accepted_answers:
		if normalized(answer).is_empty(): return "Has an empty answer."
	return ""
