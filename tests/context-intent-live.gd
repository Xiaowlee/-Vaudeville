extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://Scene/Debug/local_intent_test.tscn").instantiate()
	scene.start_local_service = false
	root.add_child(scene)
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/context-intent-cases.json"))
	var results: Array = []
	var failures := 0
	for sample in cases:
		scene.situation = sample.situation
		scene.recent_dialogue = sample.dialogue
		scene.relevant_history = sample.history
		scene.interpretation_guidance = ""
		scene.interaction_rule = sample.get("rule", 0)
		scene.expected_line = sample.get("line", "")
		scene.options.clear()
		for item in sample.options:
			var option = load("res://Script/SpeechTest/intent_option.gd").new()
			option.id = item.id
			option.meaning = item.meaning
			scene.options.append(option)
		scene.get_node("Layout/Words").text = sample.words
		scene.classify()
		while scene.busy: await process_frame
		var passed: bool = scene.last_intent == sample.expected
		if not passed: failures += 1
		results.append({"case":sample.name,"words":sample.words,"expected":sample.expected,"actual":scene.last_intent,"seconds":scene.last_seconds,"passed":passed})
		print(JSON.stringify(results.back()))
	var file := FileAccess.open("res://.task-checks/context-intent-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	quit(0 if failures == 0 else 1)
