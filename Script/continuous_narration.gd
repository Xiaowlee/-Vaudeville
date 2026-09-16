extends "res://Script/prototype_screen.gd"
## Shared presentation for both prototypes. Reading has no deadline.
signal moment_completed(index: int, category: String, used_default: bool)
signal narration_completed
const Text = preload("res://Script/narration_text.gd")
enum State { READING, PROMPT, RECOGNISED, RESPONSE, TRANSITION, COMPLETE }
@export var story: Resource
@export var autostart_voice := true
@export_node_path("RichTextLabel") var story_text_path := NodePath("StoryText")
@export_node_path("Label") var response_label_path := NodePath("VisualPlaceholder/Label")
@export_group("Pacing")
@export_range(0, 5, 0.05) var recognition_display_duration := 0.8
@export_range(0, 5, 0.05) var transition_delay := 0.25
@export_range(0, 5, 0.05) var prompt_delay := 0.25
## Internal tolerance, never displayed as a pronunciation score.
@export_range(0.4, 1, 0.05) var reading_coverage := 0.65
@export_group("Reading appearance")
@export var active_colour := Color(0.28, 0.25, 0.34, 1)
@export var inactive_colour := Color(0.28, 0.25, 0.34, 0.45)
@export_group("Player messages")
@export var reading_message := "READING — read the highlighted passage aloud."
@export var prompt_message := "LISTENING — say your response now."
@export var response_message := "STORY RESPONSE — read what happens next."
@export var recognised_message := "RECOGNISED"
@export var retry_reading_message := "TRY AGAIN — repeat the passage, or use Reading fallback."
@export var retry_prompt_message := "TRY AGAIN — say an option again, or use the default."
@export var unavailable_message := "Microphone unavailable — retry microphone or use the fallback."
@export var starting_message := "Microphone starting — please wait."
@export var fallback_message := "Default selected — continuing without voice recognition."
@export var transition_message := "Continue narration…"
@export var reading_fallback_text := "Reading fallback"
@export var prompt_fallback_text := "Use default"
@onready var feed: RichTextLabel = get_node(story_text_path)
@onready var voice = $SpeechMonitor
var state := State.READING
var active_index := 0
var finished := false
var valid := false
var queue := PackedStringArray()
var beat_index := 0
var cursor := 0
var matched := 0
var pending: Dictionary = {}
var generation := 0
func _ready() -> void:
	super._ready()
	$DefaultResponse.pressed.connect(use_default)
	$RetryMicrophone.pressed.connect(retry_microphone)
	$RetryMicrophone.hide()
	voice.transcript_received.connect(_on_transcript)
	voice.recognition_rejected.connect(_on_rejected)
	voice.status_changed.connect(_on_voice_status)
	$Status.show()
	var error: String = "Assign a Story resource." if story == null else story.validation_error()
	if not error.is_empty():
		$Status.text = error
		$DefaultResponse.disabled = true
		push_error("[Narration configuration] " + error)
		return
	valid = true
	_start_moment()
	if autostart_voice: retry_microphone()
func _start_moment() -> void:
	pending = {}
	queue = Text.beats(story.moments[active_index].narration_text)
	beat_index = 0
	_show_beat(State.READING)
func _show_beat(kind: State) -> void:
	state = kind
	cursor = 0
	matched = 0
	feed.text = queue[beat_index]
	feed.scroll_to_line(0)
	feed.add_theme_color_override("default_color", active_colour)
	$Prompt.hide()
	$Recognition.text = ""
	$DefaultResponse.disabled = false
	$DefaultResponse.text = reading_fallback_text
	_update_status()
	print("[Narration state] ", State.keys()[state], " moment=", active_index + 1, " beat=", beat_index + 1)
func _update_status() -> void:
	if state == State.COMPLETE: $Status.text = story.completed_message
	elif not autostart_voice: $Status.text = unavailable_message
	elif not voice.listening: $Status.text = unavailable_message
	elif not voice.worker_ready: $Status.text = starting_message
	elif state == State.PROMPT: $Status.text = prompt_message
	elif state == State.READING: $Status.text = reading_message
	elif state == State.RESPONSE: $Status.text = response_message
func retry_microphone() -> void:
	if not valid or finished or leaving: return
	autostart_voice = true
	$RetryMicrophone.hide()
	var phrases: PackedStringArray = story.grammar_phrases()
	voice.start_listening(phrases[0], phrases.slice(1), true)
