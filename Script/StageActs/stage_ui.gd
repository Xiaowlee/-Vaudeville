extends Control
## Emitted whenever a player-line prompt becomes visible or is cleared, even when the desktop card stays hidden.
signal cue_revealed(text: String)
signal cue_hidden
const TypingSettings = preload("res://Script/StageActs/typing_settings.gd")
const Typewriter = preload("res://Script/StageActs/typewriter.gd")
@export_group("Typewriter")
@export var typing_settings: TypingSettings = TypingSettings.new()
@export_group("")
var cue_sound_played := false
var cue_audio: Array = []
var cue_volume := -18.0
var active_typing: Resource
var writer = Typewriter.new()
@export_node_path("PanelContainer") var npc_path := NodePath("NPCDialogue")
@export_node_path("PanelContainer") var transcript_path := NodePath("PlayerTranscript")
@export var display_transcripts := true
@export var click_to_speak := true
@export var skip_dialogue_key: Key = KEY_SPACE
@export var speak_key: Key = KEY_X
@export var ready_text := "Click / X to speak"
@export var starting_text := "Starting microphone…"
@export var listening_text := "Listening…"
@export var npc_turn_text := "NPC speaking"
@export var wait_text := "Please wait"
@export var finished_text := "Heard"
@export var retry_text := "Mic unavailable — click to retry"
@export_range(0.1, 20, 0.1) var sentence_seconds := 3.0
var accept_transcript := false
var dialogue_lines := PackedStringArray()
var line_index := 0
var line_elapsed := 0.0
var turn := "WAIT"
var current_sentence_seconds := 3.0

@export_node_path("Node") var speech_path := NodePath("../SpeechMonitor")
var transcript_allowed := true
var current_voice: AudioStreamPlayer
var hide_after_voice := false
var voice_was_playing := false
var voice_pending := false
var voice_wait := 0.0
var voice_end_mode := 0
var voice_delay := 0.0
var voice_volume_db := 0.0
@export_node_path("PanelContainer") var thought_path := NodePath("PlayerThought")
@export_node_path("PanelContainer") var cue_path := NodePath("CueCard")
## Off when prompts are shown on the phone display instead of the desktop.
@export var desktop_cue_card := true
@export_node_path("PanelContainer") var ifb_path := NodePath("LocalIFB")
@export_node_path("Control") var actors_path := NodePath("../Actors")
@export_node_path("Button") var menu_path := NodePath("Menu")
@export_file("*.tscn") var menu_scene := "res://Scene/00_main_menu.tscn"
func _ready() -> void:
	var speech = get_node(speech_path)
	speech.partial_transcript_received.connect(show_transcript)
	speech.final_transcript_received.connect(show_transcript)
	get_node(menu_path).pressed.connect(func(): get_tree().change_scene_to_file(menu_scene))
	$Speak.pressed.connect(request_speech)
func request_speech() -> void:
	var target = get_node("../GameController")
	var pre = get_node_or_null("../PreShow")
	if pre != null and pre.state != "FINISHED": target = pre
	if turn == "READY": target.start_input()
	elif turn == "ERROR": target.retry_microphone()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and event.keycode == skip_dialogue_key:
		var pre = get_node_or_null("../PreShow")
		if pre != null and pre.state != "FINISHED": pre.skip_dialogue()
		else: get_node("../GameController").skip_dialogue()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and event.keycode == speak_key and turn in ["READY", "ERROR"]:
		request_speech()
		get_viewport().set_input_as_handled()
func set_turn(value: String) -> void:
	turn = value
	$Speak.visible = value != "COMPLETE"
	accept_transcript = value == "LISTENING"
	var words := {"READY":ready_text,"STARTING":starting_text,"LISTENING":listening_text,"NPC_SPEAKING":npc_turn_text,"WAIT":wait_text,"FINISHED":finished_text,"ERROR":retry_text}
	$Speak.text = words.get(value, wait_text)
	$Speak.disabled = value not in ["READY", "ERROR"]
func hide_cue() -> void:
	get_node(cue_path).hide()
	cue_hidden.emit()
func panel(path: NodePath, value: String, shown: bool) -> void:
	var node := get_node(path)
	node.get_node("Margin/Text").text = value
	node.visible = shown
func show_beat(beat: StageBeat) -> void:
	cue_sound_played = false
	cue_audio = beat.sfx_on_cue
	cue_volume = beat.sfx_volume_db
	stop_dialogue()
	transcript_allowed = beat.show_player_transcript
	panel(transcript_path, "", false)
	voice_end_mode = beat.get_meta("voice_end_mode", 0)
	voice_delay = beat.voice_delay
	voice_volume_db = beat.voice_volume_db
	active_typing = beat.typing_override if beat.typing_override is TypingSettings else typing_settings
	current_sentence_seconds = beat.presentation_seconds if beat.presentation_seconds > 0 else sentence_seconds
	var spoken_text := beat.narration_text if beat.beat_type in [StageBeat.BeatType.NARRATION, StageBeat.BeatType.TRANSITION] else beat.npc_dialogue
	play_dialogue(spoken_text, beat.npc_voice, beat.actor_id, beat.show_npc_dialogue, beat.hide_subtitle_after_voice)
	if not beat.speaker_name.is_empty(): $NPCDialogue/SpeakerLayer/Speaker.text = beat.speaker_name
	panel(thought_path, beat.player_thought, beat.show_player_thought)
	panel(cue_path, beat.cue_card_text, false)
	panel(ifb_path, "", false)
	for action in beat.actor_actions:
		if action == null: continue
		for actor in get_node(actors_path).get_children():
			if actor.identity != null and actor.identity.actor_id == action.actor_id: actor.apply_action(action)
