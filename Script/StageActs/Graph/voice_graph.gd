extends "res://Script/StageActs/Graph/voice_graph_base.gd"
@export_group("Temporary progression guard")
@export_range(2,6,1) var intro_refusals_before_takeover := 2
var intro_refusals := 0
@export_group("Interpretation")
@export var ai_enabled := true
@export var ai_model := "qwen3:4b"
@export_file("*.txt") var ai_rules_file := "res://Story/StageActs/Graph/interpretation_rules.txt"
@export_file("*.ps1") var ai_service_launcher := "res://tools/start_local_intent.ps1"
@export_range(5,120) var ai_timeout_seconds := 60.0
var ai_request: HTTPRequest
@export_multiline var unmatched_feedback := "That answer does not select an available response. Please try again, or use Testing controls."
signal cue_requested
var turn_silences := 0
signal response_resolved(category: String, intent: String, consequence: int)
const ResponsePolicy = preload("res://Script/StageActs/Graph/response_policy.gd")
var responses = ResponsePolicy.new()
var raw_transcript := ""
var interpreted_intent := ""
var silence_elapsed := 0.0
var accepting_speech := true
var response_debug: CanvasLayer
var response_debug_label: Label
var debug_category: OptionButton
var debug_intent: OptionButton
var forced_route := -1
var last_response_debug: Dictionary = {}
var response_origin := "Rules"
var fallback_reply := ""
var interpretation_trace := ""
var ai_question := ""
var ai_busy := false
var ai_turn := -1
var ai_allowed: Array = []
var ai_history: Array = []
@export var log_interpretations := true
var interpretation_log: Array=[]
var interpretation_context: Dictionary={}
var raw_ai_response := ""
var ai_started_at := 0
var ai_elapsed_ms := 0
const FITS=["supported","unrelated","uncertain","question","help"]
var frame: Dictionary = {}
var pending_visual_commands: Array=[]
var route_kinds: Array = []
var story_variables: Dictionary = {}
var story_state: Dictionary = {}
var off_script_count := 0
var off_script_reason := ""
func _ready():
    _recover_legacy_story()
    if log_interpretations:
        var log_file=FileAccess.open("user://interpretation_log.jsonl",FileAccess.WRITE)
        if log_file!=null:log_file.close()
    responses.definitions=JSON.parse_string(FileAccess.get_file_as_string("res://Story/StageActs/Graph/response_policy.json"))
    ai_request=HTTPRequest.new()
    ai_request.timeout=ai_timeout_seconds
    add_child(ai_request)
    ai_request.request_completed.connect(_ai_completed)
    if ai_enabled:
        if OS.has_feature("editor") and FileAccess.file_exists(ai_service_launcher):
            OS.create_process("powershell.exe",PackedStringArray(["-NoProfile","-ExecutionPolicy","Bypass","-File",ProjectSettings.globalize_path(ai_service_launcher)]),false)
        elif OS.get_name()=="Windows":
            var folder=OS.get_executable_path().get_base_dir().path_join(".local-speech")
            var engine=folder.path_join("ollama/ollama.exe")
            if FileAccess.file_exists(engine):
                OS.set_environment("OLLAMA_HOST","127.0.0.1:11435")
                OS.set_environment("OLLAMA_MODELS",folder.path_join("intent-models"))
                OS.set_environment("OLLAMA_NO_CLOUD","1")
                OS.create_process(engine,PackedStringArray(["serve"]),false)
    super._ready()
    _build_response_debug()
    mic.technical_failure.connect(func(_detail): handle_response("TECHNICAL_FAILURE"))
    $Layout/RouteTest/Apply.pressed.connect(_manual_route)
    for key in story.starts.keys():
        var start_node=story.nodes.get(story.starts[key],{})
        var cursor=str(start_node.get("link",""))
        var visited={}
        var info: Variant=null
        while story.nodes.has(cursor) and not visited.has(cursor):
            visited[cursor]=true
            var entry=story.nodes[cursor]
            var signal_value=str(entry.get("signalValue",""))
            if signal_value.begins_with("frame:"):
                info=JSON.parse_string(signal_value.trim_prefix("frame:"))
                break
            cursor=str(entry.get("link",""))
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
    responses.reset()
    _cancel_ai()
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
    var notice="" # Consequences now belong exclusively to handle_response.
    # Legacy per-link increments are deliberately not applied.
    var effects=frame.get("effects",[])
    if index<effects.size():
        for key in effects[index].get("assignments",{}):
            story_state[key]=effects[index].assignments[key]
    if index<effects.size():
        story_variables.merge(effects[index].get("set",{}),true)
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
    if value.begins_with("stage_visual:"):
        var command=JSON.parse_string(value.trim_prefix("stage_visual:"))
        if command is Dictionary and get_parent().has_node("DialogueView"):
            pending_visual_commands.append(command)
        return
    if not value.begins_with("frame:"):return
    _cancel_ai()
    frame=JSON.parse_string(value.trim_prefix("frame:"))
    frame["visual_cues"]=pending_visual_commands.duplicate(true)
    pending_visual_commands.clear()
    silence_elapsed=0
    turn_silences=0
    if frame.get("reset",false):
        intro_refusals=0
        responses.reset()
        story_variables.clear()
        story_state.clear()
        ai_history.clear()
        off_script_count=0
        off_script_reason=""
    fallback_reply=""
    interpretation_trace=""
    $Layout/Result.text=""
    forced_route=-1
    route_kinds=frame.get("routes",[])
    if route_kinds.is_empty():routes.clear();waiting=false
    if forced_route>=route_kinds.size():forced_route=-1
    cue=frame.get("cue","")
    $Layout/Cue.text=cue
    mode="continue" if forced_route>=0 or (route_kinds.size()==1 and route_kinds[0] in ["next","watch"]) else "draft"
    if frame.get("template_version",0)==2:mode="continue" if frame.get("input_mode","")=="continue" else "draft"