func _on_voice_status(_message: String) -> void:
	if not valid or finished or leaving: return
	$RetryMicrophone.visible = not voice.listening
	_update_status()
func _on_transcript(text: String) -> void:
	if not valid or finished or leaving: return
	if state == State.PROMPT:
		$Recognition.text = recognised_message + ": “" + text + "”"
		if story.moments[active_index].matches(text): _accept(text, false)
		else: $Status.text = retry_prompt_message
	elif state in [State.READING, State.RESPONSE]:
		$Recognition.text = recognised_message + ": “" + text + "”"
		var words := Text.normalized(queue[beat_index]).split(" ", false)
		var heard := Text.normalized(text)
		# A fresh repeat can recover from a partially recognised earlier attempt.
		if heard.begins_with(" ".join(words.slice(0, mini(3, words.size())))):
			cursor = 0
			matched = 0
		for word in heard.split(" ", false):
			var found := words.find(word, cursor)
			if found >= 0:
				cursor = found + 1
				matched += 1
		if cursor >= words.size() - 1 and float(matched) / words.size() >= reading_coverage:
			_finish_reading()
		elif cursor >= words.size() - 1:
			cursor = 0
			matched = 0
			$Status.text = retry_reading_message
func _on_rejected(_text: String) -> void:
	if not valid or finished or leaving: return
	if state in [State.READING, State.RESPONSE]:
		cursor = 0
		matched = 0
		$Status.text = retry_reading_message
	elif state == State.PROMPT: $Status.text = retry_prompt_message
func use_default() -> void:
	if not valid or finished or leaving: return
	if state == State.PROMPT: _accept("", true)
	elif state in [State.READING, State.RESPONSE]: _finish_reading()
func _finish_reading() -> void:
	var kind := state
	state = State.TRANSITION
	$DefaultResponse.disabled = true
	feed.add_theme_color_override("default_color", inactive_colour)
	$Status.text = transition_message
	generation += 1
	var ticket := generation
	await get_tree().create_timer(transition_delay).timeout
	if not is_inside_tree() or leaving or ticket != generation: return
	beat_index += 1
	if beat_index < queue.size(): _show_beat(kind)
	elif kind == State.READING: _show_prompt()
	else: _complete_response()
func _show_prompt() -> void:
	state = State.TRANSITION
	await get_tree().create_timer(prompt_delay).timeout
	if not is_inside_tree() or leaving: return
	state = State.PROMPT
	feed.text = ""
	$Prompt.text = story.moments[active_index].prompt_text
	$Prompt.show()
	$Recognition.text = ""
	$DefaultResponse.text = prompt_fallback_text
	$DefaultResponse.disabled = false
	_update_status()
	print("[Narration state] PROMPT moment=", active_index + 1)
func _accept(text: String, used_default: bool) -> void:
	pending = story.moments[active_index].outcome(text, used_default)
	pending["used_default"] = used_default
	state = State.RECOGNISED
	$DefaultResponse.disabled = true
	$Status.text = fallback_message if used_default else recognised_message
	$Recognition.text = fallback_message if used_default else recognised_message + ": “" + text + "”"
	print("[Narration input] category=", pending.category, " default=", used_default)
	await get_tree().create_timer(recognition_display_duration).timeout
	if not is_inside_tree() or leaving: return
	queue = Text.beats(pending.response)
	if pending.ends or active_index == story.moments.size() - 1:
		queue.append_array(Text.beats(pending.ending if not pending.ending.is_empty() else story.ending_text))
	beat_index = 0
	if queue.is_empty(): _complete_response()
	else: _show_beat(State.RESPONSE)
func _complete_response() -> void:
	var resolved := active_index
	var category: String = pending.category
	var used_default: bool = pending.used_default
	if pending.ends or active_index == story.moments.size() - 1:
		finished = true
		state = State.COMPLETE
		voice.stop_listening()
		$DefaultResponse.hide()
		$RetryMicrophone.hide()
		_update_status()
		print("[Narration state] COMPLETE")
		moment_completed.emit(resolved, category, used_default)
		narration_completed.emit()
	else:
		active_index = story.index_of(pending.reconnect) if not pending.reconnect.is_empty() else active_index + 1
		moment_completed.emit(resolved, category, used_default)
		_start_moment()
