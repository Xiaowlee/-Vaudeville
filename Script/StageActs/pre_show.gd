extends Node
const Typewriter = preload("res://Script/StageActs/typewriter.gd")
var writer = Typewriter.new()

var reminder_after_seconds := 8.0
@export_group("Curtain and turn timing")
var prompt_text := ""
var yes_phrases := PackedStringArray()
var no_phrases := PackedStringArray()
var voice_volume_db := 0.0
var voice_delay := 0.0
@export var curtain_open_sfx: AudioStream
@export var curtain_close_sfx: AudioStream
@export_range(-60, 6, 1) var curtain_sfx_volume_db := -18.0
var voice_pending := false
var voice_wait := 0.0
@export var curtain_animation: StringName
@export_range(0.1, 5, 0.1) var curtain_speed := 1.0
@export_range(0, 30, 0.1) var delay_before_act := 0.5
@export_range(1, 30, 0.5) var microphone_retry_delay := 8.0
var introduction_line_seconds := 6.0
@export_range(0, 10, 0.1) var transition_closed_seconds := 0.8
@export var transition_sound: AudioStream
## These existing artwork nodes stay hidden during the storybook section.
@export var full_stage_art: Array[NodePath] = []
var introduction_index := 0
var transition_state := ""
var transition_elapsed := 0.0
var first_act_beat := ""
@export var autostart_voice := true
@export_range(0, 10, 0.1) var prompt_delay := 1.0
@export_range(0.3, 2, 0.05) var acknowledgement_delay := 0.45
@onready var ui = get_node("../StageUI")

@export_node_path("AnimatedSprite2D") var curtain_path := NodePath("../Curtain/AnimatedSprite2D")
@export_node_path("Control") var panel_path := NodePath("../StageUI/PreShow")
@onready var curtain: AnimatedSprite2D = get_node(curtain_path)
@onready var panel = get_node(panel_path)
@onready var speech = get_node("../SpeechMonitor")
@onready var flow = get_node("../GameController")
@onready var voice: AudioStreamPlayer = $Voice
var opening_block: StoryBlock
var opening_input: PlayerInteractionData
var scripted_lines: Array[DialogueLineData] = []
var active_line: DialogueLineData
var reminder_count := 0
var repeating := false
var event_queue: Array[StageEvent] = []
var event_index := 0
var event_wait := -1.0
var event_after := ""
var event_curtain := false
var story_curtain := false
var state := "PRE_SHOW"
var elapsed := 0.0
var status := ""
func _ready() -> void:
	get_node("../Actors").show()
	get_node("../StageView").show()
	curtain.get_parent().show()
	curtain.stop()
	if curtain.sprite_frames.has_animation(curtain_animation):
		curtain.animation = curtain_animation
		curtain.set_frame_and_progress(0, 0)
	curtain.animation_finished.connect(opening_finished)
	speech.transcript_received.connect(receive)
	speech.recognition_rejected.connect(func(_text):
		if state in ["STARTING", "LISTENING"]: status = "Recognition unclear; retry")
	panel.hide()
	ui.set_turn("WAIT")
	opening_block = flow.sequence.opening()
	if opening_block == null:
		state = "CONFIGURATION_ERROR"
		push_error("StorySequence needs a PRESHOW block")
		return
	for entry in opening_block.ordered_content():
		if entry is DialogueLineData: scripted_lines.append(entry)
		elif entry is PlayerInteractionData: opening_input = entry
	if opening_input == null or scripted_lines.is_empty():
		state = "CONFIGURATION_ERROR"
		push_error("PRESHOW needs dialogue and one YES/NO interaction")
		return
	yes_phrases = opening_input.yes_phrases
	no_phrases = opening_input.no_phrases
	prompt_text = opening_input.cue_card_text
	reminder_after_seconds = opening_input.reminder_delay
	first_act_beat = opening_block.next_block if not opening_block.next_block.is_empty() else flow.sequence.start_beat
	for event in opening_block.end_events:
		if event.event_type == 10 and not event.animation.is_empty(): curtain_animation = event.animation
	run_events(opening_block.start_events, "INTRO")
func show_line(text: String, audio: AudioStream) -> void:
	panel.get_node("Margin/Lines/Dialogue").text = text
	writer.begin(panel.get_node("Margin/Lines/Dialogue"), active_line.presentation.typing_override if active_line != null and active_line.presentation != null and active_line.presentation.typing_override != null else ui.typing_settings)
	panel.get_node("Margin/Lines/Prompt").text = prompt_text
	panel.get_node("Margin/Lines/Prompt").hide()
	voice.stop()
	voice.stream = audio
	voice.volume_db = voice_volume_db
	voice_pending = audio != null
	voice_wait = voice_delay
	if voice_pending and voice_wait <= 0:
		voice.play()
		voice_pending = false
