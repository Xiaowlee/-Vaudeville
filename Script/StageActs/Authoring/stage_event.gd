@tool
class_name StageEvent
extends StoryEntry
@export_enum("WAIT", "PLAY_SFX", "PLAY_AMBIENCE", "STOP_AMBIENCE", "PLAY_BGM", "STOP_BGM", "SHOW_ACTOR", "HIDE_ACTOR", "PLAY_ANIMATION", "PHONE_CUE", "CURTAIN_OPEN", "CURTAIN_CLOSE", "STAGE_ACTION", "CURTAIN_TRANSITION") var event_type := 0:
	set(value):
		event_type = value
		notify_property_list_changed()
@export var duration := 0.0
@export var audio: AudioStream
@export var volume_db := -18.0
@export var actor_id := ""
@export var animation: StringName
@export var phone_cue: PhoneCue
@export_multiline var description := ""
@export_group("Advanced")
@export var dialogue: DialogueLineData
@export var presentation: StagePresentationOptions
@export var fade_seconds := 0.5
func to_beat() -> StageBeat:
	var b := dialogue.to_beat() if dialogue != null else StageBeat.new()
	b.delay_after_response = 0
	b.show_npc_dialogue = dialogue != null
	if presentation != null: presentation.apply_to(b)
	b.audio = b.audio.duplicate()
	b.actor_actions = b.actor_actions.duplicate()
	b.sfx_on_start = b.sfx_on_start.duplicate()
	b.beat_id = entry_id
	b.beat_type = StageBeat.BeatType.STAGE_DIRECTION
	b.stage_description = description
	if event_type == 0: b.delay_before_input = duration
	elif event_type == 1: b.sfx_on_start.append(audio); b.sfx_volume_db = volume_db
	elif event_type in [2, 3, 4, 5]:
		var cue := BeatAudioCue.new()
		cue.channel = 0 if event_type in [2, 3] else 1
		cue.action = 2 if event_type in [3, 5] else 1
		cue.stream = audio
		cue.volume_db = volume_db
		cue.fade_seconds = fade_seconds
		b.audio.append(cue)
	elif event_type in [6, 7, 8]:
		var action := StageActorAction.new()
		action.actor_id = actor_id
		action.visibility = 1 if event_type == 6 else (2 if event_type == 7 else 0)
		action.animation = animation
		b.actor_actions.append(action)
	elif event_type == 9: b.send_phone_cue = true; b.phone_cue = phone_cue
	elif event_type == 13: b.beat_type = StageBeat.BeatType.TRANSITION
	b.set_meta("stage_event_type", event_type)
	b.set_meta("curtain_animation", animation)
	return b

func _validate_property(property: Dictionary) -> void:
	var allowed := {"duration":[0], "audio":[1,2,4], "volume_db":[1,2,4], "actor_id":[6,7,8], "animation":[8,10,11], "phone_cue":[9], "description":[12,13], "dialogue":[12,13], "fade_seconds":[2,3,4,5]}
	if allowed.has(property.name) and event_type not in allowed[property.name]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
