class_name StageBeat
extends Resource
enum InputMode { NONE, GUIDED_LINE, YES_NO, CHOICE_INTENT, INTENT, ANY_SPEECH, ANY_SPEECH_OR_TIMEOUT }
enum BeatType { NPC_DIALOGUE, NARRATION, PLAYER_LINE, STAGE_DIRECTION, CUE, TRANSITION, PLAYER_INPUT }
@export_group("Content type")
@export var beat_type: BeatType = BeatType.NPC_DIALOGUE
@export var speaker_name := ""
@export_multiline var narration_text := ""
## Authoring/staging notes, never spoken or displayed as dialogue.
@export_multiline var stage_description := ""
## Zero uses StageUI Sentence Seconds.
@export_range(0, 60, 0.1) var presentation_seconds := 0.0
@export_group("Identity")
@export var beat_id := ""
@export_multiline var notes := ""
@export var actor_id := ""
@export_group("Display")
@export_multiline var npc_dialogue := ""
@export var npc_voice: AudioStream
@export var hide_subtitle_after_voice := false
@export var show_player_transcript := true
@export_multiline var player_thought := ""
@export_multiline var cue_card_text := ""
@export var show_npc_dialogue := true
@export var show_player_thought := false
@export var show_cue_card := false
@export_range(0, 60, 0.1) var cue_delay := 0.0
@export_group("Input")
@export var input_mode: InputMode = InputMode.NONE
@export_multiline var expected_line := ""
@export var expected_intent := ""
@export var accepted_phrases := PackedStringArray()
@export var responses: Array[StageResponse] = []
## Technical rejections get retries, then a neutral fallback; never a scripted wrong-answer reaction.
@export_range(0, 20, 1) var retry_count := 2
## Zero disables the narrative silence deadline. It starts only when the recognizer is ready.
@export_range(0, 120, 0.5) var timeout := 0.0
@export_range(1, 120, 0.5) var technical_failure_delay := 8.0
@export var allow_debug_bypass := true
## Any nonempty final recognition counts as an attempt; empty technical failures retry.
@export var accept_uncertain_attempt := false
@export_range(0.2, 1, 0.05) var line_coverage := 0.65
@export_range(0, 1, 0.05) var minimum_confidence := 0.35
@export_group("Reaction")
@export_multiline var npc_success_response := ""
@export var success_voice: AudioStream
@export var retry_voice: AudioStream
@export var unclear_voice: AudioStream
@export var timeout_voice: AudioStream
## Used only for a clearly transcribed, unexpected response; not recognizer rejection.
@export_multiline var npc_retry_response := ""
@export_multiline var npc_unclear_response := ""
@export_multiline var npc_timeout_response := ""
@export_enum("Retry", "Neutral continuation") var unmatched_action := 0
@export_group("Presentation")
@export var actor_actions: Array[StageActorAction] = []
@export var audio: Array[BeatAudioCue] = []
@export_range(0, 120, 0.1) var delay_before_input := 0.0
@export_range(0, 120, 0.1) var delay_after_response := 2.0
@export_group("Flow")
## Empty means the next item in the sequence. On the final beat, empty ends the slice.
@export var next_beat := ""
@export var alternate_beat := ""
@export var fallback_beat := ""
@export var timeout_beat := ""
@export_group("Phone / IFB")
@export var send_phone_cue := false
@export var phone_cue: PhoneCue

@export_group("Typewriter override")
## Empty uses StageUI defaults.
@export var typing_override: StageTypingSettings

@export_group("Voice timing / level")
@export_range(-60, 6, 1) var voice_volume_db := 0.0
@export_range(0, 20, 0.05) var voice_delay := 0.0
@export_group("SFX triggers")
@export var sfx_on_start: Array[AudioStream] = []
@export var sfx_on_cue: Array[AudioStream] = []
@export var sfx_after_player: Array[AudioStream] = []
@export var sfx_on_transition: Array[AudioStream] = []
@export_range(-60, 6, 1) var sfx_volume_db := -18.0
