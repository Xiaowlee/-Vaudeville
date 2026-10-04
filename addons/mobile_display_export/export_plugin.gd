@tool
extends EditorExportPlugin
## Only presets with this custom feature are affected.
const FEATURE := "mobile_display"
## Autoloads the phone display never uses. Restored in the editor right after export.
const STRIPPED := ["autoload/PhoneSession", "autoload/UIAudio", "autoload/DialogueManager"]
var saved := {}

func _get_name() -> String:
	return "MobileDisplayStripAutoloads"

func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not saved.is_empty(): return
	var keys: Array = STRIPPED if features.has(FEATURE) else (["autoload/DialogueManager"] if features.has("stage_web") else [])
	for key in keys:
		if ProjectSettings.has_setting(key):
			saved[key] = [ProjectSettings.get_setting(key), ProjectSettings.get_order(key)]
			ProjectSettings.set_setting(key, null)
	if not saved.is_empty(): print("Mobile display export: leaving out ", saved.keys())

func _export_end() -> void:
	for key in saved:
		ProjectSettings.set_setting(key, saved[key][0])
		ProjectSettings.set_order(key, saved[key][1])
	saved.clear()
