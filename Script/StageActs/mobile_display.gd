extends Control
## Phone display for stage cues. Connects to the relay as a stage phone, never as the game.
## Line prompts fill the CueCard; private IFB instructions fill the IFB panel. Layout stays in the scene.
@export_group("Relay")
## Empty uses the address of the page that served this display, on Relay Port.
@export var relay_url := ""
@export var relay_port := 8787
## Only used when this scene runs from the Godot editor. The phone browser handles TLS itself.
@export_file("*.pem") var editor_certificate := "res://mobile-companion/.certs/cert.pem"
## Empty receives cues for every phone. A ?recipient= value in the page address overrides this.
@export var recipient := ""
@export_range(0.5, 30, 0.1) var reconnect_seconds := 2.0
## Small message that keeps free relay hosting from sleeping while the phone is connected.
@export_range(10, 600, 5) var keepalive_seconds := 60.0
@export_group("Layout")
@export_node_path("PanelContainer") var cue_card_path := NodePath("CueCard")
@export_node_path("PanelContainer") var ifb_path := NodePath("IFB")
@export var hide_empty_panels := true
## Reference resolution on the phone. Anchors keep panels placed on other screen shapes. (0, 0) keeps the project size.
@export var phone_design_size := Vector2i(540, 960)
@export_group("")
var socket := WebSocketPeer.new()
var active := {"prompt": "", "ifb": ""}
var retry_at := 0
var was_open := false
var url := ""
var keepalive_at := 0

func _ready() -> void:
	if phone_design_size.x > 0 and phone_design_size.y > 0:
		get_tree().root.content_scale_size = phone_design_size
	clear_all()

func _process(_delta: float) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if was_open:
			was_open = false
			clear_all()
			print("[MobileDisplay] relay disconnected (code ", socket.get_close_code(), ")")
		if Time.get_ticks_msec() < retry_at: return
		retry_at = Time.get_ticks_msec() + int(reconnect_seconds * 1000)
		url = resolved_url()
		var error := socket.connect_to_url(url, tls_options())
		if error != OK: print("[MobileDisplay] connection error ", error)
		return
	socket.poll()
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	if not was_open:
		was_open = true
		print("[MobileDisplay] connected")
		send({"kind":"hello", "role":"stage_phone", "recipient":resolved_recipient()})
		keepalive_at = Time.get_ticks_msec() + int(keepalive_seconds * 1000)
	if Time.get_ticks_msec() >= keepalive_at:
		keepalive_at = Time.get_ticks_msec() + int(keepalive_seconds * 1000)
		send({"kind":"keepalive"})
	while socket.get_available_packet_count() > 0:
		var message = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if message is Dictionary: receive(message)

func receive(message: Dictionary) -> void:
	if message.get("kind") == "stage_cue":
		var channel := str(message.get("channel", "ifb"))
		if not active.has(channel): return
		active[channel] = str(message.get("requestId", ""))
		show_text(channel, str(message.get("text", "")))
		send({"kind":"stage_ack", "requestId":active[channel]})
		print("[MobileDisplay] ", channel, " shown: ", message.get("text", ""))
	elif message.get("kind") == "stage_cancel":
		for channel in active:
			if not active[channel].is_empty() and active[channel] == str(message.get("requestId", "")):
				active[channel] = ""
				show_text(channel, "")
				print("[MobileDisplay] ", channel, " cleared")

func show_text(channel: String, text: String) -> void:
	var panel := get_node_or_null(cue_card_path if channel == "prompt" else ifb_path) as Control
	if panel == null: return
	var label = panel.get_node_or_null("Margin/Text")
	if label != null: label.text = text
	panel.visible = not hide_empty_panels or not text.is_empty()

func clear_all() -> void:
	for channel in active:
		active[channel] = ""
		show_text(channel, "")

func resolved_url() -> String:
	if OS.has_feature("web"):
		var paired := str(JavaScriptBridge.eval("new URLSearchParams(window.location.hash.slice(1)).get('relay') || ''", true))
		if paired.begins_with("wss://") or paired.begins_with("ws://localhost:"): return paired
	if not relay_url.is_empty(): return relay_url
	var host := "127.0.0.1"
	if OS.has_feature("web"): host = str(JavaScriptBridge.eval("window.location.hostname", true))
	return "wss://%s:%d" % [host, relay_port]

func resolved_recipient() -> String:
	if OS.has_feature("web"):
		var from_page := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('recipient') || ''", true))
		if not from_page.is_empty(): return from_page
	return recipient

func tls_options() -> TLSOptions:
	if OS.has_feature("web"): return null
	var cert := X509Certificate.new()
	return TLSOptions.client(cert) if cert.load(editor_certificate) == OK else TLSOptions.client()

func send(message: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN: socket.send_text(JSON.stringify(message))
