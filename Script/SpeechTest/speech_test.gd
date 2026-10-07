extends Control
## A separate DEBUG scene: recording here never calls the narrative controller.
const Metrics = preload("res://Script/SpeechTest/speech_metrics.gd")
@export_file("*.json") var test_cases_file := "res://mobile-companion/public/speech-tests.json"
@export var output_file := "user://speech-comparison.json"
var cases: Array = []
var attempts: Array = []
var active: Dictionary = {}
var started := 0
var finals: Array[String] = []
@onready var speech = $SpeechMonitor
func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(test_cases_file))
	if not parsed is Array or parsed.is_empty():
		$Layout/Status.text = "Test cases could not be loaded."
		$Layout/Controls/Start.disabled = true
		return
	for item in parsed:
		if item is Dictionary and item.get("target_text", "") is String and item.get("keywords", []) is Array:
			cases.append(item)
	for item in cases: $Layout/Test.add_item(str(item.get("id", "test")))
	$Layout/Test.item_selected.connect(func(_i): update_case())
	$Layout/Controls/Start.pressed.connect(begin_attempt)
	$Layout/Controls/Stop.pressed.connect(finish_attempt)
	$Layout/Controls/Save.pressed.connect(save_results)
	speech.raw_recognition.connect(record_event)
	speech.status_changed.connect(func(value):
		$Layout/Status.text = value
		if not active.is_empty() and not speech.last_error.is_empty():
			active.errors.append(speech.last_error))
	$Layout/Condition.add_item("A: CURRENT - Windows (en-US)")
	$Layout/Condition.add_item("B: WEB_SPEECH - no bias")
	$Layout/Condition.add_item("C: WEB_SPEECH - phrase bias requested")
	$Layout/Language.add_item("en-AU")
	$Layout/Language.add_item("en-US")
	$Layout/Browser.pressed.connect(open_browser)
	PhoneSession.changed.connect(pair_changed)
	update_case()
func open_browser() -> void:
	if PhoneSession.speech_url.is_empty():
		PhoneSession.ensure_session()
	else:
		$PhoneCueBridge.enabled = true
		OS.shell_open(PhoneSession.speech_url)
func pair_changed() -> void:
	$Layout/Status.text = PhoneSession.message
	if PhoneSession.busy: return
	if PhoneSession.speech_url.is_empty():
		$Layout/Status.text = "Speech pairing unavailable. Deploy the updated relay and website, then restart this test."
		return
	$PhoneCueBridge.enabled = true
	OS.shell_open(PhoneSession.speech_url)
func update_case() -> void:
	if cases.is_empty(): return
	var item: Dictionary = cases[$Layout/Test.selected]
	$Layout/Expected.text = str(item.target_text) + "\nKeywords: " + ", ".join(item.keywords)
func begin_attempt() -> void:
	if cases.is_empty(): return
	finish_attempt()
	var item: Dictionary = cases[$Layout/Test.selected]
	active = {"id":str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_usec()),"case_id":item.id,"condition":"CURRENT - Windows","backend":"windows_system_speech","language":"en-US","bias_requested":false,"bias_applied":false,"recognition_mode":"dictation","expected_sentence":item.target_text,"keywords":item.keywords.duplicate(),"events":[],"errors":[],"timestamp":Time.get_datetime_string_from_system(true)}
	finals.clear()
	started = Time.get_ticks_msec()
	$Layout/Transcript.text = ""
	$Layout/Controls/Stop.disabled = false
	$Layout/Test.disabled = true
	$Layout/Condition.disabled = true
	$Layout/Language.disabled = true
	var condition: int = $Layout/Condition.selected
	speech.recognition_backend = 1 if condition == 0 else 3
	if condition > 0:
		active.condition = "WEB_SPEECH - " + ("bias requested" if condition == 2 else "no bias")
		active.backend = "web_speech"
		active.language = $Layout/Language.get_item_text($Layout/Language.selected)
		active.bias_requested = condition == 2
		speech.experimental_language = active.language
		speech.experimental_phrase_bias = active.bias_requested
		speech.experimental_phrases = PackedStringArray(item.keywords)
	active["latency_definition"] = "Elapsed since attempt start, including browser setup and speaking; not recognition-only latency."

	# Fixed dictation mode across all CURRENT attempts: no target phrase grammar silently added.
	speech.start_listening("", PackedStringArray(), true, true)