func present_line(line: DialogueLineData) -> void:
	active_line = line
	voice_delay = line.presentation.voice_delay if line.presentation != null else 0.0
	voice_volume_db = line.presentation.voice_volume_db if line.presentation != null else 0.0
	introduction_line_seconds = line.wait_after
	show_line(line.text, line.voice_audio)
	elapsed = 0
func ask(repeat: bool) -> void:
	speech.stop_listening()
	panel.show()
	repeating = repeat
	introduction_index = 0
	if repeat:
		if opening_input.reminder == null: ready_for_answer(); return
		present_line(opening_input.reminder)
	else: present_line(scripted_lines[0])
	ui.set_turn("NPC_SPEAKING")
	state = "ASKING"
func ready_for_answer() -> void:
	voice.stop()
	voice_pending = false
	panel.get_node("Margin/Lines/Prompt").show()
	state = "READY"
	elapsed = 0
	ui.set_turn("READY")
	if not ui.click_to_speak: listen()
func line_finished() -> bool:
	if not writer.finished() or elapsed < introduction_line_seconds: return false
	if active_line != null and active_line.voice_end_mode == 1:
		voice.stop()
		voice_pending = false
	return not voice_pending and not voice.playing
func maybe_remind() -> void:
	if not opening_input.reminder_enabled: return
	if reminder_count > 0 and not opening_input.reminder_repeat: return
	var delay := opening_input.reminder_delay if reminder_count == 0 else opening_input.reminder_interval
	if elapsed >= delay:
		reminder_count += 1
		ask(true)
func start_input() -> void:
	if state == "READY": listen()
func listen() -> void:
	ui.set_turn("STARTING")
	if not autostart_voice:
		state = "LISTENING"
		ui.set_turn("LISTENING")
		return
	state = "STARTING"
	elapsed = 0
	var phrases := yes_phrases + no_phrases
	speech.start_listening(phrases[0] if not phrases.is_empty() else "", phrases, true, true)
func _process(delta: float) -> void:
	if state == "EVENTS":
		advance_events(delta)
		return
	if voice_pending:
		voice_wait -= delta
		if voice_wait <= 0:
			voice_pending = false
			voice.play()
	elapsed += writer.advance(delta) if state in ["ASKING", "NO_WAIT"] else delta
	if not transition_state.is_empty():
		transition_elapsed += delta
		if transition_state == "CLOSED" and transition_elapsed >= transition_closed_seconds and ui.dialogue_finished():
			transition_state = "OPENING"
			curtain.speed_scale = curtain_speed
			curtain.play(curtain_animation)
			get_node("../ChapterAudio").play_sfx([curtain_open_sfx], curtain_sfx_volume_db)
		return
	match state:
		"READY": maybe_remind()
		"ASKING":
			if line_finished():
				if not repeating and introduction_index < scripted_lines.size() - 1:
					introduction_index += 1
					present_line(scripted_lines[introduction_index])
				elif elapsed >= introduction_line_seconds + prompt_delay: ready_for_answer()
		"STARTING":
			if speech.worker_ready and speech.listening:
				state = "LISTENING"
				elapsed = 0
				ui.set_turn("LISTENING")
			elif elapsed >= microphone_retry_delay and not speech.waiting_for_browser_microphone():
				status = speech.last_error
				state = "MIC_ERROR"
				ui.set_turn("ERROR")
		"LISTENING":
			maybe_remind()
			if state == "LISTENING" and autostart_voice and not speech.listening:
				if speech.recognition_backend == 3 and not speech.last_error.is_empty():
					status = speech.last_error
					state = "MIC_ERROR"
					ui.set_turn("ERROR")
				else: listen()
		"ACKNOWLEDGED":
			if elapsed >= acknowledgement_delay: run_events(opening_block.end_events, "ACT")
		"NO_WAIT":
			if line_finished(): ask(true)
		"ACT_DELAY":
			if elapsed >= delay_before_act:
				state = "FINISHED"
				flow.enter(flow.sequence.index_of(first_act_beat))
func receive(text: String) -> void:
	if state == "STARTING" and speech.worker_ready and speech.listening: state = "LISTENING"
	if state != "LISTENING": return
	ui.set_turn("LISTENING")
	ui.show_transcript(text)
	if flow.Matcher.alias_matches(yes_phrases, text): begin_open()
	elif flow.Matcher.alias_matches(no_phrases, text):
		speech.stop_listening()
		ui.set_turn("NPC_SPEAKING")
		if opening_input.no_reply != null: present_line(opening_input.no_reply)
		else: ask(true); return
		state = "NO_WAIT"
		elapsed = 0
	else: status = "Unclassified response; waiting for YES or NO"
