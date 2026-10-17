extends Control
func _ready() -> void:
	$Columns/Whisper.transcript_ready.connect(func(words: String):
		$Columns/Meaning.get_node("Layout/Words").text = words
		$Columns/Meaning.classify()
	)
func _process(_delta: float) -> void:
	var audio = $Columns/Whisper
	var meaning = $Columns/Meaning
	var audio_busy: bool = audio.recording or audio.pid > 0
	audio.set_controls(audio_busy or meaning.busy)
	meaning.get_node("Layout/Classify").disabled = audio_busy or meaning.busy
	meaning.get_node("Layout/Words").editable = not audio_busy and not meaning.busy
