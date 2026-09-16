@tool
extends Control
## Resource owns wording. Scene nodes own layout, anchors and typography.
signal ready_to_read
signal word_inserted(word: String)
signal performed(sentence_id: StringName)
signal state_changed(state: int)

enum State { INCOMPLETE, READY_TO_READ, COMPLETED }
@export var definition: Resource:
	set(value):
		if definition != null and definition.changed.is_connected(_content_changed):
			definition.changed.disconnect(_content_changed)
		definition = value
		if definition != null: definition.changed.connect(_content_changed)
		if is_node_ready(): _content_changed()
## First card is the correct word; following cards display the resource's distractors.
@export var word_cards: Array[NodePath] = []:
	set(value):
		word_cards = value
		if is_node_ready(): _content_changed()
@export_group("Scene References")
@export_node_path("Label") var prefix_path := NodePath("HBoxContainer/PrefixLabel")
@export_node_path("Label") var suffix_path := NodePath("HBoxContainer/SuffixLabel")
@export_node_path("Control") var drop_zone_path := NodePath("HBoxContainer/WordDropZone")
@export_node_path("Label") var hint_path := NodePath("ReadOutLoudLabel")
@export_group("Appearance")
@export var incomplete_color := Color("777c88")
@export var ready_color := Color("48404b")
@export var completed_color := Color("f53cc7")
@export var fit_blank_to_word := true:
	set(value):
		fit_blank_to_word = value
		if is_node_ready(): _content_changed()
var reading_enabled := true
var voice_required := true
var debug_logging := true
var state := State.INCOMPLETE
var inserted_card: Button
var outlines: Dictionary = {}
var content_valid := false
@onready var drop_zone: Control = get_node(drop_zone_path)
@onready var hint: Label = get_node(hint_path)
@onready var prefix: Label = get_node(prefix_path)
@onready var suffix: Label = get_node(suffix_path)

func _ready() -> void:
	if Engine.is_editor_hint():
		_content_changed()
		return
	for label in [prefix, suffix]:
		outlines[label] = label.get_theme_constant("outline_size")
	for path in word_cards:
		var card = get_node_or_null(path)
		if card == null: continue
		card.released.connect(_card_released)
		card.drag_moved.connect(_card_moved)
	drop_zone.item_rect_changed.connect(_align_inserted_card)
	drop_zone.get_parent().item_rect_changed.connect(_align_inserted_card)
	item_rect_changed.connect(_align_inserted_card)
	_apply_state()

func _content_changed() -> void:
	# Live Inspector preview; don't rewrite a sentence while a player is performing it.
	if Engine.is_editor_hint():
		configure_content()
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	if definition == null: return PackedStringArray(["The gameplay root supplies the Sentence Definition resource."])
	var errors: PackedStringArray = definition.validation_errors()
	if word_cards.size() < definition.choice_words().size():
		errors.append("Add WordCard instances and register their paths in Word Cards for all choices.")
	return errors

func configure_content() -> bool:
	if not is_node_ready() or definition == null: return false
	var errors := _get_configuration_warnings()
	content_valid = errors.is_empty()
	if not content_valid:
		if not Engine.is_editor_hint(): push_error("[Configuration] " + "; ".join(errors))
		return false
	prefix.text = definition.prefix_text()
	suffix.text = definition.suffix_text()
	hint.text = definition.read_prompt
	drop_zone.get_node("Blank").text = definition.blank_text
	var choices: PackedStringArray = definition.choice_words()
	for i in word_cards.size():
		var card = get_node_or_null(word_cards[i]) as Button
		if card == null:
			content_valid = false
			push_warning("[Configuration] Word Cards path missing: " + str(word_cards[i]))
			continue
		card.visible = i < choices.size()
		if i < choices.size(): card.text = choices[i]
	# Font/size edits also resize the blank in the editor, without altering anchors.
	for path in word_cards:
		var sizing_card = get_node_or_null(path) as Control
		if sizing_card != null:
			if not sizing_card.minimum_size_changed.is_connected(_fit_blank): sizing_card.minimum_size_changed.connect(_fit_blank)
			if not sizing_card.resized.is_connected(_fit_blank): sizing_card.resized.connect(_fit_blank)
	var blank: Label = drop_zone.get_node("Blank")
	if not blank.minimum_size_changed.is_connected(_fit_blank): blank.minimum_size_changed.connect(_fit_blank)
	_fit_blank()
	return content_valid