func _dialogue(speaker,words: String,options: Array[String]):
    super._dialogue(speaker,words,options)
    ai_history.append({"section":frame.get("id",""),"dialogue":words})
    if ai_history.size()>6:ai_history.pop_front()
    $Layout/Dialogue.text=words
    $Layout/Dialogue.scroll_to_line(0)
    if debug_intent!=null:
        debug_intent.clear()
        debug_intent.add_item("Use fallback")
        for kind in route_kinds:debug_intent.add_item(kind)
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
    if frame.get("template_version",0)==2 and responses.mic_check_pending:
        continue_after_mic_check()
        return
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
    if not waiting or not accepting_speech or not parser.is_running():
        handle_response("OUT_OF_TURN")
        return
    response_origin="Rules"
    interpretation_context={};raw_ai_response="";ai_elapsed_ms=0
    raw_transcript=words
    silence_elapsed=0
    turn_silences=0
    $Layout/Heard.text="Heard: "+words
    if words.strip_edges().is_empty():
        $Layout/Heard.text="Heard: No words recognised"
        handle_response("UNCLEAR")
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
    handle_response("SCRIPTED_RESPONSE" if last_meaning=="cue" else "VALID_INTENT",last_meaning)
func _continue_disabled(busy: bool) -> bool:
    return busy or not parser.is_running() or (waiting and not "watch" in route_kinds)
