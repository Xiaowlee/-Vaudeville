extends RefCounted
const Text = preload("res://Script/narration_text.gd")
static func option_for(beat: StageBeat, transcript: String) -> StageResponse:
	# Exact normalized authored phrases avoid classifying 'not yes' as YES.
	var heard := Text.normalized(transcript)
	var found: StageResponse
	for option in beat.responses:
		for phrase in option.accepted_phrases:
			if Text.normalized(phrase) == heard:
				if found != null and found != option: return null
				found = option
	return found
static func alias_matches(phrases: PackedStringArray, transcript: String) -> bool:
	for phrase in phrases:
		if Text.normalized(phrase) == Text.normalized(transcript): return true
	return false
static func line_progress(expected: String, transcript: String, cursor: int, matched: int) -> Vector2i:
	# Same ordered-word tolerance as the working continuous narration controller.
	var words := Text.normalized(expected).split(" ", false)
	var heard := Text.normalized(transcript)
	if heard.begins_with(" ".join(words.slice(0, mini(3, words.size())))):
		cursor = 0
		matched = 0
	for word in heard.split(" ", false):
		var found := words.find(word, cursor)
		if found >= 0:
			cursor = found + 1
			matched += 1
	return Vector2i(cursor, matched)
