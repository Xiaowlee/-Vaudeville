extends Control
## Isolated wrapper: no changes to the saved story, normal scene or recognizer.
@export_file("*.tscn") var game_scene := "res://Scene/StageActs/2.3_stage_acts_1_3.tscn"
@export var automatically_apply_results := false
var game: Node
var opening: Node
var locked := false
var pending := ""
var attempts := 0
var completed_test := false
@onready var audio = $Whisper
@onready var meaning = $Meaning
@onready var controls = $Debug/Panel/Controls
func _ready() -> void:
	game = load(game_scene).instantiate()
	game.get_node("PreShow").autostart_voice = false
	add_child(game)
	move_child(game, 0)
	opening = game.get_node("PreShow")
	controls.get_node("Record").pressed.connect(begin_recording)
	controls.get_node("Finish").pressed.connect(audio.finish_recording)
	controls.get_node("Typed").pressed.connect(func(): submit(controls.get_node("Words").text))
	controls.get_node("Apply").pressed.connect(apply_result)
	controls.get_node("Retry").pressed.connect(retry)
	controls.get_node("CancelAI").pressed.connect(meaning.cancel_attempt)
	controls.get_node("Export").pressed.connect(func(): meaning.export_dialog.popup_centered_ratio(0.7))
	audio.transcript_ready.connect(submit)
	meaning.interpretation_finished.connect(received)
	controls.get_node("Status").text = "Review mode: the AI suggests; Apply triggers the existing response. Wait for the player turn."
func begin_attempt() -> bool:
	if completed_test or locked or opening.state not in ["READY", "LISTENING"]: return false
	opening.state = "LISTENING"
	opening.elapsed = 0
	opening.set_process(false)
	locked = true
	pending = ""
	attempts += 1
	meaning.recent_dialogue = opening.panel.get_node("Margin/Lines/Dialogue").text
	meaning.relevant_history = "Pre-show answer attempt %d. Curtain is still closed. Reminder count: %d." % [attempts, opening.reminder_count]
	return true
func begin_recording() -> void:
	if not begin_attempt(): return
	audio.start_recording()
	if not audio.recording: retry(); controls.get_node("Status").text = audio.status.text
func submit(words: String) -> void:
	if completed_test or meaning.busy: return
	if not locked and not begin_attempt(): return
	if words.strip_edges().is_empty(): retry(); return
	controls.get_node("Words").text = words
	game.get_node("StageUI").show_transcript(words)
	meaning.get_node("Layout/Words").text = words
	meaning.classify()
	if not meaning.busy and meaning.last_intent.is_empty(): retry()
func received(intent: String, _seconds: float) -> void:
	if not locked or opening.state != "LISTENING": retry(); return
	pending = intent if intent in ["ready", "not_ready"] else ""
	controls.get_node("Status").text = meaning.get_node("Layout/Result").text
	if pending.is_empty():
		retry(false)
	elif automatically_apply_results:
		apply_result()
func apply_result() -> void:
	if not locked or opening.state != "LISTENING" or pending.is_empty(): return
	var phrases = opening.yes_phrases if pending == "ready" else opening.no_phrases
	if phrases.is_empty(): retry(); return
	if not meaning.records.is_empty(): meaning.records[-1]["review_action"] = "applied"
	var actual_words: String = controls.get_node("Words").text
	pending = ""
	locked = false
	opening.elapsed = 0
	opening.set_process(true)
	opening.receive(phrases[0])
	# Keep what the player really said visible, not the canonical matcher phrase.
	game.get_node("StageUI").show_transcript(actual_words)
func retry(update_message := true) -> void:
	if not pending.is_empty() and not meaning.records.is_empty(): meaning.records[-1]["review_action"] = "discarded"
	pending = ""
	locked = false
	opening.elapsed = 0
	opening.set_process(true)
	if update_message: controls.get_node("Status").text = "Ready to retry. No story outcome was applied."
func _process(_delta: float) -> void:
	if not is_instance_valid(opening): return
	var allowed: bool = opening.state in ["READY", "LISTENING"] and not completed_test
	controls.get_node("Record").disabled = not allowed or locked
	controls.get_node("Typed").disabled = not allowed or locked
	controls.get_node("Words").editable = not locked
	controls.get_node("Finish").disabled = not audio.recording
	controls.get_node("CancelAI").disabled = not meaning.busy
	controls.get_node("Apply").disabled = pending.is_empty() or meaning.busy
	controls.get_node("Retry").disabled = audio.recording or audio.pid > 0 or meaning.busy
	if locked and not audio.recording and audio.pid <= 0 and not meaning.busy and pending.is_empty():
		controls.get_node("Status").text = audio.status.text if meaning.last_intent.is_empty() else meaning.get_node("Layout/Result").text
		retry(false)
	if audio.recording or audio.pid > 0: controls.get_node("Status").text = audio.status.text
	elif meaning.busy: controls.get_node("Status").text = "Interpreting this pre-show answer locally..."
	if opening.state == "FINISHED" and not completed_test:
		completed_test = true
		game.get_node("GameController").set_process(false)
		game.get_node("SpeechMonitor").stop_listening()
		controls.get_node("Status").text = "DEBUG test complete: curtain opened and Act 1 entered. This scene pauses here; use the normal game for the rest."
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		$Debug/Panel.visible = not $Debug/Panel.visible
