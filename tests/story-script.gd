extends SceneTree
var failures: Array = []
var records: Array = []
func check(ok: bool, label: String):
    if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
    var game=load("res://Scene/StageActs/stage_graph_game.tscn").instantiate()
    var t=game.get_node("StoryRuntime")
    t.ai_enabled=false
    game.get_node("PhoneCueBridge").enabled=false
    root.add_child(game)
    var c=game.get_node("GameController")
    game.get_node("DialogueView").act_title_enabled=false
    c.curtain_enabled=false
    c.set_process(false);t.set_process(false)
    var m=JSON.parse_string(FileAccess.get_file_as_string("res://Story/StageActs/Graph/acts_0_3_manifest.json"))
    var routes_checked=0
    for section in m:
        for i in m[section].links.size():
            t.parser.start(section);t.waiting=true;t._choose(i,"graph parity",false)
            check(t.frame.id==m[section].links[i][1],section+" route "+str(i))
            routes_checked+=1
        t.parser.start(section);c._present()
        for e in t.frame.events:
            if e.kind=="narration":check(e.speaker=="",section+" narrator label")
            if e.kind in ["dialogue","narration"]:
                for prefix in ["STAGE:","SOUND:","CUE / PHONE:","CONTEXT:","AUTHOR NOTE:","PLAYER TASK:"]:
                    check(not e.text.begins_with(prefix),section+" leaked "+prefix)
        while c.semantic_index<c.semantic_events.size():c._next_content()
    # Actual runtime handling, using the imported frame data rather than hand-built fixtures.
    t.parser.start("A1_0_Begin");t.accepting_speech=true;t.responses.reset()
    t.raw_transcript="uh no";t._interpret("uh no")
    check(t.frame.id=="A1_0_No","spoken no never agrees to begin")
    t.accepting_speech=true;t.raw_transcript="yes";t._interpret("yes")
    check(t.frame.id=="A1_1_0 PreshowAnnoyed","spoken yes follows current intro route")
    t.parser.start("A1_0_Begin");t.accepting_speech=true;t.responses.reset()
    t.handle_response("OFFSCRIPT","",true);t.handle_response("OFFSCRIPT","",true)
    check(t.frame.id=="TAKEOVER::A1_0_Begin","two local intro attempts use authored takeover")
    check(t.responses.offscript_total==0,"intro exempt from global penalty")
    t.parser.start("A2_2_HallCommentAppropriate");t.accepting_speech=true;t.responses.reset()
    t.raw_transcript="no";t._interpret("no")
    check(t.frame.id=="Music_NotYet","music refusal remains refusal")
    t.waiting=true;t._choose(0,"continue",false)
    check(t.frame.id=="A2_4_CallSomeone","new music refusal does not dead-end")
    t.parser.start("A2_1_Entrance");t.accepting_speech=true;t.responses.reset()
    t.handle_response("SILENCE")
    check(t.fallback_reply==t.frame.response_overrides.SILENCE.reply,"authored shared silence")
    check(t.responses.offscript_total==0,"silence never penalized")
    t.handle_response("OFFSCRIPT","",true)
    check(t.frame.id=="A2_1_Entrance" and t.responses.offscript_total==1,"first unrelated attempt stays")
    t.handle_response("OFFSCRIPT","",true)
    check(t.frame.id=="TAKEOVER::A2_1_Entrance" and t.responses.offscript_total==2,"second unrelated attempt advances through takeover")
    t.waiting=true;t._choose(0,"continue",false)
    check(t.frame.id=="A2_2_Hall" and t.story_variables.get("entrance")=="left","takeover preserves authored entrance state")
    t.parser.start("A2_1_Entrance");t.accepting_speech=true;t.responses.reset()
    t.handle_response("UNCLEAR");t.handle_response("TECHNICAL_FAILURE");t.handle_response("UNCLEAR")
    check(t.responses.mic_check_pending,"third mixed technical failure offers microphone check")
    check("cat has stolen" in t.fallback_reply,"new authored microphone check words")
    check(t.responses.offscript_total==0,"technical failures never penalized")
    t.continue_after_mic_check()
    check(t.frame.id=="TAKEOVER::A2_1_Entrance","mic check can continue without speech")
    t.parser.start("A2_1_Entrance");t.accepting_speech=true;t.responses.reset()
    t.handle_response("UNCLEAR");t.handle_response("TECHNICAL_FAILURE")
    t.handle_response("HELP_OR_REPEAT")
    check(t.responses.technical_streak==0,"understood speech resets technical streak")
    t.responses.offscript_total=4;t.responses.conversation_attempts["A2_1_Entrance"]=1
    t.handle_response("OFFSCRIPT","",true)
    check(t.frame.id=="A0_Endgame","fifth cumulative unrelated attempt takes priority over local takeover")
    t.parser.start("A1_1_ACTOR 1'sQuestion");t.accepting_speech=true;t.responses.reset()
    t.raw_transcript="I want to become a doctor";t.handle_response("VALID_INTENT","ambition")
    check(t.frame.id=="A1_1_WrongLine" and t.responses.offscript_total==0,"forgotten-line first relevant attempt preserved without penalty")
    t.accepting_speech=true;t.handle_response("VALID_INTENT","ambition")
    check(t.frame.id=="A1_2_SecondFailure" and t.responses.offscript_total==0,"forgotten-line second relevant attempt preserved")
    t.parser.start("A2_1_Entrance");t.accepting_speech=true;t.responses.reset()
    for word in ["banana","I hate stairs","not left","left or right","I don't know"]:
        for intent in ["choice_0","choice_1"]:
            t.raw_transcript=word;t.handle_response("SELECTION",intent)
            check(t.frame.id=="A2_1_Entrance","bounded direction guard "+word)
            t.responses.technical_streak=0;t.responses.mic_check_pending=false
    var view=game.get_node("DialogueView")
    var stage_ui=game.get_node("StageUI")
    stage_ui.set_developer_mode(false)
    check(not t.visible and view.visible,"normal play hides developer controls")
    stage_ui.set_developer_mode(true)
    check(t.visible and not view.visible,"developer controls accessible")
    stage_ui.set_developer_mode(false)
    check(game.get_node("World/Atmosphere").enabled and game.get_node("World/Atmosphere").outside_mask!=null,"supplied masked pattern configured")
    for name in ["Player","Actor1","Actor2","StageManager"]:
        var actor=game.get_node("World/Performers/"+name)
        check(actor.pose_frames!=null and actor.pose_frames.get_frame_count("poses")>=2,name+" supplied pose bank")
        check(actor.pose_names.size()==actor.pose_frames.get_frame_count("poses"),name+" named poses survive inheritance")
        var original=actor.position
        actor.position+=Vector2(0,-20)
        game.apply_layout(Vector2(1280,800))
        check(actor.position==original+Vector2(0,-20),name+" authored position survives resizing")
        actor.position=original
    # A real linked transition must execute visual nodes, not bypass them via the frame signal.
    t.parser.start("A1_1_Once upon a time");t.waiting=true;t._choose(0,"continue",false)
    check(t.frame.get("visual_cues",[]).size()>0,"linked visual cue commands reach main story")
    # Real model responses must prove a current meaning; invalid evidence never advances.
    t.parser.start("A2_4_CallSomeone");t.waiting=true;t.accepting_speech=true;t.responses.reset()
    t.raw_transcript="I want to eat pizza.";t.ai_allowed=["unclear","no_match","choice_0"]
    var response_turn=t.turn
    t.ai_busy=true;t.ai_turn=t.turn
    t._ai_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"message":{"content":JSON.stringify({"fit":"supported","intent":"choice_0","evidence":"CALL CHIEF","reason":"cue is not player evidence"})},"done_reason":"stop"}).to_utf8_buffer())
    check(t.turn==response_turn and t.responses.offscript_total==0,"invented AI evidence cannot advance or punish")
    t.ai_busy=true;t.ai_turn=t.turn
    t._ai_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"message":{"content":JSON.stringify({"fit":"unrelated","intent":"no_match","evidence":"I want to eat pizza.","reason":"clear unrelated statement"})},"done_reason":"stop"}).to_utf8_buffer())
    check(t.turn==response_turn and t.responses.offscript_total==1,"understood unrelated response counts and does not accept call route")
    check(not t.interpretation_log.is_empty() and t.interpretation_log.back().has("raw_ai"),"copyable interpretation evidence is retained")
    c.last_group="Act 2";c.curtain_enabled=true;c.curtain_openness=1.0
    t.parser.start("A3_1_Actor2");c._present()
    check(not c.opening and c.transition_phase=="","Act2 to Act3 is continuous")
    check(game.get_node("World/Performers/Actor2").visible,"intruder visible without act curtain")
    # Supplied multi-file recordings must retain every spoken part in source order.
    var voice_catalog=JSON.parse_string(FileAccess.get_file_as_string(c.voice_catalog_path))
    for entry in voice_catalog:
        var recording=c._recorded_voice(entry.speaker,entry.text)
        check(recording!=null and recording.get_length()>0,str(entry.id)+" voice resource loads")
        if entry.has("parts"):
            var combined=""
            for part in entry.parts:combined+=str(part.text)
            check(c._voice_text_key(entry.speaker,combined)==c._voice_text_key(entry.speaker,entry.text),str(entry.id)+" recorded parts preserve words")
            check(recording is AudioStreamPlaylist and not recording.loop,str(entry.id)+" finite voice sequence")
    t.parser.start("A1_1_Once upon a time");c.last_group="Act 1";c._present()
    var story_voice_parts=0
    for event in c.semantic_events:
        if event.get("speaker","")=="Stage Manager":story_voice_parts+=1
    check(story_voice_parts==3,"fairytale narration plays allthree supplied parts")
    print("RESULT ",routes_checked," graph links / ",m.size()," passage presentations; response-template checks; failures=",failures)
    game.queue_free();await process_frame
    quit(0 if failures.is_empty() else 1)
