extends RefCounted
var label: Control
var settings: Resource
var content := ""
var count := 0
var remaining := 0.0
var typing := false
func begin(target: Control, profile: Resource) -> void:
	label = target
	settings = profile
	content = target.get_parsed_text() if target is RichTextLabel else target.text
	count = 0
	typing = settings.typing_enabled and not content.is_empty()
	label.visible_characters = 0 if typing else -1
	remaining = settings.delay_before_typing if typing else (settings.delay_after_typing if not content.is_empty() else 0.0)
func reveal() -> void:
	count = content.length()
	typing = false
	label.visible_characters = -1
	remaining = settings.delay_after_typing
## Returns unused time after typing/post-pause, for the existing reading hold.
func advance(delta: float) -> float:
	if not is_instance_valid(label): return delta
	while delta >= remaining:
		delta -= remaining
		remaining = 0
		if not typing: return delta
		count += 1
		label.visible_characters = count
		if count >= content.length():
			typing = false
			remaining = settings.delay_after_typing
		else:
			remaining = 1.0 / maxf(1.0, settings.characters_per_second)
			if content[count - 1] in [",", ";", ":"]: remaining += settings.comma_pause
			elif content[count - 1] in [".", "!", "?"]: remaining += settings.punctuation_pause
	remaining -= delta
	return 0.0
func finished() -> bool:
	return not typing and remaining <= 0
