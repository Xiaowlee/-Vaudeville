extends Window
@onready var speech = $SpeechMonitor
func _ready() -> void:
 close_requested.connect(close_panel)
 $Margin/Content/Close.pressed.connect(close_panel)
 $Margin/Content/Allow.pressed.connect(func():
  OS.request_permission("android.permission.RECORD_AUDIO")
  $Margin/Content/Status.text = "Allow microphone access, then tap Test microphone.")
 $Margin/Content/AppSettings.pressed.connect(func():
  if Engine.has_singleton("AndroidSpeech"): Engine.get_singleton("AndroidSpeech").open_settings())
 $Margin/Content/Test.pressed.connect(test_microphone)
 $Margin/Content/Stop.pressed.connect(func(): speech.stop_listening(); $Margin/Content/Status.text = "Microphone stopped.")
 $Margin/Content/Language.add_item("English (Australia)")
 $Margin/Content/Language.add_item("English (United States)")
 var preferences := ConfigFile.new()
 if preferences.load("user://android_microphone.cfg") == OK:
  $Margin/Content/Language.select(1 if preferences.get_value("speech", "language", "en-AU") == "en-US" else 0)
 $Margin/Content/Language.item_selected.connect(func(index):
  speech.stop_listening()
  var config := ConfigFile.new()
  config.set_value("speech", "language", "en-AU" if index == 0 else "en-US")
  if config.save("user://android_microphone.cfg") != OK: $Margin/Content/Status.text = "Could not save language.")
 speech.status_changed.connect(func(value): $Margin/Content/Status.text = value)
 speech.partial_transcript_received.connect(func(value): $Margin/Content/Transcript.text = value)
 speech.final_transcript_received.connect(func(value):
  $Margin/Content/Transcript.text = value
  $Margin/Content/Status.text = "Recognized. Tap Test microphone to try again.")
func show_panel() -> void:
 popup_centered_ratio(0.85)
 if not Engine.has_singleton("AndroidSpeech"):
  $Margin/Content/Status.text = "Android speech plugin is not included in this build."
 else:
  var plugin = Engine.get_singleton("AndroidSpeech")
  $Margin/Content/Status.text = "Ready to test." if plugin.permitted() and plugin.available() else "Enable microphone permission and an Android speech service to continue."
func test_microphone() -> void:
 $Margin/Content/Transcript.text = ""
 speech.start_listening("", PackedStringArray(), false, true)
func close_panel() -> void:
 speech.stop_listening()
 hide()
