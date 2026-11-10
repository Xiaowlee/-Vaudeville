extends Window

signal phone_requested

const Report = preload("res://Script/playtest_report.gd")
@export var offer_phone_pairing := false
var speech_check: Control
const CONFIG = "user://microphone.cfg"
var capture: AudioEffectCapture
var player: AudioStreamPlayer
var bus := "MicrophoneSettingsTest"
@onready var devices = $Margin/Body/Scroll/Content/Devices
@onready var status = $Margin/Body/Scroll/Content/Status
static func apply_saved() -> String:
    var config=ConfigFile.new()
    config.load(CONFIG)
    var preferred=str(config.get_value("audio","input","Default"))
    var available=AudioServer.get_input_device_list()
    AudioServer.input_device=preferred if preferred in available else "Default"
    return "" if preferred in available else "Saved microphone is disconnected. Using the system default."
func _ready():
    close_requested.connect(close_panel)
    $Margin/Body/Close.pressed.connect(close_panel)
    $Margin/Body/Scroll/Content/Refresh.pressed.connect(refresh)
    $Margin/Body/Scroll/Content/Test.toggled.connect(test_input)
    devices.item_selected.connect(select_device)
    $Margin/Body/Scroll/Content/SpeechCheck.pressed.connect(check_speech)
    $Margin/Body/Scroll/Content/Phone.visible = offer_phone_pairing
    $Margin/Body/Scroll/Content/Phone.pressed.connect(func():
        close_panel()
        phone_requested.emit()
    )
    $Margin/Body/Scroll/Content/CopyReport.pressed.connect(func():
        Report.copy()
        if not speech_check_busy():
            status.text = "Playtest report copied."
    )
func show_panel():
    status.text = apply_saved()
    refresh()
    var available := Vector2i(get_parent().get_viewport().get_visible_rect().size) - Vector2i(40, 64)
    popup_centered(Vector2i(mini(700, available.x), mini(515, available.y)))
    $Margin/Body/Scroll.scroll_vertical = 0

func refresh():
    devices.clear()
    for device in AudioServer.get_input_device_list():
        devices.add_item(device)
        if device==AudioServer.input_device:devices.select(devices.item_count-1)
    if devices.item_count==0:status.text="No microphone found. Check the connection and microphone permissions."
func speech_check_busy() -> bool:
    return is_instance_valid(speech_check) and (speech_check.recording or speech_check.pid > 0)

func check_speech() -> void:
    if not is_instance_valid(speech_check):
        var scene = load("res://Scene/StageActs/Graph/local_whisper.tscn") as PackedScene
        speech_check = scene.instantiate()
        speech_check.hide()
        speech_check.restore_input_device_on_exit = false
        speech_check.report_context = "Settings speech check"
        add_child(speech_check)
        speech_check.transcript_ready.connect(func(words: String):
            status.text = "Recognised: " + words if not words.is_empty() else "No words recognised. Try another short sentence."
            update_speech_check_controls()
        )
        speech_check.technical_failure.connect(func(detail: String):
            status.text = detail
            update_speech_check_controls.call_deferred()
        )
    if speech_check.recording:
        speech_check.finish_recording()
        if speech_check.pid > 0:
            status.text = "Recognising your words…"
    elif speech_check.pid <= 0:
        $Margin/Body/Scroll/Content/Test.set_pressed_no_signal(false)
        stop_test()
        speech_check.start_recording()
        if speech_check.recording:
            status.text = "Recording now. Speak, then click Finish."
    update_speech_check_controls()

func update_speech_check_controls() -> void:
    var busy := speech_check_busy()
    var recording: bool = busy and speech_check.recording
    $Margin/Body/Scroll/Content/SpeechCheck.text = "Finish speech check" if recording else "Start speech check"
    $Margin/Body/Scroll/Content/SpeechCheck.disabled = busy and not recording
    $Margin/Body/Scroll/Content/Test.disabled = busy
    $Margin/Body/Scroll/Content/Refresh.disabled = busy
    devices.disabled = busy

static func save_device(device: String) -> bool:
    AudioServer.input_device = device
    Report.record("microphone_selected")
    var config := ConfigFile.new()
    config.set_value("audio", "input", AudioServer.input_device)
    return config.save(CONFIG) == OK

func select_device(index: int):
    status.text = "Microphone saved." if save_device(devices.get_item_text(index)) else "Selected for this session; could not save settings."

func test_input(enabled: bool):
    if not enabled:
        stop_test()
        return
    AudioServer.add_bus()
    var index=AudioServer.bus_count-1
    AudioServer.set_bus_name(index,bus)
    AudioServer.set_bus_mute(index,true)
    capture=AudioEffectCapture.new()
    AudioServer.add_bus_effect(index,capture)
    player=AudioStreamPlayer.new()
    player.stream=AudioStreamMicrophone.new()
    player.bus=bus
    add_child(player)
    player.play()
    status.text="Speak now. The meter tests microphone input, not speech recognition."
func _process(_delta):
    if capture==null:return
    var frames=capture.get_frames_available()
    if frames==0:return
    var peak=0.0
    for sample in capture.get_buffer(frames):peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
    $Margin/Body/Scroll/Content/Level.value=clampf((linear_to_db(maxf(peak,0.00001))+60.0)/60.0*100.0,0,100)
func stop_test():
    if is_instance_valid(player):
        player.stop()
        player.queue_free()
    capture=null
    var index=AudioServer.get_bus_index(bus)
    if index>=0:AudioServer.remove_bus(index)
    $Margin/Body/Scroll/Content/Level.value=0
func close_panel():
    if speech_check_busy():
        speech_check.cancel_recording()
    update_speech_check_controls()
    $Margin/Body/Scroll/Content/Test.set_pressed_no_signal(false)
    stop_test()
    hide()
func _exit_tree():stop_test()
