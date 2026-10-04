class_name StagePresentationOptions
extends Resource
@export_group("Notes")
@export_multiline var stage_description := ""
@export_multiline var notes := ""
@export_group("Display")
@export var hide_subtitle_after_voice := false
@export var show_npc_dialogue := true
@export_group("Stage actions")
@export var actor_actions: Array[StageActorAction] = []
@export_storage var audio: Array[BeatAudioCue] = []
@export_group("Background sound")
@export var ambience: Array[BeatAudioCue] = []
@export var music: Array[BeatAudioCue] = []
@export var weather: Array[BeatAudioCue] = []
@export var movement: Array[BeatAudioCue] = []
@export var one_shot: Array[BeatAudioCue] = []
@export_group("Timing")
@export_range(0, 120, 0.1) var delay_before_input := 0.0
@export_range(0, 120, 0.1) var delay_after_response := 2.0
@export_group("Typewriter")
@export var typing_override: StageTypingSettings
@export_group("Voice")
@export_range(-60, 6, 1) var voice_volume_db := 0.0
@export_range(0, 20, 0.05) var voice_delay := 0.0
@export_group("Sound effects")
@export var sfx_on_start: Array[AudioStream] = []
@export var sfx_on_cue: Array[AudioStream] = []
@export var sfx_after_player: Array[AudioStream] = []
@export var sfx_on_transition: Array[AudioStream] = []
@export_range(-60, 6, 1) var sfx_volume_db := -18.0

@export_group("Phone cue during dialogue")
@export var send_phone_cue := false
@export var phone_cue: PhoneCue

func apply_to(beat: StageBeat) -> void:
	StoryEntry.copy_fields(self, beat)
	beat.audio = audio.duplicate()
	var channels := [ambience, music, weather, movement, one_shot]
	for i in channels.size():
		for source in channels[i]:
			if source == null: continue
			var cue: BeatAudioCue = source.duplicate()
			cue.channel = i
			beat.audio.append(cue)
