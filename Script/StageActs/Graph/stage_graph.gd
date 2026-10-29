extends Node
## Presentation adapter: graph selects routes; existing StageUI/Actors/Audio present them.
const ProductionCue = preload("res://Script/StageActs/Graph/production_cue.gd")
@export var presentation: Dictionary[String, StageBeat] = {}
@export var opening_sections := PackedStringArray(["A1_1_Once upon a time","A2_0_DeclarationDay"])
@export var pre_show_ambience: AudioStream = preload("res://Sound/freesound_community-people-ambience-large-hall-02-17006.mp3")
@export var stage_manager_voice: AudioStream = preload("res://Sound/voicebosch-a-gentlemanx27s-cough-179346.mp3")
@export_range(0,10,0.1) var pre_show_delay := 2.0
@export_range(0.1,5,0.1) var curtain_speed := 1.0
@export var curtain_sfx: AudioStream = preload("res://Sound/jarasnat-curtain-version-1-337564.mp3")
@export_range(0,3,0.05) var response_delay := 0.0
@export var show_player_transcript := true
@onready var runtime = get_node("../StoryRuntime")
@onready var ui = get_node("../StageUI")
@onready var curtain: AnimatedSprite2D = get_node("../Curtain/AnimatedSprite2D")
@onready var audio = get_node("../ChapterAudio")
@onready var phone = get_node("../PhoneCueBridge")
signal production_event(passage: String, phase: String, event: Dictionary)
var production_log: Array = []
var semantic_events: Array = []
var semantic_index := 0
var current_content: Dictionary = {}
var phone_preview := ""
var active_settings: StageBeat
var passage_voice_used := false
var transcript_words := ""
var transcript_seconds_left := 0.0
var transcript_loading_elapsed := 0.0
var actor_origins: Dictionary = {}
var pending_consequence := 0
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
    for actor in get_node("../Actors").get_children():
        if actor is Control or actor is Node2D:actor_origins[actor.name]=actor.position
    curtain.get_parent().show()
    curtain.frame=0
    get_node("../Actors").hide()
    curtain.animation_finished.connect(_opened)
    if not runtime.is_node_ready():await runtime.ready
    runtime.response_resolved.connect(_response_production)
    runtime.cue_requested.connect(_publish_cue)
    runtime.mic.transcript_ready.connect(_transcript_completed)
    runtime.mic.technical_failure.connect(func(_detail):
        transcript_words=""
        transcript_seconds_left=0
        _update_transcript(0))
func _process(delta):
    if runtime==null or not runtime.is_node_ready():return
    _update_transcript(delta)
    runtime.accepting_speech=state=="READY" and not opening
    if runtime.turn!=seen_turn:
        seen_turn=runtime.turn
        _present()
    if state=="OPENING_DELAY":
        response_elapsed+=delta
        _button("Please wait",false)
        if response_elapsed>=pre_show_delay:
            ui.set_process(true)
            _next_content()
            state="PRESENTING"
        return
    if opening:
        _button("Curtain opening…",false)
        return
    if state=="PRESENTING":
        _button("NPC speaking",false)
        if ui.dialogue_finished():
            if semantic_index<semantic_events.size():
                _next_content()
                return
            state="RESPONSE_DELAY"
            response_elapsed=0
        else:
            return
    if state=="RESPONSE_DELAY":
        response_elapsed+=delta
        _button("Please wait",false)
        if response_elapsed<response_delay:return
        state="READY"
        runtime.accepting_speech=runtime.waiting
        if not runtime.waiting and not runtime.routes.is_empty():
            runtime._continue()
            return
        if runtime.route_kinds.count("next")>1:
            # The existing end-of-act Continue path. Quit remains the Menu button.
            runtime.waiting=true
            runtime._choose(0,"Continue act",false)
            return
        _phase("ON LISTEN")
    if runtime.ai_busy:
        _button("Understanding…",false)
    elif runtime.mic.recording:
        _button("Finish speaking / X",true)
    elif runtime.mic.pid>0:
        _button("Recognising…",false)
    elif not runtime.fallback_reply.is_empty() and runtime.fallback_reply!=fallback_seen:
        fallback_seen=runtime.fallback_reply
        if runtime.responses.last_response_type=="TECHNICAL_FAILURE" and runtime.frame.get("template_version",0)!=2:
            _button("Microphone/interpreter unavailable — retry / X",true)
            return
        _show_fallback(fallback_seen)
        state="PRESENTING"
    elif runtime.waiting and runtime.responses.mic_check_pending:
        _button("Retry microphone / X · Continue without speech / Space",true)
    elif runtime.waiting and runtime.responses.last_response_type=="TECHNICAL_FAILURE" and not runtime.fallback_reply.is_empty() and runtime.frame.get("template_version",0)!=2:
        _button("Microphone/interpreter unavailable — retry / X",true)
    elif runtime.waiting:
        var mic_status=str(runtime.mic.status.text)
        var mic_error=mic_status.begins_with("Engine") or mic_status.begins_with("Could not") or mic_status.begins_with("No audio") or mic_status.begins_with("Transcription timed") or mic_status.begins_with("Whisper ended")
        _button("Microphone unavailable — retry / X" if mic_error else "Speak / X",true)
    else:
        _button("Continue / Space",not runtime.routes.is_empty())