func _process(_delta):
    if response_debug_label!=null:
        response_debug_label.text="Node: %s\nHeard: %s\nMeaning: %s / %s\nOff-script total: %d · streak: %d\nSilence: %d · unclear: %d · technical failures: %d · help: %d · questions: %d" % [frame.get("id",""),raw_transcript,responses.last_response_type,interpreted_intent,responses.offscript_total,responses.offscript_streak,responses.silence_count,responses.unclear_count,responses.technical_failure_count,responses.help_count,responses.question_count]
    if waiting and accepting_speech and not ai_busy and not mic.recording and mic.pid<=0:
        silence_elapsed+=_delta
        if silence_elapsed>=float(responses.definitions.get("silence_seconds",15)):
            silence_elapsed=0
            handle_response("SILENCE")
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
    var meanings: Dictionary={}
    if frame.get("template_version",0)==2:
        meanings={}
        for kind in frame.get("allowed_authored_intents",{}):
            meanings[kind]=frame.allowed_authored_intents[kind].meaning
    var help_words=" ".join(tokens(words))
    if help_words in ["help","repeat","say that again","what do i say","i don t understand","i do not understand","what should i do","what should i say","what am i supposed to do","can you repeat that","could you repeat that","what are you talking about"]:
        handle_response("HELP_OR_REPEAT")
        return
    var exact: Dictionary=meanings.get("exact_meanings",{})
    var normal=" ".join(tokens(words))
    if exact.has(normal) and exact[normal] in route_kinds:
        handle_response("VALID_INTENT",str(exact[normal]))
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
            handle_response("SELECTION",str(route_kinds[direct]))
            return
        # An unoffered yes/no is not a supported route. Let contextual interpretation
        # distinguish an intelligible refusal from uncertainty instead of an endless retry.
    var options=[]
    for i in mini(routes.size(),route_kinds.size()):
        var kind=route_kinds[i]
        if kind in ["silence","watch","next"]:continue
        if frame.has("allowed_authored_intents") and not frame.allowed_authored_intents.has(kind):continue
        if not kind in ai_allowed:ai_allowed.append(kind)
        options.append({"intent":kind,"authored_response":routes[i],"meaning":meanings.get(kind,routes[i])})
    var context={"section":frame.get("id",""),"dialogue":$Layout/Dialogue.text,"cue":cue,"history":ai_history.slice(maxi(0,ai_history.size()-3)),"story_variables":story_variables,"authored_choices":story_state,"off_script_count":off_script_count,"last_off_script_reason":off_script_reason,"allowed_authored_intents":options,"context":frame.get("context",""),"player_task":frame.get("player_task",""),"allowed_system_categories":["UNCLEAR","QUESTION","HELP_OR_REPEAT","OFFSCRIPT"]}
    interpretation_context=context.duplicate(true)
    var rules=FileAccess.get_file_as_string(ai_rules_file)
    var schema={"type":"object","properties":{"fit":{"type":"string","enum":FITS},"intent":{"type":"string","enum":ai_allowed},"evidence":{"type":"string","maxLength":180},"reason":{"type":"string","maxLength":200}},"required":["fit","intent","evidence","reason"],"additionalProperties":false}
    var payload={"model":ai_model,"stream":false,"think":false,"keep_alive":"10m","messages":[{"role":"system","content":rules+"\nScene context: "+JSON.stringify(context)},{"role":"user","content":JSON.stringify(words)}],"format":schema,"options":{"temperature":0,"num_ctx":4096,"num_predict":260}}
    ai_started_at=Time.get_ticks_msec()
    ai_turn=turn
    var error=ai_request.request("http://127.0.0.1:11435/api/chat",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload))
    ai_busy=error==OK
    ai_history.append({"player":words})
    $Layout/Result.text="Game response: Interpreting with local "+ai_model+"…" if ai_busy else "Game response: Local AI unavailable. Retry or use Testing controls."
    if not ai_busy:handle_response("TECHNICAL_FAILURE")
func _ai_completed(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray):
    if not ai_busy or ai_turn!=turn:return
    ai_busy=false
    ai_elapsed_ms=Time.get_ticks_msec()-ai_started_at
    raw_ai_response=bytes.get_string_from_utf8()
    if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
        handle_response("TECHNICAL_FAILURE")
        return
    var envelope=JSON.parse_string(bytes.get_string_from_utf8())
    var answer=null
    if envelope is Dictionary and envelope.get("message") is Dictionary and envelope.get("done_reason","")!="length":
        answer=JSON.parse_string(str(envelope.message.get("content","")))
    response_origin="AI · "+ai_model
    if not answer is Dictionary or not answer.get("intent") in ai_allowed or not answer.get("fit") in FITS or not answer.get("evidence") is String or not answer.get("reason") is String:
        handle_response("TECHNICAL_FAILURE")
        return
    var fit=str(answer.fit)
    var evidence=" ".join(tokens(str(answer.evidence)))
    var spoken=" ".join(tokens(raw_transcript))
    # Reject invented evidence or contradictions between the fit and route, not just invalid IDs.
    if evidence.is_empty() or not (" "+evidence+" ") in (" "+spoken+" "):
        interpretation_context["validation"]="Evidence is absent from current player speech"
        handle_response("UNCLEAR")
        return
    if fit=="supported":
        if not answer.intent in frame.get("allowed_authored_intents",{}):
            interpretation_context["validation"]="Supported fit without a current authored intent"
            handle_response("UNCLEAR")
            return
        last_meaning=str(answer.intent)
        handle_response("VALID_INTENT",last_meaning)
        return
    if not answer.intent in ["unclear","no_match"]:
        interpretation_context["validation"]="Nonmatching fit attempted a story route"
        handle_response("UNCLEAR")
        return
    last_meaning="no_match"
    match fit:
        "unrelated":handle_response("OFFSCRIPT","",true)
        "question":handle_response("QUESTION")
        "help":handle_response("HELP_OR_REPEAT")
        _:handle_response("UNCLEAR")
