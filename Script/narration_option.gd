extends Resource
@export var category := ""
@export var accepted_answers: PackedStringArray = PackedStringArray()
@export_multiline var response_text := ""
## Blank continues to the next moment. Otherwise enter a later Moment Id.
@export var reconnect_point := ""
@export var ends_story := false
## Used when Ends Story is checked. Blank uses the story's Ending Text.
@export_multiline var ending_text := ""