func _transcript_completed(words: String):
    transcript_words=words.strip_edges()
    transcript_seconds_left=5.0 if not transcript_words.is_empty() else 0.0
    transcript_loading_elapsed=0.0
    if not transcript_words.is_empty():ui.acknowledge()
    _update_transcript(0)
func _update_transcript(delta: float = 0.0):
    transcript_seconds_left=maxf(0.0,transcript_seconds_left-delta)
    if not show_player_transcript:
        ui.panel(ui.transcript_path,"",false)
        return
    if runtime.mic.recording:
        transcript_words=""
        transcript_seconds_left=0.0
        transcript_loading_elapsed=0.0
        ui.panel(ui.transcript_path,"",false)
    elif runtime.mic.pid>0:
        transcript_loading_elapsed+=delta
        var dots=1+(int(transcript_loading_elapsed/0.35)%3)
        ui.panel(ui.transcript_path,".".repeat(dots),true)
    else:
        transcript_loading_elapsed=0.0
        ui.panel(ui.transcript_path,transcript_words,transcript_seconds_left>0.0 and not transcript_words.is_empty())
func _button(text: String, enabled: bool):
    ui.get_node("Speak").text=text
    ui.get_node("Speak").disabled=not enabled
    ui.get_node("Speak").visible=not runtime.route_kinds.is_empty()
func graph_input():
    if opening or state!="READY" or runtime.ai_busy:return
    if runtime.waiting:
        runtime.fallback_reply=""
        fallback_seen=""
        runtime._speak()
    else:
        runtime._continue()
func skip_dialogue():
    if opening or state=="OPENING_DELAY":return
    if state=="PRESENTING":
        ui.skip_current_passage()
    elif state=="READY" and runtime.responses.mic_check_pending:
        runtime.continue_after_mic_check()
    elif state=="READY" and not runtime.waiting:
        runtime._continue()
func _present():
    ui.set_process(true)
    get_node("../Actors").modulate=Color.WHITE
    for actor_name in actor_origins:get_node("../Actors/"+actor_name).position=actor_origins[actor_name]
    section=str(runtime.frame.get("id",""))
    state="PRESENTING"
    runtime.accepting_speech=false
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
    passage_voice_used=false
    active_settings=presentation.get(section)
    ui.active_typing=ui.typing_settings
    ui.current_sentence_seconds=ui.sentence_seconds
    ui.voice_volume_db=0
    if active_settings!=null:
        ui.active_typing=active_settings.typing_override if active_settings.typing_override!=null else ui.typing_settings
        ui.current_sentence_seconds=active_settings.presentation_seconds if active_settings.presentation_seconds>0 else ui.sentence_seconds
        ui.voice_volume_db=active_settings.voice_volume_db
        _apply_production(active_settings)
        for sound_cue in active_settings.audio:audio.apply_cue(sound_cue)
        audio.play_sfx(active_settings.sfx_on_start,active_settings.sfx_volume_db)
    semantic_events=runtime.frame.get("events",[])
    semantic_index=0
    current_content={}
    phone_preview=""
    _phase("ON ENTER")
    if section!="Start":_next_content()
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
    if pending_consequence>0:_show_consequence()
func _opened():
    if not opening:return
    opening=false
    curtain.get_parent().hide()
    ui.set_process(true)
    # The first text must be visible on the reveal, not an empty typing frame.
    if ui.writer.typing:ui.writer.advance(0.05)
func _publish_cue():
    if runtime.cue.is_empty():return
    _send_phone(runtime.cue)
func _send_phone(words: String):
    phone_preview=words
    phone.send_text("ifb" if "IFB" in words else "prompt",words)
    if ui.desktop_cue_card:ui.panel(ui.cue_path,"DEBUG · Phone preview\n"+words,true)