func begin_open() -> void:
	if state in ["ACKNOWLEDGED", "OPENING", "ACT_DELAY", "FINISHED"]: return
	speech.stop_listening()
	voice.stop()
	voice_pending = false
	if not curtain.sprite_frames.has_animation(curtain_animation) or curtain.sprite_frames.get_animation_loop(curtain_animation):
		state = "CONFIGURATION_ERROR"
		status = "Assign a non-looping curtain animation"
		push_error(status)
		return
	panel.get_node("Margin/Lines/Prompt").hide()
	ui.set_turn("FINISHED")
	ui.acknowledge()
	state = "ACKNOWLEDGED"
	elapsed = 0
func begin_storybook() -> void:
	panel.hide()
	curtain.get_parent().hide()
	get_node("../StageView").show()
	get_node("../Actors").show()
	for path in full_stage_art: get_node(path).show()
	state = "ACT_DELAY"
	elapsed = 0

func start_transition() -> void:
	speech.stop_listening()
	ui.hide_cue()
	ui.set_turn("WAIT")
	curtain.stop()
	curtain.animation = curtain_animation
	curtain.set_frame_and_progress(0, 0)
	curtain.get_parent().show()
	for path in full_stage_art: get_node(path).show()
	transition_state = "CLOSED"
	transition_elapsed = 0
	get_node("../ChapterAudio").play_sfx([curtain_close_sfx, transition_sound], curtain_sfx_volume_db)

func play_open(play_sound := true) -> void:
	get_node("../StageView").show()
	get_node("../Actors").show()
	for path in full_stage_art: get_node(path).show()
	panel.hide()
	state = "OPENING"
	curtain.speed_scale = curtain_speed
	curtain.play(curtain_animation)
	if play_sound: get_node("../ChapterAudio").play_sfx([curtain_open_sfx], curtain_sfx_volume_db)
func opening_finished() -> void:
	if story_curtain:
		story_curtain = false
		curtain.get_parent().hide()
		flow.finish_stage_event()
		return
	if event_curtain:
		event_curtain = false
		curtain.get_parent().hide()
		event_index += 1
		event_wait = -1
		state = "EVENTS"
		return
	if transition_state == "OPENING":
		curtain.get_parent().hide()
		transition_state = ""
		flow.finish_transition()
		return
	if state != "OPENING": return
	curtain.get_parent().hide()
	get_node("../StageView").show()
	get_node("../Actors").show()
	state = "ACT_DELAY"
	elapsed = 0
func debug_advance() -> void:
	if OS.is_debug_build(): begin_open()
func retry_microphone() -> void:
	if state in ["STARTING", "LISTENING", "MIC_ERROR"]: listen()
func _exit_tree() -> void:
	if state != "FINISHED" and is_instance_valid(speech): speech.stop_listening()

func skip_dialogue() -> void:
	if state not in ["ASKING", "NO_WAIT"]: return
	if writer.typing:
		writer.reveal()
		return
	voice.stop()
	voice_pending = false
	writer.remaining = 0
	elapsed = introduction_line_seconds + prompt_delay
	_process(0)

func run_events(events: Array[StageEvent], after: String) -> void:
	event_queue = events
	event_index = 0
	event_wait = -1
	event_after = after
	state = "EVENTS"
func advance_events(delta: float) -> void:
	if event_index >= event_queue.size():
		if event_after == "INTRO": ask(false)
		else: state = "ACT_DELAY"; elapsed = 0
		return
	var event := event_queue[event_index]
	if event == null: event_index += 1; return
	if event.event_type == 0:
		if event_wait < 0: event_wait = event.duration
		event_wait -= delta
		if event_wait > 0: return
	elif event.event_type == 10:
		if not event.animation.is_empty(): curtain_animation = event.animation
		event_curtain = true
		play_open(false)
		return
	elif event.event_type == 11:
		curtain.stop()
		curtain.set_frame_and_progress(0, 0)
		curtain.get_parent().show()
	else:
		var b := event.to_beat()
		for cue in b.audio: get_node("../ChapterAudio").apply_cue(cue)
		get_node("../ChapterAudio").play_sfx(b.sfx_on_start, b.sfx_volume_db)
		for action in b.actor_actions:
			for actor in get_node("../Actors").get_children():
				if actor.identity.actor_id == action.actor_id: actor.apply_action(action)
		if b.send_phone_cue: get_node("../IFB").on_beat(b)
	event_index += 1
	event_wait = -1

func start_story_curtain(kind: int, animation_name: StringName) -> void:
	if not animation_name.is_empty(): curtain_animation = animation_name
	curtain.get_parent().show()
	if kind == 11:
		curtain.stop()
		curtain.animation = curtain_animation
		curtain.set_frame_and_progress(0, 0)
		flow.call_deferred("finish_stage_event")
	else:
		if not curtain.sprite_frames.has_animation(curtain_animation) or curtain.sprite_frames.get_animation_loop(curtain_animation):
			push_error("Curtain opening requires a non-looping animation")
			return
		story_curtain = true
		curtain.speed_scale = curtain_speed
		curtain.play(curtain_animation)
