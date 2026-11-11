extends Control

const MicSettings = preload("res://Script/microphone_settings.gd")
const Report = preload("res://Script/playtest_report.gd")
enum Step { VOICE, PHONE, QUOTE }

@export_file("*.tscn") var stage_scene := "res://Scene/StageActs/stage_graph_game.tscn"
@export_file("*.tscn") var menu_scene := "res://Scene/00_main_menu.tscn"
@export_group("Transitions")
@export_range(0.0, 3.0, 0.05) var fade_seconds := 0.4
@export_group("Quote Typing", "quote_")
## Time to type the quote and author credit. Increase this to slow the typing. Set to 0 for instant text.
@export_range(0.0, 15.0, 0.1, "or_greater", "suffix:s") var quote_typing_duration := 4.0
## Reading pause after both the quote and author credit finish typing.
@export_range(0.0, 30.0, 0.1, "suffix:s") var quote_hold_seconds := 5.0

@export_group("Phone Reminder")
## Open this scene to edit and preview the real phone layout in 2D.
@export var phone_reminder_scene: PackedScene = preload("res://Scene/UI/phone_reminder.tscn")

@export_group("Developer Bypass")
## Advance one pregame step in debug builds with Developer Mode enabled.
@export var developer_skip_shortcut: Shortcut

@onready var cover: ColorRect = $TransitionCover
@onready var quotation: Label = $Design/Quote/Quotation
@onready var author: Label = $Design/Quote/Author
@onready var canvas: Control = $Design
@onready var voice: Control = $Design/Voice
@onready var phone: Control = $Design/Phone
@onready var bridge = $PhoneCueBridge
@onready var mic = $Whisper
@onready var mic_status: Label = $Design/Voice/Status
var step := Step.VOICE
var design_size: Vector2
var transitioning := false
var quote_run := 0
var quote_reveal: Tween
var developer_skipped_pairing := false

func _ready() -> void:
	design_size = canvas.size
	resized.connect(_fit_design)
	_fit_design()
	mic.transcript_ready.connect(_speech_result)
	mic.technical_failure.connect(func(detail: String): mic_status.text = detail)
	for device in AudioServer.get_input_device_list():
		voice.get_node("Devices").add_item(device)
		if device == AudioServer.input_device:
			voice.get_node("Devices").select(voice.get_node("Devices").item_count - 1)
	voice.get_node("Devices").item_selected.connect(func(index: int):
		MicSettings.save_device(voice.get_node("Devices").get_item_text(index))
	)
	voice.get_node("Check").pressed.connect(_check_voice)
	voice.get_node("Next").pressed.connect(func(): _transition_to(Step.PHONE))
	phone.get_node("Next").pressed.connect(func():
		if bridge.phone_connected:
			_transition_to(Step.QUOTE)
	)
	phone.get_node("Retry").pressed.connect(PhoneSession.ensure_session)
	$Design/Back.pressed.connect(_back)
	if phone_reminder_scene:
		var reminder = phone_reminder_scene.instantiate()
		bridge.phone_reminder = reminder.browser_style()
		reminder.free()
	_show_step(Step.VOICE)
	transitioning = true
	await _fade(false, true)
	transitioning = false

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not bool(PhoneSession.get_meta("developer_mode", false)):
		return
	if developer_skip_shortcut == null or not event.is_pressed() or not developer_skip_shortcut.matches_event(event):
		return
	get_viewport().set_input_as_handled()
	if event.is_echo() or transitioning:
		return
	match step:
		Step.VOICE:
			_transition_to(Step.PHONE)
		Step.PHONE:
			developer_skipped_pairing = true
			_transition_to(Step.QUOTE)
		Step.QUOTE:
			if quote_reveal and quote_reveal.is_running():
				quote_reveal.kill()
			_leave_for(stage_scene)

func _can_show_quote() -> bool:
	return bridge.phone_connected or developer_skipped_pairing

func _fit_design() -> void:
	var factor := minf(size.x / design_size.x, size.y / design_size.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - design_size * factor) * 0.5

