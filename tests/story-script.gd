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
    var cases=[
        ["A scripted","A1_3_FirstCue","I want to create stories people can gather around and remember.","SCRIPTED_RESPONSE","cue",false,"A1_4_SecondCue"],
        ["C bounded","A2_1_Entrance","left","SELECTION","choice_0",false,"A2_1_Left"],
        ["C unsupported","A2_1_Entrance","banana","SELECTION","choice_0",false,"A2_1_Entrance"],
        ["D contextual","A2_2_Hall","There are so many people here","CONTEXTUAL_COMMENT","choice_0",false,"A2_2_HallCommentAppropriate"],
        ["E offscript","A2_1_Entrance","I refuse both entrances","OFFSCRIPT","no_match",true,"A2_1_Offscript"],
        ["F silence","A2_1_Entrance","","SILENCE","",false,"A2_1_Entrance"],
        ["G unclear","A2_1_Entrance","I do not know","UNCLEAR","choice_0",false,"A2_1_Entrance"],
        ["H technical","A2_1_Entrance","","TECHNICAL_FAILURE","choice_0",false,"A2_1_Entrance"],
        ["I question","A2_1_Entrance","Why is the entrance crowded?","QUESTION","choice_0",false,"A2_1_Entrance"],
        ["J help","A2_1_Entrance","What should I do?","HELP_OR_REPEAT","choice_0",false,"A2_1_Entrance"]]
    for test in cases:
        t.parser.start(test[1]);t.accepting_speech=true;t.responses.reset();t.raw_transcript=test[2];c._present()
        t.accepting_speech=true
        t.handle_response(test[3],test[4],test[5])
        check(t.frame.id==test[6],test[0]+" destination")
        check(t.responses.offscript_total==(1 if test[3]=="OFFSCRIPT" else 0),test[0]+" counter")
        records.append({"test":test[0],"input":test[2],"classification":t.responses.last_response_type,"route":t.frame.id,"state_changes":t.story_variables.duplicate(true),"offscript":t.responses.offscript_total,"main_output":t.fallback_reply if not t.fallback_reply.is_empty() else t.frame.events.filter(func(e):return e.kind in ["dialogue","narration"]),"phone":c.phone_preview,"production":c.production_log.duplicate(true)})
    t.parser.start("A2_1_Entrance");t.accepting_speech=true;t.responses.reset()
    t.handle_response("SILENCE");check(t.fallback_reply=="","silence first waits")
    t.handle_response("SILENCE");check("waiting" in t.fallback_reply,"silence second prompt")
    t.handle_response("SILENCE");check("Take your time" in t.fallback_reply,"silence third stronger")
    check(t.responses.offscript_total==0,"silence no punishment")
    t.handle_response("HELP_OR_REPEAT");t.handle_response("QUESTION")
    check(t.responses.help_count==1 and t.responses.question_count==1,"separate counters")
    check(not t.cue in t.fallback_reply,"cue not in fallback main output")
    t.parser.start("A1_0_Begin");t.accepting_speech=true;t.responses.reset()
    for i in 5:
        t.waiting=true;t.handle_response("OFFSCRIPT","",true)
    check(t.responses.offscript_total==5 and t.frame.id=="A0_Endgame","K threshold termination")
    t.parser.start("A2_1_Entrance");t.accepting_speech=true;t.responses.reset()
    for word in ["banana","I hate stairs","let's fly","what are you talking about","not left","left or right","I don't know"]:
        for intent in ["choice_0","choice_1"]:
            t.raw_transcript=word;t.handle_response("SELECTION",intent)
            check(t.frame.id=="A2_1_Entrance","bounded guard "+word)
    var f=FileAccess.open("D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/semantic-script-2026-10-18/policy-matrix.json",FileAccess.WRITE)
    f.store_string(JSON.stringify(records,"  "));f.close()
    print("RESULT ",routes_checked," authored routes / 57 passage presentation checks; failures=",failures)
    game.queue_free();await process_frame
    quit(0 if failures.is_empty() else 1)
