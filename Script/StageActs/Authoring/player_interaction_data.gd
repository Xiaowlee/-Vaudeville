@tool
class_name PlayerInteractionData
extends StoryEntry
@export var dialogue: DialogueLineData
@export var input_mode: StageBeat.InputMode = StageBeat.InputMode.NONE
@export_multiline var expected_line := ""
@export var expected_intent := ""
@export var accepted_phrases := PackedStringArray()
@export var responses: Array[StageResponse] = []
@export_group("Player hint and transcript")
@export var show_player_transcript := true
@export_multiline var player_thought := ""
@export_multiline var cue_card_text := ""
@export var show_player_thought := false
@export var show_cue_card := false
@export_range(0, 60, 0.1) var cue_delay := 0.0
@export_group("Advanced recognition")
@export_range(0, 20, 1) var retry_count := 2
@export_range(0, 120, 0.5) var timeout := 0.0
@export_range(1, 120, 0.5) var technical_failure_delay := 8.0
@export var allow_debug_bypass := true
@export var accept_uncertain_attempt := false
@export_range(0.2, 1, 0.05) var line_coverage := 0.65
@export_range(0, 1, 0.05) var minimum_confidence := 0.35
@export_group("Responses")
@export_multiline var npc_success_response := ""
@export var success_voice: AudioStream
@export var retry_voice: AudioStream
@export var unclear_voice: AudioStream
@export var timeout_voice: AudioStream
@export_multiline var npc_retry_response := ""
@export_multiline var npc_unclear_response := ""
@export_multiline var npc_timeout_response := ""
@export_enum("Retry", "Neutral continuation") var unmatched_action := 0
@export_group("Destinations")
@export var next_beat := ""
@export var alternate_beat := ""
@export var fallback_beat := ""
@export var timeout_beat := ""
@export_group("Phone")
@export var send_phone_cue := false
@export var phone_cue: PhoneCue
@export_group("Advanced presentation")
@export var presentation: StagePresentationOptions
@export_storage var legacy_type := 6
@export_storage var pre_show_input := false
@export_group("Reminder")
@export var reminder_enabled := false
@export_range(0.1, 60, 0.5) var reminder_delay := 5.0
@export var reminder: DialogueLineData
@export var reminder_repeat := true
@export_range(0.1, 60, 0.5) var reminder_interval := 5.0
@export_group("Pre-show replies")
@export var yes_phrases := PackedStringArray()
@export var no_phrases := PackedStringArray()
@export var no_reply: DialogueLineData
func to_beat() -> StageBeat:
	var b := dialogue.to_beat() if dialogue != null else StageBeat.new()
	if presentation != null: presentation.apply_to(b)
	copy_fields(self, b)
	b.beat_id = entry_id
	b.beat_type = legacy_type if not entry_id.is_empty() else (StageBeat.BeatType.PLAYER_LINE if input_mode == StageBeat.InputMode.GUIDED_LINE else StageBeat.BeatType.PLAYER_INPUT)
	return b

func _validate_property(property: Dictionary) -> void:
	if not pre_show_input and (property.name.begins_with("reminder") or property.name in ["yes_phrases", "no_phrases", "no_reply"]):
		property.usage &= ~PROPERTY_USAGE_EDITOR
