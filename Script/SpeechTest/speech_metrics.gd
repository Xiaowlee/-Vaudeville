extends RefCounted
## Scoring only. This is never called by the story matcher.
static func normalized(value: String) -> String:
	var expression := RegEx.new()
	expression.compile("[^a-z0-9]+")
	return expression.sub(value.to_lower().replace("'", "").replace("’", ""), " ", true).strip_edges()
static func score(test: Dictionary, transcript: String) -> Dictionary:
	var heard := " " + normalized(transcript) + " "
	var hits: Array[String] = []
	var missed: Array[String] = []
	for word in test.get("keywords", []):
		if heard.contains(" " + normalized(str(word)) + " "): hits.append(str(word))
		else: missed.append(str(word))
	return {"keyword_hits":hits,"failed_keywords":missed,"keyword_recall":float(hits.size()) / max(1, hits.size() + missed.size())}
