extends SceneTree
func _initialize():call_deferred("run")
func run():
    var t=load("res://Scene/StageActs/Graph/story_runtime.tscn").instantiate();root.add_child(t)
    var cases=[
        ["A1_1_Mother'sQuestion","I want to become a baby","A1_1_WrongLine"],
        ["A1_1_Mother'sQuestion","I want to eat fish","A1_1_Offtopic"],
        ["A1_0_Begin","I don't know","A1_0_STH"],
        ["A1_0_Begin","uh no","A1_0_No"],
        ["A1_0_Begin","yes let's begin","A1_1_0 PreshowHappy"],
        ["A2_1_Entrance","How about we just escape this place?","A2_1_Entrance"],
        ["A2_1_Entrance","Let's go right","A2_1_Right"],
        ["A2_1_Entrance","The western stairs please","A2_1_Left"],
        ["A2_2_HallCommentAppropriate","No, I think we shouldn't let them begin","A2_2_HallCommentAppropriate"],
        ["A2_2_HallCommentAppropriate","Yes please start the music","A2_3_Agree"],
        ["A2_2_HallCommentAppropriate","I'm not sure","A2_2_HallCommentAppropriate"],
        ["A2_1_Entrance","Neither entrance, I want to leave","A2_1_Entrance"],
        ["A2_2_HallCommentAppropriate","Hold on, the musicians should wait","A2_2_HallCommentAppropriate"],
        ["A1_0_Begin","No actually yes, let's start","A1_1_0 PreshowHappy"]]
    var passed=0
    for c in cases:
        t.off_script_count=0;t.ai_history.clear();t.parser.start(c[0]);t.submit_words(c[1])
        while t.ai_busy:await create_timer(0.1).timeout
        var ok=t.frame.id==c[2]
        if ok:passed+=1
        print("PASS " if ok else "FAIL ",c[1]," -> ",t.frame.id," meaning=",t.last_meaning)
    print("RESULT ",passed,"/",cases.size())
    quit(0 if passed==cases.size() else 1)

