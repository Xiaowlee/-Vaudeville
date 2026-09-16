@tool
extends Control
## Shared sequencing only. Wording and requirements belong to Sentence Definition.
signal story_completed(sentence_id: StringName)
signal transition_requested(scene_path: String)
signal interaction_state_changed(state: String)
@export_group("Content")
@export var sentence_definition: Resource = preload("res://prototype_1/scene_0_sentence.tres"):
	set(value):
		sentence_definition = value
		if is_node_ready() and Engine.is_editor_hint(): _preview_content()
@export_group("Transition")
@export_file("*.tscn") var intro_scene := "res://Scene/Intro.tscn"
@export_file("*.tscn") var next_scene := ""
@export var auto_advance := true
@export_range(0.0, 60.0, 0.1, "or_greater") var transition_delay := 5.0
@export_group("Response")
@export var animation_name: StringName = &"light_on"
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = ^"AnimationPlayer"
@export_node_path("Control") var room_path: NodePath = ^"Margin/Layout/Room"
@export var completion_signal_name: StringName = &"story_completed"
@export var starts_dark := true
@export_range(0.0, 60.0, 0.1, "or_greater") var response_delay := 0.0
@export_range(0.0, 60.0, 0.1, "or_greater") var light_fade_duration := 1.8
@export_range(0.0, 60.0, 0.1, "or_greater") var face_response_delay := 0.6
@export var accepted_mic_color := Color("48404b")
@export_group("Debug")
@export var debug_logging := true
@export var debug_manual_enabled := true
@export_group("Legacy Compatibility")
## Existing face-first scene only. New configurations use the resource input toggles.
@export var requires_face_first := false
var face_complete := false
var drag_required := true
var face_required := false
var voice_required := true
var interaction_state := "INITIALIZING"
@onready var sentence = $Margin/Layout/Story/Sentence
@onready var speech = $SpeechMonitor
@onready var mic: Label = $Margin/Layout/Story/MicIndicator
@onready var animation: AnimationPlayer = get_node_or_null(animation_player_path)
@onready var room = get_node_or_null(room_path)
var completed := false
var advancing := false
var response_finished := false
var auto_timer: Timer

func _preview_content() -> void:
	if sentence != null:
		sentence.definition = sentence_definition
		sentence.configure_content()

func _ready() -> void:
	if Engine.is_editor_hint():
		_preview_content()
		return
	_log("Scene", scene_file_path)
	if not has_signal(completion_signal_name):
		add_user_signal(completion_signal_name, [{"name":"sentence_id", "type":TYPE_STRING_NAME}])
	auto_timer = Timer.new()
	auto_timer.one_shot = true
	add_child(auto_timer)
	auto_timer.timeout.connect(advance)
	$Margin/Layout/Story/Next.pressed.connect(advance)
	$Margin/Layout/Story/Next.hide()
	$Button.pressed.connect(go_home)
	$"Dark bg".mouse_filter = Control.MOUSE_FILTER_IGNORE
	$"Dark bg".modulate.a = 1.0 if starts_dark else 0.0
	if room != null and not starts_dark: room.light_amount = 1.0
	sentence.definition = sentence_definition
	sentence.debug_logging = debug_logging
	if not sentence.configure_content():
		sentence.set_choices_visible(false)
		_set_state("CONFIGURATION_ERROR")
		return
	drag_required = sentence_definition.require_drag and not requires_face_first
	face_required = sentence_definition.require_face or requires_face_first
	voice_required = sentence_definition.require_voice
	sentence.voice_required = voice_required
	sentence.reading_enabled = false
	sentence.ready_to_read.connect(_sentence_ready)
	sentence.performed.connect(_perform_scene)
	speech.transcript_received.connect(sentence.submit_transcript)
	speech.status_changed.connect(func(message: String):
		mic.text = message
		_log("Voice status", message))
	$PhoneInputHook.phone_connected.connect(func(value: bool): _log("Phone", "connected" if value else "disconnected"))
	$PhoneInputHook.face_present.connect(func(value: bool): _log("Face presence", str(value)))
	$PhoneInputHook.face_cue_met.connect(_face_succeeded)
	_begin_inputs.call_deferred()

func _begin_inputs() -> void:
	if advancing: return
	mic.text = sentence_definition.idle_prompt
	if face_required:
		sentence.set_choices_visible(false)
		mic.text = sentence_definition.face_prompt
		_set_state("WAITING_FOR_FACE")
		$PhoneInputHook.start_face_request()
	else:
		_begin_drag_or_voice()

