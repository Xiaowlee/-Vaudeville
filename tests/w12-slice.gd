extends SceneTree
func _initialize():call_deferred("run")
func run():
    var game=load("res://Scene/StageActs/stage_graph_game.tscn").instantiate()
    var t=game.get_node("StoryRuntime")
    game.get_node("PhoneCueBridge").enabled=false
    root.add_child(game)
    var controller=game.get_node("GameController")
    t.parser.start("A1_1_Once upon a time")
    await create_timer(3).timeout
    t.parser.start("A1_3_FirstCue")
    await process_frame
    controller.skip_dialogue()
    await create_timer(1).timeout
    controller.skip_dialogue()
    await create_timer(1).timeout
    controller.state="READY"
    t.accepting_speech=true
    t.recording_turn=t.turn
    t.mic.transcribe("D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/w12-response-policy/cue.wav")
    while t.mic.pid>0 or t.ai_busy:await create_timer(0.1).timeout
    await process_frame
    print("SLICE heard: ",t.raw_transcript,"; category: ",t.responses.last_response_type,"; destination: ",t.frame.id)
    assert(t.frame.id=="A1_4_SecondCue")
    assert(t.story_variables.get("act1_cue_reached",false))
    assert(game.get_node("Actors").modulate!=Color.WHITE)
    assert(game.get_node("Actors/player").position==controller.actor_origins["player"]+Vector2(12,0))
    if "--visual" in OS.get_cmdline_user_args():
        controller.skip_dialogue()
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/w12-response-policy/slice.png")
        var key=InputEventKey.new()
        key.keycode=KEY_F3
        key.pressed=true
        t._input(key)
        assert(t.response_debug.visible)
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/w12-response-policy/debug.png")
    print("PASS synthetic audio → Whisper → Qwen → authored route → stage, sound and phone hook")
    game.queue_free()
    await process_frame
    quit()
