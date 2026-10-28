extends "res://Script/StageActs/stage_beat.gd"
## Optional production settings; dialogue and routing remain in the graph.
@export_group("Stage production")
@export var actor_positions: Dictionary[String, Vector2] = {}
@export var actor_offsets: Dictionary[String, Vector2] = {}
@export var stage_tint := Color.WHITE
@export_enum("Keep","Open","Close") var curtain_action := 0
@export var animation_player: NodePath
@export var stage_animation: StringName
@export_group("Phone and state")
@export_multiline var phone_message := ""
@export_enum("prompt","ifb") var phone_channel := "ifb"
@export var state_changes: Dictionary = {}
@export_group("Planning")
@export var assets_required: Array[String] = []
@export_multiline var unresolved := ""

@export_group("Response phase hooks")
## Phase names map to arrays of existing StageBeat/production_cue resources.
@export var phase_cues: Dictionary = {}
