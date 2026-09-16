extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func mouse(point: Vector2, pressed: bool, motion := false) -> void:
	var event: InputEventMouse
	if motion:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)

func drag(card: Control, target: Vector2) -> void:
	var click := card.global_position + Vector2(22, 18)
	mouse(click, false, true)
	await process_frame
	mouse(click, true)
	await process_frame
	check(card.dragging, "Actual card starts held drag")
	check(card.click_offset.distance_to(Vector2(22, 18)) < 1, "Click offset preserved")
	mouse(target, true, true)
	await create_timer(0.3).timeout
	check(card.global_position.distance_to(target - Vector2(22, 18)) < 2, "Actual card follows mouse")
	mouse(target, false)
	await create_timer(0.4).timeout

func run() -> void:
	root.size = Vector2i(1152, 800)
	root.content_scale_size = Vector2i(1152, 800)
	var scene = load("res://Scene/prototype_1.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.get_node("SpeechMonitor").enabled = false
	await process_frame
	var story = scene.get_node("Margin/Layout/Story")
	var sentence = story.get_node("Sentence")
	var correct = story.get_node("On")
	var wrong = story.get_node("Off")
	var target: Vector2 = sentence.drop_zone.get_global_rect().get_center()
	check(scene.get_node("Dark bg").modulate.a == 1.0, "Dark starts on")
	check(scene.get_node("Margin/Layout/Room/AnimatedSprite2D").modulate.a == 0.0, "Character starts obscured")
	await drag(wrong, target)
	check(wrong.position.distance_to(wrong.origin) < 1 and not wrong.locked, "Wrong word snaps back and remains draggable")
	await drag(correct, Vector2(20, 350))
	check(correct.position.distance_to(correct.origin) < 1 and not correct.locked, "Correct word outside zone returns")
	await drag(correct, target)
	check(correct.locked and sentence.state == sentence.State.READY_TO_READ, "Correct snap locks and readies sentence")
	check(sentence.hint.visible and sentence.get_node("HBoxContainer/PrefixLabel").get_theme_constant("outline_size") == 3, "Prompt and ready outline enabled")
	for unrelated in ["She turns condiments", "she times higher in tonight's", "sheet size on July", "she turns off the light"]:
		sentence.submit_transcript(unrelated)
		check(sentence.state == sentence.State.READY_TO_READ, "Reject unrelated: " + unrelated)
	sentence.submit_transcript("SHE TURNS ON THE LIGHT!")
	await create_timer(2.2).timeout
	check(scene.completed and scene.response_finished, "Completed response finishes")
	check(not sentence.hint.visible and sentence.get_node("HBoxContainer/PrefixLabel").get_theme_constant("outline_size") == 0, "Completion removes outline/prompt")
	check(scene.get_node("Dark bg").modulate.a == 0.0 and scene.get_node("Margin/Layout/Room").light_amount == 1.0, "Light reveals character")
	check(story.get_node("Next").visible, "Next available after response")
	check(scene.transition_delay == 5.0, "Five second transition configured")
	var sprite: AnimatedSprite2D = scene.get_node("Margin/Layout/Room/AnimatedSprite2D")
	check(sprite.sprite_frames.get_animation_loop("standby") and sprite.is_playing(), "Standby loops")
	# Test action completion with a temporary in-memory animation, not new artwork.
	var room = scene.get_node("Margin/Layout/Room")
	sprite.sprite_frames.add_animation("test_action")
	sprite.sprite_frames.add_frame("test_action", sprite.sprite_frames.get_frame_texture("standby", 0))
	sprite.sprite_frames.add_frame("test_action", sprite.sprite_frames.get_frame_texture("standby", 1))
	sprite.sprite_frames.set_animation_speed("test_action", 20.0)
	room.action_animation = &"test_action"
	room.has_played = false
	await room.play_once()
	check(not sprite.sprite_frames.get_animation_loop("test_action") and sprite.frame == 1 and not sprite.is_playing(), "Action plays once and holds last frame")
	room.has_played = false
	room.return_to_standby = true
	await room.play_once()
	check(sprite.animation == &"standby" and sprite.is_playing(), "Configurable return to standby")
	# Temporary valid destination proves the real timeout path without adding story scenes.
	scene.next_scene = "res://Scene/Intro.tscn"
	scene.auto_timer.start(scene.transition_delay)
	await create_timer(4.7).timeout
	check(current_scene == scene, "No early auto-advance")
	await create_timer(0.5).timeout
	check(current_scene.scene_file_path == "res://Scene/Intro.tscn", "Five-second auto-advance loads destination")
	print("SCENE0_TEST_FAILURES=", failures)
	quit(failures)
