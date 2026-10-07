extends Node
signal completed
signal beat_entered(current: StageBeat)
signal turn_resolved(current: StageBeat, result: String)
const Matcher = preload("res://Script/StageActs/stage_matcher.gd")
const Text = preload("res://Script/narration_text.gd")
@export var sequence: StageSequence
@export var autostart_voice := true
@export var autostart_sequence := true
@export_range(0, 3, 0.05) var turn_wait := 0.4
@export_range(0.3, 0.6, 0.05) var recognition_pause := 0.45
var queued_response := ""
var queued_voice: AudioStream

@export_node_path("Node") var speech_path := NodePath("../SpeechMonitor")
@export_node_path("Control") var ui_path := NodePath("../StageUI")
@export_node_path("Node") var audio_path := NodePath("../ChapterAudio")
@export_range(0, 10, 0.1) var audio_end_fade := 0.5
@onready var speech = get_node(speech_path)
@onready var ui = get_node(ui_path)
@onready var chapter_audio = get_node(audio_path)
var beat: StageBeat
var index := -1
var state := "IDLE"
var elapsed := 0.0
var beat_elapsed := 0.0
var input_turn_elapsed := 0.0
var retries := 0
var unmatched := 0
var had_technical_rejection := false
var transcript := ""
var detected_intent := ""
var match_result := ""
var progress := Vector2i.ZERO
var destination := ""
var cue_revealed := false
func _ready() -> void:
	speech.transcript_received.connect(receive_transcript)
	speech.recognition_rejected.connect(technical_rejection)
	var error := "No sequence assigned" if sequence == null else sequence.validation_error()
	if not error.is_empty():
		state = "CONFIGURATION_ERROR"
		match_result = error
		push_error("[Stage] " + error)
		return
	if not autostart_sequence: return
	enter(sequence.index_of(sequence.start_beat) if not sequence.start_beat.is_empty() else 0)
func enter(next_index: int) -> void:
	speech.stop_listening()
	if next_index >= sequence.beats.size():
		state = "COMPLETE"
		ui.set_turn("COMPLETE")
		ui.hide_cue()
		chapter_audio.stop_all(audio_end_fade)
		completed.emit()
		print("[Stage] COMPLETE")
		return
	if next_index < 0:
		state = "CONFIGURATION_ERROR"
		match_result = "Missing destination"
		return
	index = next_index
	beat = sequence.beats[index]
	elapsed = 0
	beat_elapsed = 0
	input_turn_elapsed = 0
	retries = 0
	unmatched = 0
	had_technical_rejection = false
	progress = Vector2i.ZERO
	transcript = ""
	detected_intent = ""
	match_result = ""
	cue_revealed = false
	ui.show_beat(beat)
	chapter_audio.play_sfx(beat.sfx_on_start, beat.sfx_volume_db)
	# Apply on each actual beat entry, including authored loops; loop audio preserves playback.
	for cue in beat.audio:
		if cue != null: chapter_audio.apply_cue(cue)
	state = "TRANSITION" if beat.beat_type == StageBeat.BeatType.TRANSITION else "PREPARING"
	ui.set_turn("NPC_SPEAKING")
	beat_entered.emit(beat)
	if state == "TRANSITION":
		chapter_audio.play_sfx(beat.sfx_on_transition, beat.sfx_volume_db)
		get_node("../PreShow").start_transition()
	if beat.get_meta("stage_event_type", -1) in [10, 11]:
		state = "STAGE_EVENT"
		get_node("../PreShow").start_story_curtain(beat.get_meta("stage_event_type"), beat.get_meta("curtain_animation", &""))
	print("[Stage] ", beat.beat_id, " ", state, " mode=", StageBeat.InputMode.keys()[beat.input_mode])
