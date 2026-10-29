extends RefCounted
const TYPES = ["SCRIPTED_RESPONSE","VALID_INTENT","CONTEXTUAL_COMMENT","QUESTION","HELP_OR_REPEAT","SILENCE","UNCLEAR","TECHNICAL_FAILURE","COMMAND","SELECTION","OFFSCRIPT","OUT_OF_TURN"]
var definitions: Dictionary = {}
var conversation_attempts: Dictionary = {}
var technical_streak := 0
var mic_check_pending := false
var offscript_total := 0
var offscript_streak := 0
var last_response_type := ""
var silence_count := 0
var unclear_count := 0
var technical_failure_count := 0
var help_count := 0
var question_count := 0
func reset():
    conversation_attempts.clear()
    technical_streak=0
    mic_check_pending=false
    offscript_total=0
    offscript_streak=0
    last_response_type=""
    silence_count=0
    unclear_count=0
    technical_failure_count=0
    help_count=0
    question_count=0
func resolve(node: String, act: String, category: String) -> Dictionary:
    for layer in [definitions.get("nodes",{}).get(node,{}),definitions.get("acts",{}).get(act,{}),definitions.get("global",{})]:
        if layer.has(category):return layer[category].duplicate(true)
    return {"action":"stay","reply":"Please try again."}
func record(category: String, deliberate: bool) -> int:
    last_response_type=category
    match category:
        "OFFSCRIPT":
            if deliberate:
                offscript_total+=1
                offscript_streak+=1
                var limits=definitions.get("thresholds",{})
                if offscript_total==int(limits.get("termination",5)):return 5
                if offscript_total==int(limits.get("disruption",3)):return 3
                if offscript_total==int(limits.get("correction",1)):return 1
        "SILENCE":silence_count+=1
        "UNCLEAR":unclear_count+=1
        "TECHNICAL_FAILURE":technical_failure_count+=1
        "HELP_OR_REPEAT":
            help_count+=1
            offscript_streak=0
        "QUESTION":
            question_count+=1
            offscript_streak=0
        "SCRIPTED_RESPONSE","VALID_INTENT","SELECTION","COMMAND","CONTEXTUAL_COMMENT":offscript_streak=0
    return 0

# New Twine template counts unrelated attempts per conversation, not a global streak.
func record_template(category: String, deliberate: bool, frame: Dictionary) -> Dictionary:
    var result={"consequence":0,"takeover":false,"mic_check":false}
    var conversation=str(frame.get("conversation",frame.get("id","")))
    if category in ["UNCLEAR","TECHNICAL_FAILURE"]:
        record(category,false)
        technical_streak+=1
        mic_check_pending=technical_streak>=3
        result.mic_check=mic_check_pending
        return result
    if category!="SILENCE" and category!="OUT_OF_TURN":
        technical_streak=0
        mic_check_pending=false
    if category=="OFFSCRIPT":
        last_response_type=category
        if deliberate:
            var attempts=int(conversation_attempts.get(conversation,0))+1
            conversation_attempts[conversation]=attempts
            # Intro can be taken over locally, but never earns resistance penalties.
            if not frame.get("intro_exempt",false):
                offscript_total+=1
                offscript_streak+=1
                if offscript_total>=5:
                    result.consequence=5
                    return result
            result.takeover=attempts>=2
    else:
        record(category,false)
    return result
