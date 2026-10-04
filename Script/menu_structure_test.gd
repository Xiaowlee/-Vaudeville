extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, detail: String) -> void:
	if value: print("PASS: ", detail)
	else:
		failures += 1
		push_error(detail)
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.task-checks/" + label + ".png")
func run() -> void:
	root.size = Vector2i(1152, 800)
	root.content_scale_size = Vector2i(1152, 800)
	change_scene_to_file("res://Scene/00_main_menu.tscn")
	await process_frame
	await process_frame
	check(current_scene.has_node("Menu/Prototype1") and current_scene.has_node("Menu/Prototype2"), "Intro offers both routes")
	await capture("intro")
	for pair in [["Prototype1", "2.2_a_performer_baseline"], ["Prototype2", "2.2_c_increased_agency"]]:
		current_scene.get_node("Menu/" + pair[0]).pressed.emit()
		await process_frame
		await process_frame
		check(current_scene.scene_file_path == "res://Scene/" + pair[1] + ".tscn", "Correct destination: " + pair[1])
		check(current_scene.get_node("%StoryText") is RichTextLabel, "Story text is an editable node")
		check(current_scene.get_node("VisualPlaceholder") is ColorRect, "Simple visual placeholder")
		check(current_scene.valid, "Mode story configuration is valid")
		await capture(pair[1])
		current_scene.get_node("Back").pressed.emit()
		await process_frame
		await process_frame
		check(current_scene.scene_file_path == "res://Scene/00_main_menu.tscn", "Back returns to Intro")
	current_scene.get_node("Menu/Previous").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://Scene/00_previous_prototypes_menu.tscn", "Previous menu separate")
	check(current_scene.prototype_1_scene == "res://Scene/2.1_continuous_narration.tscn", "Previous 1 preserved")
	check(current_scene.prototype_2_scene == "res://Scene/2.1_narrator_agency.tscn", "Previous 2 preserved")
	check(ResourceLoader.exists(current_scene.earlier_scene), "Earlier prototype accessible")
	current_scene.get_node("Menu/Back").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://Scene/00_main_menu.tscn", "Previous Back works")
	check(ProjectSettings.get_setting("application/config/name") == "Folio 2 Test 2", "Copied project has separate runtime identity")
	print("MENU_STRUCTURE_FAILURES=", failures)
	quit(failures)
