extends Control
signal transcript_ready(words: String)
## Isolated desktop experiment. Never changes the active story/backend.
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
	previous_device = AudioServer.input_device
	for device in AudioServer.get_input_device_list():
		$Layout/Devices.add_item(device)
		if device == previous_device: $Layout/Devices.select($Layout/Devices.item_count - 1)
	$Layout/Devices.item_selected.connect(func(index: int): AudioServer.input_device = $Layout/Devices.get_item_text(index))
	$Layout/Start.pressed.connect(start_recording)
	$Layout/Finish.pressed.connect(finish_recording)
	$Layout/Fixture.pressed.connect(func(): transcribe(ProjectSettings.globalize_path("res://.local-speech/jfk.wav")))
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(index, recorder)
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
	if not FileAccess.file_exists(engine_path) or not FileAccess.file_exists(model_path):
		status.text = "Engine or model missing. Check this scene's Inspector paths."
		return
	recording = true
	started = Time.get_ticks_msec()
	microphone.play()
	recorder.set_recording_active(true)
	transcript.text = ""
	set_controls(true)

func finish_recording() -> void:
	if not recording: return
	recorder.set_recording_active(false)
	microphone.stop()
	recording = false
	var audio := recorder.get_recording()
	if audio == null or audio.data.is_empty():
		status.text = "No audio captured. Check Windows microphone permission and selected device."
		set_controls(false)
		return
	# whisper.cpp resamples supported WAV sample rates internally.
	wav_path = ProjectSettings.globalize_path("user://whisper_attempt_%s.wav" % Time.get_ticks_usec())
	if audio.save_to_wav(wav_path) != OK:
		status.text = "Could not save temporary recording."
		set_controls(false)
		return
	transcribe(wav_path)

func transcribe(path: String) -> void:
	if pid > 0 or recording: return
	transcript.text = ""
	if not FileAccess.file_exists(path):
		status.text = "Recording file missing. No transcription started."
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
	if pid <= 0:
		status.text = "Could not start Whisper. Check engine path in Inspector."
		cleanup()

func _process(_delta: float) -> void:
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	if recording:
		status.text = "Recording %.1f seconds. Click Finish when done." % seconds
		if seconds >= maximum_recording_seconds: finish_recording()
	elif pid > 0:
		if not OS.is_process_running(pid):
			if FileAccess.file_exists(output_path + ".txt"):
				transcript.text = FileAccess.get_file_as_string(output_path + ".txt").strip_edges()
				status.text = "Result in %.2f seconds after Finish. Compare the words below with what you said." % seconds
			else:
				status.text = "Whisper ended without a result. Check Godot Output and model/engine paths."
			pid = -1
			cleanup()
			if not transcript.text.is_empty(): transcript_ready.emit(transcript.text)
		elif seconds > transcription_timeout_seconds:
			OS.kill(pid)
			pid = -1
			status.text = "Transcription timed out. Try a shorter recording."
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
	AudioServer.input_device = previous_device
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0: AudioServer.remove_bus(index)
	for path in [wav_path, output_path + ".txt"]:
		if not path.is_empty() and FileAccess.file_exists(path): DirAccess.remove_absolute(path)
