extends Control

const Report = preload("res://Script/playtest_report.gd")
@export var show_input_meter := false
var input_level := 0.0
var input_capture: AudioEffectCapture
var restore_input_device_on_exit := true
var report_context := "Gameplay"
var report_passage := ""

func report(action: String, details: Dictionary = {}) -> void:
	details["context"] = report_context
	details["passage"] = report_passage
	Report.record(action, details)

func fail(detail: String, reason: String) -> void:
	status.text = detail
	report("speech_failed", {"reason": reason})
	technical_failure.emit(detail)

signal transcript_ready(words: String)
signal technical_failure(detail: String)
## Local desktop speech recognition used by the main game.
@export_file("*.exe") var engine_path := "res://.local-speech/engine/Release/whisper-cli.exe"
@export_file("*.bin") var model_path := "res://.local-speech/ggml-base.en.bin"
@export_range(5, 120) var maximum_recording_seconds := 30.0
@export_range(10, 300) var transcription_timeout_seconds := 90.0
var recorder: AudioEffectRecord
var microphone: AudioStreamPlayer
var bus_name := "WhisperDebugCapture"
var recording := false
var started := 0
var pid := -1
var output_path := ""
var wav_path := ""
var previous_device := ""
@onready var status: Label = $Layout/Status
@onready var transcript: TextEdit = $Layout/Transcript

func _ready() -> void:
	preload("res://Script/microphone_settings.gd").apply_saved()
	previous_device = AudioServer.input_device
	engine_path = portable_path(engine_path)
	model_path = portable_path(model_path)
	for device in AudioServer.get_input_device_list():
		$Layout/Devices.add_item(device)
		if device == previous_device: $Layout/Devices.select($Layout/Devices.item_count - 1)
	$Layout/Devices.item_selected.connect(func(index: int): AudioServer.input_device = $Layout/Devices.get_item_text(index))
	$Layout/Start.pressed.connect(start_recording)
	$Layout/Finish.pressed.connect(finish_recording)
	$Layout/Fixture.pressed.connect(func(): transcribe(ProjectSettings.globalize_path("res://.local-speech/jfk.wav")))
	bus_name += str(get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(index, recorder)
	if show_input_meter:
		input_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(index, input_capture)
	AudioServer.set_bus_mute(index, true)
	microphone = AudioStreamPlayer.new()
	microphone.stream = AudioStreamMicrophone.new()
	microphone.bus = bus_name
	add_child(microphone)
	set_controls(false)
	status.text = "Ready. Start, speak, then Finish. Audio stays on this computer."

func set_controls(busy: bool) -> void:
	$Layout/Start.disabled = busy
	$Layout/Fixture.disabled = busy
	$Layout/Devices.disabled = busy
	$Layout/Finish.disabled = not recording

func start_recording() -> void:
	if recording or pid > 0: return
	var has_engine := FileAccess.file_exists(engine_path)
	var has_model := FileAccess.file_exists(model_path)
	if not has_engine or not has_model:
		report("speech_dependencies", {"engine_present": has_engine, "model_present": has_model})
		fail("Speech files are missing. Extract the entire Windows playtest ZIP before opening the game.", "missing_runtime")
		return
	recording = true
	if input_capture: input_capture.clear_buffer()
	started = Time.get_ticks_msec()
	microphone.play()
	recorder.set_recording_active(true)
	report("recording_started")
	transcript.text = ""
	set_controls(true)

func finish_recording() -> void:
	if not recording: return
	recorder.set_recording_active(false)
	microphone.stop()
	recording = false
	input_level = 0.0
	var audio := recorder.get_recording()
	if audio == null or audio.data.is_empty():
		fail("No audio captured. Check your microphone permissions and selected device.", "no_audio_frames")
		set_controls(false)
		return
	report("recording_finished", {"duration_ms": Time.get_ticks_msec() - started, "audio_bytes": audio.data.size()})
	# whisper.cpp resamples supported WAV sample rates internally.
	wav_path = ProjectSettings.globalize_path("user://whisper_attempt_%s.wav" % Time.get_ticks_usec())
	if audio.save_to_wav(wav_path) != OK:
		fail("Could not save temporary recording.", "audio_write_failed")
		set_controls(false)
		return
	transcribe(wav_path)

func transcribe(path: String) -> void:
	if pid > 0 or recording: return
	transcript.text = ""
	if not FileAccess.file_exists(path):
		fail("Recording file missing. No transcription started.", "audio_file_missing")
		cleanup()
		return
	output_path = ProjectSettings.globalize_path("user://whisper_result_%s" % Time.get_ticks_usec())
	pid = OS.create_process(ProjectSettings.globalize_path(engine_path), PackedStringArray([
		"-m", ProjectSettings.globalize_path(model_path), "-f", path,
		"-l", "en", "-otxt", "-of", output_path, "-np", "-nt", "-ng"
	]), false)
	started = Time.get_ticks_msec()
	status.text = "Transcribing locally..."
	set_controls(true)
	if pid > 0: report("recognition_started")
	if pid <= 0:
		fail("Speech recognition could not start. Copy a playtest report from Settings.", "engine_launch_failed")
		cleanup()

func _process(_delta: float) -> void:
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	if recording:
		if input_capture:
			var frames := input_capture.get_frames_available()
			if frames > 0:
				var peak := 0.0
				for sample in input_capture.get_buffer(frames):
					peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
				input_level = clampf((linear_to_db(maxf(peak, 0.00001)) + 60.0) / 60.0, 0, 1)
		status.text = "Recording %.1f seconds. Click Finish when done." % seconds
		if seconds >= maximum_recording_seconds: finish_recording()
	elif pid > 0:
		if not OS.is_process_running(pid):
			if FileAccess.file_exists(output_path + ".txt"):
				transcript.text = FileAccess.get_file_as_string(output_path + ".txt").strip_edges()
				status.text = "Result in %.2f seconds after Finish. Compare the words below with what you said." % seconds
			else:
				fail("Speech recognition exited without a result. Copy a playtest report from Settings.", "engine_no_result")
			pid = -1
			cleanup()
			if status.text.begins_with("Result"):
				report("recognition_finished", {"has_words": not transcript.text.is_empty(), "duration_ms": roundi(seconds * 1000)})
				transcript_ready.emit(transcript.text)
		elif seconds > transcription_timeout_seconds:
			OS.kill(pid)
			pid = -1
			fail("Transcription timed out. Try a shorter recording.", "recognition_timeout")
			cleanup()

func cleanup() -> void:
	for path in [wav_path, output_path + ".txt"]:
		if not path.is_empty() and FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	wav_path = ""
	set_controls(false)

func _exit_tree() -> void:
	if pid > 0: OS.kill(pid)
	if recorder: recorder.set_recording_active(false)
	if microphone: microphone.stop()
	if restore_input_device_on_exit:
		AudioServer.input_device = previous_device
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0: AudioServer.remove_bus(index)
	for path in [wav_path, output_path + ".txt"]:
		if not path.is_empty() and FileAccess.file_exists(path): DirAccess.remove_absolute(path)



func portable_path(path: String) -> String:
	if FileAccess.file_exists(path):return ProjectSettings.globalize_path(path)
	var relative=path.replace("res://", "")
	if ".local-speech/" in relative:relative=".local-speech/"+relative.get_slice(".local-speech/",1)
	return OS.get_executable_path().get_base_dir().path_join(relative)
func cancel_recording() -> void:
	if pid>0:OS.kill(pid)
	pid=-1
	recording=false
	input_level=0.0
	recorder.set_recording_active(false)
	microphone.stop()
	cleanup()
