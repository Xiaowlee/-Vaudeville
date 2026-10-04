extends Node
const BROWSER = preload("res://Script/browser_speech.gd")
## Developer-only backend choice. No player-facing engine selector.
@export_enum("Automatic", "Windows", "Browser") var recognition_backend := 0
var using_browser := false
const PACKAGED_HELPER = preload("res://prototype_1/windows_speech_helper.tres")
## Windows-only local phrase recognition, using the installed OS recognizer. No downloads.
signal transcript_received(text: String)
signal partial_transcript_received(text: String)
signal final_transcript_received(text: String)
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
var player_error := ""
const ERROR_MESSAGES = {
	"browser": "Speech unavailable. Check browser microphone permission, then retry.",
	"dictation_unavailable": "Free speech is unavailable on this Windows setup. Please report this to the facilitator.",
	"helper_missing": "Speech files are missing. Please download the updated game.",
	"recognizer_missing": "Install Windows English (United States) speech recognition, then retry.",
	"microphone_unavailable": "Check Windows microphone access and default input, then retry.",
	"speech_unavailable": "Windows speech support could not start. Check your Windows speech setup.",
	"platform": "Voice recognition requires Windows.",
	"powershell_missing": "Windows PowerShell is unavailable. Speech cannot start.",
	"storage": "Speech setup could not be saved. Check your user-folder permissions.",
	"worker": "Speech could not start. Retry microphone; if it persists, share the game log."
}

func start_listening(target_phrase: String, rejected_phrases: PackedStringArray = [], continuous_mode := false, dictation_mode := false) -> void:
	stop_listening()
	last_error = ""
	player_error = ""
	worker_error = ""
	if enabled and (recognition_backend == 2 or (recognition_backend == 0 and OS.has_feature("web"))):
		if not OS.has_feature("web"):
			_fail("Browser speech requires the web export", "browser")
			return
		using_browser = true
		listening = true
		worker_ready = false
		startup_time = 0.0
		var error := BROWSER.start()
		if not error.is_empty(): _fail(error, "browser")
		else: status_changed.emit("Mic starting…")
		return
	if not enabled or OS.get_name() != "Windows":
		_fail("SpeechMonitor is disabled" if not enabled else "Speech recognition requires Windows", "platform" if OS.get_name() != "Windows" else "worker")
		return
	# A direct resource dependency survives exports even with an empty include filter.
	var helper_text: String = PACKAGED_HELPER.get_meta("source", "")
	if helper_text.strip_edges().is_empty():
		_fail("Packaged speech helper is empty or unreadable", "helper_missing")
		return
	result_path = "user://speech_%s_%s.jsonl" % [OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot create speech event file: " + str(FileAccess.get_open_error()), "storage")
		return
	file.close()
	# Copy packaged script to user data so this also works after export.
	var helper := "user://windows_speech.ps1"
	var helper_file := FileAccess.open(helper, FileAccess.WRITE)
	if helper_file == null:
		_fail("Cannot prepare speech helper: " + str(FileAccess.get_open_error()), "storage")
		return
	helper_file.store_string(helper_text)
	helper_file.close()
	var powershell := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	if not FileAccess.file_exists(powershell):
		_fail("Windows PowerShell executable not found", "powershell_missing")
		return
	var arguments := PackedStringArray(["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ProjectSettings.globalize_path(helper), "-OutputPath", ProjectSettings.globalize_path(result_path), "-GameProcessId", str(OS.get_process_id())])
	# Dictation/any-speech has no target. Windows drops empty string arguments.
	if not target_phrase.is_empty():
		arguments.append_array(PackedStringArray(["-TargetPhrase", target_phrase]))
	# Windows drops a trailing empty argument. Omit this optional parameter entirely.
	if not rejected_phrases.is_empty():
		arguments.append_array(PackedStringArray(["-RejectPhrases", "|".join(rejected_phrases)]))
	if continuous_mode: arguments.append("-Continuous")
	if dictation_mode: arguments.append("-Dictation")
	worker_io = OS.execute_with_pipe(powershell, arguments, false)
	worker_pid = worker_io.get("pid", -1)
	listening = worker_pid > 0
	startup_time = 0.0
	worker_ready = false
	if listening: status_changed.emit("Mic starting…")
	else: _fail("Windows could not launch the speech worker")

func _process(delta: float) -> void:
	if not listening: return
	if using_browser:
		for event in BROWSER.events():
			if not listening: return
			match event.get("kind", ""):
				"ready":
					worker_ready = true
					status_changed.emit("Mic listening")
				"partial": partial_transcript_received.emit(str(event.text))
				"final":
					final_transcript_received.emit(str(event.text))
					transcript_received.emit(str(event.text))
				"error", "ended":
					_fail(str(event.get("text", "Browser listening ended; retry microphone")), "browser")
		return
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
		if event.get("kind") == "partial": partial_transcript_received.emit(str(event.get("text", "")))
		elif event.get("kind") in ["final", "rejected"]: final_transcript_received.emit(str(event.get("text", "")))
		if event.get("kind") == "final" and float(event.get("confidence", 0.0)) >= minimum_confidence:
			transcript_received.emit(str(event.text))
			if not listening: return
		elif event.get("kind") in ["final", "rejected"]:
			recognition_rejected.emit(str(event.get("text", "")))
		elif event.get("status") == "listening":
			worker_ready = true
			status_changed.emit("Mic listening")
		elif event.get("status") in ["unavailable", "stopped"]:
			_fail(str(event.get("detail", "Speech worker stopped")), str(event.get("code", "worker")))
			return
	if not worker_ready and startup_time > 12.0:
		_fail("Speech worker did not become ready within 12 seconds")
	elif not OS.is_process_running(worker_pid):
		_read_worker_output()
		_fail(worker_error.strip_edges() if not worker_error.is_empty() else "Speech worker exited without a diagnostic")

func stop_listening() -> void:
	if using_browser: BROWSER.stop()
	using_browser = false
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

func _fail(reason: String, code := "worker") -> void:
	last_error = reason
	player_error = ERROR_MESSAGES.get(code, ERROR_MESSAGES.worker)
	push_warning("[Speech error] " + reason)
	stop_listening()
	status_changed.emit(player_error)
