extends CanvasLayer
@onready var controller=get_node("../GameController")
@onready var runtime=get_node("../StoryRuntime")
@onready var view=get_node("../DialogueView")
var release_to_player := true
@export_range(0,8,.25) var current_sentence_seconds := 3.0
var auto_advance := false
var revealed_hold := 0.0
var manual_advance := false
var recorded_voice_active := false
var voice_end_mode := 1
var voice_delay := 0.0
var voice_volume_db := 0.0
var desktop_cue_card := false
var content_shown := false
var pending_speaker := ""
var pending_text := ""
var line_age := 0.0
var developer_mode := false
var developer_ui_open := false
@onready var developer_ui_toggle: CheckButton = $Overlay/DeveloperUI
@onready var developer_toggle = $Overlay/GameMenu/Options/Developer
@onready var microphone_settings = get_node("../DesktopMicrophoneSettings")
func _ready():
    # The shared pairing scene keeps its launcher for the main menu only.
    $Overlay/PhonePairing/ConnectPhone.hide()
    var config=ConfigFile.new()
    config.load("user://dialogue.cfg")
    auto_advance=bool(config.get_value("dialogue","auto_advance",false))
    $Overlay/GameMenu/Options/AutoAdvance.set_pressed_no_signal(auto_advance)
    $Overlay/GameMenu/Options/AutoAdvance.toggled.connect(func(value):
        auto_advance=value
        config.set_value("dialogue","auto_advance",value)
        config.save("user://dialogue.cfg"))
    $Overlay/Settings.pressed.connect(func():$Overlay/GameMenu.visible=not $Overlay/GameMenu.visible)
    $Overlay/GameMenu/Options/Microphone.pressed.connect(func():
        $Overlay/GameMenu.hide()
        get_node("../DesktopMicrophoneSettings").show_panel())
    $Overlay/GameMenu/Options/PhoneQR.pressed.connect(func():
        $Overlay/GameMenu.hide()
        $Overlay/PhonePairing.show_panel())
    $Overlay/GameMenu/Options/MainMenu.pressed.connect(func():get_tree().change_scene_to_file("res://Scene/00_main_menu.tscn"))
    $Overlay/GameMenu/Options/Resume.pressed.connect(func():$Overlay/GameMenu.hide())
    $Overlay/ConfirmSpeech.pressed.connect(runtime.confirm_transcript)
    $Overlay/Speak.pressed.connect(func():controller.graph_input())
    $Overlay/GameMenu.visibility_changed.connect(developer_toggle.reset_access)
    developer_toggle.toggled.connect(set_developer_mode)
    developer_ui_toggle.toggled.connect(set_developer_ui)
    microphone_settings.developer_toggle.toggled.connect(set_developer_mode)
    runtime.get_node("Layout/Tools").hide()
    set_developer_mode(bool(PhoneSession.get_meta("developer_mode",false)))
func set_developer_mode(value: bool):
    developer_mode=value
    PhoneSession.set_meta("developer_mode",value)
    developer_toggle.set_pressed_no_signal(value)
    microphone_settings.developer_toggle.set_pressed_no_signal(value)
    developer_ui_toggle.visible = value
    set_developer_ui(developer_ui_open)

func set_developer_ui(value: bool) -> void:
    developer_ui_open = developer_mode and value
    developer_ui_toggle.set_pressed_no_signal(developer_ui_open)
    runtime.visible = developer_ui_open
    get_node("../FrameCutInLayer").visible = not developer_ui_open
    view.visible = not developer_ui_open
    $Overlay/ResponseCheck.visible = developer_ui_open
    runtime.get_node("Layout/Tools").set_pressed_no_signal(developer_ui_open)
    for path in ["Typed", "RouteTest", "Jump", "Restart"]:
        runtime.get_node("Layout/" + path).visible = developer_ui_open
