@tool
extends Resource
## One reusable story sentence. Missing word index is zero-based.
@export_group("Narrative")
@export_multiline var sentence_text: String = "":
    set(value):
        sentence_text = value
        emit_changed()
@export var correct_word: String = "":
    set(value):
        correct_word = value
        emit_changed()
## Zero-based index: the first word is 0. Must identify Correct Word in Sentence Text.
@export_range(0, 100) var missing_word_index: int = 0:
    set(value):
        missing_word_index = value
        emit_changed()
## The correct word is choice 1; these supply the remaining choices in order.
@export var distractors: PackedStringArray = []:
    set(value):
        distractors = value
        emit_changed()
@export var sentence_id: StringName = &"":
    set(value):
        sentence_id = value
        emit_changed()
@export_group("Required Inputs")
@export var require_drag := true
@export var require_voice := true
## Uses the existing smile relay. Order stays face, then drag if enabled, then voice.
@export var require_face := false
@export_group("Prompts")
@export var blank_text := "_____":
    set(value):
        blank_text = value
        emit_changed()
@export var read_prompt := "Read out loud":
    set(value):
        read_prompt = value
        emit_changed()
@export var idle_prompt := "Mic idle"
@export var face_prompt := "On your phone: enable the camera and smile."
@export var face_success_prompt := "Ready"
@export var accepted_prompt := "Accepted"
@export_group("Recognition")
@export_range(0.5, 1.0, 0.01) var match_threshold: float = 0.78
var words: PackedStringArray:
    get: return sentence_text.split(" ", false)
var missing_indices: PackedInt32Array:
    get: return PackedInt32Array([missing_word_index])

func normalized(text: String) -> String:
    var punctuation := RegEx.new()
    punctuation.compile("[^a-z0-9 ]")
    return " ".join(punctuation.sub(text.to_lower(), "", true).split(" ", false))

func matches(transcript: String) -> bool:
    var heard := normalized(transcript)
    var target := normalized(sentence_text)
    if heard.is_empty() or target.is_empty():
        return false
    # Preserve the key verb/preposition: 'off' must not match an 'on' sentence.
    if not heard.split(" ").has(normalized(correct_word)):
        return false
    var a := heard.split(" ")
    var b := target.split(" ")
    var previous: Array[int] = []
    for j in range(b.size() + 1): previous.append(j)
    for i in a.size():
        var current: Array[int] = [i + 1]
        for j in b.size():
            current.append(mini(mini(current[j] + 1, previous[j + 1] + 1), previous[j] + (0 if a[i] == b[j] else 1)))
        previous = current
    return 1.0 - float(previous[b.size()]) / maxi(a.size(), b.size()) >= match_threshold

func choice_words() -> PackedStringArray:
    var result := PackedStringArray([correct_word])
    result.append_array(distractors)
    return result

func prefix_text() -> String:
    return " ".join(words.slice(0, missing_word_index))

func suffix_text() -> String:
    return " ".join(words.slice(missing_word_index + 1))

func validation_errors() -> PackedStringArray:
    var errors := PackedStringArray()
    if sentence_text.strip_edges().is_empty(): errors.append("Sentence Text is empty.")
    if correct_word.strip_edges().is_empty(): errors.append("Correct Word is empty.")
    if missing_word_index >= words.size():
        errors.append("Missing Word Index is outside the sentence.")
    elif normalized(words[missing_word_index]) != normalized(correct_word):
        errors.append("Missing Word Index must point to Correct Word in Sentence Text (first word = 0).")
    var seen := PackedStringArray([normalized(correct_word)])
    for word in distractors:
        var value := normalized(word)
        if value.is_empty() or value in seen: errors.append("Choices must be non-empty and different.")
        seen.append(value)
    return errors

func rejected_phrases() -> PackedStringArray:
    var result := PackedStringArray()
    if not validation_errors().is_empty(): return result
    for word in distractors:
        var phrase := words
        phrase[missing_word_index] = word
        result.append(normalized(" ".join(phrase)))
    return result
