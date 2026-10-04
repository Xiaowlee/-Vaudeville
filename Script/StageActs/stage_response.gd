class_name StageResponse
extends Resource
@export var intent := ""
@export var accepted_phrases := PackedStringArray()
@export_multiline var npc_response := ""
@export var next_beat := ""

@export var voice: AudioStream