func reveal_cue(beat: StageBeat) -> void:
	var text := beat.cue_card_text
	if text.is_empty() and beat.beat_type == StageBeat.BeatType.PLAYER_LINE: text = beat.expected_line
	panel(cue_path, text, beat.show_cue_card and desktop_cue_card)
	if beat.show_cue_card and not text.is_empty(): cue_revealed.emit(text)
func reaction(text: String) -> void:
	if not text.is_empty(): panel(npc_path, text, true)
func local_ifb(text: String, shown: bool) -> void:
	panel(ifb_path, text, shown)

func show_transcript(value: String) -> void:
	if not accept_transcript: return
	panel(transcript_path, value, display_transcripts and transcript_allowed and not value.is_empty())
func stop_dialogue() -> void:
	if is_instance_valid(current_voice): current_voice.stop()
	voice_was_playing = false
	voice_pending = false
func play_dialogue(text: String, stream: AudioStream, actor_id := "", shown := true, hide_when_done := false) -> void:
	stop_dialogue()
	dialogue_lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n\n", false)
	line_index = 0
	line_elapsed = 0
	panel(npc_path, dialogue_lines[0] if not dialogue_lines.is_empty() else "", shown and not text.is_empty())
	writer.begin(get_node(npc_path).get_node("Margin/Text"), active_typing if active_typing != null else typing_settings)
	var descriptor := ""
	for actor in get_node(actors_path).get_children():
		if actor.identity != null and actor.identity.actor_id == actor_id: descriptor = actor.identity.display_name
	$NPCDialogue/SpeakerLayer/Speaker.text = descriptor
	hide_after_voice = hide_when_done
	current_voice = $DialogueVoice
	for actor in get_node(actors_path).get_children():
		if actor.identity != null and actor.identity.actor_id == actor_id:
			current_voice = actor.play_voice(null)
			break
	if current_voice == $DialogueVoice:
		current_voice.stream = stream
		
	current_voice.stream = stream
	current_voice.volume_db = voice_volume_db
	voice_pending = stream != null
	voice_wait = voice_delay
	if voice_pending and voice_wait <= 0:
		current_voice.play()
		voice_pending = false
	voice_was_playing = current_voice.playing
func dialogue_playing() -> bool:
	return voice_pending or (is_instance_valid(current_voice) and current_voice.playing)
func dialogue_finished() -> bool:
	if voice_end_mode == 1 and writer.finished() and (dialogue_lines.is_empty() or (line_index == dialogue_lines.size() - 1 and line_elapsed >= current_sentence_seconds)):
		stop_dialogue()
	return writer.finished() and not dialogue_playing() and (dialogue_lines.is_empty() or (line_index == dialogue_lines.size() - 1 and line_elapsed >= current_sentence_seconds))
func _process(_delta: float) -> void:
	if voice_pending:
		voice_wait -= _delta
		if voice_wait <= 0:
			voice_pending = false
			current_voice.play()
			voice_was_playing = true
	line_elapsed += writer.advance(_delta)
	if line_index < dialogue_lines.size() - 1 and line_elapsed >= current_sentence_seconds:
		line_index += 1
		line_elapsed = 0
		get_node(npc_path).get_node("Margin/Text").text = dialogue_lines[line_index]
		writer.begin(get_node(npc_path).get_node("Margin/Text"), active_typing if active_typing != null else typing_settings)
	if voice_was_playing and not dialogue_playing() and writer.finished():
		voice_was_playing = false
		if hide_after_voice and writer.finished(): get_node(npc_path).hide()

func acknowledge() -> void:
	if $Acknowledgement.stream != null: $Acknowledgement.play()

func skip_current_passage() -> bool:
	if writer.typing:
		writer.reveal()
		return false
	# Explicit skip cancels this passage's voice, including a delayed start.
	stop_dialogue()
	writer.remaining = 0
	if line_index < dialogue_lines.size() - 1:
		line_index += 1
		line_elapsed = 0
		get_node(npc_path).get_node("Margin/Text").text = dialogue_lines[line_index]
		writer.begin(get_node(npc_path).get_node("Margin/Text"), active_typing if active_typing != null else typing_settings)
		return false
	line_elapsed = current_sentence_seconds
	return true

func play_cue_sound() -> void:
	if cue_sound_played: return
	cue_sound_played = true
	get_node("../ChapterAudio").play_sfx(cue_audio, cue_volume)
