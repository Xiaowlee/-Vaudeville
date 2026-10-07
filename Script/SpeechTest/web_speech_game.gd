extends Control
## DEBUG-only launcher. The ordinary menu and saved story are unchanged.
@export_file("*.tscn") var game_scene := "res://Scene/StageActs/2.3_stage_acts_1_3.tscn"
@export_enum("en-US", "en-AU") var language := "en-US"
var game: Node
func _ready() -> void:
 $Debug/Panel/Buttons/Connect.pressed.connect(connect_session)
 $Debug/Panel/Buttons/Browser.pressed.connect(open_browser)
 $Debug/Panel/Buttons/Play.pressed.connect(start_game)
 PhoneSession.changed.connect(pair_changed)
func connect_session() -> void:
 PhoneSession.ensure_session()
func pair_changed() -> void:
 $Debug/Panel/Buttons/Status.text = PhoneSession.message
 var ready: bool = not PhoneSession.speech_url.is_empty() and not PhoneSession.game_relay.is_empty()
 $Debug/Panel/Buttons/Browser.disabled = not ready
 $Debug/Panel/Buttons/Play.disabled = not ready or is_instance_valid(game)
 if not PhoneSession.busy and not PhoneSession.game_relay.is_empty() and not ready:
  $Debug/Panel/Buttons/Status.text = "Relay needs the speech update. Deploy website + relay, then restart this test."
func open_browser() -> void:
 if PhoneSession.speech_url.is_empty(): return
 OS.shell_open(PhoneSession.speech_url)
func start_game() -> void:
 if is_instance_valid(game) or PhoneSession.speech_url.is_empty(): return
 var packed = load(game_scene)
 if not packed is PackedScene:
  $Debug/Panel/Buttons/Status.text = "Game scene could not load."
  return
 game = packed.instantiate()
 var speech = game.get_node("SpeechMonitor")
 speech.recognition_backend = 3
 speech.experimental_language = language
 speech.experimental_phrase_bias = false
 speech.status_changed.connect(func(value): $Debug/Panel/Buttons/Status.text = "DEBUG browser speech: " + value)
 speech.raw_recognition.connect(func(event):
  if event.get("type") == "speech_result":
   $Debug/Panel/Buttons/Status.text = "DEBUG " + ("final: " if event.get("is_final", false) else "hearing: ") + str(event.get("transcript", "")))
 game.get_node("PhoneCueBridge").enabled = true
 add_child(game)
 $Debug/Panel/Buttons/Play.disabled = true
