extends SceneTree
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> bool:
	print(("PASS " if value else "FAIL ") + message)
	return value
func run() -> void:
	var scene = load("res://Scene/Debug/context_preshow_test.tscn").instantiate()
	root.add_child(scene)
	var passed := true
	var opening = scene.opening
	opening.ready_for_answer()
	scene.submit("No, not yet.")
	while scene.meaning.busy: await process_frame
	passed = check(scene.pending == "not_ready" and opening.state == "LISTENING", "real model suggests refusal without applying it") and passed
	scene.apply_result()
	passed = check(opening.state == "NO_WAIT", "authored NO response used") and passed
	opening.ready_for_answer()
	scene.submit("Yes, let's begin.")
	while scene.meaning.busy: await process_frame
	passed = check(scene.pending == "ready", "real model suggests agreement") and passed
	scene.apply_result()
	passed = check(opening.state == "ACKNOWLEDGED", "accepted result enters existing curtain flow") and passed
	var deadline := Time.get_ticks_msec() + 20000
	while not scene.completed_test and Time.get_ticks_msec() < deadline: await process_frame
	passed = check(scene.completed_test, "curtain finishes and Act 1 is reached") and passed
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)
