extends Control
@export_file("*.tscn") var pregame_scene := "res://Scene/Pregame.tscn"
@export_range(0.02,1,.02) var spotlight_speed := 0.16
@export_range(0.1,0.6,.01) var spotlight_radius := 0.3
var spotlight_clock := 0.0
var opening := false
@export_group("Before Play · required files and AI")
@export var interpretation_model := "qwen3:4b"
@export var readiness_url := "http://127.0.0.1:11435"
@export_range(5,120,1) var model_warmup_timeout_seconds := 60.0
@export_range(1,15,1) var service_start_attempts := 8
@export var playtest_report_folder := "D:/RMIT/Master/Studio 1/Folio 2/2.6 Fix/Feedback/Playtest Reports"
var preparation_ready := false
var checking := false
var readiness_request: HTTPRequest
const Report=preload("res://Script/playtest_report.gd")

@onready var settings = $DesktopMicrophoneSettings
func _ready():
	Report.folder=playtest_report_folder
	$PhonePairing/ConnectPhone.hide()
	settings.phone_requested.connect($PhonePairing.show_panel)
	$PhonePairing.panel_closed.connect(settings.show_panel)
	$Menu/Play.pressed.connect(_open)
	$Menu/Settings.pressed.connect(func(): settings.show_panel())
	$Menu/Quit.visible=not OS.has_feature("web")
	$Menu/Quit.pressed.connect(func():Report.finish("Stopped from menu");get_tree().quit())
	$Menu/Retry.pressed.connect(check_preparation)
	readiness_request=HTTPRequest.new()
	add_child(readiness_request)
	check_preparation.call_deferred()
func _open():
	if opening or not preparation_ready:return
	if not Report.active:Report.begin_session()
	opening=true
	var result=get_tree().change_scene_to_file(pregame_scene)
	if result!=OK:opening=false;push_error("Could not open pregame setup")

func _process(delta):
	spotlight_clock+=delta*spotlight_speed
	var mat=$Background.material
	mat.set_shader_parameter("screen_size",size)
	mat.set_shader_parameter("radius",spotlight_radius)
	mat.set_shader_parameter("focus",Vector2(.5+sin(spotlight_clock)*.28,.46+cos(spotlight_clock*.73)*.18))

func required_path(relative: String) -> String:
	if OS.has_feature("editor"):return ProjectSettings.globalize_path("res://.local-speech/"+relative)
	return OS.get_executable_path().get_base_dir().path_join(".local-speech/"+relative)

func preparation_status(words: String, ready: bool = false):
	preparation_ready=ready
	$Menu/Preparation.text=words
	$Menu/Play.disabled=not ready
	$Menu/Retry.visible=not ready and not checking
	$Menu/Retry.disabled=checking

func readiness_call(path: String, payload: Dictionary = {}, seconds: float = 3.0) -> Array:
	readiness_request.timeout=seconds
	var err=readiness_request.request(readiness_url+path,PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_GET if payload.is_empty() else HTTPClient.METHOD_POST,JSON.stringify(payload) if not payload.is_empty() else "")
	if err!=OK:return [err,0,PackedStringArray(),PackedByteArray()]
	return await readiness_request.request_completed

func check_preparation():
	if checking:return
	checking=true
	preparation_status("Preparing speech and AI…")
	var missing: Array[String]=[]
	for file in ["engine/Release/whisper-cli.exe","engine/Release/whisper.dll","engine/Release/ggml.dll","engine/Release/ggml-base.dll","ggml-base.en.bin"]:
		var handle=FileAccess.open(required_path(file),FileAccess.READ)
		if handle==null or handle.get_length()==0:missing.append(file.get_file())
		if handle!=null:handle.close()
	if not missing.is_empty():
		checking=false
		preparation_status("Speech files missing: "+", ".join(missing)+". Restore the .local-speech folder beside the game, then Retry.")
		return
	var reply=await readiness_call("/api/tags")
	if reply[0]!=HTTPRequest.RESULT_SUCCESS or reply[1]!=200:
		preload("res://Script/StageActs/Graph/voice_graph.gd").start_local_service()
		for attempt in range(service_start_attempts):
			await get_tree().create_timer(1.0).timeout
			reply=await readiness_call("/api/tags")
			if reply[0]==HTTPRequest.RESULT_SUCCESS and reply[1]==200:break
	if reply[0]!=HTTPRequest.RESULT_SUCCESS or reply[1]!=200:
		checking=false
		preparation_status("The local AI could not start. Restore its .local-speech files, then Retry. Settings is still available.")
		return
	var data=JSON.parse_string(reply[3].get_string_from_utf8())
	var found=false
	if data is Dictionary:
		for model in data.get("models",[]):
			if str(model.get("name",""))==interpretation_model:found=true
	if not found:
		checking=false
		preparation_status("AI model missing: "+interpretation_model+". Restore the supplied intent-models folder, then Retry.")
		Report.record("preparation_failed",{"reason":"model_missing","model":interpretation_model})
		return
	preparation_status("Preparing the AI for your first reply…")
	reply=await readiness_call("/api/chat",{"model":interpretation_model,"stream":false,"think":false,"keep_alive":"30m","format":"json","messages":[{"role":"user","content":"Return only this JSON: {\"ready\":true}"}],"options":{"temperature":0,"num_predict":32,"num_ctx":4096}},model_warmup_timeout_seconds)
	var envelope=JSON.parse_string(reply[3].get_string_from_utf8())
	var answer=null
	if envelope is Dictionary:answer=JSON.parse_string(str(envelope.get("message",{}).get("content","")))
	checking=false
	if reply[0]!=HTTPRequest.RESULT_SUCCESS or reply[1]!=200 or not answer is Dictionary or answer.get("ready")!=true:
		preparation_status("The AI did not finish its check. Close other heavy apps, then Retry.")
		Report.record("preparation_failed",{"reason":"warmup_failed","http_status":reply[1],"detail":reply[3].get_string_from_utf8().left(800)})
		return
	preparation_status("Speech files and AI ready. Play to check your microphone and connect your phone.",true)
	Report.record("preparation_ready",{"model":interpretation_model})
	$Menu/Play.grab_focus()