func _process(delta: float) -> void:
	if beat == null or state in ["COMPLETE", "CONFIGURATION_ERROR"]: return
	beat_elapsed += delta
	if state in ["READY", "STARTING", "LISTENING"]: input_turn_elapsed += delta
	if state in ["READY", "STARTING", "LISTENING"] and not cue_revealed and input_turn_elapsed >= beat.cue_delay:
		cue_revealed = true
		ui.reveal_cue(beat)
		if beat.show_cue_card: ui.play_cue_sound()
	elapsed += delta
	match state:
		"PREPARING":
			if elapsed >= beat.delay_before_input and ui.dialogue_finished():
				if beat.input_mode == StageBeat.InputMode.NONE: resolve(beat.npc_success_response, beat.next_beat, "automatic", beat.success_voice)
				else:
					state = "WAIT"
					elapsed = 0
					ui.set_turn("WAIT")
		"WAIT":
			if elapsed >= turn_wait:
				state = "READY"
				ui.set_turn("READY")
				if not ui.click_to_speak: start_input()
		"PLAYER_FINISHED":
			if elapsed >= recognition_pause:
				if not queued_response.is_empty() or queued_voice != null: ui.play_dialogue(queued_response, queued_voice, beat.actor_id, true, beat.hide_subtitle_after_voice)
				state = "RESPONSE"
				elapsed = 0
				ui.set_turn("NPC_SPEAKING")
		"STARTING":
			if speech.worker_ready and speech.listening:
				state = "LISTENING"
				ui.set_turn("LISTENING")
				elapsed = 0
			elif elapsed >= beat.technical_failure_delay and not speech.waiting_for_browser_microphone():
				state = "MIC_ERROR"
				ui.set_turn("ERROR")
		"LISTENING":
			if speech.recognition_backend == 3 and speech.listening and not speech.worker_ready:
				state = "STARTING"
				elapsed = 0
				ui.set_turn("STARTING")
				return
			if autostart_voice and not speech.listening:
				state = "STARTING"
				elapsed = 0
			elif beat.timeout > 0 and elapsed >= beat.timeout:
				if had_technical_rejection:
					technical_fallback("Unclear speech before timeout")
				else: resolve(beat.npc_timeout_response, beat.timeout_beat if not beat.timeout_beat.is_empty() else beat.next_beat, "silence timeout", beat.timeout_voice)
		"RESPONSE":
			if elapsed >= beat.delay_after_response and ui.dialogue_finished():
				enter(sequence.index_of(destination) if not destination.is_empty() else index + 1)
func finish_transition() -> void:
	if state == "TRANSITION":
		enter(sequence.index_of(beat.next_beat) if not beat.next_beat.is_empty() else index + 1)

func start_input() -> void:
	if state not in ["READY", "MIC_ERROR", "STARTING", "LISTENING"]: return
	ui.set_turn("STARTING")
	elapsed = 0
	state = "STARTING"
	if not autostart_voice:
		state = "LISTENING"
		ui.set_turn("LISTENING")
		return
	speech.minimum_confidence = beat.minimum_confidence
	var phrases := beat.accepted_phrases.duplicate()
	for option in beat.responses: phrases.append_array(option.accepted_phrases)
	var target := beat.expected_line
	if target.is_empty() and not phrases.is_empty(): target = phrases[0]
	# Dictation allows unlisted names/attempts and keeps out-of-category speech distinct.
	speech.start_listening(target, phrases, true, beat.input_mode != StageBeat.InputMode.GUIDED_LINE)
func receive_transcript(value: String) -> void:
	if state == "STARTING" and speech.worker_ready and speech.listening:
		state = "LISTENING"
		elapsed = 0
	if state != "LISTENING" or Text.normalized(value).is_empty(): return
	ui.set_turn("LISTENING")
	ui.show_transcript(value)
	transcript = value
	if beat.input_mode in [StageBeat.InputMode.ANY_SPEECH, StageBeat.InputMode.ANY_SPEECH_OR_TIMEOUT]:
		detected_intent = beat.expected_intent
		resolve(beat.npc_success_response, beat.next_beat, "speech attempt", beat.success_voice)
		return
	if beat.input_mode == StageBeat.InputMode.GUIDED_LINE:
		progress = Matcher.line_progress(beat.expected_line, value, progress.x, progress.y)
		var count := Text.normalized(beat.expected_line).split(" ", false).size()
		if Matcher.alias_matches(beat.accepted_phrases, value) or (count > 0 and progress.x >= count - 1 and float(progress.y) / count >= beat.line_coverage):
			resolve(beat.npc_success_response, beat.next_beat, "guided line matched", beat.success_voice)
		else:
			match_result = "Partial line; repeat or continue"
		return
	var option: StageResponse = Matcher.option_for(beat, value)
	if option != null:
		detected_intent = option.intent
		resolve(option.npc_response, option.next_beat if not option.next_beat.is_empty() else beat.next_beat, "intent matched", option.voice)
	elif Matcher.alias_matches(beat.accepted_phrases, value):
		detected_intent = beat.expected_intent
		resolve(beat.npc_success_response, beat.next_beat, "intent matched", beat.success_voice)
	elif beat.unmatched_action == 1:
		resolve(beat.npc_unclear_response, beat.alternate_beat if not beat.alternate_beat.is_empty() else beat.next_beat, "transcribed, unclassified", beat.unclear_voice)
	else:
		unmatched += 1
		match_result = "Transcribed outside authored phrases; retry"
		if unmatched > beat.retry_count:
			resolve(beat.npc_unclear_response, beat.fallback_beat if not beat.fallback_beat.is_empty() else beat.next_beat, "neutral fallback")
		else:
			ui.play_dialogue(beat.npc_retry_response, beat.retry_voice, beat.actor_id, beat.show_npc_dialogue)
			if beat.retry_voice != null:
				speech.stop_listening()
				state = "PREPARING"
				ui.set_turn("NPC_SPEAKING")
				elapsed = 0
