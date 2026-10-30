extends Node
## Dialogue Nodes owns routing; this adapter presents the same story through the final stage.
const ProductionCue=preload("res://Script/StageActs/Graph/production_cue.gd")
@export var presentation: Dictionary[String,StageBeat]={}
@export var voice_lines: Dictionary[String,AudioStream]={}
## Exact speaker/text matches reuse the same take across authored branches.
@export_file("*.json") var voice_catalog_path := "res://Story/StageActs/Graph/voice_recordings.json"
var recorded_voices: Dictionary={}
var voice_stream_cache: Dictionary={}
@export var pre_show_ambience: AudioStream=preload("res://Sound/freesound_community-people-ambience-large-hall-02-17006.mp3")
@export_range(-60,0,1) var audience_volume_db := -24.0
@export_range(-60,0,1) var curtain_volume_db := -18.0
@export_range(0,10,.1) var pre_show_delay := 2.0
@export var curtain_sfx: AudioStream=preload("res://Sound/jarasnat-curtain-version-1-337564.mp3")
@export_group("Act transitions")
@export var curtain_enabled := true
@export var curtain_left: Texture2D=preload("res://Visual Asset/Stage/Background/leftCurtain.png")
@export var curtain_right: Texture2D=preload("res://Visual Asset/Stage/Background/rightCurtain.png")
@export_range(0,1,.05) var curtain_spot_dimming := 0.7
@export_range(0.05,4,.05) var curtain_seconds := 1.6
@export var act_titles: Dictionary[String,String]={"Act 1":"","Act 2":"","Act 3":""}
@export var completion_passages := PackedStringArray(["A3_5_End"])
@export_group("Speech and presentation")
@export_range(0,3,.05) var response_delay := 0.0
@export var show_player_transcript := true
@export_range(80,300,10) var dialogue_page_characters := 180
@onready var runtime=get_node("../StoryRuntime")
@onready var ui=get_node("../StageUI")
@onready var view=get_node("../DialogueView")
@onready var actors=get_node("../World/Performers")
@onready var audio=get_node("../ChapterAudio")
@onready var phone=get_node("../PhoneCueBridge")
signal production_event(passage: String, phase: String, event: Dictionary)
var production_log: Array=[]
var semantic_events: Array=[]
var semantic_index := 0
var current_content: Dictionary={}
var phone_preview := ""
var active_settings: StageBeat
var state := "PRESENTING"
var section := ""
var seen_turn := -1
var fallback_seen := ""
var response_elapsed := 0.0
var opening := false
var transition_phase := ""
var curtain_openness := 0.0
var curtain_tween: Tween
var last_group := ""
@export_range(0,6,.25) var curtain_light_linger_seconds := 2.0
var curtain_focus_strength := 0.0
var actor2_line_count := 0
var transcript_words := ""
var transcript_seconds_left := 0.0
var transcript_loading_elapsed := 0.0
var visual_state: Dictionary={}
var used_visual_cues: Dictionary={}
var played_voice_keys: Dictionary={}
var first_lights: Dictionary={}
var opening_texture_played := false
var phone_sound_state := ""
var menacing_sound_played := false
func _ready():
    _load_voice_catalog()
    UIAudio.start_playthrough()
    for actor in actors.get_children():actor.flip_started.connect(func():UIAudio.stage_effect(UIAudio.flip_sound,UIAudio.flip_volume_db))
    get_node("../World/Lighting").focus_started.connect(_first_light)
    get_node("../FrameCutInLayer/FrameCutIn").cutin_shown.connect(func():UIAudio.stage_effect(UIAudio.cutin_sound,UIAudio.cutin_volume_db))
    _prepare_curtain()
    _update_curtain()
    runtime.response_resolved.connect(_response_production)
    runtime.cue_requested.connect(_publish_cue)
    runtime.mic.transcript_ready.connect(_transcript_completed)
    runtime.mic.technical_failure.connect(func(_detail):
        transcript_words="";transcript_seconds_left=0)
