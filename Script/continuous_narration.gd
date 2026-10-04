extends "res://Script/prototype_screen.gd"
## Shared presentation for both prototypes. Reading has no deadline.
signal moment_completed(index: int, category: String, used_default: bool)
signal narration_completed
const Text = preload("res://Script/narration_text.gd")
enum State { READING, PROMPT, RECOGNISED, RESPONSE, TRANSITION, COMPLETE }
@export var story: Resource
@export var autostart_voice := true
@export_node_path("RichTextLabel") var story_text_path := NodePath("%StoryText")
@export_node_path("Label") var response_label_path := NodePath("VisualPlaceholder/Label")
@export_group("Presentation bindings")
@export_node_path("Button") var default_button_path := NodePath("DefaultResponse")
@onready var default_button: Button = get_node(default_button_path)
@export_node_path("Button") var retry_button_path := NodePath("RetryMicrophone")
@onready var retry_button: Button = get_node(retry_button_path)
@export_node_path("Label") var status_label_path := NodePath("Status")
@onready var status_label: Label = get_node(status_label_path)
@export_node_path("Label") var recognition_label_path := NodePath("Recognition")
@onready var recognition_label: Label = get_node(recognition_label_path)
@export_node_path("RichTextLabel") var prompt_label_path := NodePath("%Prompt")
@onready var prompt_label: RichTextLabel = get_node(prompt_label_path)
@export_node_path("Node") var speech_monitor_path := NodePath("SpeechMonitor")
@export_group("Pacing")
@export_range(0, 5, 0.05) var recognition_display_duration := 0.8
@export_range(0, 5, 0.05) var transition_delay := 0.25
@export_range(0, 5, 0.05) var prompt_delay := 0.25
## Internal tolerance, never displayed as a pronunciation score.
@export_range(0.4, 1, 0.05) var reading_coverage := 0.65
@export_group("Reading appearance")
## Use the label's Inspector/Theme colour instead of replacing it at runtime.
@export var use_scene_text_colour := true
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
@onready var voice = get_node(speech_monitor_path)
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
	default_button.pressed.connect(use_default)
	retry_button.pressed.connect(retry_microphone)
	retry_button.hide()
	voice.transcript_received.connect(_on_transcript)
	voice.recognition_rejected.connect(_on_rejected)
	voice.status_changed.connect(_on_voice_status)
	status_label.show()
	var error: String = "Assign a Story resource." if story == null else story.validation_error()
	if not error.is_empty():
		status_label.text = error
		default_button.disabled = true
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
	feed.show()
	feed.text = queue[beat_index]
	feed.scroll_to_line(0)
	if not use_scene_text_colour: feed.add_theme_color_override("default_color", active_colour)
	prompt_label.hide()
	recognition_label.text = ""
	default_button.disabled = false
	default_button.text = reading_fallback_text
	_update_status()
	print("[Narration state] ", State.keys()[state], " moment=", active_index + 1, " beat=", beat_index + 1)
func _update_status() -> void:
	if state == State.COMPLETE: status_label.text = story.completed_message
	elif not autostart_voice: status_label.text = unavailable_message
	elif not voice.listening: status_label.text = voice.player_error if not voice.player_error.is_empty() else unavailable_message
	elif not voice.worker_ready: status_label.text = starting_message
	elif state == State.PROMPT: status_label.text = prompt_message
	elif state == State.READING: status_label.text = reading_message
	elif state == State.RESPONSE: status_label.text = response_message
func retry_microphone() -> void:
	if not valid or finished or leaving: return
	autostart_voice = true
	retry_button.hide()
	var phrases: PackedStringArray = story.grammar_phrases()
	voice.start_listening(phrases[0], phrases.slice(1), true)
func _on_voice_status(_message: String) -> void:
	if not valid or finished or leaving: return
	retry_button.visible = not voice.listening
	_update_status()
func _on_transcript(text: String) -> void:
	if not valid or finished or leaving: return
	if state == State.PROMPT:
		recognition_label.text = recognised_message + ": “" + text + "”"
		if story.moments[active_index].matches(text): _accept(text, false)
		else: status_label.text = retry_prompt_message
	elif state in [State.READING, State.RESPONSE]:
		recognition_label.text = recognised_message + ": “" + text + "”"
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
			status_label.text = retry_reading_message
func _on_rejected(_text: String) -> void:
	if not valid or finished or leaving: return
	if state in [State.READING, State.RESPONSE]:
		cursor = 0
		matched = 0
		status_label.text = retry_reading_message
	elif state == State.PROMPT: status_label.text = retry_prompt_message
func use_default() -> void:
	if not valid or finished or leaving: return
	if state == State.PROMPT: _accept("", true)
	elif state in [State.READING, State.RESPONSE]: _finish_reading()
func _finish_reading() -> void:
	var kind := state
	state = State.TRANSITION
	default_button.disabled = true
	if not use_scene_text_colour: feed.add_theme_color_override("default_color", inactive_colour)
	status_label.text = transition_message
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
	feed.hide()
	feed.text = ""
	prompt_label.text = story.moments[active_index].prompt_text
	prompt_label.show()
	recognition_label.text = ""
	default_button.text = prompt_fallback_text
	default_button.disabled = false
	_update_status()
	print("[Narration state] PROMPT moment=", active_index + 1)
func _accept(text: String, used_default: bool) -> void:
	pending = story.moments[active_index].outcome(text, used_default)
	pending["used_default"] = used_default
	state = State.RECOGNISED
	default_button.disabled = true
	status_label.text = fallback_message if used_default else recognised_message
	recognition_label.text = fallback_message if used_default else recognised_message + ": “" + text + "”"
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
		default_button.hide()
		retry_button.hide()
		_update_status()
		print("[Narration state] COMPLETE")
		moment_completed.emit(resolved, category, used_default)
		narration_completed.emit()
	else:
		active_index = story.index_of(pending.reconnect) if not pending.reconnect.is_empty() else active_index + 1
		moment_completed.emit(resolved, category, used_default)
		_start_moment()
