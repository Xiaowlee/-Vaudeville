extends RefCounted
const TYPES = ["SCRIPTED_RESPONSE","VALID_INTENT","CONTEXTUAL_COMMENT","QUESTION","HELP_OR_REPEAT","SILENCE","UNCLEAR","TECHNICAL_FAILURE","COMMAND","SELECTION","OFFSCRIPT","OUT_OF_TURN"]
var definitions: Dictionary = {}
var offscript_total := 0
var offscript_streak := 0
var last_response_type := ""
var silence_count := 0
var unclear_count := 0
var technical_failure_count := 0
var help_count := 0
var question_count := 0
func reset():
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
