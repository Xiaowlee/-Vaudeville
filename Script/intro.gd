extends Control
@export_file("*.tscn") var stage_scene := "res://Scene/StageActs/stage_graph_game.tscn"
@export_range(0.02,1,.02) var spotlight_speed := 0.16
@export_range(0.1,0.6,.01) var spotlight_radius := 0.3
var spotlight_clock := 0.0
var opening := false
func _ready():
	$Menu/Play.pressed.connect(_open)
	$Menu/Settings.pressed.connect(func():
		$DesktopMicrophoneSettings.show_panel())
	$Menu/Developer.set_pressed_no_signal(bool(PhoneSession.get_meta("developer_mode",false)))
	$Menu/Developer.toggled.connect(func(value):PhoneSession.set_meta("developer_mode",value))
	$Menu/Quit.visible=not OS.has_feature("web")
	$Menu/Quit.pressed.connect(func():get_tree().quit())
	$Menu/Play.grab_focus()
func _open():
	if opening:return
	opening=true
	var result=get_tree().change_scene_to_file(stage_scene)
	if result!=OK:opening=false;push_error("Could not open main game")

func _process(delta):
	spotlight_clock+=delta*spotlight_speed
	var mat=$Background.material
	mat.set_shader_parameter("screen_size",size)
	mat.set_shader_parameter("radius",spotlight_radius)
	mat.set_shader_parameter("focus",Vector2(.5+sin(spotlight_clock)*.28,.46+cos(spotlight_clock*.73)*.18))
