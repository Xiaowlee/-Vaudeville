extends Resource
const Text = preload("res://Script/narration_text.gd")
@export var beats: Array[PerformerStoryBeat] = []
@export var initial_state: Dictionary[String, String] = {}
@export var completed_message := "Story complete."
func index_of(id: String) -> int:
	for i in beats.size():
		if beats[i].beat_id == id: return i
	return -1
func meets(requirements: Dictionary, values: Dictionary) -> bool:
	for key in requirements:
		if not values.has(key) or values[key] != requirements[key]: return false
	return true
func validation_error(variant: Resource) -> String:
	if variant == null: return "Assign a variant."
	if beats.is_empty(): return "Add at least one story beat."
	var ids := []
	for beat in beats:
		if beat == null: return "Remove empty beat slots or create a Story Beat."
		if not beat.beat_id.is_empty():
			if ids.has(beat.beat_id): return "Duplicate Beat Id: " + beat.beat_id
			ids.append(beat.beat_id)
		if beat.kind == 0 and beat.text.strip_edges().is_empty(): return "Narration needs text: " + beat.beat_id
	for beat in beats:
		if not beat.next_beat_id.is_empty() and not ids.has(beat.next_beat_id): return "Missing destination: " + beat.next_beat_id
		var interaction = beat.interaction
		if interaction == null: continue
		if beat.kind != 0: return "Put interactions on narration beats: " + beat.beat_id
		if interaction.prompt_a.is_empty() or interaction.prompt_c.is_empty(): return "Add A and C prompts: " + beat.beat_id
		var categories := []
		var aliases := []
		for option in interaction.options:
			if option == null or option.category.is_empty(): return "Every response needs a category."
			if categories.has(option.category): return "Duplicate category: " + option.category
			categories.append(option.category)
			if option.category != variant.unknown_category and option.accepted_answers.is_empty(): return "Add accepted phrases: " + option.category
			for phrase in option.accepted_answers:
				var normalized := Text.normalized(phrase)
				if normalized.is_empty() or aliases.has(normalized): return "Empty or duplicate accepted phrase: " + phrase
				aliases.append(normalized)
			if not option.reconnect_point.is_empty() and not ids.has(option.reconnect_point): return "Missing response destination: " + option.reconnect_point
		if not categories.has(variant.unknown_category): return "Add an UNKNOWN response: " + beat.beat_id
		for category in interaction.allowed_categories_a:
			if not categories.has(category) or category == variant.unknown_category: return "Invalid A category: " + category
		if interaction.phrases(variant).is_empty(): return "Interaction needs spoken responses."
	return ""

func grammar_phrases() -> PackedStringArray:
	var phrases := PackedStringArray()
	for beat in beats:
		if beat.kind == 0:
			for phrase in Text.phrases(beat.text):
				if not phrases.has(phrase): phrases.append(phrase)
	return phrases
