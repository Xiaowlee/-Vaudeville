extends Window
const CONFIG = "user://microphone.cfg"
var capture: AudioEffectCapture
var player: AudioStreamPlayer
var bus := "MicrophoneSettingsTest"
@onready var devices = $Margin/Content/Devices
@onready var status = $Margin/Content/Status
static func apply_saved() -> String:
    var config=ConfigFile.new()
    config.load(CONFIG)
    var preferred=str(config.get_value("audio","input","Default"))
    var available=AudioServer.get_input_device_list()
    AudioServer.input_device=preferred if preferred in available else "Default"
    return "" if preferred in available else "Saved microphone is disconnected. Using the system default."
func _ready():
    close_requested.connect(close_panel)
    $Margin/Content/Close.pressed.connect(close_panel)
    $Margin/Content/Refresh.pressed.connect(refresh)
    $Margin/Content/Test.toggled.connect(test_input)
    devices.item_selected.connect(select_device)
func show_panel():
    status.text=apply_saved()
    refresh()
    popup_centered()
func refresh():
    devices.clear()
    for device in AudioServer.get_input_device_list():
        devices.add_item(device)
        if device==AudioServer.input_device:devices.select(devices.item_count-1)
    if devices.item_count==0:status.text="No microphone found. Check the connection and microphone permissions."
func select_device(index: int):
    AudioServer.input_device=devices.get_item_text(index)
    var config=ConfigFile.new()
    config.set_value("audio","input",AudioServer.input_device)
    var error=config.save(CONFIG)
    status.text="Microphone saved." if error==OK else "Selected for this session; could not save settings."
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
    $Margin/Content/Level.value=clampf((linear_to_db(maxf(peak,0.00001))+60.0)/60.0*100.0,0,100)
func stop_test():
    if is_instance_valid(player):
        player.stop()
        player.queue_free()
    capture=null
    var index=AudioServer.get_bus_index(bus)
    if index>=0:AudioServer.remove_bus(index)
    $Margin/Content/Level.value=0
func close_panel():
    $Margin/Content/Test.set_pressed_no_signal(false)
    stop_test()
    hide()
func _exit_tree():stop_test()
