extends "res://Script/StageActs/stage_ui.gd"
# Uses the existing stage layout; microphone ownership belongs to the graph runtime.
func _ready() -> void:
    get_node(menu_path).pressed.connect(func(): get_tree().change_scene_to_file(menu_scene))
    $Speak.pressed.connect(request_speech)
    $PreShow.hide()
    panel(thought_path,"",false)
    panel(ifb_path,"",false)
    panel(transcript_path,"",false)
    hide_cue()
func request_speech() -> void:
    get_node("../GameController").graph_input()
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed:
        if event.keycode==speak_key:
            request_speech()
            get_viewport().set_input_as_handled()
        elif event.keycode==skip_dialogue_key:
            get_node("../GameController").skip_dialogue()
            get_viewport().set_input_as_handled()