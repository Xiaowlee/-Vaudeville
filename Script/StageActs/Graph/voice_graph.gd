extends "res://Script/StageActs/Graph/voice_graph_base.gd"
@export var ai_enabled := true
@export var ai_model := "qwen3:4b"
@export_file("*.txt") var ai_rules_file := "res://Story/StageActs/Graph/interpretation_rules.txt"
@export_file("*.ps1") var ai_service_launcher := "D:/RMIT/Master/Studio 1/Folio 2/folio-2-test-2/tools/start_local_intent.ps1"
@export_range(5,120) var ai_timeout_seconds := 60.0
var ai_request: HTTPRequest
@export_file("*.json") var ai_meanings_file := "res://Story/StageActs/Graph/interpretation_meanings.json"
@export_multiline var unmatched_feedback := "That answer does not select an available response. Please try again, or use Testing controls."
var forced_route := -1
var fallback_reply := ""
var interpretation_trace := ""
var ai_question := ""
var ai_busy := false
var ai_turn := -1
var ai_allowed: Array = []
var ai_history: Array = []
var frame: Dictionary = {}
var route_kinds: Array = []
var story_variables: Dictionary = {}
var story_state: Dictionary = {}
var off_script_count := 0
var off_script_reason := ""
func _ready():
    ai_request=HTTPRequest.new()
    ai_request.timeout=ai_timeout_seconds
    add_child(ai_request)
    ai_request.request_completed.connect(_ai_completed)
    if ai_enabled and FileAccess.file_exists(ai_service_launcher):
        OS.create_process("powershell.exe",PackedStringArray(["-NoProfile","-ExecutionPolicy","Bypass","-File",ai_service_launcher]),false)
    super._ready()
    $Layout/RouteTest/Apply.pressed.connect(_manual_route)
    for key in story.starts.keys():
        var start_node=story.nodes.get(story.starts[key],{})
        var signal_node=story.nodes.get(start_node.get("link",""),{})
        var info=JSON.parse_string(str(signal_node.get("signalValue","")).trim_prefix("frame:"))
        var label=str(info.get("group",""))+" / "+str(key) if info is Dictionary else str(key)
        $Layout/Jump/Section.add_item(label)
        $Layout/Jump/Section.set_item_metadata($Layout/Jump/Section.item_count-1,key)
    $Layout/Jump/Go.pressed.connect(_jump_section)
    $Layout/Tools.toggled.connect(func(open):
        for path in ["Typed", "RouteTest", "Jump", "Restart"]:
            get_node("Layout/"+path).visible=open
        $Layout/Result.text=interpretation_trace if open and not interpretation_trace.is_empty() else fallback_reply)
func _manual_route():
    if mic.recording or mic.pid>0:return
    var index=$Layout/RouteTest/Choice.selected
    if not parser.is_running() or index<0:
        $Layout/Result.text="Game response: No route selected."
        return
    waiting=true
    _choose(index,"Manual selection")
func _jump_section():
    if mic.recording or mic.pid>0:return
    var index=$Layout/Jump/Section.selected
    if index<0:return
    var section=str($Layout/Jump/Section.get_item_metadata(index))
    story_variables.clear()
    off_script_count=0
    off_script_reason=""
    ai_history.clear()
    parser.set_data(story)
    parser.start(section)
    $Layout/Heard.text="Heard: —"
    $Layout/Result.text="Scene management: Opened "+section+" (fresh test state)"
