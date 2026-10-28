extends SceneTree
func _initialize():call_deferred("run")
func run():
    var game=load("res://Scene/StageActs/stage_graph_game.tscn").instantiate()
    var t=game.get_node("StoryRuntime")
    t.ai_enabled=false
    game.get_node("PhoneCueBridge").enabled=false
    root.add_child(game)
    var m=JSON.parse_string(FileAccess.get_file_as_string("res://Story/StageActs/Graph/acts_0_3_manifest.json"))
    var count=0
    for section in m:
        for i in m[section].links.size():
            t.parser.start(section)
            t.waiting=true
            t._choose(i,"graph regression",false)
            assert(t.frame.id==m[section].links[i][1],section)
            count+=1
    for category in t.ResponsePolicy.TYPES:
        t.parser.start("A1_0_Begin")
        t.accepting_speech=true
        t.responses.reset()
        t.handle_response(category,"",category=="OFFSCRIPT")
        assert(t.responses.last_response_type==category)
        assert(t.responses.offscript_total==(1 if category=="OFFSCRIPT" else 0))
    t.parser.start("A1_0_Begin")
    t.accepting_speech=true
    t.responses.reset()
    for category in ["UNCLEAR","TECHNICAL_FAILURE","HELP_OR_REPEAT","QUESTION","CONTEXTUAL_COMMENT","OUT_OF_TURN"]:
        t.handle_response(category)
        assert(t.responses.offscript_total==0)
        assert(t.frame.id=="A1_0_Begin")
    t.handle_response("SILENCE")
    assert(t.responses.offscript_total==0)
    t.parser.start("A1_0_Begin")
    t.handle_response("OFFSCRIPT","",false)
    assert(t.responses.offscript_total==0)
    t.handle_response("OFFSCRIPT","",true)
    assert(t.responses.offscript_total==1)
    t.handle_response("VALID_INTENT")
    assert(t.responses.offscript_streak==0)
    t.responses.definitions.nodes.TEST={"UNCLEAR":{"reply":"node"}}
    t.responses.definitions.acts.TEST={"UNCLEAR":{"reply":"act"}}
    assert(t.responses.resolve("TEST","TEST","UNCLEAR").reply=="node")
    assert(t.responses.resolve("missing","TEST","UNCLEAR").reply=="act")
    assert(t.responses.resolve("missing","missing","UNCLEAR").has("reply"))
    t.parser.start("A1_4_SecondCue")
    game.get_node("GameController")._present()
    assert(t.story_variables.get("act1_cue_reached",false))
    assert(game.get_node("Actors").modulate!=Color.WHITE)
    assert(not t.response_debug.visible)
    t.parser.start("A1_0_Begin")
    t.accepting_speech=true
    t.responses.reset()
    for i in 5:
        t.handle_response("OFFSCRIPT","",true)
    assert(t.responses.offscript_total==5)
    assert(t.frame.id=="A0_Endgame")
    t.parser.start("A1_0_Begin")
    t.accepting_speech=false
    t.handle_response("SELECTION","yes")
    assert(t.responses.last_response_type=="OUT_OF_TURN")
    assert(t.frame.id=="A1_0_Begin")
    print("PASS ",count," W12 graph routes, category safety, hierarchy, streak reset and Act1 production hooks")
    game.queue_free()
    await process_frame
    quit()