func play_dialogue(words: String, stream: AudioStream, _actor_id := "", shown := true, _hide_when_done := false, wait_for_recording := false):
    stop_dialogue()
    recorded_voice_active=wait_for_recording and stream!=null
    pending_text=words if shown else ""
    content_shown=shown and not words.is_empty()
    line_age=0
    revealed_hold=0;manual_advance=false
    controller.transcript_words=""
    controller.transcript_seconds_left=0.0
    view.show_player_transcript("",false,false)
    $Voice.stream=stream
    if stream!=null:$Voice.play()
    if not shown:view.show_line("","",str(runtime.frame.get("id","")))
func set_speaker(speaker: String):
    pending_speaker=speaker
    if not pending_text.is_empty():
        for actor in get_node("../World/Performers").get_children():actor.begin_dialogue()
    view.show_line(speaker,pending_text,str(runtime.frame.get("id","")))
func dialogue_finished() -> bool:
    var revealed=view.line_revealed()
    if revealed and voice_end_mode==1 and not recorded_voice_active:stop_dialogue()
    return revealed and not $Voice.playing and (manual_advance or (auto_advance and revealed_hold>=current_sentence_seconds))
func dialogue_playing() -> bool:return $Voice.playing
func stop_dialogue():$Voice.stop()
func skip_current_passage() -> bool:
    if not view.line_revealed():
        view.reveal_line()
        revealed_hold=0.0
        return false
    view.reveal_line()
    stop_dialogue()
    line_age=100000
    manual_advance=true
    return true
func set_prompt(words: String, enabled: bool):
    $Overlay/Speak.text=words
    $Overlay/Speak.disabled=not enabled
    $Overlay/Speak.visible=not words.is_empty() and not runtime.route_kinds.is_empty()
func show_transcript(words: String, shown: bool):
    view.show_player_transcript(words,shown,not controller.group_is_preshow())

func _process(delta):
    $Overlay/ConfirmSpeech.visible=runtime.awaiting_review() and not overlay_open()
    runtime.size=get_viewport().get_visible_rect().size
    line_age+=delta
    if view.line_revealed() and not $Voice.playing and not overlay_open():revealed_hold+=delta
    if view.line_revealed() and not $Voice.playing:view.finish_talking()
    if not developer_ui_open:return
    var data=runtime.last_response_debug
    var conversation=str(runtime.frame.get("conversation",runtime.frame.get("id","")))
    var count=" · Offscript %d/5 · Conversation %d/2" % [runtime.responses.offscript_total,runtime.responses.conversation_attempts.get(conversation,0)]
    $Overlay/ResponseCheck.text="AI is interpreting…" if runtime.ai_busy else (str(data.get("result",""))+" · "+str(data.get("outcome",""))+count)
func _input(event):
    if not event is InputEventKey or not event.pressed or event.echo:return
    if microphone_settings.visible:
        return # The Settings window handles its own keyboard input.
    if overlay_open():
        if $Overlay/GameMenu.visible:
            developer_toggle.accept_code(event)
        if event.keycode==KEY_ESCAPE:
            $Overlay/GameMenu.hide()
            $Overlay/PhonePairing/Card.hide()
        get_viewport().set_input_as_handled()
        return
    if developer_mode and event.keycode in [KEY_ENTER,KEY_KP_ENTER] and (event.ctrl_pressed or event.shift_pressed):
        if controller.state=="READY" and runtime.waiting and not runtime.routes.is_empty():
            runtime.mic.cancel_recording();runtime._cancel_ai();runtime._choose(0,"Developer bypass (not speech)",false)
        else:controller.skip_dialogue(true)
        get_viewport().set_input_as_handled()
    elif event.keycode==KEY_X:
        controller.speak_input();get_viewport().set_input_as_handled()
    elif event.keycode==KEY_SPACE:
        controller.skip_dialogue();get_viewport().set_input_as_handled()

func overlay_open() -> bool:
    return $Overlay/GameMenu.visible or $Overlay/PhonePairing/Card.visible or get_node("../DesktopMicrophoneSettings").visible
