extends Node
## Scene 2 owns a fresh request; old/repeated face events cannot advance it.
signal phone_connected(connected: bool)
signal face_present(present: bool)
signal face_cue_met(cue: StringName)
@export var relay_url := "wss://127.0.0.1:8787"
@export_file("*.pem") var relay_certificate := "res://mobile-companion/.certs/cert.pem"
var connected := false
var present := false
var request_id := ""
var socket := WebSocketPeer.new()
var active := false
var retry_at := 0
var was_open := false

func start_face_request() -> void:
	request_id = str(Time.get_ticks_usec())
	active = true
	retry_at = 0

func _process(_delta: float) -> void:
	if not active: return
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if was_open:
			was_open = false
			set_phone_connected(false)
		if Time.get_ticks_msec() < retry_at: return
		retry_at = Time.get_ticks_msec() + 2000
		var cert := X509Certificate.new()
		if cert.load(relay_certificate) != OK:
			push_warning("Relay certificate missing: start mobile-companion first.")
			return
		socket.connect_to_url(relay_url, TLSOptions.client(cert))
	socket.poll()
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	if not was_open:
		was_open = true
		send({"kind":"hello", "role":"game"})
		send({"kind":"face_request", "requestId":request_id, "cue":"smile"})
	while socket.get_available_packet_count() > 0:
		var message = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if message is Dictionary: receive(message)

func send(message: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))

func receive(message: Dictionary) -> void:
	if message.get("kind") == "phone_status":
		set_phone_connected(message.get("connected") == true)
	elif message.get("kind") == "face_present":
		set_face_present(message.get("present") == true)
	elif active and message.get("kind") == "face_cue" and message.get("requestId") == request_id and message.get("cue") == "smile" and message.get("met") == true:
		send({"kind":"face_ack", "requestId":request_id})
		face_cue_met.emit(&"smile")

func finish_request() -> void:
	send({"kind":"face_cancel", "requestId":request_id})
	active = false
	socket.close()

func set_phone_connected(value: bool) -> void:
	connected = value
	phone_connected.emit(value)

func set_face_present(value: bool) -> void:
	present = value
	face_present.emit(value)

func report_face_cue(cue: StringName) -> void:
	face_cue_met.emit(cue)

func _exit_tree() -> void:
	finish_request()