func _next_content():
    while semantic_index<semantic_events.size():
        var event: Dictionary=semantic_events[semantic_index]
        semantic_index+=1
        var kind=str(event.get("kind",""))
        if kind in ["dialogue","narration"]:
            current_content=event
            pending_text=str(event.get("text",""))
            var speaker=str(event.get("speaker","")) if kind=="dialogue" else ""
            selected_actor={"Actor 1":"mother","Actor 2":"actor_2","MC":"player"}.get(speaker,"")
            ui.release_to_player=true
            for remaining in semantic_events.slice(semantic_index):
                if remaining.get("kind","") in ["dialogue","narration"]:ui.release_to_player=false
            ui.voice_end_mode=1
            ui.voice_delay=active_settings.voice_delay if active_settings!=null else 0
            var stream: AudioStream=null
            if not passage_voice_used and speaker!="":
                stream=stage_manager_voice if speaker=="Stage Manager" else null
                if active_settings!=null:stream=active_settings.npc_voice
                if stream!=null:passage_voice_used=true
            ui.play_dialogue(pending_text,stream,selected_actor)
            ui.set_speaker(speaker)
            return
        if kind=="phone":_send_phone(str(event.get("text","")))
        _emit_production("SEQUENCE",event)
    if current_content.is_empty():
        ui.play_dialogue("",null,"",false)
        ui.set_speaker("")
func _show_fallback(words: String):
    var text=words
    var speaker=""
    for name in ["Stage Manager","Actor 1","Actor 2"]:
        if words.begins_with(name+":"):
            speaker=name
            text=words.trim_prefix(name+":").strip_edges()
            break
    ui.release_to_player=true
    ui.play_dialogue(text,null,"")
    ui.set_speaker(speaker)
func _emit_production(phase: String, event: Dictionary):
    production_log.append({"passage":section,"phase":phase,"event":event.duplicate(true),"implemented":false})
    if production_log.size()>200:production_log.pop_front()
    production_event.emit(section,phase,event)
func _phase(phase: String):
    for event in runtime.frame.get("production_hooks",{}).get(phase,[]):_emit_production(phase,event)
    if active_settings is ProductionCue:
        for resource in active_settings.phase_cues.get(phase,[]):
            if resource is StageBeat:
                _apply_production(resource)
                for sound_cue in resource.audio:audio.apply_cue(sound_cue)
                audio.play_sfx(resource.sfx_on_start,resource.sfx_volume_db)
    _emit_production(phase,{"kind":"hook","text":phase})
func _exit_tree():
    if is_instance_valid(phone):
        phone.cancel("prompt")
        phone.cancel("ifb")
    if is_instance_valid(audio):audio.stop_all(0)
func _apply_production(settings: StageBeat):
    # Preserve existing StageBeat actor animation/action hooks.
    for action in settings.actor_actions:
        if action==null:continue
        for actor in get_node("../Actors").get_children():
            if actor.identity!=null and actor.identity.actor_id==action.actor_id:actor.apply_action(action)
    if settings.send_phone_cue and settings.phone_cue!=null:phone.deliver(settings.phone_cue)
    if not settings is ProductionCue:return
    var actors=get_node("../Actors")
    actors.modulate=settings.stage_tint
    for actor_name in settings.actor_positions:
        var actor=actors.get_node_or_null(NodePath(actor_name))
        if actor is Node2D or actor is Control:actor.position=settings.actor_positions[actor_name]
    for actor_name in settings.actor_offsets:
        var actor=actors.get_node_or_null(NodePath(actor_name))
        if actor is Node2D or actor is Control:actor.position+=settings.actor_offsets[actor_name]
    if settings.curtain_action==2:
        curtain.stop()
        curtain.frame=0
        curtain.get_parent().show()
    elif settings.curtain_action==1:
        opening=true
        curtain.get_parent().show()
        curtain.play("default")
    if not settings.animation_player.is_empty():
        var player=get_node_or_null(settings.animation_player)
        if player is AnimationPlayer and player.has_animation(settings.stage_animation):player.play(settings.stage_animation)
    runtime.story_variables.merge(settings.state_changes,true)
    if not settings.phone_message.is_empty():phone.send_text(settings.phone_channel,settings.phone_message)
func _response_production(_category: String, _intent: String, consequence: int):
    fallback_seen=""
    var phase={"UNCLEAR":"ON UNCLEAR","SILENCE":"ON SILENCE","QUESTION":"ON QUESTION","OFFSCRIPT":"ON OFFSCRIPT"}.get(_category,"ON ACCEPT" if _category in ["VALID_INTENT","SCRIPTED_RESPONSE","SELECTION","COMMAND","CONTEXTUAL_COMMENT"] else "")
    if not phase.is_empty():_phase(phase)
    if consequence>0:
        pending_consequence=consequence
        call_deferred("_show_consequence")
func _show_consequence():
    if runtime.turn!=seen_turn:return
    var consequence=pending_consequence
    pending_consequence=0
    if consequence==1:
        phone.send_text("ifb","Stay with the script.")
    elif consequence==3:
        var actors=get_node("../Actors")
        var tween=create_tween()
        tween.tween_property(actors,"modulate",Color(0.7,0.6,0.9),0.15)
        tween.tween_property(actors,"modulate",Color.WHITE,0.4)
        phone.send_text("ifb","Stay with the script. The performance must continue.")