func _voice_text_key(speaker: String, words: String) -> String:
    var regex=RegEx.new()
    regex.compile("[^a-z0-9]")
    return speaker+":"+regex.sub(words.to_lower(),"",true)
func _load_voice_catalog():
    recorded_voices.clear();voice_stream_cache.clear()
    if not FileAccess.file_exists(voice_catalog_path):
        push_warning("Voice recording catalogue missing: "+voice_catalog_path)
        return
    var entries=JSON.parse_string(FileAccess.get_file_as_string(voice_catalog_path))
    if not entries is Array:return
    for entry in entries:
        recorded_voices[_voice_text_key(str(entry.speaker),str(entry.text))]=str(entry.audio)
func _recorded_voice(speaker: String, words: String) -> AudioStream:
    var path=str(recorded_voices.get(_voice_text_key(speaker,words),""))
    if path.is_empty():return null
    if not voice_stream_cache.has(path):voice_stream_cache[path]=load(path)
    return voice_stream_cache[path] as AudioStream
func _process(delta):
    _update_curtain()
    _update_transcript(delta)
    if ui.overlay_open():
        runtime.accepting_speech=false
        return
    runtime.accepting_speech=state=="READY" and not opening
    if runtime.turn!=seen_turn:
        seen_turn=runtime.turn
        _present()
    if state=="COMPLETE":
        _button("",false)
        return
    if state=="OPENING_DELAY":
        response_elapsed+=delta
        _button("Please wait",false)
        if response_elapsed>=pre_show_delay:state="PRESENTING";_next_content()
        return
    if opening:
        _button("",false)
        if transition_phase=="TITLE" and not view.title_running:
            opening=false
            transition_phase=""
            state="PRESENTING"
            _next_content()
        return
    if state=="PRESENTING":
        _button("",false)
        if not ui.dialogue_finished():return
        if semantic_index<semantic_events.size():_next_content();return
        if runtime.frame.get("routes",[]).is_empty() or section in completion_passages:
            _finish_show()
            return
        state="RESPONSE_DELAY";response_elapsed=0
    if state=="RESPONSE_DELAY":
        response_elapsed+=delta
        if response_elapsed<response_delay:return
        state="READY"
        runtime.accepting_speech=runtime.waiting
        if runtime.waiting:_phone_presentation("Waiting", false, true)
        if not runtime.waiting and not runtime.routes.is_empty():runtime._continue();return
        if runtime.route_kinds.count("next")>1:
            runtime.waiting=true;runtime._choose(0,"Continue act",false);return
        if actors.get_node("Actor1").visible:actors.get_node("Actor1").flip_to_pose("Actor1Listening")
        _phase("ON LISTEN")
    if runtime.ai_busy:_button("Understanding…",false)
    elif runtime.mic.recording:_button("Finish speaking / X",true)
    elif runtime.mic.pid>0:_button("Recognising…",false)
    elif not runtime.fallback_reply.is_empty() and runtime.fallback_reply!=fallback_seen:
        fallback_seen=runtime.fallback_reply
        _show_fallback(fallback_seen);state="PRESENTING"
    elif runtime.waiting and runtime.responses.mic_check_pending:_button("Retry microphone / X · Continue without speech / Space",true)
    elif runtime.waiting:_button("Speak / X",true)
    else:_button("Continue / Space",not runtime.routes.is_empty())