func _exit_tree():
    _cancel_ai()


func _narrative_retry(_allow_authored_route: bool):
    handle_response("UNCLEAR")

func handle_response(category: String, intent: String = "", deliberate: bool = false):
    var entry={"time":Time.get_datetime_string_from_system(),"node":str(frame.get("id","")),"transcript":raw_transcript,"source":response_origin,"model":ai_model if response_origin.begins_with("AI") else "","allowed":frame.get("allowed_authored_intents",{}).duplicate(true),"cue":cue,"context":interpretation_context.duplicate(true),"raw_ai":raw_ai_response,"ai_ms":ai_elapsed_ms,"requested_category":category,"requested_intent":intent,"offscript_before":responses.offscript_total}
    _apply_response(category,intent,deliberate)
    entry["decision"]=last_response_debug.duplicate(true)
    entry["offscript_after"]=responses.offscript_total
    entry["unclear_count"]=responses.unclear_count
    entry["technical_count"]=responses.technical_failure_count
    entry["next_node"]=str(frame.get("id",""))
    interpretation_log.append(entry)
    if interpretation_log.size()>200:interpretation_log.pop_front()
    if log_interpretations:
        print("[Interpretation] "+JSON.stringify(entry))
        var file=FileAccess.open("user://interpretation_log.jsonl",FileAccess.READ_WRITE)
        if file!=null:file.seek_end();file.store_line(JSON.stringify(entry));file.close()
func copy_interpretation_log():
    var report={"model":ai_model,"rules_sha256":FileAccess.get_sha256(ai_rules_file),"entries":interpretation_log}
    DisplayServer.clipboard_set(JSON.stringify(report,"  "))
    print("Interpretation log copied: ",interpretation_log.size()," entries. Local log: ",ProjectSettings.globalize_path("user://interpretation_log.jsonl"))
