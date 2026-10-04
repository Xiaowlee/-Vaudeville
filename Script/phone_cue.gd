class_name PhoneCue
extends Resource
## Empty recipient broadcasts to all stage phones. Otherwise matches the phone's recipient query.
@export var recipient_id := ""
@export_multiline var text := ""
@export_enum("PROMPTER", "PRIVATE", "SCRIPT_UPDATE", "WARNING") var cue_type := "PRIVATE"
@export_range(0, 60, 0.1) var delay_seconds := 0.0
## Delivery acknowledgement means the cue was rendered, not that a person acted on it.
@export var wait_for_delivery := false