func _choose(index: int, meaning: String, apply_punishment: bool = true):
    if not waiting or index<0 or index>=routes.size():return
    _cancel_ai()
    var chosen=routes[index]
    var notice=""
    var effects=frame.get("effects",[])
    if index<effects.size():
        for key in effects[index].get("assignments",{}):
            story_state[key]=effects[index].assignments[key]
    if index<effects.size():
        story_variables.merge(effects[index].get("set",{}),true)
    if apply_punishment and index<effects.size() and int(effects[index].get("increment",0))>0:
        var previous_count=off_script_count
        off_script_count+=int(effects[index].increment)
        off_script_reason=effects[index].get("reason","")
        var limits=frame.get("thresholds",{})
        if off_script_count>=int(limits.get("KickOut",5)):
            parser.start(frame.get("endgame",""))
            $Layout/Result.text="Game response: Off-script limit reached — performance ended."
            return
        var category="disruption" if off_script_count>=int(limits.get("Disruption",3)) else "correction"
        var threshold=int(limits.get("Disruption",3)) if category=="disruption" else int(limits.get("Correction",1))
        if previous_count<threshold and off_script_count>=threshold:
            notice=frame.get("notices",{}).get(category,"")
    super._choose(index,meaning)
    if not notice.is_empty():$Layout/Dialogue.text=notice+"\n\n"+$Layout/Dialogue.text
    interpretation_trace=meaning+" → "+chosen
    $Layout/Result.text=interpretation_trace if $Layout/Tools.button_pressed else ""
func _restart():
    _cancel_ai()
    ai_history.clear()
    super._restart()
    $Layout/Heard.text="Heard: —"
    $Layout/Result.text="Game response: Ready." if parser.is_running() else $Layout/Debug.text
func _signal(value: String):
    if not value.begins_with("frame:"):return
    _cancel_ai()
    frame=JSON.parse_string(value.trim_prefix("frame:"))
    if frame.get("reset",false):
        story_variables.clear()
        story_state.clear()
        ai_history.clear()
        off_script_count=0
        off_script_reason=""
    fallback_reply=""
    interpretation_trace=""
    $Layout/Result.text=""
    var definitions=JSON.parse_string(FileAccess.get_file_as_string(ai_meanings_file))
    var policy: Dictionary=definitions.get(str(frame.get("id","")),{}) if definitions is Dictionary else {}
    forced_route=int(policy.get("continue_route",-1))
    route_kinds=frame.get("routes",[])
    if forced_route>=route_kinds.size():forced_route=-1
    cue=frame.get("cue","")
    $Layout/Cue.text=cue
    mode="continue" if forced_route>=0 or (route_kinds.size()==1 and route_kinds[0] in ["next","watch"]) else "draft"
func _dialogue(speaker,words: String,options: Array[String]):
    super._dialogue(speaker,words,options)
    ai_history.append({"section":frame.get("id",""),"dialogue":words})
    if ai_history.size()>6:ai_history.pop_front()
    $Layout/Dialogue.text=words
    $Layout/Dialogue.scroll_to_line(0)
    $Layout/RouteTest/Choice.clear()
    for option in options:$Layout/RouteTest/Choice.add_item(option)
    waiting=mode!="continue" and not route_kinds.is_empty()
    for child in $Layout/StoryChoices.get_children():
        $Layout/StoryChoices.remove_child(child)
        child.queue_free()
    if route_kinds.count("next")>1:
        for i in routes.size():
            var button=Button.new()
            button.text=routes[i]
            button.pressed.connect(func():
                if mic.recording or mic.pid>0:return
                waiting=true
                _choose(i,"Selected"))
            $Layout/StoryChoices.add_child(button)
    $Layout/Debug.text="Your turn — speak when ready." if waiting else "Story — read, then Continue."
func _continue():
    if ai_busy:return
    if forced_route>=0 and not mic.recording and mic.pid<=0:
        waiting=true
        _choose(forced_route,"Story continues",false)
        return
    if waiting:
        var watch=route_kinds.find("watch")
        if watch>=0 and not mic.recording and mic.pid<=0:_choose(watch,"watch the show")
        return
    super._continue()