func _present():
    _cancel_transition()
    section=str(runtime.frame.get("id",""))
    used_visual_cues.clear();played_voice_keys.clear()
    view.current_visual_state["cut_in"]={"action":"hide"}
    view.apply_graph_visuals(view.current_visual_state)
    state="PRESENTING";fallback_seen="";semantic_index=0;current_content={}
    runtime.accepting_speech=false
    phone.cancel("prompt");phone.cancel("ifb");phone_preview=""
    var group=str(runtime.frame.get("group",""))
    active_settings=presentation.get(section)
    semantic_events=[]
    for index in runtime.frame.get("events",[]).size():
        var event=runtime.frame.events[index].duplicate(true)
        event["recording_key"]=section+":"+str(index)
        if event.kind in ["dialogue","narration"]:
            # A recorded unit stays intact: don't split its text and cut/restart its take.
            var pages=PackedStringArray([str(event.text)]) if recorded_voices.has(_voice_text_key(str(event.get("speaker","")),str(event.text))) else _pages(str(event.text))
            for words in pages:
                var part=event.duplicate(true);part.text=words;semantic_events.append(part)
        else:semantic_events.append(event)
    if section=="Start":
        UIAudio.start_playthrough();first_lights.clear();opening_texture_played=false;menacing_sound_played=false
        phone.send_sound("all","stop");phone_sound_state=""
        actor2_line_count=0
        curtain_openness=0.0
        _set_stage_cast(group)
        _update_curtain()
        var ambience=BeatAudioCue.new();ambience.action=1;ambience.channel=0;ambience.stream=pre_show_ambience;ambience.volume_db=audience_volume_db;audio.apply_cue(ambience)
        visual_state.clear();view.current_visual_state.clear()
        state="OPENING_DELAY";response_elapsed=0
        ui.play_dialogue("",null,"",false);ui.set_speaker("")
    elif group!=last_group and act_titles.has(group):
        _begin_act(group)
    else:
        _set_stage_cast(group)
        _next_content()
    last_group=group
func _pages(words: String) -> PackedStringArray:
    var result=PackedStringArray()
    var regex=RegEx.new();regex.compile("[^.!?]+[.!?]+|[^.!?]+$")
    var current=""
    for sentence in regex.search_all(words):
        var phrase=sentence.get_string().strip_edges()
        if phrase.is_empty():continue
        if current.length()+phrase.length()>dialogue_page_characters and not current.is_empty():
            result.append(current);current=""
        current+=(" " if not current.is_empty() else "")+phrase
    if not current.is_empty():result.append(current)
    return result
func _next_content():
    while semantic_index<semantic_events.size():
        var event: Dictionary=semantic_events[semantic_index];semantic_index+=1
        for i in runtime.frame.get("visual_cues",[]).size():
            var command=runtime.frame.visual_cues[i]
            var trigger=str(command.get("when_text",""))
            if not used_visual_cues.has(i) and (trigger.is_empty() or str(event.text).contains(trigger)):
                view.visual_command(command,section+":"+str(i))
                used_visual_cues[i]=true
        if event.kind in ["dialogue","narration"]:
            current_content=event
            var speaker=str(event.speaker) if event.kind=="dialogue" else ""
            ui.release_to_player=true
            for later in semantic_events.slice(semantic_index):
                if later.kind in ["dialogue","narration"]:ui.release_to_player=false
            var voice_key=str(event.get("recording_key",""))
            var recorded=_recorded_voice(speaker,str(event.text))
            var stream=recorded
            if stream==null:stream=voice_lines.get(voice_key) if not played_voice_keys.has(voice_key) else null
            played_voice_keys[voice_key]=true
            if stream==null and active_settings!=null:stream=active_settings.npc_voice
            ui.play_dialogue(str(event.text),stream,"",true,false,recorded!=null)
            ui.set_speaker(speaker)
            if group_is_preshow() and speaker=="Stage Manager":
                if not opening_texture_played:
                    opening_texture_played=true;UIAudio.stage_effect(UIAudio.opening_texture,UIAudio.opening_volume_db)
                if "silence" in str(event.text).to_lower():
                    var stop_audience=BeatAudioCue.new();stop_audience.action=2;stop_audience.channel=0;stop_audience.fade_seconds=0.0;audio.apply_cue(stop_audience)
                _first_light("StageManager")
            _phone_presentation("Speaking" if speaker=="Stage Manager" else "", speaker=="Stage Manager", true)
            return
        if event.kind=="phone":_send_phone(str(event.text))
        _emit_production("SEQUENCE",event)
    if current_content.is_empty():
        ui.play_dialogue("",null,"",false);ui.set_speaker("")
        _phone_presentation("", false, false)
