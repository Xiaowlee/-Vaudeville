extends "res://Script/StageActs/stage_ui.gd"
# Uses the existing stage layout; microphone ownership belongs to the graph runtime.
@export var show_response_debug := true
var release_to_player := true
var content_shown := false
func _ready() -> void:
    get_node(menu_path).pressed.connect(func(): get_tree().change_scene_to_file(menu_scene))
    $Speak.pressed.connect(request_speech)
    $PreShow.hide()
    panel(thought_path,"",false)
    panel(ifb_path,"",false)
    panel(transcript_path,"",false)
    hide_cue()
    move_child($DialogueBackground,0)
    for box in [$NPCDialogue,$PlayerTranscript,$PlayerLine]:
        box.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    $PlayerTranscript/Margin.add_theme_constant_override("margin_bottom",76)
    $NPCDialogue/Margin.add_theme_constant_override("margin_top",24)
    for label in [$NPCDialogue/SpeakerLayer/Speaker,$PlayerTranscript/DebugLayer/Name,$PlayerLine/Indicator/Name]:
        var plate=StyleBoxFlat.new()
        plate.bg_color=Color(0.10,0.10,0.20,1)
        plate.content_margin_left=20
        plate.content_margin_right=20
        plate.content_margin_top=8
        plate.content_margin_bottom=8
        label.add_theme_stylebox_override("normal",plate)
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func set_speaker(value: String) -> void:
    $NPCDialogue/SpeakerLayer/Speaker.text=value if npc_path==NodePath("NPCDialogue") else ""
    $PlayerLine/Indicator/Name.text=value if npc_path==NodePath("PlayerLine") else ""

func request_speech() -> void:
    get_node("../GameController").graph_input()
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER] and (event.ctrl_pressed or event.shift_pressed):
        var controller=get_node("../GameController")
        var runtime=get_node("../StoryRuntime")
        if controller.state=="READY" and runtime.waiting and not runtime.routes.is_empty():
            runtime.mic.cancel_recording()
            runtime._cancel_ai()
            runtime._choose(0,"Manual playtest bypass (not speech recognition)",false)
        else:
            controller.skip_dialogue()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed:
        if event.keycode==speak_key:
            request_speech()
            get_viewport().set_input_as_handled()
        elif event.keycode==skip_dialogue_key:
            get_node("../GameController").skip_dialogue()
            get_viewport().set_input_as_handled()
func play_dialogue(text: String, stream: AudioStream, actor_id := "", shown := true, hide_when_done := false) -> void:
    # Whitespace-only chunks must never become timed blank dialogue pages.
    var paragraphs=PackedStringArray()
    for paragraph in text.replace("\r\n","\n").replace("\r","\n").split("\n\n",false):
        if not paragraph.strip_edges().is_empty():paragraphs.append(paragraph.strip_edges())
    content_shown=shown and not paragraphs.is_empty()
    # A new authored line takes the shared box; old transcripts cannot cover it.
    get_node("../GameController").transcript_seconds_left=0.0
    panel(transcript_path,"",false)
    $NPCDialogue.hide()
    $PlayerLine.hide()
    npc_path=NodePath("PlayerLine") if actor_id=="player" else NodePath("NPCDialogue")
    super.play_dialogue("\n\n".join(paragraphs),stream,actor_id,shown,hide_when_done)
    set_speaker("MC" if actor_id=="player" else $NPCDialogue/SpeakerLayer/Speaker.text)

func dialogue_finished() -> bool:
    var runtime=get_node("../StoryRuntime")
    var last_line=dialogue_lines.is_empty() or line_index==dialogue_lines.size()-1
    if release_to_player and runtime.waiting and last_line and not writer.typing:
        # Player can answer when the final line is revealed; no artificial hold.
        if voice_end_mode==1:stop_dialogue()
        return not dialogue_playing()
    return super.dialogue_finished()

func _process(delta: float) -> void:
    super._process(delta)
    var readout=get_node_or_null("PlayerTranscript/DebugLayer/ResponseReadout")
    $NPCDialogue.visible=content_shown and npc_path==NodePath("NPCDialogue") and not $PlayerTranscript.visible
    $PlayerLine.visible=content_shown and npc_path==NodePath("PlayerLine") and not $PlayerTranscript.visible
    $NPCDialogue/SpeakerLayer/Speaker.visible=not $NPCDialogue/SpeakerLayer/Speaker.text.is_empty()
    if readout==null:return
    readout.visible=show_response_debug and OS.is_debug_build()
    if not readout.visible:return
    var runtime=get_node("../StoryRuntime")
    var data: Dictionary=runtime.last_response_debug
    var words="Response check · no response yet"
    if runtime.ai_busy:
        words="Response check · AI is interpreting…"
    elif not data.is_empty():
        words="Response check · "+str(data.source)+" · "+str(data.result)+"\n"+str(data.node)+" · "+str(data.outcome)
        if str(data.proposed).strip_edges().trim_suffix("/").strip_edges()!=str(data.result):
            words+=" · proposed: "+str(data.proposed)
    readout.get_node("Text").text=words
