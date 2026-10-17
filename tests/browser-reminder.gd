extends SceneTree
class OpenSocket extends RefCounted:
 func get_ready_state(): return WebSocketPeer.STATE_OPEN
class Bridge extends Node:
 var socket = OpenSocket.new()
 func send_speech(_message): pass
func _initialize(): call_deferred("run")
func run():
 var game = load("res://Scene/StageActs/2.3_stage_acts_1_3.tscn").instantiate()
 root.add_child(game)
 var speech = game.get_node("SpeechMonitor")
 var bridge = Bridge.new()
 root.add_child(bridge)
 speech.recognition_backend = 3
 speech.relay_bridge = bridge
 speech.listening = true
 speech.worker_ready = false
 var pre = game.get_node("PreShow")
 pre.state = "STARTING"
 pre.elapsed = 100
 pre._process(0)
 assert(pre.state == "STARTING", "Browser button wait must not become mic failure")
 speech.worker_ready = true
 pre._process(0)
 assert(pre.state == "LISTENING")
 speech.relay_turn = "test-turn"
 speech._relay_event({"type":"speech_error","session_id":"test-turn","error":"browser_disconnected","recoverable":true})
 assert(speech.listening and not speech.worker_ready)
 pre._process(0)
 assert(pre.state == "STARTING")
 speech._relay_event({"type":"speech_status","session_id":"test-turn","status":"listening"})
 pre._process(0)
 assert(pre.state == "LISTENING")
 # Reproduce speech detected, then cross the five-second reminder deadline.
 pre.opening_input = pre.opening_input.duplicate()
 pre.opening_input.reminder_enabled = true
 pre.opening_input.reminder_delay = 5.0
 pre.opening_input.reminder_repeat = true
 speech._relay_event({"type":"speech_status","session_id":"test-turn","status":"Speech detected — recognizing words"})
 for i in range(10):
  speech._process(1.0)
  pre._process(1.0)
 assert(pre.state == "LISTENING" and speech.listening, "Reminder must not stop pending browser recognition")
 assert(pre.reminder_count == 0)
 speech._relay_event({"type":"speech_result","session_id":"test-turn","is_final":true,"transcript":"unclassified test"})
 assert(not speech.awaiting_browser_result())
 pre._process(6.0)
 assert(pre.reminder_count == 1, "Reminder must still work after recognition finishes")
 # Pending speech is bounded, even when the provider never supplies final words.
 speech.listening = true
 speech.worker_ready = true
 speech.relay_turn = "second-turn"
 speech._relay_event({"type":"speech_status","session_id":"second-turn","status":"Speech detected — recognizing words"})
 speech._process(speech.browser_result_wait_seconds + 1.0)
 assert(not speech.awaiting_browser_result())
 speech.stop_listening()
 print("PASS: five-second cutoff reproduced and prevented; reminders resume after final text; pending recognition has a bounded wait")
 game.free()
 bridge.free()
 quit()