func _show_fallback(words: String):
    var speaker=""
    var text=words
    for name in ["Stage Manager","Actor 1","Actor 2","MC"]:
        if words.begins_with(name+":"):
            speaker=name;text=words.trim_prefix(name+":").strip_edges();break
    # Multiple authored response paragraphs remain sequential dialogue, not developer text.
    ui.release_to_player=true
    var recorded=_recorded_voice(speaker,text)
    ui.play_dialogue(text,recorded,"",true,false,recorded!=null)
    ui.set_speaker(speaker)
    _phone_presentation("Speaking" if speaker=="Stage Manager" else "", speaker=="Stage Manager", true)
func _button(words: String, enabled: bool):ui.set_prompt(words,enabled)
func graph_input():
    if ui.overlay_open() or opening or state!="READY" or runtime.ai_busy:return
    if runtime.waiting:
        runtime.fallback_reply="";fallback_seen="";runtime._speak()
    else:runtime._continue()
func skip_dialogue():
    if ui.overlay_open() or opening or state=="OPENING_DELAY":return
    if state=="PRESENTING":ui.skip_current_passage()
    elif state=="READY" and runtime.responses.mic_check_pending:runtime.continue_after_mic_check()
    elif state=="READY" and not runtime.waiting:runtime._continue()
func _transcript_completed(words: String):
    transcript_words=words;transcript_seconds_left=5.0
func _update_transcript(delta):
    transcript_seconds_left=maxf(0,transcript_seconds_left-delta)
    if not show_player_transcript:ui.show_transcript("",false);return
    if runtime.mic.recording:transcript_words="";transcript_seconds_left=0;ui.show_transcript("",false)
    elif runtime.mic.pid>0:
        transcript_loading_elapsed+=delta;ui.show_transcript(".".repeat(1+int(transcript_loading_elapsed/.35)%3),true)
    else:ui.show_transcript(transcript_words,transcript_seconds_left>0)
func _publish_cue():
    if not runtime.cue.is_empty():_send_phone(runtime.cue)
func _send_phone(words: String):
    phone_preview=words
    var channel := "ifb" if "IFB" in words else "prompt"
    var cue_type := "PRIVATE" if channel == "ifb" else "PROMPTER"
    phone.send_text(channel, words, "", cue_type, "Cue", false, true)
func _phone_presentation(expression: String, talking := false, dialogue_boundary := true) -> void:
    if is_instance_valid(phone):
        phone.send_presentation(expression, talking, dialogue_boundary)
        var desired="tea" if expression=="Waiting" else ""
        if phone_sound_state!=desired:
            phone.send_sound("tea","stop");phone_sound_state=desired
            if desired=="tea":phone.send_sound(UIAudio.phone_waiting_sound,"play",UIAudio.tea_volume_db)
        if expression=="Menancing" and not menacing_sound_played:
            menacing_sound_played=true;phone.send_sound(UIAudio.phone_menacing_sound,"play",UIAudio.suspense_volume_db)
func group_is_preshow() -> bool:return str(runtime.frame.get("group",""))=="Act 0 · Pre-show"
func _first_light(character: String):
    if first_lights.has(character):return
    # Curtain blocks the world beam; its own manager spotlight is handled explicitly.
    if curtain_enabled and curtain_openness<0.999 and character!="StageManager":return
    first_lights[character]=true
    UIAudio.stage_effect(UIAudio.light_sound,UIAudio.light_volume_db)
func _emit_production(phase: String,event: Dictionary):
    production_log.append({"passage":section,"phase":phase,"event":event.duplicate(true),"implemented":false})
    if production_log.size()>200:production_log.pop_front()
    production_event.emit(section,phase,event)
func _phase(phase: String):
    for event in runtime.frame.get("production_hooks",{}).get(phase,[]):_emit_production(phase,event)
    if active_settings is ProductionCue:
        for cue in active_settings.phase_cues.get(phase,[]):
            if cue is StageBeat:_apply_production(cue)