func _apply_response(category: String, intent: String = "", deliberate: bool = false):
    last_response_debug={"source":("System" if category in ["SILENCE","TECHNICAL_FAILURE","OUT_OF_TURN"] else response_origin),"node":str(frame.get("id","")),"proposed":category+" / "+intent,"result":"","outcome":"","fallback":""}
    if not category in ResponsePolicy.TYPES:category="UNCLEAR"
    if not waiting or not accepting_speech:category="OUT_OF_TURN"
    if category=="OFFSCRIPT" and not deliberate:category="UNCLEAR"
    var accepted=["SCRIPTED_RESPONSE","VALID_INTENT","SELECTION","COMMAND","CONTEXTUAL_COMMENT"]
    if category in accepted and frame.has("allowed_authored_intents"):
        if not frame.allowed_authored_intents.has(intent) or not _supports_bounded_intent(intent,raw_transcript):
            category="UNCLEAR"
            intent=""
    interpreted_intent=intent
    last_response_debug.result=category+(" / "+intent if not intent.is_empty() else "")
    var template_result={}
    var consequence=0
    if frame.get("template_version",0)==2:
        template_result=responses.record_template(category,deliberate,frame)
        consequence=int(template_result.consequence)
    else:
        consequence=responses.record(category,deliberate)
    off_script_count=responses.offscript_total
    silence_elapsed=0
    var policy=responses.resolve(str(frame.get("id","")),str(frame.get("group","")),category)
    # Imported authored fallback links are node-specific, above act/global defaults.
    if frame.get("response_overrides",{}).has(category):policy=frame.response_overrides[category].duplicate(true)
    var fallback_source="Global"
    if responses.definitions.get("acts",{}).get(str(frame.get("group","")),{}).has(category):fallback_source="Act"
    if responses.definitions.get("nodes",{}).get(str(frame.get("id","")),{}).has(category):fallback_source="Node"
    if frame.get("response_overrides",{}).has(category):fallback_source="Story graph"
    last_response_debug.fallback=fallback_source
    response_resolved.emit(category,intent,consequence)
    if consequence==5:
        _cancel_ai()
        var ending=str(frame.get("endgame",""))
        last_response_debug.outcome="Consequence → "+ending
        if story.starts.has(ending):parser.start(ending)
        return
    if frame.get("template_version",0)==2:
        if frame.get("intro_exempt",false) and category in accepted and intent=="no":
            intro_refusals+=1
            if intro_refusals>intro_refusals_before_takeover:
                last_response_debug.outcome="Repeated refusal → authored forced progression"
                _start_authored_takeover()
                return
        if template_result.get("takeover",false):
            _start_authored_takeover()
            return
        if template_result.get("mic_check",false):
            fallback_reply=str(frame.get("mic_check_reply",""))
            last_response_debug.outcome="Microphone check · retry or continue through authored takeover"
            $Layout/Result.text=fallback_reply
            return
    if policy.get("action","")=="ignore":
        last_response_debug.outcome="Ignored outside player turn"
        return
    # Never use technical/model uncertainty as evidence for a narrative route.
    var route=str(policy.get("route",intent))
    if category in ["TECHNICAL_FAILURE","UNCLEAR"]:route=""
    if category=="OUT_OF_TURN":
        route=str(policy.get("route","")) if policy.get("action","")=="interrupt" else ""
    if category in ["SILENCE","HELP_OR_REPEAT","QUESTION","OFFSCRIPT"]:route=str(policy.get("route",""))
    if route in route_kinds and not route in ["unclear","no_match"]:
        if category=="OUT_OF_TURN":waiting=true # Explicit node-authored interruption only.
        var route_label=str(routes[route_kinds.find(route)])
        _choose(route_kinds.find(route),category+" / "+route,false)
        last_response_debug.outcome="Route: "+route_label+" → "+str(frame.get("id",""))
        last_response_debug.fallback=""
        return
    if not policy.has("reply"):
        policy=responses.resolve("",str(frame.get("group","")),category)
        fallback_source="Act" if responses.definitions.get("acts",{}).get(str(frame.get("group","")),{}).has(category) else "Global"
        last_response_debug.fallback=fallback_source
    last_response_debug.outcome="Stay here · "+fallback_source+" fallback"
    fallback_reply=str(policy.get("reply",""))
    if category=="SILENCE":
        turn_silences+=1
        if turn_silences==1 and frame.get("template_version",0)!=2:
            fallback_reply=""
            last_response_debug.outcome="Stay here · waiting quietly"
            return
        if turn_silences>=3:
            fallback_reply=str(policy.get("stronger_reply",fallback_reply))
            cue_requested.emit()
    if policy.get("action","")=="cue":cue_requested.emit()
    interpretation_trace=category+" / "+intent
    $Layout/Result.text=fallback_reply

func _supports_bounded_intent(intent: String, words: String) -> bool:
    var evidence: Dictionary=frame.get("bounded_evidence",{})
    if not evidence.has(intent):return true
    var spoken=tokens(words)
    var normal=" ".join(spoken)
    # Reject ambiguous alternatives, negation and questions; never guess a direction.
    if "?" in words:return false
    for phrase in ["don t","do not","not","neither","maybe","unsure","know","hate"]:
        if (" "+phrase+" ") in (" "+normal+" "):return false
    var supports=false
    for option in evidence:
        for word in evidence[option]:
            if word in spoken:
                if option!=intent:return false
                supports=true
    return supports

