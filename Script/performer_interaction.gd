class_name PerformerInteraction
extends Resource
const Text = preload("res://Script/narration_text.gd")
@export_multiline var prompt_a := ""
@export_multiline var prompt_c := ""
@export var allow_free_response := true
@export_enum("DIALOGUE", "ACTION", "STRUCTURAL") var agency_type := 0
@export var retry_unknown := false
## Disable when negative phrases (e.g. does not move) are themselves authored options.
@export var negation_guard := true
@export_multiline var author_notes := ""
@export var options: Array[PerformerResponse] = []
## Empty permits every non-UNKNOWN option in A.
@export var allowed_categories_a: PackedStringArray = PackedStringArray()
@export_range(0, 30, 0.1) var response_pause := 1.5
func available(option: PerformerResponse, free: bool, unknown: String) -> bool:
	return free or (option.category != unknown and (allowed_categories_a.is_empty() or allowed_categories_a.has(option.category)))
func choose(transcript: String, variant: Resource) -> PerformerResponse:
	var heard := Text.normalized(transcript)
	if heard.is_empty(): return null
	var free: bool = variant.free_response and allow_free_response
	var found: Array[PerformerResponse] = []
	var fallback: PerformerResponse
	for option in options:
		if option.category == variant.unknown_category:
			fallback = option
			continue
		if not available(option, free, variant.unknown_category): continue
		for phrase in option.accepted_answers:
			var alias := Text.normalized(phrase)
			if ((" " + heard + " ").contains(" " + alias + " ") if free else heard == alias):
				if not found.has(option): found.append(option)
				break
	if free:
		for word in variant.negation_words:
			if negation_guard and heard.split(" ", false).has(Text.normalized(word)): return fallback
		return found[0] if found.size() == 1 else fallback
	return found[0] if found.size() == 1 else null
func phrases(variant: Resource) -> PackedStringArray:
	var result := PackedStringArray()
	for option in options:
		if available(option, variant.free_response and allow_free_response, variant.unknown_category):
			result.append_array(option.accepted_answers)
	return result
