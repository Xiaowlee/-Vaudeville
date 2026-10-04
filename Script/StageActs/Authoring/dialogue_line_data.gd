@tool
class_name DialogueLineData
extends StoryEntry
@export var speaker := "":
	set(value):
		speaker = value
		update_name()
@export_multiline var text := "":
	set(value):
		text = value
		update_name()
@export var voice_audio: AudioStream
## Zero uses the existing stage text hold.
@export_range(0, 60, 0.1) var wait_after := 0.0
@export_group("Advanced")
@export_enum("Character", "Narrator") var delivery := 0
@export var actor_id := ""
@export var presentation: StagePresentationOptions
@export_enum("WAIT_FOR_AUDIO", "STOP_ON_LINE_END") var voice_end_mode := 0
func to_beat() -> StageBeat:
	var b := StageBeat.new()
	b.delay_after_response = 0
	if presentation != null: presentation.apply_to(b)
	b.beat_id = entry_id
	b.beat_type = StageBeat.BeatType.NARRATION if delivery == 1 else StageBeat.BeatType.NPC_DIALOGUE
	b.speaker_name = speaker
	b.actor_id = actor_id
	if delivery == 1: b.narration_text = text
	else: b.npc_dialogue = text
	b.npc_voice = voice_audio
	b.presentation_seconds = wait_after
	b.set_meta("voice_end_mode", voice_end_mode)
	return b

func update_name() -> void:
	resource_name = ((speaker + ": ") if not speaker.is_empty() else "") + text.replace("\n", " ").left(60)
