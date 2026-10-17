extends Node
## Presentation adapter: graph selects routes; existing StageUI/Actors/Audio present them.
@export var presentation: Dictionary[String, StageBeat] = {}
@export var opening_sections := PackedStringArray(["A1_1_Once upon a time","A2_0_DeclarationDay"])
@export var pre_show_ambience: AudioStream = preload("res://Sound/freesound_community-people-ambience-large-hall-02-17006.mp3")
@export var stage_manager_voice: AudioStream = preload("res://Sound/voicebosch-a-gentlemanx27s-cough-179346.mp3")
@export_range(0,10,0.1) var pre_show_delay := 2.0
@export_range(0.1,5,0.1) var curtain_speed := 1.0
@export var curtain_sfx: AudioStream = preload("res://Sound/jarasnat-curtain-version-1-337564.mp3")
@export_range(0,3,0.05) var response_delay := 0.45
@export var show_player_transcript := false
@onready var runtime = get_node("../StoryRuntime")
@onready var ui = get_node("../StageUI")
@onready var curtain: AnimatedSprite2D = get_node("../Curtain/AnimatedSprite2D")
@onready var audio = get_node("../ChapterAudio")
@onready var phone = get_node("../PhoneCueBridge")
var seen_turn := -1
var state := "PRESENTING"
var fallback_seen := ""
var response_elapsed := 0.0
var opening := false
var pending_text := ""
var selected_actor := ""
var section := ""
var last_group := ""
func _ready():
    curtain.get_parent().show()
    curtain.frame=0
    get_node("../Actors").hide()
    curtain.animation_finished.connect(_opened)
    if not runtime.is_node_ready():await runtime.ready
    runtime.mic.transcript_ready.connect(func(words):
        if not words.strip_edges().is_empty():ui.acknowledge())
func _process(delta):
    if runtime==null or not runtime.is_node_ready():return
    if runtime.turn!=seen_turn:
        seen_turn=runtime.turn
        _present()
    if state=="OPENING_DELAY":
        response_elapsed+=delta
        _button("Please wait",false)
        if response_elapsed>=pre_show_delay:
            ui.set_process(true)
            ui.play_dialogue(pending_text,stage_manager_voice,"")
            ui.get_node("NPCDialogue/SpeakerLayer/Speaker").text="Stage Manager"
            state="PRESENTING"
        return
    if opening:
        _button("Curtain opening…",false)
        return
    if state=="PRESENTING":
        _button("NPC speaking",false)
        if ui.dialogue_finished():
            state="RESPONSE_DELAY"
            response_elapsed=0
        return
    if state=="RESPONSE_DELAY":
        response_elapsed+=delta
        _button("Please wait",false)
        if response_elapsed<response_delay:return
        state="READY"
        if not runtime.waiting and not runtime.routes.is_empty():
            runtime._continue()
            return
        if runtime.route_kinds.count("next")>1:
            # The existing end-of-act Continue path. Quit remains the Menu button.
            runtime.waiting=true
            runtime._choose(0,"Continue act",false)
            return
        _publish_cue()
    if runtime.ai_busy:
        _button("Understanding…",false)
    elif runtime.mic.recording:
        _button("Finish speaking / X",true)
    elif runtime.mic.pid>0:
        _button("Recognising…",false)
    elif not runtime.fallback_reply.is_empty() and runtime.fallback_reply!=fallback_seen:
        fallback_seen=runtime.fallback_reply
        ui.play_dialogue(fallback_seen,null,selected_actor)
        state="PRESENTING"
    elif runtime.waiting:
        var mic_status=str(runtime.mic.status.text)
        var mic_error=mic_status.begins_with("Engine") or mic_status.begins_with("Could not") or mic_status.begins_with("No audio") or mic_status.begins_with("Transcription timed") or mic_status.begins_with("Whisper ended")
        _button("Microphone unavailable — retry / X" if mic_error else "Speak / X",true)
    else:
        _button("Continue / Space",not runtime.routes.is_empty())
    if show_player_transcript:
        ui.panel(ui.transcript_path,runtime.get_node("Layout/Heard").text,true)
