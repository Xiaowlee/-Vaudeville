extends SceneTree
func _initialize():call_deferred("run")
func run():
    var mic=load("res://Scene/StageActs/Graph/local_whisper.tscn").instantiate()
    root.add_child(mic)
    mic.transcribe(ProjectSettings.globalize_path("res://.local-speech/jfk.wav"))
    while mic.pid>0:await create_timer(0.1).timeout
    var words=mic.transcript.text.to_lower()
    print("WHISPER FIXTURE: ",words)
    var ok="ask not" in words and "country" in words
    print("PASS local audio fixture" if ok else "FAIL local audio fixture")
    quit(0 if ok else 1)