func _apply_production(settings: StageBeat):
    for action in settings.actor_actions:
        if action==null:continue
        var actor=actors.get_node_or_null({"player":"Player","mother":"Actor1","actor_2":"Actor2","manager":"StageManager"}.get(action.actor_id,action.actor_id))
        if actor==null:continue
        if action.visibility!=0:actor.visible=action.visibility==1
        var sprite=actor.get_node("Swing/Card/Art")
        if action.animation==&"flip":actor.flip()
        elif not action.animation.is_empty() and sprite.sprite_frames.has_animation(action.animation):sprite.play(action.animation)
    for cue in settings.audio:audio.apply_cue(cue)
    audio.play_sfx(settings.sfx_on_start,settings.sfx_volume_db)
    if settings.send_phone_cue and settings.phone_cue!=null:phone.deliver(settings.phone_cue)
    if settings is ProductionCue:
        for key in settings.actor_positions:
            var actor=actors.get_node_or_null({"player":"Player","mother":"Actor1","actor_2":"Actor2","manager":"StageManager"}.get(key,key))
            if actor!=null:actor.position=settings.actor_positions[key]
        for key in settings.actor_offsets:
            var actor=actors.get_node_or_null({"player":"Player","mother":"Actor1","actor_2":"Actor2","manager":"StageManager"}.get(key,key))
            if actor!=null:actor.position+=settings.actor_offsets[key]
        runtime.story_variables.merge(settings.state_changes,true)
        if not settings.phone_message.is_empty():phone.send_text(settings.phone_channel,settings.phone_message)
func _response_production(category: String,_intent: String,consequence: int):
    fallback_seen=""
    var mc=actors.get_node("Player")
    var actor1=actors.get_node("Actor1")
    var manager=actors.get_node("StageManager")
    var total=runtime.responses.offscript_total
    var streak=runtime.responses.offscript_streak
    var conversation=str(runtime.frame.get("conversation",section))
    var local=int(runtime.responses.conversation_attempts.get(conversation,0))
    if category=="OFFSCRIPT":
        UIAudio.stage_effect(UIAudio.boing_sound,UIAudio.boing_volume_db)
        if mc.visible:mc.flip_to_pose("MCThreaten" if total>=4 else ("MCControl" if local>=2 else "MCSilly"))
        if actor1.visible:actor1.flip_to_pose("Actor1Disappoint")
        if manager.visible:manager.flip_to_pose("StageManager_Disappointed")
        if total>=4:_phone_presentation("Menancing", false, true)
        elif streak>=2:_phone_presentation("Angry", false, true)
        else:_phone_presentation("Disappointed", false, true)
    elif category in ["UNCLEAR","TECHNICAL_FAILURE"]:
        if mc.visible:mc.flip_to_pose("MCConfused")
        _phone_presentation("Confused", false, true)
    elif category in ["SCRIPTED_RESPONSE","VALID_INTENT","CONTEXTUAL_COMMENT","SELECTION","COMMAND"]:
        if mc.visible:mc.flip_to_pose("MCActing")
        if actor1.visible:actor1.flip_to_pose("Actor1Accept")
        _phone_presentation("Accept", false, true)

func _exit_tree():
    UIAudio.leave_game()
    if is_instance_valid(phone):phone.send_sound("all","stop")
    if is_instance_valid(phone):phone.cancel("prompt");phone.cancel("ifb")
    if is_instance_valid(audio):audio.stop_all(0)

func _prepare_curtain():
    for side in ["Left","Right"]:
        var image=get_node("../CurtainLayer/Curtain/"+side)
        image.texture=curtain_left if side=="Left" else curtain_right
        var mat=ShaderMaterial.new()
        mat.shader=preload("res://Script/Stage/Shaders/curtain_light.gdshader")
        image.material=mat