func _fit_blank() -> void:
	if fit_blank_to_word and not word_cards.is_empty():
		var correct = get_node_or_null(word_cards[0]) as Button
		if correct != null and "content_minimum" in drop_zone:
			var blank: Label = drop_zone.get_node("Blank")
			drop_zone.content_minimum = correct.size.max(correct.get_combined_minimum_size()).max(blank.get_combined_minimum_size())
	elif "content_minimum" in drop_zone:
		drop_zone.content_minimum = Vector2.ZERO

func set_choices_visible(value: bool) -> void:
	var count: int = definition.choice_words().size() if definition != null else 0
	for i in word_cards.size():
		var card = get_node_or_null(word_cards[i])
		if card != null: card.visible = value and i < count

func _card_moved(card: Control) -> void:
	drop_zone.get_node("HoverFeedback").visible = content_valid and state == State.INCOMPLETE and drop_zone.get_global_rect().has_point(get_global_mouse_position()) and definition.normalized(card.text) == definition.normalized(definition.correct_word)

func _card_released(card: Control) -> void:
	drop_zone.get_node("HoverFeedback").hide()
	if not content_valid or state != State.INCOMPLETE or not drop_zone.get_global_rect().has_point(get_global_mouse_position()) or definition.normalized(card.text) != definition.normalized(definition.correct_word):
		card.return_home()
		return
	_insert(card)
	_log("Drag success", card.text)
	word_inserted.emit(card.text)
	if reading_enabled: enable_reading()

func _insert(card: Button) -> void:
	inserted_card = card
	card.show()
	card.snap_to(drop_zone.get_node("SnapPoint").global_position - card.size / 2.0)
	outlines[card] = card.get_theme_constant("outline_size")
	drop_zone.get_node("Blank").hide()
	_apply_state()

func _align_inserted_card() -> void:
	if inserted_card != null:
		inserted_card.set_deferred("global_position", drop_zone.get_node("SnapPoint").global_position - inserted_card.size / 2.0)

func _apply_state() -> void:
	var color: Color = incomplete_color if state == State.INCOMPLETE else (ready_color if state == State.READY_TO_READ else completed_color)
	var parts: Array = [prefix, suffix]
	if inserted_card != null: parts.append(inserted_card)
	for part in parts:
		part.add_theme_color_override("font_color", color)
		part.add_theme_color_override("font_disabled_color", color)
		part.add_theme_constant_override("outline_size", outlines.get(part, 0) if state == State.READY_TO_READ else 0)
	hint.visible = state == State.READY_TO_READ and voice_required
	state_changed.emit(state)

func submit_transcript(text: String) -> void:
	print("[Speech final] ", text)
	if voice_required and state == State.READY_TO_READ and definition.matches(text):
		_log("Voice success", text)
		accept_speech()

func accept_speech() -> void:
	if state != State.READY_TO_READ: return
	state = State.COMPLETED
	_apply_state()
	performed.emit(definition.sentence_id)

func enable_reading() -> void:
	reading_enabled = true
	if inserted_card == null or state != State.INCOMPLETE: return
	state = State.READY_TO_READ
	_apply_state()
	ready_to_read.emit()

func reveal_correct_word() -> void:
	if content_valid and not word_cards.is_empty(): _insert(get_node(word_cards[0]))

func _log(event: String, detail: String) -> void:
	if debug_logging: print("[", definition.sentence_id, "][", event, "] ", detail)
