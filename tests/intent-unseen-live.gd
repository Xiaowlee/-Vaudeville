extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://Scene/Debug/local_intent_test.tscn").instantiate()
	scene.start_local_service = false
	root.add_child(scene)
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/intent-unseen-cases.json"))
	var results: Array = []
	var failures := 0
	for sample in cases:
		scene.get_node("Layout/Words").text = sample.words
		scene.classify()
		while scene.busy: await process_frame
		var passed: bool = scene.last_intent == sample.expected
		if not passed: failures += 1
		results.append({"words":sample.words,"expected":sample.expected,"actual":scene.last_intent,"seconds":scene.last_seconds,"passed":passed})
		print(JSON.stringify(results.back()))
	var file := FileAccess.open("res://.task-checks/intent-unseen-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	print("Real local model: %s/%s cases passed" % [cases.size()-failures,cases.size()])
	quit(0 if failures == 0 else 1)
