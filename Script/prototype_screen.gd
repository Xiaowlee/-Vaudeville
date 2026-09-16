extends Control
## Shared screen shell only. Narration progression is intentionally not implemented yet.
@export_file("*.tscn") var intro_scene: String
var leaving := false
func _ready() -> void:
	$Back.pressed.connect(go_back)
	$Back.grab_focus()
	print("[Prototype screen] ", scene_file_path)
func go_back() -> void:
	if leaving: return
	leaving = true
	var error := get_tree().change_scene_to_file(intro_scene)
	if error != OK:
		leaving = false
		push_error("[Prototype screen] Could not return to: " + intro_scene)
