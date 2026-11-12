extends RefCounted
## Local text only. The main menu Inspector chooses the approved report folder.
const BUILD := "2.6.3 Expo candidate"
static var events: Array[Dictionary] = []
static var active := false
static var participant := "P01"
static var session_id := ""
static var folder := "D:/RMIT/Master/Studio 1/Folio 2/2.6 Fix/Feedback/Playtest Reports"
static var started_ms := 0
static var ended_ms := 0
static var outcome := "In progress"
static var attempt := 0
static var save_error := ""
static var hardware: Dictionary = {}

static func begin_session() -> bool:
    if active:
        finish("Stopped / new session")
        if not save_error.is_empty():return false
    var preflight=events.filter(func(item):return str(item.action).begins_with("preparation_"))
    events.clear()
    active=true;attempt=0;outcome="In progress";started_ms=Time.get_ticks_msec();ended_ms=0
    session_id=Time.get_datetime_string_from_system().replace(":","-")+"-"+str(Time.get_ticks_usec())
    hardware={"os":OS.get_name(),"os_version":OS.get_version(),"cpu":OS.get_processor_name(),"cpu_threads":OS.get_processor_count(),"memory":OS.get_memory_info(),"gpu":RenderingServer.get_video_adapter_name(),"speech_backend":"whisper.cpp CPU / base.en", "ai_model":"qwen3:4b","ai_compute_backend":"Not measured"}
    save_error=""
    var err=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    if err!=OK:save_error="Could not create the playtest report folder."
    record("session_started",{"participant":participant,"build":BUILD,"hardware":hardware})
    for item in preflight:record(item.action,item.details)
    return save_error.is_empty()

static func record(action: String, fields: Dictionary = {}) -> void:
    if action=="recording_started":attempt+=1
    var event={"time":Time.get_datetime_string_from_system(),"elapsed_ms":Time.get_ticks_msec()-started_ms if active else 0,"attempt":attempt,"action":action,"details":fields.duplicate(true)}
    events.append(event)
    if events.size()>2000:events.pop_front()
    if not active:return
    var file_path=folder.path_join(session_id+".jsonl")
    var file=FileAccess.open(file_path,FileAccess.READ_WRITE if FileAccess.file_exists(file_path) else FileAccess.WRITE)
    if file==null:save_error="Could not save the playtest report.";return
    file.seek_end();file.store_line(JSON.stringify(event));file.close()

static func timing_summary(action: String) -> String:
    var values: Array[float]=[]
    for event in events:
        if event.action==action and event.details.has("duration_ms"):values.append(float(event.details.duration_ms)/1000.0)
    if values.is_empty():return "No completed attempts"
    var first=values[0]
    values.sort()
    var middle=values.size()/2
    var median=values[middle] if values.size()%2 else (values[middle-1]+values[middle])/2.0
    return "%d attempts · first %.2fs · median %.2fs · longest %.2fs" % [values.size(),first,median,values[-1]]

static func summary() -> String:
    var counts={}
    var incidents: Array[String]=[]
    for event in events:
        counts[event.action]=int(counts.get(event.action,0))+1
        if event.action in ["speech_failed","preparation_failed"] or (event.action=="interpretation_returned" and int(event.details.get("http_status",200))!=200):
            incidents.append(str(event.time)+" · "+str(event.action)+" · "+JSON.stringify(event.details))
    var end=ended_ms if ended_ms>0 else Time.get_ticks_msec()
    var ram_gb=float(hardware.get("memory",{}).get("physical",0))/1073741824.0
    return "Beneath the Lines · %s\nParticipant: %s · Session: %s\nOutcome: %s · Duration: %.1f minutes\nCPU: %s · Threads: %s · RAM: %.1f GB\nGPU: %s · OS: %s\nSpeech: %s\nInterpretation: %s\nEvents: %s\nIssues:\n%s\nFull event history: %s\n%s" % [BUILD,participant,session_id,outcome,(end-started_ms)/60000.0,hardware.get("cpu","Not recorded"),hardware.get("cpu_threads","?"),ram_gb,hardware.get("gpu","Not recorded"),hardware.get("os","?"),timing_summary("recognition_finished"),timing_summary("interpretation_returned"),JSON.stringify(counts),"\n".join(incidents.slice(-12)) if not incidents.is_empty() else "None recorded",ProjectSettings.globalize_path(folder.path_join(session_id+".jsonl")),save_error]

static func save() -> String:
    if session_id.is_empty():return "No playtest session has started yet."
    var target=folder.path_join(session_id+"-summary.txt")
    var file=FileAccess.open(target,FileAccess.WRITE)
    if file==null:save_error="Could not save the report summary.";return save_error
    file.store_string(summary());file.close()
    return "Report saved: "+ProjectSettings.globalize_path(target)

static func finish(result: String):
    if not active:return
    outcome=result;ended_ms=Time.get_ticks_msec()
    record("session_finished",{"outcome":result})
    save();active=false

static func copy() -> void:
    DisplayServer.clipboard_set(summary() if not session_id.is_empty() else JSON.stringify({"build":BUILD,"events":events},"  "))