func technical_rejection(_value: String) -> void:
	if state not in ["LISTENING", "STARTING"]: return
	if beat.accept_uncertain_attempt:
		if not Text.normalized(_value).is_empty():
			state = "LISTENING"
			receive_transcript(_value)
		else:
			speech.stop_listening()
			state = "MIC_ERROR"
			ui.set_turn("ERROR")
			match_result = "No recognisable words; retry this turn"
		return
	retries += 1
	had_technical_rejection = true
	progress = Vector2i.ZERO
	match_result = "Technical recognition rejection; retry"
	print("[Stage speech] ", match_result, " count=", retries)
	if retries > beat.retry_count: technical_fallback("Recognition retry limit")
func technical_fallback(reason: String) -> void:
	# No NPC wrong/unclear response on technical failure.
	resolve("", beat.fallback_beat if not beat.fallback_beat.is_empty() else beat.next_beat, "Technical fallback: " + reason)
func resolve(response: String, target: String, result: String, voice: AudioStream = null) -> void:
	if state in ["PLAYER_FINISHED", "RESPONSE", "COMPLETE"]: return
	speech.stop_listening()
	match_result = result
	destination = target
	queued_response = response
	queued_voice = voice
	ui.hide_cue()
	ui.set_turn("FINISHED")
	if result in ["guided line matched", "speech attempt", "intent matched", "transcribed, unclassified"]:
		ui.acknowledge()
		chapter_audio.play_sfx(beat.sfx_after_player, beat.sfx_volume_db)
	state = "PLAYER_FINISHED"
	elapsed = 0
	turn_resolved.emit(beat, result)
	print("[Stage] ", beat.beat_id, " ", result, " intent=", detected_intent)
func debug_advance(option_index := -1) -> void:
	if not OS.is_debug_build() or beat == null or not beat.allow_debug_bypass or state in ["COMPLETE", "CONFIGURATION_ERROR", "TRANSITION"]: return
	if state == "RESPONSE":
		elapsed = beat.delay_after_response
	elif option_index >= 0 and option_index < beat.responses.size():
		var option := beat.responses[option_index]
		detected_intent = option.intent
		resolve(option.npc_response, option.next_beat if not option.next_beat.is_empty() else beat.next_beat, "DEBUG selected response")
	else: resolve(beat.npc_success_response, beat.next_beat, "DEBUG bypass")
func retry_microphone() -> void:
	if state not in ["STARTING", "LISTENING", "MIC_ERROR"]: return
	autostart_voice = true
	start_input()
func _exit_tree() -> void:
	if is_instance_valid(speech): speech.stop_listening()

func skip_dialogue() -> void:
	if state not in ["PREPARING", "RESPONSE", "TRANSITION"]: return
	if ui.skip_current_passage():
		if state == "PREPARING": elapsed = beat.delay_before_input
		elif state == "RESPONSE": elapsed = beat.delay_after_response
		_process(0)

func finish_stage_event() -> void:
	if state == "STAGE_EVENT":
		enter(sequence.index_of(beat.next_beat) if not beat.next_beat.is_empty() else index + 1)