func _begin_drag_or_voice() -> void:
	if drag_required:
		sentence.set_choices_visible(true)
		sentence.reading_enabled = true
		_set_state("WAITING_FOR_DRAG")
	else:
		sentence.set_choices_visible(false)
		if sentence.inserted_card == null: sentence.reveal_correct_word()
		else: sentence.inserted_card.show()
		sentence.enable_reading()

func _sentence_ready() -> void:
	if face_required and not face_complete: return
	if not voice_required:
		_log("Input", "Voice not required; configured inputs satisfied")
		sentence.accept_speech()
		return
	_set_state("WAITING_FOR_VOICE")
	var alternatives: PackedStringArray = sentence_definition.rejected_phrases()
	speech.start_listening(sentence_definition.normalized(sentence_definition.sentence_text), alternatives)
	if debug_manual_enabled and OS.is_debug_build():
		_log("Debug", "Ctrl+Enter accepts manually; it is not speech recognition.")

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and event.ctrl_pressed:
		debug_accept()

func debug_accept() -> void:
	if debug_manual_enabled and OS.is_debug_build() and sentence.state == sentence.State.READY_TO_READ:
		_log("Debug manual success", sentence_definition.sentence_text)
		sentence.accept_speech()

func _perform_scene(id: StringName) -> void:
	if completed or (face_required and not face_complete): return
	completed = true
	speech.stop_listening()
	mic.text = sentence_definition.accepted_prompt
	_set_state("RESPONDING")
	emit_signal(completion_signal_name, id)
	if response_delay > 0.0: await get_tree().create_timer(response_delay).timeout
	if advancing: return
	if animation != null and animation.has_animation(animation_name):
		_log("Animation", "Playing " + str(animation_name))
		animation.play(animation_name)
	elif not animation_name.is_empty():
		push_warning("[Animation] Configured response animation not found: " + str(animation_name))
	var fade: Tween
	if starts_dark:
		fade = create_tween()
		fade.tween_property($"Dark bg", "modulate:a", 0.0, light_fade_duration)
	if room != null: await room.play_once()
	if fade != null and fade.is_running(): await fade.finished
	if animation != null and animation.is_playing():
		if animation.get_animation(animation.current_animation).loop_mode == Animation.LOOP_NONE:
			await animation.animation_finished
		else: push_warning("[Animation] Response loops; it cannot be used as a completion timer.")
	if advancing: return
	response_finished = true
	_set_state("COMPLETED")
	_log("Scene completion", "Response finished")
	mic.add_theme_color_override("font_color", accepted_mic_color)
	var next_button: Button = $Margin/Layout/Story/Next
	next_button.show()
	next_button.disabled = next_scene.is_empty()
	if not next_scene.is_empty() and auto_advance:
		_log("Transition", "Scheduled in %s seconds: %s" % [transition_delay, next_scene])
		if transition_delay > 0.0: auto_timer.start(transition_delay)
		else: advance.call_deferred()
	elif next_scene.is_empty(): mic.text = ""

func advance() -> void:
	if not response_finished or advancing or next_scene.is_empty(): return
	advancing = true
	auto_timer.stop()
	_set_state("TRANSITIONING")
	_log("Transition", next_scene)
	transition_requested.emit(next_scene)
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		advancing = false
		_set_state("COMPLETED")
		push_error("Could not open next scene: " + next_scene)

func go_home() -> void:
	auto_timer.stop()
	advancing = true
	speech.stop_listening()
	_log("Transition", "Home: " + intro_scene)
	get_tree().change_scene_to_file(intro_scene)

func _face_succeeded(cue: StringName) -> void:
	if not face_required or face_complete or advancing or cue != &"smile": return
	face_complete = true
	_log("Face success", str(cue))
	_set_state("FACE_RESPONSE")
	if not drag_required: sentence.reveal_correct_word()
	mic.text = sentence_definition.face_success_prompt
	if face_response_delay > 0.0: await get_tree().create_timer(face_response_delay).timeout
	if not advancing: _begin_drag_or_voice()

func _set_state(value: String) -> void:
	interaction_state = value
	_log("State", value)
	interaction_state_changed.emit(value)

func _log(event: String, detail: String) -> void:
	if debug_logging:
		var id: String = str(sentence_definition.sentence_id) if sentence_definition != null else name
		print("[", id, "][", event, "] ", detail)
