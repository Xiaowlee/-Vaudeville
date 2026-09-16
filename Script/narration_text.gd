extends RefCounted
## Blank lines are designer-authored beat boundaries. No story content lives here.
static func beats(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for paragraph in value.replace("\r", "").split("\n\n", false):
		if not paragraph.strip_edges().is_empty(): result.append(paragraph.strip_edges())
	return result
static func normalized(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-z0-9 ]")
	value = value.to_lower().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	return " ".join(regex.sub(value, "", true).split(" ", false))
static func phrases(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	var regex := RegEx.new()
	regex.compile("[^.!?]+[.!?]*")
	for beat in beats(value):
		var full := normalized(beat)
		if not full.is_empty(): result.append(full)
		for sentence in regex.search_all(beat):
			var phrase := normalized(sentence.get_string())
			if not phrase.is_empty() and not result.has(phrase): result.append(phrase)
	return result
