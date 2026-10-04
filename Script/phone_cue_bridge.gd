extends Node
## Sends stage cues to the phone display through the local relay.
## Channels are independent: "prompt" (CueCard line prompts) and "ifb" (private instructions).
const CHANNELS := ["prompt", "ifb"]
@export var enabled := false
@export var relay_url := "wss://127.0.0.1:8787"
@export_file("*.pem") var relay_certificate := "res://mobile-companion/.certs/cert.pem"
@export_range(0.1, 30, 0.1) var reconnect_seconds := 2.0
var socket := WebSocketPeer.new()
var pending: Dictionary = {}
var acks: Dictionary = {}
## Legacy single-cue callers use the "ifb" channel.
var acknowledged: bool:
	get: return acks.get("ifb", false)
	set(value): acks["ifb"] = value
var phone_connected := false
var last_received_at := 0
@export_range(3, 30, 1) var connection_timeout_seconds := 8.0
var generations: Dictionary = {}
var retry_at := 0
var was_open := false
var last_error := ""
func deliver(cue: PhoneCue, channel := "ifb") -> void:
	cancel(channel)
	var ticket: int = generations.get(channel, 0)
	if cue.delay_seconds > 0: await get_tree().create_timer(cue.delay_seconds).timeout
	if not is_inside_tree() or ticket != generations.get(channel, 0): return
	send_text(channel, cue.text, cue.recipient_id, cue.cue_type)
	while cue.wait_for_delivery and not is_acknowledged(channel) and ticket == generations.get(channel, 0):
		await get_tree().process_frame
func send_text(channel: String, text: String, recipient := "", cue_type := "PRIVATE") -> void:
	if pending.has(channel): cancel(channel)
	pending[channel] = {"kind":"stage_cue", "channel":channel, "requestId":str(OS.get_process_id()) + "_" + str(Time.get_ticks_usec()), "recipient":recipient, "text":text, "cueType":cue_type}
	acks[channel] = false
	_send(pending[channel])
func is_acknowledged(channel: String) -> bool:
	return acks.get(channel, false)
func _process(_delta: float) -> void:
	if OS.has_feature("web") and PhoneSession.game_relay.is_empty(): return
	if not enabled:
		acks.clear()
		phone_connected = false
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN: socket.close()
		if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED: socket.poll()
		return
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		was_open = false
		acks.clear()
		phone_connected = false
		if Time.get_ticks_msec() < retry_at: return
		retry_at = Time.get_ticks_msec() + int(reconnect_seconds * 1000)
		var session := get_node_or_null("/root/PhoneSession")
		var hosted: bool = session != null and not session.game_relay.is_empty()
		var target: String = session.game_relay if hosted else relay_url
		var tls := TLSOptions.client()
		if not hosted and not OS.has_feature("web"):
			var cert := X509Certificate.new()
			if cert.load(relay_certificate) != OK:
				last_error = "Relay certificate unavailable"
				return
			tls = TLSOptions.client(cert)
		socket.connect_to_url(target, null if OS.has_feature("web") else tls)
	socket.poll()
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		acks.clear()
		phone_connected = false
		return
	if was_open and Time.get_ticks_msec() - last_received_at > connection_timeout_seconds * 1000:
		last_error = "Relay heartbeat timed out"
		acks.clear()
		phone_connected = false
		socket.close()
		return
	if not was_open:
		was_open = true
		last_received_at = Time.get_ticks_msec()
		last_error = ""
		_send({"kind":"hello", "role":"game"})
		for channel in pending: _send(pending[channel])
	while socket.get_available_packet_count() > 0:
		var message = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if message is Dictionary: receive(message)
func receive(message: Dictionary) -> void:
	last_received_at = Time.get_ticks_msec()
	if message.get("kind") == "stage_phone_status":
		phone_connected = message.get("connected", false)
		var acknowledged_ids: Array = message.get("acknowledged", [])
		for channel in pending:
			acks[channel] = phone_connected and acknowledged_ids.has(pending[channel].requestId)
	if message.get("kind") == "stage_ack":
		for channel in pending:
			if message.get("requestId") == pending[channel].requestId: acks[channel] = true
func _send(message: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN: socket.send_text(JSON.stringify(message))
func bypass_wait() -> void:
	if OS.is_debug_build():
		print("[DEBUG] Phone delivery wait bypassed")
		for channel in CHANNELS: acks[channel] = true
## Empty channel cancels every channel.
func cancel(channel := "") -> void:
	for ch in (CHANNELS if channel.is_empty() else [channel]):
		if pending.has(ch): _send({"kind":"stage_cancel", "channel":ch, "requestId":pending[ch].requestId})
		generations[ch] = generations.get(ch, 0) + 1
		pending.erase(ch)
		acks[ch] = false
func _exit_tree() -> void:
	cancel()
	socket.close()
