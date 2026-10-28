extends SceneTree
func _initialize():call_deferred("run")
func run():
    var game=load("res://Scene/StageActs/stage_graph_game.tscn").instantiate()
    var t=game.get_node("StoryRuntime")
    game.get_node("PhoneCueBridge").enabled=false
    root.add_child(game)
    var c=game.get_node("GameController")
    c.set_process(false);t.set_process(false)
    var tests=[
        ["A2_1_Entrance","left","A2_1_Left"],
        ["A2_1_Entrance","take the left entrance","A2_1_Left"],
        ["A2_1_Entrance","right","A2_1_Right"],
        ["A2_1_Entrance","right side please","A2_1_Right"],
        ["A2_1_Entrance","banana","NOT_DIRECTION"],
        ["A2_1_Entrance","I hate stairs","NOT_DIRECTION"],
        ["A2_1_Entrance","Let's fly","NOT_DIRECTION"],
        ["A2_1_Entrance","what are you talking about?","HELP_OR_REPEAT"],
        ["A2_1_Entrance","I don't know","UNCLEAR"],
        ["A2_1_Entrance","what should I do?","HELP_OR_REPEAT"],
        ["A2_1_Entrance","What am I supposed to do?","HELP_OR_REPEAT"],
        ["A2_1_Entrance","What should I say?","HELP_OR_REPEAT"],
        ["A2_1_Entrance","Can you repeat that?","HELP_OR_REPEAT"],
        ["A2_1_Entrance","Why is the entrance crowded?","QUESTION"],
        ["A2_2_Hall","There's so many people here","A2_2_HallCommentAppropriate"],
        ["A2_2_Hall","The moon is made of cheese","NOT_HALL"],
        ["A1_3_FirstCue","I want to create stories people can gather around and remember","A1_4_SecondCue"],
        ["A1_1_ACTOR 1'sQuestion","I want to become a writer","A1_1_WrongLine"],
        ["A1_0_Begin","uh no","A1_0_No"],
        ["A2_6_ScriptChange","No","A2_7_Decline"],
        ["A2_6_ScriptChange","Yes","A2_7_Agree"],
        ["A2_6_ScriptChange","I'm not sure anymore","A2_7_NotSure"],
        ["A3_2_FirstQuestion","No","A3_2_No"],
        ["A2_4_CallSomeone","Chief, please fetch the scroll","A2_5_Called"],
        ["A3_4_Conflict","I want to answer Actor 2","A3_4_EngageActor2"]]
    var records=[];var failed=0
    for test in tests:
        t.parser.start(test[0]);t.responses.reset();t.ai_history.clear();t.accepting_speech=true
        c._present();t.accepting_speech=true
        t.submit_words(test[1])
        while t.ai_busy:await create_timer(0.1).timeout
        var expected=test[2]
        var ok=t.frame.id==expected or (expected in t.ResponsePolicy.TYPES and t.responses.last_response_type==expected and t.frame.id==test[0])
        if expected=="NOT_DIRECTION":ok=not t.frame.id in ["A2_1_Left","A2_1_Right"]
        if expected=="NOT_HALL":ok=not t.frame.id in ["A2_2_HallCommentAppropriate","A2_2_HallCommentAwkward"]
        if t.responses.last_response_type=="TECHNICAL_FAILURE":ok=false
        if not ok:failed+=1
        var category=t.responses.last_response_type
        if t.frame.id!=test[0]:c._present()
        var outputs=[]
        for event in t.frame.events:
            if event.kind in ["dialogue","narration"]:outputs.append(event)
        while c.semantic_index<c.semantic_events.size():c._next_content()
        records.append({"node":test[0],"input":test[1],"classification":category,"intent":t.interpreted_intent,"route":t.frame.id,"passed":ok,"state_changes":t.story_variables.duplicate(true),"offscript":t.responses.offscript_total,"main_output":t.fallback_reply if not t.fallback_reply.is_empty() else outputs,"phone_output":c.phone_preview,"production_events":c.production_log.duplicate(true)})
        print("PASS " if ok else "FAIL ",test[1]," => ",category," / ",t.frame.id)
    var file=FileAccess.open("D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/semantic-script-2026-10-18/real-ai-matrix.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(records,"  "));file.close()
    print("RESULT ",tests.size()-failed,"/",tests.size()," real local Qwen cases")
    game.queue_free();await process_frame
    quit(0 if failed==0 else 1)