func classify(words: String) -> String:
    var spoken=tokens(words)
    if spoken.is_empty():return "unclear"
    var normal=" ".join(spoken)
    for kind in ["yes","no"]:
        if kind in route_kinds and normal in frame.get(kind,[]):return kind
    # Negative phrases must not become yes by substring matching.
    if "cue" in route_kinds and not cue.is_empty():
        var expected=tokens(cue)
        var at=0
        var matched=0
        for word in expected:
            var found=spoken.find(word,at)
            if found>=0:matched+=1;at=found+1
        if float(matched)/maxi(1,expected.size())>=float(frame.get("coverage",0.8)) and spoken.size()<=expected.size()+3:return "cue"
    if "ambition" in route_kinds:
        for word in frame.get("ambition",[]):
            if word in spoken:return "ambition"
    return "other" if "other" in route_kinds else "unclear"
func submit_words(words: String):
    if not waiting or not parser.is_running():
        $Layout/Result.text="Game response: This section is not waiting for speech. Use Continue."
        return
    $Layout/Heard.text="Heard: "+words
    if words.strip_edges().is_empty():
        $Layout/Heard.text="Heard: No words recognised"
        _narrative_retry(false)
        return
    if ai_busy:return
    if ai_enabled:
        _interpret(words)
        return
    last_meaning=classify(words)
    var index=route_kinds.find(last_meaning)
    if index<0:
        _narrative_retry(false)
        return
    _choose(index,"Accepted ("+last_meaning+")")
func _continue_disabled(busy: bool) -> bool:
    return busy or not parser.is_running() or (waiting and not "watch" in route_kinds)
func _process(_delta):
    var busy=mic.recording or mic.pid>0 or ai_busy
    $Layout/Silence.visible=false
    $Layout/Continue.disabled=_continue_disabled(busy)
    $Layout/Continue.text="Watch the show" if "watch" in route_kinds else "Continue"
    $Layout/Continue.visible=(mode=="continue" or "watch" in route_kinds) and not route_kinds.is_empty() and route_kinds.count("next")<=1
    $Layout/Speak.disabled=not waiting or mic.pid>0 or ai_busy
    $Layout/Speak.text="Finish speaking" if mic.recording else "Speak"
    $Layout/Speak.visible=waiting and route_kinds.count("next")<=1
    $Layout/Debug.text=str(frame.get("group",""))+" · "+("Your turn" if waiting else "Story — read, then Continue")
    if route_kinds.is_empty():
        $Layout/Debug.text="Act 2 preview — this trial ends here." if frame.get("boundary",false) else "End of this story path."
    if not parser.is_running():$Layout/Debug.text="Story stopped — restart or select a section"
    if mic.recording:
        $Layout/MicStatus.text="Microphone: Recording — click Finish speaking when done."
    elif mic.pid>0:
        $Layout/MicStatus.text="Microphone: Processing your recording…"
    elif mic.status.text.begins_with("Ready") or mic.status.text.begins_with("Result"):
        $Layout/MicStatus.text="Microphone: Ready"
    else:
        $Layout/MicStatus.text="Microphone: "+mic.status.text
    $Layout/RouteTest/Apply.disabled=busy or not parser.is_running()
    $Layout/Jump/Go.disabled=busy
    $Layout/Restart.disabled=busy
    $Layout/Typed/Submit.disabled=not waiting or busy




func _cancel_ai():
    if ai_request!=null:ai_request.cancel_request()
    ai_busy=false
    ai_turn=-1
