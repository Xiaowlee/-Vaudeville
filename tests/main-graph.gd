extends SceneTree
func _initialize():call_deferred("run")
func run():
    var menu=load("res://Scene/00_main_menu.tscn").instantiate()
    assert(menu.stage_scene=="res://Scene/StageActs/stage_graph_game.tscn")
    menu.free()
    var game=load("res://Scene/StageActs/stage_graph_game.tscn").instantiate()
    var t=game.get_node("StoryRuntime")
    t.ai_enabled=false
    game.get_node("PhoneCueBridge").enabled=false
    root.add_child(game)
    assert(t.frame.id=="Start")
    var m=JSON.parse_string(FileAccess.get_file_as_string("res://Story/StageActs/Graph/acts_0_3_manifest.json"))
    var count=0
    for section in m:
        for i in m[section].links.size():
            t.off_script_count=0
            t.parser.start(section)
            t.waiting=true
            t._choose(i,"check")
            assert(t.frame.id==m[section].links[i][1],section)
            count+=1
    t.ai_enabled=true
    for section in ["A1_1_Offtopic","A1_1_WrongLine","A1_1_Silence"]:
        t.off_script_count=0
        t.parser.start(section)
        t.submit_words("I want to eat pizza.")
        assert(t.frame.id=="A1_2_SecondFailure",section)
        assert(not t.ai_busy)
    t.parser.start("A1_1_Offtopic")
    t.submit_words("")
    assert(t.frame.id=="A1_1_Offtopic")
    t.submit_words("pizza again")
    assert(t.frame.id=="A1_2_SecondFailure")
    t._narrative_retry(true)
    assert(t.frame.id=="A1_3_Offscript")
    t._process(0)
    assert(not t.get_node("Layout/Speak").visible)
    t._continue()
    assert(t.frame.id=="A1_3_FirstCue")
    assert(t.get_node("Layout/Result").text=="")
    print("PASS repeated off-script progression, empty recording stays, interpretation hidden.")
    t.parser.start("A1_0_NoAgain")
    t._process(0)
    assert(not t.waiting and not t.get_node("Layout/Speak").visible)
    t._continue()
    assert(t.frame.id=="A1_0_Forced start")
    t.off_script_count=2
    t.parser.start("A1_2_SecondFailure")
    t._narrative_retry(true)
    assert(t.off_script_count==2)
    t.parser.start("A1_0_Begin")
    t._narrative_retry(false)
    var reply=t.get_node("Layout/Result").text
    t.get_node("Layout/Tools").button_pressed=true
    t.get_node("Layout/Tools").button_pressed=false
    assert(t.get_node("Layout/Result").text==reply)
    print("PASS forced continuation, fallback has no punishment, fallback survives tools toggle.")
    for section in m:
        t.parser.start(section)
        if not t.waiting:continue
        t._narrative_retry(false)
        assert(not t.get_node("Layout/Result").text.is_empty(),section)
        if t.route_kinds.count("next")<=1:
            assert(t.get_node("Layout/StoryChoices").get_child_count()==0,section)
    for c in [["A1_0_Begin","uh no","A1_0_No"],["A2_6_ScriptChange","No!","A2_7_Decline"],["A3_2_FirstQuestion","You know what? No.","A3_2_No"]]:
        t.off_script_count=0
        t.parser.start(c[0])
        t.submit_words(c[1])
        assert(t.frame.id==c[2],c[0])
        assert(not t.ai_busy)
    t.parser.start("A2_2_HallCommentAppropriate")
    t.submit_words("No!")
    assert(t.frame.id=="A2_2_HallCommentAppropriate")
    assert(not t.ai_busy)
    assert(t.get_node("Layout/StoryChoices").get_child_count()==0)
    t.submit_words("Yes.")
    assert(t.frame.id=="A2_3_Agree")
    print("PASS fallback coverage without choice buttons, explicit refusals, spoken progression.")
    t._restart()
    assert(t.frame.id=="Start")
    print("PASS clean project startup, ",count," routes and restart.")
    var stage=game.get_node("GameController")
    stage._process(0)
    assert(game.get_node("Curtain").visible)
    t.parser.start("A1_1_Once upon a time")
    stage._process(0)
    assert(stage.opening)
    assert(game.get_node("Actors").visible)
    stage._opened()
    assert(not game.get_node("Curtain").visible)
    t.parser.start("A2_1_Entrance")
    stage._process(0)
    assert(stage.state=="PRESENTING")
    var before=t.turn
    stage.graph_input()
    assert(not t.mic.recording and t.turn==before)
    stage._publish_cue()
    assert(game.get_node("PhoneCueBridge").pending.has("prompt"))
    t.parser.start("A3_2_FirstQuestion")
    stage._process(0)
    assert(game.get_node("Actors/actor_2").visible)
    assert(not game.get_node("StoryRuntime").visible)
    stage.state="READY"
    t.mic.engine_path="res://missing-test-engine.exe"
    game.get_node("StageUI").get_node("Speak").pressed.emit()
    assert(t.mic.status.text.begins_with("Engine"))
    assert(not t.mic.recording)
    stage._process(0)
    assert("unavailable" in game.get_node("StageUI/Speak").text)
    print("PASS menu destination and single Speak control error recovery.")
    print("PASS main stage: curtains, actors, phone cue, NPC speech lock, hidden rehearsal UI.")
    if "--visual" in OS.get_cmdline_user_args():
        await process_frame
        await process_frame
        game.get_node("StageUI").writer.reveal()
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/main_graph_preview.png")
    quit()
