class_name StageSequence
extends Resource
@export_storage var beats: Array[StageBeat] = []
@export_storage var start_beat := ""
@export var blocks: Array[StoryBlock] = []
var block_indices := {}
func index_of(id: String) -> int:
	if block_indices.has(id): return block_indices[id]
	for i in beats.size():
		if beats[i] != null and beats[i].beat_id == id: return i
	return -1
func validation_error() -> String:
	if not blocks.is_empty():
		var issue := compile_blocks()
		if not issue.is_empty(): return issue
	if beats.is_empty(): return "No beats assigned"
	var ids := PackedStringArray()
	for beat in beats:
		if beat == null or beat.beat_id.is_empty(): return "Every beat needs an ID"
		if ids.has(beat.beat_id): return "Duplicate ID: " + beat.beat_id
		ids.append(beat.beat_id)
	if not start_beat.is_empty() and not ids.has(start_beat): return "Missing start beat"
	for beat in beats:
		var targets := [beat.next_beat, beat.alternate_beat, beat.fallback_beat, beat.timeout_beat]
		for option in beat.responses:
			if option == null or option.intent.is_empty() or option.accepted_phrases.is_empty(): return "Incomplete response on " + beat.beat_id
			targets.append(option.next_beat)
		for target in targets:
			if not target.is_empty() and not ids.has(target) and not block_indices.has(target): return "Missing destination: " + target
		if beat.input_mode == StageBeat.InputMode.GUIDED_LINE and beat.expected_line.is_empty(): return "Missing expected line: " + beat.beat_id
		if beat.input_mode in [StageBeat.InputMode.YES_NO, StageBeat.InputMode.CHOICE_INTENT, StageBeat.InputMode.INTENT] and beat.responses.is_empty() and beat.accepted_phrases.is_empty(): return "Missing accepted phrases: " + beat.beat_id
		if beat.input_mode == StageBeat.InputMode.ANY_SPEECH_OR_TIMEOUT and beat.timeout <= 0: return "Set a silence timeout: " + beat.beat_id
	return ""

func compile_blocks() -> String:
	beats = []
	block_indices.clear()
	var seen := {}
	for block in blocks:
		if block == null or block.block_id.is_empty(): return "Every block needs a name"
		if seen.has(block.block_id): return "Duplicate block: " + block.block_id
		seen[block.block_id] = true
		if block.pre_show:
			if block != blocks[0]: return "Keep PRESHOW first"
			if block.dialogue_lines.is_empty() or block.player_interaction == null: return "PRESHOW needs lines and an interaction"
			if not block.following_moments.is_empty(): return "PRESHOW uses Dialogue Lines and Player Interaction; move extra moments into the next block"
			if block.player_interaction.input_mode != StageBeat.InputMode.YES_NO: return "PRESHOW requires YES_NO"
			if block.player_interaction.yes_phrases.is_empty() or block.player_interaction.no_phrases.is_empty(): return "PRESHOW needs YES and NO accepted words"
			continue
		block_indices[block.block_id] = beats.size()
		var entries: Array = []
		entries.append_array(block.start_events)
		entries.append_array(block.ordered_content())
		entries.append_array(block.end_events)
		if entries.is_empty(): return "Empty block: " + block.block_id
		for i in entries.size():
			if not (entries[i] is DialogueLineData or entries[i] is PlayerInteractionData or entries[i] is StageEvent): return "Choose a dialogue line, player interaction or stage event in " + block.block_id
			var b: StageBeat = entries[i].to_beat()
			if b.beat_id.is_empty(): b.beat_id = block.block_id + "/" + str(i)
			beats.append(b)
		if not block.next_block.is_empty(): beats[-1].next_beat = block.next_block
	start_beat = beats[0].beat_id if not beats.is_empty() else ""
	return ""
func opening() -> StoryBlock:
	for block in blocks:
		if block != null and block.pre_show: return block
	return null

func _validate_property(property: Dictionary) -> void:
	# Runtime expansion must never become a second saved story.
	if not blocks.is_empty() and property.name in ["beats", "start_beat"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