func _interpret(words: String):
    ai_allowed=["unclear","no_match"]
    ai_question=str(frame.get("id",""))
    var definitions=JSON.parse_string(FileAccess.get_file_as_string(ai_meanings_file))
    var meanings: Dictionary=definitions.get(ai_question,{}) if definitions is Dictionary else {}
    var attempted_route=str(meanings.get("any_spoken_route",""))
    if not tokens(words).is_empty() and attempted_route in route_kinds:
        _choose(route_kinds.find(attempted_route),"Authored spoken attempt",false)
        return
    var exact: Dictionary=meanings.get("exact_meanings",{})
    var normal=" ".join(tokens(words))
    if exact.has(normal) and exact[normal] in route_kinds:
        _choose(route_kinds.find(exact[normal]),"Answer to "+ai_question+" — authored meaning: "+str(exact[normal]))
        return
    # Protect unambiguous yes/no answers before invoking the model.
    var short_answer=normal
    for filler in ["uh ", "um ", "well ", "you know what "]:
        short_answer=short_answer.trim_prefix(filler)
    var refusal=short_answer in ["no","nope","nah","no thanks","no thank you","not yet","not ready","i said no","i don t want to","i do not want to"]
    var agreement=short_answer in ["yes","yeah","yep","yes please"]
    if refusal or agreement:
        var wanted="no" if refusal else "yes"
        var direct=route_kinds.find(wanted)
        if direct<0:
            for i in routes.size():
                if " ".join(tokens(routes[i]))==wanted:
                    direct=i
                    break
        if direct>=0:
            last_meaning=route_kinds[direct]
            _choose(direct,"Explicit "+wanted)
        else:
            _narrative_retry(false)
        return
    var options=[]
    for i in mini(routes.size(),route_kinds.size()):
        var kind=route_kinds[i]
        if kind in ["silence","watch","next"]:continue
        if not kind in ai_allowed:ai_allowed.append(kind)
        options.append({"intent":kind,"authored_response":routes[i],"meaning":meanings.get(kind,routes[i])})
    if options.is_empty():
        $Layout/Result.text="Game response: This moment uses the on-screen choices."
        return
    var context={"section":frame.get("id",""),"dialogue":$Layout/Dialogue.text,"cue":cue,"history":ai_history.slice(maxi(0,ai_history.size()-3)),"story_variables":story_variables,"authored_choices":story_state,"off_script_count":off_script_count,"last_off_script_reason":off_script_reason,"allowed_responses":options}
    var rules=FileAccess.get_file_as_string(ai_rules_file)
    var payload={"model":ai_model,"stream":false,"think":false,"keep_alive":"10m","messages":[{"role":"system","content":rules+"\nScene context: "+JSON.stringify(context)},{"role":"user","content":JSON.stringify(words)}],"format":{"type":"object","properties":{"intent":{"type":"string","enum":ai_allowed}},"required":["intent"],"additionalProperties":false},"options":{"temperature":0,"num_ctx":4096,"num_predict":80}}
    ai_turn=turn
    var error=ai_request.request("http://127.0.0.1:11435/api/chat",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload))
    ai_busy=error==OK
    ai_history.append({"player":words})
    $Layout/Result.text="Game response: Interpreting with local "+ai_model+"…" if ai_busy else "Game response: Local AI unavailable. Retry or use Testing controls."
    if not ai_busy:_narrative_retry(false)
func _ai_completed(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray):
    if not ai_busy or ai_turn!=turn:return
    ai_busy=false
    if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
        _narrative_retry(false)
        return
    var envelope=JSON.parse_string(bytes.get_string_from_utf8())
    var answer=null
    if envelope is Dictionary and envelope.get("message") is Dictionary and envelope.get("done_reason","")!="length":
        answer=JSON.parse_string(str(envelope.message.get("content","")))
    if not answer is Dictionary or not answer.get("intent") is String or not answer.intent in ai_allowed:
        _narrative_retry(false)
        return
    last_meaning=answer.intent
    if last_meaning in ["unclear","no_match"]:
        _narrative_retry(true)
        return
    var index=route_kinds.find(last_meaning)
    if index<0:return
    _choose(index,"Answer to "+ai_question+" — AI selected "+str(routes[index]))
func _exit_tree():
    _cancel_ai()


func _narrative_retry(allow_authored_route: bool):
    var definitions=JSON.parse_string(FileAccess.get_file_as_string(ai_meanings_file))
    var policy: Dictionary=definitions.get(str(frame.get("id","")),{}) if definitions is Dictionary else {}
    var route=str(policy.get("unmatched_route",""))
    if allow_authored_route and not route.is_empty() and route in route_kinds:
        _choose(route_kinds.find(route),"Authored fallback",false)
        return
    interpretation_trace=""
    fallback_reply=str(policy.get("retry_reply",unmatched_feedback))
    $Layout/Result.text=fallback_reply
