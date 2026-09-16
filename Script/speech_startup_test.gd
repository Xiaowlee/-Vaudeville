extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures := 0
	for attempt in range(3):
		for scene_name in ["prototype_1", "scene_1_headphones", "scene_3_bumpedIntoSb"]:
			var scene = load("res://Scene/" + scene_name + ".tscn").instantiate()
			scene.auto_advance = false
			scene.get_node("PhoneInputHook").set_process(false)
			root.add_child(scene)
			current_scene = scene
			await process_frame
			# Bypass face/drag only inside this test; exercise each actual resource's grammar.
			scene.face_complete = true
			scene.sentence.reveal_correct_word()
			scene.sentence.enable_reading()
			var speech = scene.get_node("SpeechMonitor")
			var deadline := Time.get_ticks_msec() + 13000
			while not speech.worker_ready and speech.listening and Time.get_ticks_msec() < deadline:
				await process_frame
			print("MIC_STARTUP attempt=", attempt, " scene=", scene_name, " ready=", speech.worker_ready, " error=", speech.last_error)
			if not speech.worker_ready: failures += 1
			# Check the worker stays alive after initialization rather than accepting a transient status.
			await create_timer(0.5).timeout
			if not speech.listening: failures += 1
			speech.stop_listening()
			scene.queue_free()
			await process_frame
	print("MIC_STARTUP_FAILURES=", failures)
	quit(failures)
