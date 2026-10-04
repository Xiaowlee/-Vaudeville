class_name StoryEntry
extends Resource
# Stable legacy destinations are retained internally; new entries get block-relative IDs.
@export_storage var entry_id := ""
func to_beat() -> StageBeat:
	return StageBeat.new()
static func copy_fields(source: Resource, target: Resource) -> void:
	var names := {}
	for p in target.get_property_list(): names[p.name] = true
	for p in source.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name != "script" and names.has(p.name):
			target.set(p.name, source.get(p.name))
