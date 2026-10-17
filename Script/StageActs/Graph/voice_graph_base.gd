extends Control
@export var story: DialogueData
@export var start_section: String = "START"
@export_range(0.5,1.0) var cue_coverage := 0.8
@onready var parser: DialogueParser = $Parser
@onready var mic = $Whisper
var mode := "continue"
var cue := ""
var waiting := false
var turn := 0
var recording_turn := -1
var routes: Array[String] = []
var last_meaning := ""
func _ready():
    parser.dialogue_processed.connect(_dialogue)
    parser.dialogue_signal.connect(_signal)
    parser.dialogue_ended.connect(func():
        waiting=false
        $Layout/Dialogue.text=""
        $Layout/Debug.text="DEBUG — Trial complete. Restart to try another route.")
    mic.transcript_ready.connect(_transcript)
    $Layout/Speak.pressed.connect(_speak)
    $Layout/Continue.pressed.connect(_continue)
    $Layout/Silence.pressed.connect(func(): _choose(1, "deliberate silence — DEBUG simulation"))
    $Layout/Restart.pressed.connect(_restart)
    $Layout/Typed/Submit.pressed.connect(func(): submit_words($Layout/Typed/Input.text))
    _restart()
func _restart():
    if mic.recording or mic.pid>0:return
    turn+=1
    waiting=false
    cue=""
    $Layout/Cue.text=""
    parser.set_data(story)
    var resolved=start_section
    if story == null:
        $Layout/Debug.text="DEBUG — No story assigned in Inspector."
        return
    if not story.starts.has(resolved):
        var matches: Array[String] = []
        for key in story.starts:
            if str(key).nocasecmp_to(start_section)==0: matches.append(str(key))
        if matches.size()==1:
            resolved=matches[0]
        else:
            parser.stop()
            $Layout/Debug.text="DEBUG — Starting section '"+start_section+"' was not found. Choose Start Section in Inspector or use Jump to section."
            return
    parser.start(resolved)
func _signal(value: String):
    if value.begins_with("mode:"): mode=value.trim_prefix("mode:")
    if value.begins_with("cue:"):
        cue=value.trim_prefix("cue:")
        $Layout/Cue.text=cue
func _dialogue(speaker, words: String, options: Array[String]):
    turn+=1
    waiting=false
    routes=options
    $Layout/Dialogue.text=str(speaker)+":\n"+words
    $Layout/Continue.text="Your turn" if mode!="continue" else "Continue"
    $Layout/Debug.text="DEBUG — NPC / stage direction. Read, then continue."
func _continue():
    if mic.recording or mic.pid>0 or waiting or not parser.is_running():return
    if mode=="continue":
        parser.select_option(0)
    else:
        waiting=true
        $Layout/Debug.text="DEBUG — Your turn. Click Speak, then Finish when done."
func _speak():
    if not waiting or not parser.is_running():return
    if mic.recording:
        mic.finish_recording()
    elif mic.pid<=0:
        recording_turn=turn
        mic.start_recording()
func _transcript(words: String):
    if recording_turn!=turn or not waiting:return
    submit_words(words)
func tokens(words: String) -> PackedStringArray:
    var regex=RegEx.new()
    regex.compile("[a-z]+")
    var result=PackedStringArray()
    for match_result in regex.search_all(words.to_lower()): result.append(match_result.get_string())
    return result
func classify(words: String) -> String:
    var spoken=tokens(words)
    if spoken.is_empty():return "unclear"
    if mode=="any":return "spoken attempt"
    if mode!="guided" or cue.is_empty():return "unclear"
    var expected=tokens(cue)
    # Ordered word coverage with an extra-word limit: forgiving, not semantic AI.
    var at:=0
    var matched:=0
    for word in expected:
        var found=spoken.find(word,at)
        if found>=0:
            matched+=1
            at=found+1
    var coverage=float(matched)/maxi(1,expected.size())
    if coverage>=cue_coverage and spoken.size()<=expected.size()+3:return "cue read"
    return "unclear"
func submit_words(words: String):
    if not waiting or not parser.is_running():return
    $Layout/Heard.text="Heard: "+words
    last_meaning=classify(words)
    if last_meaning=="unclear":
        $Layout/Debug.text="DEBUG — Unclear / cue not matched. Same turn; try again."
        return
    _choose(0,last_meaning)
func _choose(index: int, meaning: String):
    if not waiting or index<0 or index>=routes.size():return
    waiting=false
    var chosen=routes[index]
    parser.select_option(index)
    $Layout/Result.text="DEBUG — Meaning: "+meaning+" | Selected graph route: "+chosen
func _continue_disabled(busy: bool) -> bool:
    return waiting or busy or not parser.is_running()
func _process(_delta):
    var busy=mic.recording or mic.pid>0
    $Layout/Speak.disabled=not waiting or mic.pid>0
    $Layout/Speak.text="Finish and recognise" if mic.recording else "Speak"
    $Layout/Continue.disabled=_continue_disabled(busy)
    $Layout/Restart.disabled=busy
    $Layout/Silence.visible=waiting and mode=="any" and routes.size()>1
    $Layout/Silence.disabled=busy
    $Layout/Typed/Submit.disabled=not waiting or busy
    $Layout/MicStatus.text=mic.status.text


