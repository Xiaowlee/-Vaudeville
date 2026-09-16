extends Node
## Local amplitude detector; no transcription, recording, or network transmission.
signal level_changed(db: float)
signal progress_changed(fraction: float)
signal sustained_speech
signal calibration_finished(success: bool, message: String)
@export_range(-70.0, -10.0, 1.0) var threshold_db: float = -38.0
@export_range(0.2, 5.0, 0.1) var required_seconds: float = 1.2
@export_range(0.0, 1.0, 0.01) var silence_grace: float = 0.25
@export_range(0.5, 5.0) var calibration_seconds: float = 2.0
@export_range(3.0, 24.0) var noise_margin_db: float = 10.0
var armed := false
var voiced_seconds := 0.0
var quiet_seconds := 0.0
var current_db := -90.0
var capture: AudioEffectCapture
var player: AudioStreamPlayer
var bus_name: StringName
var calibrating := false
var calibration_elapsed := 0.0
var calibration_levels: Array[float] = []
var no_audio_seconds := 0.0

func start_input(device: String = "Default") -> void:
    AudioServer.input_device = device
    if player == null:
        bus_name = StringName("PrototypeMic_%s" % get_instance_id())
        AudioServer.add_bus()
        var index := AudioServer.bus_count - 1
        AudioServer.set_bus_name(index, bus_name)
        capture = AudioEffectCapture.new()
        capture.buffer_length = 0.5
        AudioServer.add_bus_effect(index, capture)
        # Capture runs before the bus is muted: never play the mic through speakers.
        AudioServer.set_bus_mute(index, true)
        player = AudioStreamPlayer.new()
        player.stream = AudioStreamMicrophone.new()
        player.bus = bus_name
        add_child(player)
    player.play()
    capture.clear_buffer()

func calibrate(device: String = "Default") -> void:
    set_armed(false)
    start_input(device)
    calibrating = true
    calibration_elapsed = 0.0
    calibration_levels.clear()
    no_audio_seconds = 0.0

func set_armed(value: bool) -> void:
    armed = value
    voiced_seconds = 0.0
    quiet_seconds = 0.0
    if capture != null:
        capture.clear_buffer()
    progress_changed.emit(0.0)

func _process(delta: float) -> void:
    if capture == null:
        return
    var available := capture.get_frames_available()
    var measured := -90.0
    var has_audio_signal := false
    if available > 0:
        var frames := capture.get_buffer(available)
        var sum_squared := 0.0
        for frame in frames:
            sum_squared += (frame.x * frame.x + frame.y * frame.y) * 0.5
        if not frames.is_empty():
            measured = maxf(-90.0, linear_to_db(sqrt(sum_squared / frames.size())))
            has_audio_signal = measured > -85.0
        # Use captured time, not rendering time, to measure vocal duration.
        consume_level(measured, minf(float(available) / AudioServer.get_mix_rate(), 0.1))
    else:
        consume_level(-90.0, delta)
    if calibrating:
        calibration_elapsed += delta
        if has_audio_signal:
            calibration_levels.append(measured)
        if calibration_elapsed >= calibration_seconds:
            calibrating = false
            if calibration_levels.is_empty():
                calibration_finished.emit(false, "No microphone signal. Check your input device and Windows microphone permission, then retry.")
            else:
                calibration_levels.sort()
                var floor_db: float = calibration_levels[floori(calibration_levels.size() / 2.0)]
                threshold_db = clampf(floor_db + noise_margin_db, -60.0, -15.0)
                calibration_finished.emit(true, "Now say a few words to test your microphone.")

func consume_level(db: float, seconds: float) -> void:
    current_db = db
    level_changed.emit(db)
    if not armed:
        return
    if db >= threshold_db:
        voiced_seconds += seconds
        quiet_seconds = 0.0
    else:
        quiet_seconds += seconds
        if quiet_seconds > silence_grace:
            voiced_seconds = 0.0
    progress_changed.emit(clampf(voiced_seconds / required_seconds, 0.0, 1.0))
    if voiced_seconds >= required_seconds:
        armed = false
        sustained_speech.emit()

func _exit_tree() -> void:
    if player != null:
        player.stop()
    if bus_name != &"":
        var index := AudioServer.get_bus_index(bus_name)
        if index >= 0:
            AudioServer.remove_bus(index)