func _fade(opaque: bool, instant_start := false) -> void:
	if instant_start:
		cover.modulate.a = 1.0
	cover.show()
	var tween := create_tween()
	tween.tween_property(cover, "modulate:a", float(opaque), fade_seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if not opaque:
		cover.hide()

func _transition_to(next_step: Step) -> void:
	if transitioning or step == next_step:
		return
	transitioning = true
	quote_run += 1
	if quote_reveal and quote_reveal.is_running():
		quote_reveal.kill()
	await _fade(true)
	if next_step == Step.QUOTE and not _can_show_quote():
		next_step = Step.PHONE
	_show_step(next_step)
	await _fade(false)
	transitioning = false
	if step == Step.QUOTE and _can_show_quote():
		_play_quote(quote_run)

func _show_step(next_step: Step) -> void:
	if step == Step.VOICE and next_step != Step.VOICE:
		mic.cancel_recording()
	step = next_step
	voice.visible = step == Step.VOICE
	phone.visible = step == Step.PHONE
	$Design/Quote.visible = step == Step.QUOTE
	$Design/Back.visible = step != Step.QUOTE
	bridge.enabled = step != Step.VOICE
	Report.record("pregame_step", {"step": Step.keys()[step]})
	match step:
		Step.VOICE:
			developer_skipped_pairing = false
			voice.get_node("Devices").grab_focus()
		Step.PHONE:
			PhoneSession.ensure_session()
			_refresh_phone()
		Step.QUOTE:
			quotation.visible_ratio = 0.0
			author.visible_ratio = 0.0

func _play_quote(run: int) -> void:
	quote_reveal = create_tween()
	var quote_characters := quotation.get_total_character_count()
	var total_characters := quote_characters + author.get_total_character_count()
	var quote_duration := quote_typing_duration * float(quote_characters) / maxi(total_characters, 1)
	quote_reveal.tween_property(quotation, "visible_ratio", 1.0, quote_duration)
	quote_reveal.tween_property(author, "visible_ratio", 1.0, quote_typing_duration - quote_duration)
	quote_reveal.tween_interval(quote_hold_seconds)
	await quote_reveal.finished
	if run == quote_run and _can_show_quote():
		_leave_for(stage_scene)

func _check_voice() -> void:
	if mic.recording:
		mic.finish_recording()
		if mic.pid > 0:
			mic_status.text = "Recognising your words…"
	elif mic.pid <= 0:
		mic.start_recording()
		if mic.recording:
			mic_status.text = "Recording. Say a short line, then press Finish."
	_update_voice_controls()

func _speech_result(words: String) -> void:
	mic_status.text = "Recognised: " + words.left(160) if not words.is_empty() else "No words recognised. Try again."

func _update_voice_controls() -> void:
	var busy: bool = mic.recording or mic.pid > 0
	voice.get_node("Check").text = "Finish" if mic.recording else "Start speech check"
	voice.get_node("Check").disabled = busy and not mic.recording
	voice.get_node("Devices").disabled = busy
	voice.get_node("Next").disabled = busy
	voice.get_node("Meter").value = mic.input_level
	if mic.pid > 0:
		mic_status.text = "Recognising your words…"

func _refresh_phone() -> void:
	var paired: bool = bridge.phone_connected
	phone.get_node("QR").texture = PhoneSession.qr
	phone.get_node("QR").visible = not paired and PhoneSession.qr != null
	phone.get_node("Status").text = "Phone connected" if paired else PhoneSession.message
	phone.get_node("Retry").visible = not paired and not PhoneSession.busy and PhoneSession.qr == null
	phone.get_node("Next").visible = paired

func _process(_delta: float) -> void:
	match step:
		Step.VOICE:
			_update_voice_controls()
		Step.PHONE:
			_refresh_phone()
		Step.QUOTE:
			if not _can_show_quote():
				_transition_to(Step.PHONE)

func _back() -> void:
	if transitioning:
		return
	match step:
		Step.VOICE:
			mic.cancel_recording()
			_leave_for(menu_scene)
		Step.PHONE:
			bridge.send_phone_reminder(null)
			_transition_to(Step.VOICE)

func _leave_for(path: String) -> void:
	if transitioning:
		return
	var destination := load(path) as PackedScene
	if not destination:
		push_error("Could not open " + path)
		return
	transitioning = true
	await _fade(true)
	if step == Step.QUOTE and not _can_show_quote():
		_show_step(Step.PHONE)
		await _fade(false)
		transitioning = false
		return

	# Carry the same cover over the scene change, above both scenes' UI.
	var tree := get_tree()
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	tree.root.add_child(fade_layer)
	cover.reparent(fade_layer, false)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var result := tree.change_scene_to_packed(destination)
	if result != OK:
		cover.reparent(self, false)
		fade_layer.queue_free()
		await _fade(false)
		transitioning = false
		push_error("Could not open " + path)
		return
	var reveal := fade_layer.create_tween()
	reveal.tween_property(cover, "modulate:a", 0.0, fade_seconds).set_trans(Tween.TRANS_SINE)
	reveal.tween_callback(fade_layer.queue_free)