func record_event(event: Dictionary) -> void:
	if active.is_empty(): return
	var copy := event.duplicate(true)
	copy["received_elapsed_ms"] = Time.get_ticks_msec() - started
	active.events.append(copy)
	var is_result: bool = event.get("type") == "speech_result" or event.get("kind", "") in ["partial", "final", "rejected"]
	if is_result:
		var final_result: bool = event.get("is_final", false) or event.get("kind", "") in ["final", "rejected"]
		var timing_key := "first_final_elapsed_ms" if final_result else "first_partial_elapsed_ms"
		if not active.has(timing_key): active[timing_key] = copy.received_elapsed_ms
	if active.backend == "windows_system_speech": $PhoneCueBridge.send_speech({"type":"speech_observation", "event":copy})
	if event.get("type") == "speech_result":
		$Layout/Transcript.text = str(event.get("transcript", ""))
		active.bias_applied = event.get("bias_applied", false)
		if event.get("is_final", false): finals.append(str(event.get("transcript", "")))
	if event.get("type") == "speech_error": active.errors.append(event.get("error", "Unknown browser error"))
	var kind := str(event.get("kind", ""))
	if kind in ["partial", "final", "rejected"]:
		$Layout/Transcript.text = kind + ": " + str(event.get("text", ""))
	if kind in ["final", "rejected"]:
		# Record raw recognized/rejected words before gameplay confidence filtering.
		finals.append(str(event.get("text", "")))
	if event.get("status") == "unavailable" or kind == "audio_problem": active.errors.append(event.get("detail", "Recognition error"))
func finish_attempt() -> void:
	speech.stop_listening()
	if active.is_empty(): return
	var text := " ".join(finals)
	active["raw_transcript"] = text
	active["is_final"] = true
	active["duration_ms"] = Time.get_ticks_msec() - started
	active["alternatives"] = []
	var confidence: Array[float] = []
	for event in active.events:
		if event.get("type") == "speech_result" and event.get("is_final", false):
			active.alternatives.append(event.get("alternatives", []))
			var alternatives: Array = event.get("alternatives", [])
			if not alternatives.is_empty() and alternatives[0].get("confidence") != null: confidence.append(float(alternatives[0].confidence))
		if event.get("kind", "") in ["final", "rejected"] and event.has("confidence"): confidence.append(float(event.confidence))
	active["confidence"] = null if confidence.is_empty() else confidence.reduce(func(a,b): return a+b, 0.0) / confidence.size()
	active.merge(Metrics.score(active, text))
	var summary := active.duplicate(true)
	summary.erase("events")
	$PhoneCueBridge.send_speech({"type":"speech_attempt", "attempt":summary})
	attempts.append(active.duplicate(true))
	active.clear()
	$Layout/Test.disabled = false
	$Layout/Controls/Stop.disabled = true
	$Layout/Condition.disabled = false
	$Layout/Language.disabled = false
	var groups: Dictionary = {}
	for row in attempts:
		var key: String = str(row.condition) + " / " + str(row.language) + " / bias applied: " + str(row.bias_applied)
		if not groups.has(key): groups[key] = {"hits":0,"total":0,"count":0,"missed":[],"errors":0,"confidence":[],"elapsed":[]}
		groups[key].hits += row.keyword_hits.size()
		groups[key].total += row.keywords.size()
		groups[key].count += 1
		if row.get("confidence") != null: groups[key].confidence.append(row.confidence)
		if row.has("first_final_elapsed_ms"): groups[key].elapsed.append(row.first_final_elapsed_ms)
		groups[key].missed.append_array(row.failed_keywords)
		if not row.errors.is_empty(): groups[key].errors += 1
	var lines: Array[String] = []
	for key in groups:
		var g: Dictionary = groups[key]
		lines.append("%s: %d attempts, recall %d/%d (%.1f%%), attempts with errors %d; missed: %s" % [key,g.count,g.hits,g.total,100.0*g.hits/max(1,g.total),g.errors,", ".join(g.missed)])
		var confidence_label := "unavailable" if g.confidence.is_empty() else "%.3f" % (g.confidence.reduce(func(a,b): return a+b, 0.0)/g.confidence.size())
		var elapsed_label := "unavailable" if g.elapsed.is_empty() else "%.0f ms" % (g.elapsed.reduce(func(a,b): return a+b, 0.0)/g.elapsed.size())
		lines.append("Provider confidence: %s; mean time to first final (includes setup/speaking): %s" % [confidence_label,elapsed_label])
	$Layout/Summary.text = "\n".join(lines)
	save_results()
func save_results() -> void:
	var file := FileAccess.open(output_file, FileAccess.WRITE)
	if file == null:
		$Layout/Status.text = "Could not save results."
		return
	file.store_string(JSON.stringify({"attempts":attempts}, "  "))
	file.close()
	$Layout/Status.text = "Saved: " + ProjectSettings.globalize_path(output_file)
func _exit_tree() -> void:
	if is_instance_valid(speech): speech.stop_listening()

