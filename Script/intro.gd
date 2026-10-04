extends Control
## Scene routes only; menu wording and appearance belong to Intro.tscn.
@export_file("*.tscn") var prototype_1_scene: String
@export_file("*.tscn") var prototype_2_scene: String
@export_file("*.tscn") var previous_scene: String
@export_file("*.tscn") var stage_scene: String
@export_file("*.tscn") var earlier_scene: String
@export_file("*.tscn") var back_scene: String
var opening := false
func _ready() -> void:
	if not stage_scene.is_empty(): PhoneSession.ensure_session()
	for pair in [["Prototype1", prototype_1_scene], ["Prototype2", prototype_2_scene], ["PerformerA", "res://Scene/2.2_a_performer_baseline.tscn"], ["PerformerC", "res://Scene/2.2_c_increased_agency.tscn"], ["StagePrototype", stage_scene], ["Previous", previous_scene], ["Earlier", earlier_scene], ["Back", back_scene]]:
		var button = get_node_or_null("Menu/" + pair[0])
		if button != null: button.pressed.connect(_open.bind(pair[1]))
	$Menu/Quit.visible = not OS.has_feature("web")
	$Menu/Quit.pressed.connect(func(): get_tree().quit())
	var first_button = get_node_or_null("Menu/StagePrototype")
	if first_button == null: first_button = $Menu/Prototype1
	first_button.grab_focus()
func _open(path: String) -> void:
	if opening: return
	opening = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		opening = false
		push_error("[Menu] Could not open: " + path)
