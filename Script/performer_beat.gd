class_name PerformerStoryBeat
extends Resource
## One editable reading beat. Blank lines may divide it further with the same visual.
@export_multiline var text := ""
@export var visual: Texture2D

## Add Element > New BeatAudioCue. Empty list keeps all current sounds.
@export var audio_cues: Array[BeatAudioCue] = []

@export var beat_id := ""
@export_enum("Narration", "Game response", "Ending") var kind := 0
@export var interaction: PerformerInteraction
## All entries must match; missing keys do not match. Empty means unconditional.
@export var required_state: Dictionary[String, String] = {}
## Empty follows list order. A branch's last beat can reconnect using this ID.
@export var next_beat_id := ""
@export_range(0, 30, 0.1) var automatic_pause := 1.5

@export var source_passage := ""
## Stops this provisional route after this beat; uncheck when extending it.
@export var provisional_route_endpoint := false
@export_multiline var author_notes := ""

@export var actor: ActorDefinition
@export var phone_cue: PhoneCue
