extends CanvasLayer
@export var panel_visible := false
@export var shortcuts_enabled := true
@export_node_path("Node") var director_path := NodePath("../PerformanceDirector")
@onready var director = get_node(director_path)
func _ready() -> void:
	visible = panel_visible and OS.is_debug_build()
func _process(_delta: float) -> void:
	if not visible: return
	var beat: String = "" if director.story_source == null or not director.valid or director.active_index >= director.story_source.beats.size() else director.story_source.beats[director.active_index].beat_id
	$Panel/Rows/Details.text = "Beat: %s | State: %s | Actor: %s" % [beat, director.State.keys()[director.state], director.current_actor.display_name if director.current_actor != null else ""]
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not shortcuts_enabled or not event is InputEventKey: return
	if not event.pressed or event.echo: return
	if event.keycode == KEY_F3:
		visible = not visible
	elif event.ctrl_pressed and event.keycode == KEY_ENTER: director.debug_advance()
	elif event.ctrl_pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9: director.debug_advance(event.keycode - KEY_1)
	elif event.ctrl_pressed and event.keycode == KEY_R: director.retry_microphone()
	else: return
	get_viewport().set_input_as_handled()
