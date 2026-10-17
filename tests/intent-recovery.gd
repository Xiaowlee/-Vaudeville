extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	print(("PASS " if value else "FAIL ") + name)
	if not value: failures += 1
func run() -> void:
	var panel = load("res://Scene/Debug/local_intent_test.tscn").instantiate()
	panel.start_local_service = false
	root.add_child(panel)
	panel.last_intent = "ready"
	panel.get_node("Layout/Words").text = ""
	panel.classify()
	check(panel.last_intent.is_empty() and not panel.busy, "empty transcript clears stale result")
	panel.get_node("Layout/Words").text = "Yes"
	panel.classify()
	panel.cancel_attempt()
	check(panel.last_intent == "cancelled" and not panel.busy, "cancel releases input")
	panel.completed(0,200,PackedStringArray(),'{"message":{"content":"{\"intent\":\"ready\"}"}}'.to_utf8_buffer())
	check(panel.last_intent == "cancelled", "late completion ignored after cancel")
	panel.local_model = "missing-local-test-model"
	panel.classify()
	while panel.busy: await process_frame
	check(panel.last_intent == "error", "unavailable model is technical error")
	panel.local_model = "qwen3:4b"
	panel.request.timeout = 0.001
	panel.classify()
	while panel.busy: await process_frame
	check(panel.last_intent == "error" and panel.get_node("Layout/Words").editable, "timeout releases input")
	panel.request.timeout = 60
	panel.classify()
	while panel.busy: await process_frame
	check(panel.last_intent == "ready", "retry succeeds after failure")
	panel.export_records("res://.task-checks/recovery-export.json")
	var saved = JSON.parse_string(FileAccess.get_file_as_string("res://.task-checks/recovery-export.json"))
	check(saved.records.size() >= 4 and saved.records[0].has("situation"), "export contains snapshots and failures")
	panel.classify()
	panel.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("PASS leaving scene during request did not crash")
	var act = load("res://Scene/Debug/act1_context_test.tscn").instantiate()
	root.add_child(act)
	for index in [0,2]:
		act.select_beat(index)
		act.get_node("Layout/Words").text = "I want to become a writer, just like you."
		act.classify()
		check(act.last_intent == "authored_attempt", "early attempt cannot skip authored failure")
	act.select_beat(4)
	act.get_node("Layout/Words").text = act.selected.expected_line
	act.classify()
	check(act.last_intent == "script_match", "authored cue passes existing matcher")
	act.get_node("Layout/Words").text = "I would rather fly to the moon"
	act.classify()
	check(act.last_intent == "script_mismatch", "unrelated guided answer does not pass")
	quit(0 if failures == 0 else 1)