func _update_curtain():
    var layer=get_node_or_null("../CurtainLayer")
    if layer==null:return
    layer.visible=curtain_enabled and curtain_left!=null and curtain_openness<0.999 and not ui.developer_mode
    var size=get_viewport().get_visible_rect().size
    layer.transform=get_viewport().get_canvas_transform().affine_inverse()
    layer.get_node("Curtain").size=size
    var manager=actors.get_node("StageManager")
    var focused=manager.visible and pending_manager_speech()
    curtain_focus_strength=move_toward(curtain_focus_strength,1.0 if focused else 0.0,get_process_delta_time()*2.5)
    var centre=(get_viewport().get_canvas_transform()*manager.get_lighting_anchor()-Vector2(0,size.y*.20))/size
    for side in ["Left","Right"]:
        var image=layer.get_node("Curtain/"+side)
        image.size=size
        image.position=Vector2(size.x*.58*curtain_openness*(-1 if side=="Left" else 1),0)
        image.material.set_shader_parameter("screen_size",size)
        image.material.set_shader_parameter("focus",centre)
        image.material.set_shader_parameter("slide",image.position/size)
        image.material.set_shader_parameter("dimming",curtain_spot_dimming*curtain_focus_strength)
func pending_manager_speech() -> bool:
    return ui.pending_speaker=="Stage Manager" and (actors.get_node("StageManager").flipping or (state=="PRESENTING" and (not view.line_revealed() or ui.revealed_hold<curtain_light_linger_seconds)))
func _cancel_transition():
    if curtain_tween!=null:curtain_tween.kill()
    opening=false
    transition_phase=""
    view.cancel_backdrop_title()
func _set_stage_cast(group: String):
    UIAudio.enter_group(group)
    var pre_show=group=="Act 0 · Pre-show"
    var actor2=actors.get_node("Actor2")
    var entering_actor2=group=="Act 3" and not actor2.visible
    actors.get_node("StageManager").visible=pre_show
    actors.get_node("Player").visible=not pre_show
    actors.get_node("Actor1").visible=not pre_show
    actor2.visible=group=="Act 3"
    if entering_actor2:_phone_presentation("Unexpected", false, true)
    if active_settings!=null:_apply_production(active_settings)
    _phase("ON ENTER")
func _move_curtain(target: float, after: Callable):
    if curtain_tween!=null:curtain_tween.kill()
    if curtain_enabled and curtain_sfx!=null:audio.play_sfx([curtain_sfx],curtain_volume_db)
    if not curtain_enabled or absf(curtain_openness-target)<0.001:
        curtain_openness=target
        _update_curtain()
        after.call()
        return
    curtain_tween=create_tween()
    curtain_tween.tween_property(self,"curtain_openness",target,curtain_seconds*absf(curtain_openness-target)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    curtain_tween.tween_callback(func():
        _update_curtain()
        after.call())
func _begin_act(group: String):
    opening=true
    state="ACT_TRANSITION"
    transition_phase="CLOSING"
    runtime.accepting_speech=false
    transcript_words="";transcript_seconds_left=0
    ui.play_dialogue("",null,"",false);ui.set_speaker("")
    audio.stop_all(0.3)
    var reveal=func():
        _set_stage_cast(group)
        transition_phase="OPENING"
        # Prepare the zoomed/dark title behind the closed curtain, avoiding a bright flash.
        view.play_backdrop_text(_act_title(group),true)
        _move_curtain(1.0,func():transition_phase="TITLE")
    _move_curtain(0.0,reveal)
func _finish_show():
    opening=true
    state="ACT_TRANSITION"
    transition_phase="ENDING"
    runtime.accepting_speech=false
    ui.play_dialogue("",null,"",false);ui.set_speaker("")
    view.finish_talking()
    _move_curtain(0.0,func():
        opening=false
        transition_phase=""
        state="COMPLETE"
        audio.stop_all(0.3))

func _act_title(group: String) -> String:
    var override=str(act_titles.get(group,""))
    if not override.strip_edges().is_empty():return override
    var name=str({"Act 1":view.act_one_name,"Act 2":view.act_two_name,"Act 3":view.act_three_name}.get(group,""))
    return group+(": "+name if not name.strip_edges().is_empty() else "")
