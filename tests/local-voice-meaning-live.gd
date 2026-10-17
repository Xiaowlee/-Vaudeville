extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://Scene/Debug/local_voice_meaning_test.tscn").instantiate()
	root.add_child(scene)
	var audio = scene.get_node("Columns/Whisper")
	var meaning = scene.get_node("Columns/Meaning")
	audio.transcribe(ProjectSettings.globalize_path("res://.task-checks/not-ready.wav"))
	while audio.pid > 0 or meaning.busy: await process_frame
	print("Synthetic spoken fixture transcript: " + audio.transcript.text)
	print("Real interpretation: " + meaning.last_intent)
	var passed: bool = meaning.last_intent == "not_ready"
	print("PASS synthetic voice -> Whisper -> Qwen -> authored wait response" if passed else "FAIL voice-to-meaning integration")
	quit(0 if passed else 1)
