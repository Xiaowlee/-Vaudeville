extends CanvasLayer
@export var panel_visible := false
@export var shortcuts_enabled := true
@export_node_path("Node") var controller_path := NodePath("../GameController")
@onready var controller = get_node(controller_path)
func _ready() -> void:
	visible = panel_visible and OS.is_debug_build()
func _process(_delta: float) -> void:
	if not visible: return
	var b: StageBeat = controller.beat
	$Panel/Margin/Details.text = "DEBUG\nBeat: %s | State: %s | Input: %s\nMic: %s | Error: %s\nTranscript: %s\nIntent: %s | Result: %s | Retries: %s" % [b.beat_id if b != null else "", controller.state, StageBeat.InputMode.keys()[b.input_mode] if b != null else "", controller.speech.worker_ready, controller.speech.last_error, controller.transcript, controller.detected_intent, controller.match_result, controller.retries]
	var ifb = controller.get_parent().get_node_or_null("IFB")
	if ifb != null:
		$Panel/Margin/Details.text += "\nMobile: " + ("CONNECTED" if ifb.bridge.phone_connected else "DISCONNECTED")
		$Panel/Margin/Details.text += "\nLast cue sent: " + ifb.last_cue_text + " | Cue type: " + ifb.last_cue_type
		$Panel/Margin/Details.text += "\nWebSocket: " + ifb.bridge.relay_url + " | " + ifb.status + " | " + ifb.bridge.last_error
	var pre = controller.get_parent().get_node_or_null("PreShow")
	if pre != null: $Panel/Margin/Details.text += "\nPre-show: " + pre.state + " | " + pre.status
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not shortcuts_enabled or not event is InputEventKey or not event.pressed or event.echo: return
	var target = controller
	var pre = controller.get_parent().get_node_or_null("PreShow")
	if pre != null and pre.state != "FINISHED": target = pre
	if event.keycode == KEY_F3: visible = not visible
	elif event.ctrl_pressed and event.keycode == KEY_ENTER: target.debug_advance()
	elif target == controller and event.ctrl_pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9: controller.debug_advance(event.keycode - KEY_1)
	elif event.ctrl_pressed and event.keycode == KEY_R: target.retry_microphone()
	else: return
	get_viewport().set_input_as_handled()
