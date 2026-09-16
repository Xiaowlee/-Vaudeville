extends Control
## Scene routes only; menu wording and appearance belong to Intro.tscn.
@export_file("*.tscn") var prototype_1_scene: String
@export_file("*.tscn") var prototype_2_scene: String
var opening := false
func _ready() -> void:
	$Menu/Prototype1.pressed.connect(_open.bind(prototype_1_scene))
	$Menu/Prototype2.pressed.connect(_open.bind(prototype_2_scene))
	$Menu/Quit.pressed.connect(func(): get_tree().quit())
	$Menu/Prototype1.grab_focus()
func _open(path: String) -> void:
	if opening: return
	opening = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		opening = false
		push_error("[Menu] Could not open: " + path)
