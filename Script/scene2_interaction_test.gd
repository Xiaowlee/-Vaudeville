extends "res://Script/scene0_interaction_test.gd"

func run() -> void:
	root.size = Vector2i(1152, 800)
	var scene = load("res://Scene/scene_2_key.tscn").instantiate()
	scene.get_node("SpeechMonitor").enabled = false
	var hook = scene.get_node("PhoneInputHook")
	hook.relay_url = "wss://127.0.0.1:18787"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var story = scene.get_node("Margin/Layout/Story")
	var sentence = story.get_node("Sentence")
	var sprite = scene.get_node("Margin/Layout/Room/AnimatedSprite2D")
	check(not sentence.hint.visible and not story.get_node("On").visible, "Face phase hides read prompt and draggable choices")
	sentence.submit_transcript(scene.sentence_definition.sentence_text)
	scene.debug_accept()
	check(not scene.completed and not scene.face_complete, "Early transcript and manual voice fallback cannot bypass face")
	hook.receive({"kind":"face_cue", "requestId":"old", "cue":"smile", "met":true})
	check(not scene.face_complete, "Stale face result ignored")
	var deadline := Time.get_ticks_msec() + 10000
	while not scene.face_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(scene.face_complete and hook.connected, "Synthetic phone success crosses real secure relay to Godot")
	check(story.get_node("On").visible and story.get_node("On").locked and not sentence.hint.visible, "Laptop reveals key before read prompt")
	check(sprite.animation == &"standby" and not scene.completed, "Face alone does not open door")
	await create_timer(0.7).timeout
	check(sentence.state == sentence.State.READY_TO_READ and sentence.hint.visible, "Narration unlocks after response pause")
	sentence.submit_transcript("She picks the book and opens the door.")
	check(not scene.completed, "Wrong noun rejected")
	sentence.submit_transcript(scene.sentence_definition.sentence_text)
	check(scene.completed and sprite.animation == &"door_open", "Voice after face starts door response")
	hook.receive({"kind":"face_cue", "requestId":hook.request_id, "cue":"smile", "met":true})
	check(not sentence.hint.visible, "Duplicate face cannot reopen narration")
	await create_timer(2.2).timeout
	check(scene.response_finished and sprite.frame == 1 and not sprite.is_playing(), "Door plays once and holds final frame")
	check(story.get_node("Next").visible and story.get_node("Next").disabled and scene.auto_timer.is_stopped(), "Resolution stops without inventing Scene 3")
	print("SCENE2_TEST_FAILURES=", failures)
	quit(failures)
