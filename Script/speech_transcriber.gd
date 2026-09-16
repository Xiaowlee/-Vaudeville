extends Node
## Windows-only local phrase recognition, using the installed OS recognizer. No downloads.
signal transcript_received(text: String)
signal recognition_rejected(text: String)
signal status_changed(message: String)
@export var enabled := true
@export_range(0.0, 1.0) var minimum_confidence := 0.60
var worker_pid := -1
var listening := false
var result_path := ""
var read_offset := 0
var poll_time := 0.0
var startup_time := 0.0
var worker_ready := false
var worker_io: Dictionary = {}
var worker_error := ""
var last_error := ""

func start_listening(target_phrase: String, rejected_phrases: PackedStringArray = [], continuous_mode := false) -> void:
	stop_listening()
	last_error = ""
	worker_error = ""
	if not enabled or OS.get_name() != "Windows":
		_fail("SpeechMonitor is disabled" if not enabled else "Speech recognition requires Windows")
		return
	result_path = "user://speech_%s_%s.jsonl" % [OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot create speech event file: " + str(FileAccess.get_open_error()))
		return
	file.close()
	# Copy packaged script to user data so this also works after export.
	var helper := "user://windows_speech.ps1"
	var helper_file := FileAccess.open(helper, FileAccess.WRITE)
	if helper_file == null:
		_fail("Cannot prepare speech helper: " + str(FileAccess.get_open_error()))
		return
	helper_file.store_string(FileAccess.get_file_as_string("res://prototype_1/windows_speech.ps1"))
	helper_file.close()
	var powershell := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	var arguments := PackedStringArray(["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ProjectSettings.globalize_path(helper), "-OutputPath", ProjectSettings.globalize_path(result_path), "-GameProcessId", str(OS.get_process_id()), "-TargetPhrase", target_phrase])
	# Windows drops a trailing empty argument. Omit this optional parameter entirely.
	if not rejected_phrases.is_empty():
		arguments.append_array(PackedStringArray(["-RejectPhrases", "|".join(rejected_phrases)]))
	if continuous_mode: arguments.append("-Continuous")
	worker_io = OS.execute_with_pipe(powershell, arguments, false)
	worker_pid = worker_io.get("pid", -1)
	listening = worker_pid > 0
	startup_time = 0.0
	worker_ready = false
	if listening: status_changed.emit("Mic starting…")
	else: _fail("Windows could not launch the speech worker")

func _process(delta: float) -> void:
	if not listening: return
	startup_time += delta
	poll_time += delta
	if poll_time < 0.2: return
	poll_time = 0.0
	_read_worker_output()
	var events: Array[Dictionary] = []
	var file := FileAccess.open(result_path, FileAccess.READ)
	if file != null:
		file.seek(read_offset)
		while file.get_position() < file.get_length():
			var line_start := file.get_position()
			var line := file.get_line()
			var event = JSON.parse_string(line)
			if not event is Dictionary:
				file.seek(line_start)
				break
			read_offset = file.get_position()
			events.append(event)
		file.close()
	for event in events:
		print("[Speech bridge] ", event)
		if event.get("kind") == "final" and float(event.get("confidence", 0.0)) >= minimum_confidence:
			transcript_received.emit(str(event.text))
			if not listening: return
		elif event.get("kind") in ["final", "rejected"]:
			recognition_rejected.emit(str(event.get("text", "")))
		elif event.get("status") == "listening":
			worker_ready = true
			status_changed.emit("Mic listening")
		elif event.get("status") in ["unavailable", "stopped"]:
			_fail(str(event.get("detail", "Speech worker stopped")))
			return
	if not worker_ready and startup_time > 12.0:
		_fail("Speech worker did not become ready within 12 seconds")
	elif not OS.is_process_running(worker_pid):
		_read_worker_output()
		_fail(worker_error.strip_edges() if not worker_error.is_empty() else "Speech worker exited without a diagnostic")

func stop_listening() -> void:
	listening = false
	if worker_pid > 0 and OS.is_process_running(worker_pid):
		OS.kill(worker_pid)
	worker_pid = -1
	for pipe_name in ["stdio", "stderr"]:
		if worker_io.has(pipe_name): worker_io[pipe_name].close()
	worker_io.clear()
	read_offset = 0
	if not result_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(result_path))
	result_path = ""

func _exit_tree() -> void:
	stop_listening()

func _read_worker_output() -> void:
	# Non-blocking pipes expose startup/parameter errors that occur before JSON logging.
	for pipe_name in ["stderr", "stdio"]:
		if not worker_io.has(pipe_name): continue
		var output: String = worker_io[pipe_name].get_buffer(65536).get_string_from_utf8()
		if output.is_empty(): continue
		print("[Speech worker ", pipe_name, "] ", output.strip_edges())
		if pipe_name == "stderr": worker_error += output

func _fail(reason: String) -> void:
	last_error = reason
	push_warning("[Speech error] " + reason)
	stop_listening()
	status_changed.emit("Voice unavailable · see Output")
