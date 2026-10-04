extends "res://Script/continuous_narration.gd"
@export var story_source: Resource
@export var variant: Resource
@export_range(0, 1, 0.05) var interaction_minimum_confidence := 0.35
@export_range(0, 1, 0.05) var narration_minimum_confidence := 0.60
@export var developer_skip_enabled := true
@export var uncertain_message := "Heard uncertainly"
@export var game_response_message := "STORY RESPONSE — watch what happens."
@export var ending_message := "ENDING"
@export var provisional_endpoint_message := "Current route stops here — provisional endpoint."
@export_group("Stage bindings")
@export_node_path("TextureRect") var beat_visual_path := NodePath("BeatVisual")
@onready var beat_visual = get_node(beat_visual_path)
@export_node_path("Control") var visual_placeholder_path := NodePath("VisualPlaceholder")
@onready var visual_placeholder = get_node(visual_placeholder_path)
@export_node_path("Node") var chapter_audio_path := NodePath("ChapterAudio")
@onready var chapter_audio = get_node(chapter_audio_path)
@export_group("")
var developer_option_index := 0
var story_state: Dictionary = {}
var _voice_started := false
var _voice_phase := ""
var current_interaction: PerformerInteraction
func _ready() -> void:
	back_button.pressed.connect(go_back)
	retry_button.pressed.connect(retry_microphone)
	default_button.hide()
	retry_button.hide()
	prompt_label.hide()
	status_label.show()
	voice.transcript_received.connect(_on_transcript)
	voice.recognition_rejected.connect(_on_rejected)
	voice.status_changed.connect(_on_voice_status)
	var error: String = "Assign a story." if story_source == null else story_source.validation_error(variant)
	if not error.is_empty():
		feed.text = ""
		status_label.text = error
		push_error("[Story configuration] " + error)
		return
	story = story_source
	story_state = story_source.initial_state.duplicate()
	valid = true
	_voice_started = autostart_voice
	narration_completed.connect(func(): chapter_audio.stop_all())
	_enter(0)
func _enter(index: int) -> void:
	if leaving or not is_inside_tree(): return
	while index < story_source.beats.size():
		if story_source.meets(story_source.beats[index].required_state, story_state): break
		index += 1
	if index >= story_source.beats.size():
		_finish_story()
		return
	active_index = index
	var beat: PerformerStoryBeat = story_source.beats[index]
	current_interaction = beat.interaction
	pending = {}
	recognition_label.text = ""
	chapter_audio.enter_beat(index, beat.audio_cues)
	beat_visual.texture = beat.visual
	beat_visual.visible = beat.visual != null
	visual_placeholder.visible = beat.visual == null
	print("[Story beat] ", index + 1, " id=", beat.beat_id, " state=", story_state)
	if beat.kind == 2:
		_show_ending(beat.text)
	elif beat.kind == 1:
		await _automatic(beat.text, beat.automatic_pause)
		if is_inside_tree() and not leaving: _route(beat.next_beat_id)
	else:
		queue = Text.beats(beat.text)
		beat_index = 0
		_show_beat(State.READING)
func _show_beat(kind: State) -> void:
	super._show_beat(kind)
	default_button.hide()
	if _voice_started: _configure_voice("narration")
func _finish_reading() -> void:
	if state != State.READING: return
	state = State.TRANSITION
	status_label.text = transition_message
	await get_tree().create_timer(transition_delay).timeout
	if not is_inside_tree() or leaving: return
	beat_index += 1
	if beat_index < queue.size(): _show_beat(State.READING)
	elif current_interaction != null: _show_prompt()
	else: _route(story_source.beats[active_index].next_beat_id)
func _show_prompt() -> void:
	state = State.TRANSITION
	await get_tree().create_timer(prompt_delay).timeout
	if not is_inside_tree() or leaving: return
	state = State.PROMPT
	feed.hide()
	prompt_label.text = current_interaction.prompt_c if variant.free_response and current_interaction.allow_free_response else current_interaction.prompt_a
	prompt_label.show()
	recognition_label.text = ""
	if _voice_started: _configure_voice("prompt_" + str(active_index))
	_update_status()
	print("[Story state] PLAYER_DIALOGUE beat=", active_index + 1)
func _on_transcript(text: String) -> void:
	if not valid or finished or leaving: return
	if _voice_started and not voice.worker_ready: return
	if state == State.READING:
		super._on_transcript(text)
	elif state == State.PROMPT:
		recognition_label.text = recognised_message + ": “" + text + "”"
		var choice = current_interaction.choose(text, variant)
		if choice != null and not (current_interaction.retry_unknown and choice.category == variant.unknown_category): _accept(text, false)
		else: status_label.text = retry_prompt_message
