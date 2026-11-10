extends RefCounted

const BUILD := "2.6.2 Windows playtest"
static var events: Array[Dictionary] = []

static func record(action: String, fields: Dictionary = {}) -> void:
    events.append({"time": Time.get_datetime_string_from_system(), "action": action, "details": fields})
    if events.size() > 150:
        events.pop_front()

static func copy() -> void:
    DisplayServer.clipboard_set(JSON.stringify({
        "build": BUILD,
        "desktop_os": OS.get_name(),
        "desktop_version": OS.get_version(),
        "events": events,
    }, "  "))
