class_name BeatAudioCue
extends Resource
## Keep leaves the current sound untouched. Start replaces only this channel.
@export_enum("Ambience", "Music", "Weather", "Movement", "OneShot") var channel: int = 2
@export_enum("Keep", "Start", "Stop", "Change") var action: int = 0
@export var stream: AudioStream
@export_range(-60, 6, 1) var volume_db := -18.0
@export_range(0, 5, 0.1) var fade_seconds := 0.5

## Negative uses the legacy Fade Seconds value.
@export_range(-1, 10, 0.1) var fade_in_seconds := -1.0
@export_range(-1, 10, 0.1) var fade_out_seconds := -1.0