func _build_response_debug():
    response_debug=CanvasLayer.new()
    response_debug.layer=120
    add_child(response_debug)
    response_debug.hide()
    var panel=PanelContainer.new()
    panel.position=Vector2(20,20)
    panel.custom_minimum_size=Vector2(650,0)
    response_debug.add_child(panel)
    var box=VBoxContainer.new()
    panel.add_child(box)
    var title=Label.new()
    title.text="Interpretation diagnostics · F3 to close"
    box.add_child(title)
    response_debug_label=Label.new()
    box.add_child(response_debug_label)
    var copy_log=Button.new()
    copy_log.text="Copy interpretation log"
    copy_log.pressed.connect(func():copy_interpretation_log();copy_log.text="Copied — paste into chat")
    box.add_child(copy_log)
    debug_category=OptionButton.new()
    for category in ResponsePolicy.TYPES:debug_category.add_item(category)
    box.add_child(debug_category)
    debug_intent=OptionButton.new()
    box.add_child(debug_intent)
    var trigger=Button.new()
    trigger.text="Manual category test — bypasses AI"
    trigger.pressed.connect(func():
        if mic.recording or mic.pid>0:return
        _cancel_ai()
        var intent=debug_intent.get_item_text(debug_intent.selected) if debug_intent.selected>0 else ""
        response_origin="Manual test"
        raw_transcript="[Manual category test]"
        handle_response(debug_category.get_item_text(debug_category.selected),intent,debug_category.get_item_text(debug_category.selected)=="OFFSCRIPT"))
    box.add_child(trigger)
func _input(event):
    if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:
        response_debug.visible=not response_debug.visible
        debug_intent.clear()
        debug_intent.add_item("Use fallback")
        for kind in route_kinds:debug_intent.add_item(kind)
        get_viewport().set_input_as_handled()

func _recover_legacy_story():
    # An open editor can save a cached pre-semantic graph over the newer import.
    # Recover the existing DialogueData contract from the last explicit Twine import.
    if story==null or not story.resource_path.ends_with("acts_0_3_cleaned.tres"):return
    var stale=false
    for node in story.nodes.values():
        var signal_value=str(node.get("signalValue",""))
        if not signal_value.begins_with("frame:"):continue
        var data=JSON.parse_string(signal_value.trim_prefix("frame:"))
        if data is Dictionary and not data.has("events"):stale=true;break
    if not stale:return
    var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://Story/StageActs/Graph/acts_0_3_manifest.json"))
    if not manifest is Dictionary or manifest.is_empty():
        push_error("Story display data is missing. Reimport the current Twine working copy.")
        return
    var recovered=DialogueData.new()
    var ids={}
    var index=0
    for name in manifest:
        ids[name]=str(index)
        index+=1
    for name in manifest:
        var entry=manifest[name]
        if not entry is Dictionary or not entry.get("frame",{}).has("events"):return
        var suffix=ids[name]
        recovered.starts[name]="0_"+suffix
        recovered.nodes["0_"+suffix]={"start_id":name,"link":"3_"+suffix}
        recovered.nodes["3_"+suffix]={"signalValue":"frame:"+JSON.stringify(entry.frame),"link":"1_"+suffix}
        var text=PackedStringArray()
        for event in entry.frame.events:
            if event.get("kind","") in ["dialogue","narration"]:text.append(str(event.get("text","")))
        var options={}
        for i in entry.links.size():
            var target=str(entry.links[i][1])
            if not ids.has(target):return
            options[i]={"text":str(entry.links[i][0]),"link":"3_"+ids[target],"condition":[]}
        recovered.nodes["1_"+suffix]={"speaker":"","dialogue":"\n\n".join(text),"options":options}
    story=recovered
    push_warning("Recovered outdated story display data from the last Twine import. Reload the story graph in the editor before saving it.")

func _start_authored_takeover():
    var target=str(frame.get("takeover_start",""))
    if not story.starts.has(target):return
    _cancel_ai()
    responses.mic_check_pending=false
    responses.technical_streak=0
    last_response_debug.outcome="Authored takeover → "+target
    parser.start(target)

func continue_after_mic_check():
    if not responses.mic_check_pending or mic.recording or mic.pid>0:return
    _start_authored_takeover()