func _button(text: String, enabled: bool):
    ui.get_node("Speak").text=text
    ui.get_node("Speak").disabled=not enabled
    ui.get_node("Speak").visible=not runtime.route_kinds.is_empty()
func graph_input():
    if opening or state!="READY" or runtime.ai_busy:return
    if runtime.waiting:
        runtime._speak()
    else:
        runtime._continue()
func skip_dialogue():
    if opening or state=="OPENING_DELAY":return
    if state=="PRESENTING":
        ui.skip_current_passage()
    elif state=="READY" and not runtime.waiting:
        runtime._continue()
func _present():
    ui.set_process(true)
    section=str(runtime.frame.get("id",""))
    state="PRESENTING"
    fallback_seen=""
    ui.hide_cue()
    phone.cancel("prompt")
    phone.cancel("ifb")
    var group=str(runtime.frame.get("group",""))
    if section=="Start":
        var ambience=BeatAudioCue.new()
        ambience.action=1
        ambience.channel=0
        ambience.stream=pre_show_ambience
        ambience.volume_db=-24
        audio.apply_cue(ambience)
        curtain.get_parent().show()
        curtain.stop()
        curtain.frame=0
        get_node("../Actors").hide()
        get_node("../Actors/actor_2").hide()
    if group=="Act 3":get_node("../Actors/actor_2").show()
    selected_actor="mother"
    if group.begins_with("Act 0"):selected_actor=""
    elif group=="Act 3":selected_actor="actor_2"
    var settings: StageBeat=presentation.get(section)
    pending_text=_display_text(runtime.get_node("Layout/Dialogue").text)
    if settings!=null:
        var beat: StageBeat=settings.duplicate()
        beat.npc_dialogue=pending_text
        beat.show_player_transcript=show_player_transcript
        ui.show_beat(beat)
        for cue in beat.audio:audio.apply_cue(cue)
        audio.play_sfx(beat.sfx_on_start,beat.sfx_volume_db)
        selected_actor=beat.actor_id
    else:
        ui.voice_end_mode=1
        ui.voice_delay=0
        ui.play_dialogue(pending_text,stage_manager_voice if group.begins_with("Act 0") else null,selected_actor)
        ui.get_node("NPCDialogue/SpeakerLayer/Speaker").text="Stage Manager" if group.begins_with("Act 0") else ("Actor 2" if selected_actor=="actor_2" else "Mother")
    if section=="Start":
        state="OPENING_DELAY"
        response_elapsed=0
        ui.set_process(false)
        ui.stop_dialogue()
        ui.get_node("NPCDialogue").hide()
    if section in opening_sections:
        audio.stop_all(0.3)
        opening=true
        curtain.get_parent().show()
        curtain.stop()
        curtain.frame=0
        get_node("../Actors").show()
        curtain.speed_scale=curtain_speed
        curtain.play("default")
        audio.play_sfx([curtain_sfx],-18.0)
        # Pause text presentation until the curtain reveals the stage.
        ui.set_process(false)
    last_group=group
func _opened():
    if not opening:return
    opening=false
    curtain.get_parent().hide()
    ui.set_process(true)
func _publish_cue():
    if runtime.cue.is_empty():return
    var channel="ifb" if "IFB" in runtime.cue else "prompt"
    phone.send_text(channel,runtime.cue)
    if ui.desktop_cue_card:
        ui.panel(ui.cue_path,runtime.cue,true)
func _display_text(words: String) -> String:
    # Stage instructions remain in the graph; only narrative and spoken text are shown.
    var lines=PackedStringArray()
    for line in words.split("
"):
        var trimmed=line.strip_edges()
        if trimmed.begins_with("STAGE:") or trimmed.begins_with("SOUND:") or trimmed.begins_with("CUE / PHONE:") or trimmed.begins_with("CUE CARD:"):continue
        if trimmed in ["ACTOR 1:","ACTOR 1::","ACTOR 2:","STAGE MANAGER:","THE MAIN ACTOR:"]:continue
        lines.append(line)
    return "
".join(lines).strip_edges()
func _exit_tree():
    if is_instance_valid(phone):
        phone.cancel("prompt")
        phone.cancel("ifb")
    if is_instance_valid(audio):audio.stop_all(0)