extends Node
## Non-blocking adapter: reuses the existing relay. No story or cue text lives here.
## IFB cues go to the phone "ifb" channel; revealed player-line prompts go to the phone "prompt" channel.
@export_node_path("Node") var controller_path := NodePath("../GameController")
@export_node_path("Node") var bridge_path := NodePath("../PhoneCueBridge")
@export_node_path("Control") var ui_path := NodePath("../StageUI")
@export var mirror_locally := false
@export var local_fallback := true
@export_range(0, 30, 0.1) var delivery_grace_seconds := 1.0
@export_group("Phone prompts")
@export var send_prompts_to_phone := true
## Empty sends prompts to every connected phone display.
@export var prompt_recipient := ""
@export_group("")
@onready var bridge = get_node(bridge_path)
@onready var ui = get_node(ui_path)
var cue: PhoneCue
var elapsed := 0.0
var sent := false
var status := "Idle"
var last_cue_text := ""
var last_cue_type := ""
func _ready() -> void:
	var controller := get_node(controller_path)
	controller.beat_entered.connect(on_beat)
	controller.completed.connect(clear)
	controller.turn_resolved.connect(_on_turn_resolved)
	ui.cue_revealed.connect(_on_prompt_revealed)
	ui.cue_hidden.connect(clear_prompt)
func on_beat(beat: StageBeat) -> void:
	clear()
	if beat.send_phone_cue and beat.phone_cue != null:
		cue = beat.phone_cue
		status = "Cue scheduled"
func clear() -> void:
	clear_ifb()
	clear_prompt()
func clear_ifb() -> void:
	bridge.cancel("ifb")
	cue = null
	elapsed = 0
	sent = false
	status = "Idle"
	ui.local_ifb("", false)
func clear_prompt() -> void:
	bridge.cancel("prompt")
func _on_prompt_revealed(text: String) -> void:
	if send_prompts_to_phone and bridge.enabled: bridge.send_text("prompt", text, prompt_recipient, "PROMPTER")
func _on_turn_resolved(beat: StageBeat, _result: String) -> void:
	if beat.input_mode != StageBeat.InputMode.NONE: clear_ifb()
func _process(delta: float) -> void:
	if cue == null: return
	elapsed += delta
	if elapsed < cue.delay_seconds: return
	if not sent:
		sent = true
		last_cue_text = cue.text
		last_cue_type = cue.cue_type
		if bridge.enabled:
			var delivery: PhoneCue = cue.duplicate()
			delivery.delay_seconds = 0
			delivery.wait_for_delivery = false
			bridge.deliver(delivery, "ifb")
	var delivered: bool = bridge.enabled and bridge.phone_connected and bridge.is_acknowledged("ifb")
	var unavailable: bool = not bridge.enabled or elapsed >= cue.delay_seconds + delivery_grace_seconds
	var fallback_shown: bool = mirror_locally or (local_fallback and unavailable and not delivered)
	ui.local_ifb(cue.text, fallback_shown)
	if delivered or fallback_shown: ui.play_cue_sound()
	status = "Delivered to phone" if delivered else ("Local fallback / no delivery" if unavailable else "Awaiting delivery")
