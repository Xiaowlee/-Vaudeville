extends "res://Script/SpeechTest/local_intent_test.gd"
@export var story: StageSequence
@export var test_beats := PackedStringArray(["A1.1", "A1.first_reaction", "A1.2", "A1.backstage", "A1.3", "A1.4", "A1.5"])
var compiled: StageSequence
var selected: StageBeat
var selected_index := 0
func _ready() -> void:
	start_local_service = false # These authored rules do not need an AI guess.
	super._ready()
	compiled = story.duplicate(true)
	var issue := compiled.validation_error()
	if not issue.is_empty():
		$Layout/Result.text = issue
		$Layout/Classify.disabled = true
		return
	for id in test_beats: $Layout/Beat.add_item(id)
	$Layout/Beat.item_selected.connect(select_beat)
	select_beat(0)
func select_beat(index: int) -> void:
	if busy: $Layout/Beat.select(selected_index); return
	selected_index = index
	var found := compiled.index_of(test_beats[index])
	if found < 0:
		selected = null
		$Layout/Result.text = "Beat missing from the current story file."
		return
	selected = compiled.beats[found]
	situation = selected.beat_id
	recent_dialogue = selected.npc_dialogue
	relevant_history = "Preview of saved story order; no actual playthrough history is simulated."
	expected_line = selected.expected_line
	$Layout/Context.text = "Saved beat: " + selected.beat_id + "\nNPC: " + selected.npc_dialogue + "\nCue: " + selected.cue_card_text
	$Layout/Result.text = "Tests the existing authored rule. Does not advance the game or replace it with AI."
	$Layout/Classify.disabled = selected.input_mode == StageBeat.InputMode.NONE
func classify() -> void:
	if selected == null or busy: return
	var words: String = $Layout/Words.text.strip_edges()
	last_intent = ""
	if words.is_empty():
		$Layout/Result.text = "Empty input is not a failed performance. No result selected."
		return
	started = Time.get_ticks_msec()
	active_record = {"input_text":words,"beat":selected.beat_id,"npc_dialogue":selected.npc_dialogue,"cue":selected.cue_card_text,"expected_line":selected.expected_line,"expected_result":$Layout/Expected.text,"rule":selected.input_mode,"source":"saved story rule, no AI"}
	if selected.input_mode == StageBeat.InputMode.ANY_SPEECH_OR_TIMEOUT:
		$Layout/Result.text = "Authored response to an attempt: " + selected.npc_success_response + "\nAuthored timeout response (not triggered here): " + selected.npc_timeout_response
		finish_result("authored_attempt")
	elif selected.input_mode == StageBeat.InputMode.GUIDED_LINE:
		var matcher = preload("res://Script/StageActs/stage_matcher.gd")
		var progress: Vector2i = matcher.line_progress(selected.expected_line, words, 0, 0)
		var count := preload("res://Script/narration_text.gd").normalized(selected.expected_line).split(" ", false).size()
		var matched: bool = matcher.alias_matches(selected.accepted_phrases, words) or (count > 0 and progress.x >= count - 1 and float(progress.y) / count >= selected.line_coverage)
		$Layout/Result.text = ("Accepted: " + selected.npc_success_response) if matched else "Not enough of the authored line. Retry; AI cannot supply a different route."
		finish_result("script_match" if matched else "script_mismatch")
	else:
		$Layout/Result.text = "This beat has no supported player-input test. Inspect its authored presentation in the story."
