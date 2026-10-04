class_name PerformerResponse
extends "res://Script/narration_option.gd"
## Exact string key/value assignments; retained for the current playthrough.
@export var state_changes: Dictionary[String, String] = {}
@export var response_visual: Texture2D
@export var audio_cues: Array[BeatAudioCue] = []
