extends "res://Script/scene0_interaction_test.gd"

func run() -> void:
	root.size = Vector2i(1152, 800)
	root.content_scale_size = Vector2i(1152, 800)
	for flags in range(8):
		var scene = load("res://Scene/2.0_01_headphones.tscn").instantiate()
		scene.sentence_definition = scene.sentence_definition.duplicate()
		var config = scene.sentence_definition
		config.require_drag = bool(flags & 1)
		config.require_voice = bool(flags & 2)
		config.require_face = bool(flags & 4)
		# Changed content must flow into labels/cards and the recognition grammar.
		config.sentence_text = "She picks up the notebook and puts it down."
		config.correct_word = "notebook"
		config.distractors = PackedStringArray(["book", "phone"])
		scene.next_scene = ""
		scene.face_response_delay = 0.01
		scene.get_node("SpeechMonitor").enabled = false
		scene.get_node("PhoneInputHook").set_process(false)
		root.add_child(scene)
		current_scene = scene
		await process_frame
		await process_frame
		var sentence = scene.sentence
		var card = sentence.get_node(sentence.word_cards[0])
		check(card.text == "notebook" and sentence.suffix.text == "and puts it down.", "Resource updates displayed wording: flags %s" % flags)
		check(config.rejected_phrases()[0] == "she picks up the book and puts it down", "Grammar follows edited content")
		if config.require_face:
			check(scene.interaction_state == "WAITING_FOR_FACE" and not scene.completed, "Face gate is independently configurable")
			sentence.submit_transcript(config.sentence_text)
			check(not scene.completed, "Voice cannot bypass face")
			scene.get_node("PhoneInputHook").report_face_cue(&"smile")
			await create_timer(0.03).timeout
		if config.require_drag:
			check(scene.interaction_state == "WAITING_FOR_DRAG" and not scene.completed, "Drag gate remains after optional face")
			await drag(card, sentence.drop_zone.get_global_rect().get_center())
		if config.require_voice:
			check(scene.interaction_state == "WAITING_FOR_VOICE" and sentence.hint.visible and not scene.completed, "Voice gate is independently configurable")
			sentence.submit_transcript(config.sentence_text)
		check(scene.completed and card.visible, "Only configured inputs complete scene; word stays visible")
		check(not sentence.hint.visible, "No read prompt after completion or when voice disabled")
		# Let one-shot animations finish before disposing their awaiters.
		await create_timer(2.1).timeout
		scene.queue_free()
		await process_frame
	# Layout bounds: test the actual inherited scene at two display widths.
	for width in [1152, 1440]:
		root.size = Vector2i(width, 800)
		var scene = load("res://Scene/2.0_01_headphones.tscn").instantiate()
		scene.get_node("SpeechMonitor").enabled = false
		root.add_child(scene)
		current_scene = scene
		await process_frame
		await process_frame
		var sentence = scene.sentence
		var card = sentence.get_node(sentence.word_cards[0])
		var row: Rect2 = sentence.prefix.get_parent().get_global_rect()
		check(not card.get_global_rect().intersects(row), "Starting headphones card clears sentence at width %s" % width)
		check(row.position.x >= 0 and row.end.x <= root.get_visible_rect().size.x, "Sentence fits viewport")
		check(sentence.drop_zone.get_node("Blank").get_global_rect().end.x <= sentence.suffix.get_global_rect().position.x, "Blank clears suffix")
		await drag(card, sentence.drop_zone.get_global_rect().get_center())
		check(card.get_global_rect().position.x >= sentence.prefix.get_global_rect().end.x and card.get_global_rect().end.x <= sentence.suffix.get_global_rect().position.x, "Inserted word stays between prefix and suffix")
		scene.queue_free()
		await process_frame
	print("DESIGNER_CONFIGURATION_TEST_FAILURES=", failures)
	quit(failures)
