extends "res://Script/performer_controller.gd"
@export_node_path("Node") var phone_bridge_path := NodePath("../PhoneCueBridge")
@onready var phone_bridge = get_node(phone_bridge_path)
var waiting_for_phone := false
var current_actor: ActorDefinition
var cue_generation := 0
func _ready() -> void:
	if story_source == null:
		feed.text = ""
		prompt_label.hide()
		status_label.text = "No stage story assigned. Set PerformanceDirector > Story Source."
		return
	super._ready()
	narration_completed.connect(phone_bridge.cancel)
func _enter(index: int) -> void:
	cue_generation += 1
	var ticket := cue_generation
	phone_bridge.cancel()
	while index < story_source.beats.size() and not story_source.meets(story_source.beats[index].required_state, story_state): index += 1
	if index >= story_source.beats.size():
		super._enter(index)
		return
	var beat: PerformerStoryBeat = story_source.beats[index]
	current_actor = beat.actor
	if beat.phone_cue != null:
		_pause_voice()
		state = State.TRANSITION
		waiting_for_phone = true
		status_label.text = "Waiting for phone cue delivery"
		await phone_bridge.deliver(beat.phone_cue)
		if not is_inside_tree() or leaving or ticket != cue_generation: return
		waiting_for_phone = false
	super._enter(index)
func _unhandled_key_input(_event: InputEvent) -> void:
	# Debug input belongs to the separate DebugOverlay component in this scene.
	pass
func debug_advance(option_index: int = 0) -> void:
	if not OS.is_debug_build() or not developer_skip_enabled: return
	if waiting_for_phone:
		phone_bridge.bypass_wait()
		return
	developer_option_index = option_index
	use_default()
