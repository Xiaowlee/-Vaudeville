class_name StoryBlock
extends Resource
@export var block_id := ""
@export_multiline var designer_notes := ""
@export var start_events: Array[StageEvent] = []
## Add DialogueLineData, PlayerInteractionData or StageEvent, in performance order.
@export var dialogue_lines: Array[DialogueLineData] = []
@export var player_interaction: PlayerInteractionData
## Only for sections with more than one player turn: dialogue, input and events in order.
@export var following_moments: Array[StoryEntry] = []
@export var end_events: Array[StageEvent] = []
@export_group("Flow")
## Empty means the next block in the list.
@export var next_block := ""
@export_group("Advanced")
@export var pre_show := false

func ordered_content() -> Array[StoryEntry]:
	var entries: Array[StoryEntry] = []
	entries.append_array(dialogue_lines)
	if player_interaction != null: entries.append(player_interaction)
	entries.append_array(following_moments)
	return entries
