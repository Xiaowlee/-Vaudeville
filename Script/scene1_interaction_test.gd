extends "res://Script/scene0_interaction_test.gd"

func run() -> void:
	root.size = Vector2i(1152, 800)
	root.content_scale_size = Vector2i(1152, 800)
	var scene = load("res://Scene/scene_1_headphones.tscn").instantiate()
	scene.get_node("SpeechMonitor").enabled = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var story = scene.get_node("Margin/Layout/Story")
	var sentence = story.get_node("Sentence")
	var card = story.get_node("On")
	var room = scene.get_node("Margin/Layout/Room")
	var sprite: AnimatedSprite2D = room.get_node("AnimatedSprite2D")
	var object: AnimatedSprite2D = room.get_node("HeadphoneObject")
	check(scene.get_node("Dark bg").modulate.a == 0.0 and sprite.modulate.a == 1.0, "Scene 1 begins visible and lit")
	check(sprite.animation == &"standby" and sprite.is_playing() and sprite.sprite_frames.get_animation_loop("standby"), "Standby loops before input")
	check(sentence.definition.correct_word == "headphones" and card.text == "headphones", "Headphones target and editable card configured")
	check(story.get_node("Off").text == "book" and story.get_node("Away").text == "phone", "Editable distractors configured")
	check(sentence.get_node("HBoxContainer/PrefixLabel").text + " " + card.text + " " + sentence.get_node("HBoxContainer/SuffixLabel").text == scene.sentence_definition.sentence_text, "Authored sentence agrees with recognition target")
	var target: Vector2 = sentence.drop_zone.get_global_rect().get_center()
	await drag(story.get_node("Off"), target)
	check(sentence.state == sentence.State.INCOMPLETE, "Wrong word leaves sentence incomplete")
	await drag(card, target)
	check(card.locked and sentence.state == sentence.State.READY_TO_READ and sentence.hint.visible, "Snap readies sentence")
	for part in [sentence.get_node("HBoxContainer/PrefixLabel"), sentence.get_node("HBoxContainer/SuffixLabel"), card]:
		check(part.get_theme_constant("outline_size") == 3, "Whole sentence outlined")
	sentence.submit_transcript("She picks up the book and puts it on.")
	check(not scene.completed, "Wrong spoken noun rejected")
	scene.get_node("SpeechMonitor").transcript_received.emit("SHE PICKS UP THE HEADPHONES AND PUTS THEM ON!")
	await create_timer(0.2).timeout
	check(scene.completed and not sentence.hint.visible, "Existing transcript signal completes sentence")
	check(sprite.animation == &"headphones" and sprite.is_playing() and object.is_playing(), "Both supplied action layers play")
	check(not sprite.sprite_frames.get_animation_loop("headphones") and not object.sprite_frames.get_animation_loop("headphones"), "Action layers do not loop")
	check(not story.get_node("Next").visible, "Next waits for action")
	await create_timer(2.1).timeout
	check(sprite.frame == 1 and object.frame == 1 and not sprite.is_playing() and not object.is_playing(), "Final headphone pose held")
	check(scene.response_finished and story.get_node("Next").visible, "Next shown after action")
	check(sentence.get_node("HBoxContainer/PrefixLabel").get_theme_color("font_color") == sentence.completed_color, "Scene completed colour applied")
	check(not scene.auto_timer.is_stopped() and scene.next_scene == "res://Scene/scene_2_key.tscn", "Scene 1 leads to Scene 2 after response")
	# Use a temporary valid destination to exercise the production Next button.
	scene.next_scene = "res://Scene/Intro.tscn"
	story.get_node("Next").disabled = false
	story.get_node("Next").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://Scene/Intro.tscn", "Manual Next loads configured destination")
	# A fresh instance checks the timer starts only after the real headphone animation.
	current_scene.queue_free()
	await process_frame
	scene = load("res://Scene/scene_1_headphones.tscn").instantiate()
	scene.next_scene = "res://Scene/Intro.tscn"
	scene.get_node("SpeechMonitor").enabled = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene._perform_scene(&"scene_1_headphones")
	await create_timer(2.2).timeout
	check(scene.response_finished and not scene.auto_timer.is_stopped(), "Auto-next timer starts after action")
	await create_timer(4.5).timeout
	check(current_scene == scene, "No premature auto-next")
	await create_timer(0.5).timeout
	check(current_scene.scene_file_path == "res://Scene/Intro.tscn", "Auto-next uses five-second delay")
	print("SCENE1_TEST_FAILURES=", failures)
	quit(failures)