func _accept(text: String, used_default: bool) -> void:
	if state != State.PROMPT: return
	var option: PerformerResponse
	if used_default:
		var choices: Array[PerformerResponse] = []
		for candidate in current_interaction.options:
			if candidate.category != variant.unknown_category and current_interaction.available(candidate, variant.free_response, variant.unknown_category): choices.append(candidate)
		if not choices.is_empty(): option = choices[clampi(developer_option_index, 0, choices.size()-1)]
	else: option = current_interaction.choose(text, variant)
	if option == null: return
	state = State.RECOGNISED
	_pause_voice()
	status_label.text = recognised_message
	recognition_label.text = fallback_message if used_default else recognised_message + ": “" + text + "”"
	for key in option.state_changes: story_state[key] = option.state_changes[key]
	print("[Story choice] ", option.category, " state=", story_state)
	await get_tree().create_timer(recognition_display_duration).timeout
	if not is_inside_tree() or leaving: return
	if option.response_visual != null:
		beat_visual.texture = option.response_visual
		beat_visual.show()
		visual_placeholder.hide()
	for cue in option.audio_cues:
		if cue != null: chapter_audio.apply_cue(cue)
	await _automatic(option.response_text, current_interaction.response_pause)
	if not is_inside_tree() or leaving: return
	moment_completed.emit(active_index, option.category, used_default)
	if option.ends_story: _show_ending(option.ending_text)
	else: _route(option.reconnect_point if not option.reconnect_point.is_empty() else story_source.beats[active_index].next_beat_id)
func _automatic(text: String, seconds: float) -> void:
	state = State.RESPONSE
	_pause_voice()
	prompt_label.hide()
	feed.show()
	feed.text = text
	recognition_label.text = ""
	status_label.text = game_response_message
	print("[Story state] GAME_RESPONSE")
	await get_tree().create_timer(seconds).timeout
func _show_ending(text: String) -> void:
	prompt_label.hide()
	feed.show()
	feed.text = text
	_finish_story()
	if not text.is_empty(): status_label.text = ending_message
func _finish_story() -> void:
	finished = true
	state = State.COMPLETE
	_pause_voice()
	prompt_label.hide()
	recognition_label.text = ""
	status_label.text = story_source.completed_message
	narration_completed.emit()
	print("[Story state] ENDING / COMPLETE state=", story_state)
func _route(id: String) -> void:
	if story_source.beats[active_index].provisional_route_endpoint:
		_finish_story()
		status_label.text = provisional_endpoint_message
		print("[Story state] PROVISIONAL_ROUTE_ENDPOINT ", story_source.beats[active_index].beat_id)
		return
	var index: int = active_index + 1 if id.is_empty() else story_source.index_of(id)
	if index < 0:
		_pause_voice()
		status_label.text = "Missing destination: " + id
		return
	_enter(index)
func _pause_voice() -> void:
	voice.stop_listening()
	_voice_phase = ""
	retry_button.hide()
func retry_microphone() -> void:
	if not valid or finished or leaving or state not in [State.READING, State.PROMPT]: return
	autostart_voice = true
	_voice_started = true
	_voice_phase = ""
	_configure_voice("prompt_" + str(active_index) if state == State.PROMPT else "narration")
func _configure_voice(phase: String) -> void:
	if _voice_phase == phase: return
	_voice_phase = phase
	retry_button.hide()
	var prompt := state == State.PROMPT
	var phrases: PackedStringArray = current_interaction.phrases(variant) if prompt else story_source.grammar_phrases()
	voice.minimum_confidence = interaction_minimum_confidence if prompt else narration_minimum_confidence
	voice.start_listening(phrases[0], phrases.slice(1), true, prompt and variant.free_response and current_interaction.allow_free_response)
func _on_voice_status(message: String) -> void:
	if state in [State.READING, State.PROMPT]: super._on_voice_status(message)
func _on_rejected(text: String) -> void:
	if state not in [State.READING, State.PROMPT]: return
	super._on_rejected(text)
	if state == State.PROMPT and not text.is_empty(): recognition_label.text = uncertain_message + ": “" + text + "”"
func use_default() -> void:
	if not valid or finished or leaving: return
	if state == State.PROMPT: _accept("", true)
	elif state == State.READING: _finish_reading()
func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and developer_skip_enabled and event is InputEventKey:
		if event.pressed and not event.echo and event.ctrl_pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9 and state == State.PROMPT:
			developer_option_index = event.keycode - KEY_1
			print("[Developer route selection] option=", developer_option_index + 1)
			use_default()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_ENTER:
			developer_option_index = 0
			print("[Performer development skip] state=", State.keys()[state])
			use_default()
			get_viewport().set_input_as_handled()
