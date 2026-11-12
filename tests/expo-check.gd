extends SceneTree
var failures: Array[String]=[]
const Report=preload("res://Script/playtest_report.gd")
func check(ok: bool, label: String):
    if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
    var game=load("res://Scene/StageActs/stage_graph_game.tscn").instantiate()
    var t=game.get_node("StoryRuntime")
    t.ai_enabled=false;t.log_interpretations=false
    game.get_node("PhoneCueBridge").enabled=false
    root.add_child(game)
    var c=game.get_node("GameController")
    var ui=game.get_node("StageUI")
    var view=game.get_node("DialogueView")
    c.set_process(false);t.set_process(false)
    c.curtain_enabled=false;c.opening=false;view.act_title_enabled=false
    ui.auto_advance=false
    ui.play_dialogue("This sentence must appear before it can advance.",null)
    ui.set_speaker("Stage Manager")
    ui.skip_current_passage()
    check(view.line_revealed() and not ui.manual_advance,"First Space reveals without advancing")
    ui.skip_current_passage()
    check(ui.manual_advance,"Second Space advances")
    t.parser.start("A1_0_Begin");t.waiting=true;t.accepting_speech=true
    t.recording_turn=t.turn;t.review_this_attempt=true
    var history=t.ai_history.size()
    t.mic.transcript_ready.emit("yes")
    check(t.awaiting_review() and t.ai_history.size()==history,"Review does not interpret before confirmation")
    c.transcript_seconds_left=0.1;c._update_transcript(10.0)
    check(c.transcript_seconds_left>0,"Reviewed transcript stays visible")
    var before=t.responses.silence_count
    t._process(99.0)
    check(t.responses.silence_count==before,"Review cannot time out into a silence response")
    t.mic.pid=123456
    t._speak()
    t.mic.pid=-1
    check(not t.awaiting_review(),"Redo clears reviewed words without sending them")
    t.recording_turn=t.turn;t.review_this_attempt=true;t.mic.transcript_ready.emit("yes")
    t.confirm_transcript()
    check(not t.awaiting_review() and str(t.frame.id)=="A1_1_0 PreshowHappy","Confirm submits to existing yes route")
    t.parser.start("A1_0_Begin");t.waiting=true;t.recording_turn=t.turn;t.review_this_attempt=true;t._transcript("no")
    t.parser.start("A2_1_Entrance")
    t.confirm_transcript()
    check(not t.awaiting_review() and str(t.frame.id)=="A2_1_Entrance","Old reviewed words cannot affect another passage")
    c._response_production("TECHNICAL_FAILURE","",0)
    check(c.board_elapsed<0,"Technical failures do not create an unclear board")
    c._response_production("UNCLEAR","",0)
    check(c.reaction_board.visible and c.reaction_board.texture==c.question_board,"Unclear shows supplied question artwork")
    c._update_feedback(0.5)
    var x=c.reaction_board.position.x
    c._update_feedback(0.5)
    check(c.reaction_board.position.x>x,"Board travels left to right")
    c._update_feedback(3.0)
    check(not c.reaction_board.visible,"Board hides at configured duration")
    c._takeover_feedback()
    check(c.reaction_board.texture==c.takeover_board and is_equal_approx(c.board_duration,3.0),"Takeover uses supplied X artwork for three seconds")
    t.mic.recording=true;t.mic.input_level=0.4;c._update_feedback(0.01)
    var mc=game.get_node("World/Performers/Player")
    check(mc.recording_level>0,"Recording volume reaches MC motion")
    t.mic.recording=false;c._update_feedback(0.01)
    check(mc.recording_level==0,"MC input motion stops after recording")
    game.queue_free();await process_frame
    var whisper=load("res://Scene/StageActs/Graph/local_whisper.tscn").instantiate()
    root.add_child(whisper)
    whisper.transcribe(ProjectSettings.globalize_path("res://.local-speech/jfk.wav"))
    var recognition_wait=0.0
    while whisper.pid>0 and recognition_wait<95:
        await create_timer(0.1).timeout;recognition_wait+=0.1
    check("country" in whisper.transcript.text.to_lower(),"Actual Whisper transcribes the bundled audio fixture")
    print("RESULT Whisper fixture seconds=",recognition_wait)
    whisper.queue_free();await process_frame
    Report.folder="user://expo-check-temporary"
    Report.participant="CHECK-01"
    check(Report.begin_session(),"Report folder can be created")
    Report.record("recognition_finished",{"duration_ms":1000})
    Report.record("interpretation_returned",{"duration_ms":2000,"http_status":404,"model":"missing","error":"model not found"})
    var first=Report.session_id
    Report.finish("Test completed")
    check(FileAccess.file_exists(Report.folder.path_join(first+"-summary.txt")),"Report summary saved at completion")
    check("model not found" in Report.summary(),"Summary preserves actual server error")
    Report.begin_session()
    check(Report.session_id!=first and FileAccess.file_exists(Report.folder.path_join(first+".jsonl")),"New session preserves previous report")
    Report.finish("Test completed")
    var dir=DirAccess.open(Report.folder)
    for file in dir.get_files():dir.remove(file)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Report.folder))
    Report.folder="user://playtests";Report.session_id="";Report.events.clear()
    var menu=load("res://Scene/00_main_menu.tscn").instantiate()
    root.add_child(menu)
    check(menu.get_node("Menu/Play").disabled,"Play starts disabled while preparing")
    var elapsed=0.0
    while menu.checking or elapsed<0.1:
        await create_timer(0.1).timeout;elapsed+=0.1
        if elapsed>100:break
    check(menu.preparation_ready,"Actual local model warmup enables Play: "+menu.get_node("Menu/Preparation").text)
    if not DisplayServer.get_name()=="headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("D:/RMIT/Master/Studio 1/Folio 2/2.6 Fix/Debug/expo-preparation.png")
    menu.interpretation_model="missing-expo-check-model"
    menu.check_preparation()
    while menu.checking:await create_timer(0.1).timeout
    check(not menu.preparation_ready and menu.get_node("Menu/Play").disabled and menu.get_node("Menu/Retry").visible,"Missing AI model blocks Play and offers Retry")
    check("AI model missing" in menu.get_node("Menu/Preparation").text,"Missing model has an understandable explanation")
    if not DisplayServer.get_name()=="headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("D:/RMIT/Master/Studio 1/Folio 2/2.6 Fix/Debug/expo-missing-model.png")
    check(menu.get_node("Menu/Retry").get_global_rect().end.y<root.get_visible_rect().size.y,"Recovery button fits in the menu")
    menu.queue_free();await process_frame
    print("RESULT Expo checks failures=",failures)
    quit(0 if failures.is_empty() else 1)
